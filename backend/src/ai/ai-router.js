// Sa7bi AI - AI provider router.
// Text and image generation keep their existing Gemini -> Workers AI flow.
// Vision uses Gemini first, then Moondream 3.1 through the existing AI binding.

import {
  generateGeminiText,
  generateGeminiImage,
  isGeminiConfigured,
  getGeminiModels,
} from "./gemini.js";

import {
  generateWorkersText,
  generateWorkersImage,
  isWorkersAIConfigured,
  getWorkersAIModels,
} from "./workers-ai.js";

import {
  generateMoondreamVision,
  MOONDREAM_VISION_MODEL,
} from "./moondream-vision.js";

function getErrorCode(error) {
  return error?.code || error?.name || "AI_PROVIDER_ERROR";
}

function getErrorMessage(error) {
  return error?.message || String(error) || "Unknown AI provider error";
}

function normalizeProviderError(error) {
  return {
    code: getErrorCode(error),
    message: getErrorMessage(error),
  };
}

function isForcedFallback(request) {
  if (!request) return false;

  try {
    const value = (request.headers.get("X-Sa7bi-Force-Fallback") || "")
      .trim()
      .toLowerCase();

    if (["1", "true", "yes"].includes(value)) return true;

    const provider = (new URL(request.url).searchParams.get("provider") || "")
      .trim()
      .toLowerCase();

    return ["workers", "workers-ai", "fallback"].includes(provider);
  } catch (_) {
    return false;
  }
}

function forcedFallbackReason() {
  return {
    code: "FORCED_FALLBACK",
    message: "Workers AI fallback was explicitly requested.",
  };
}

function normalizeMessages(messages) {
  if (!Array.isArray(messages)) return [];

  return messages.filter((message) =>
    message &&
    typeof message === "object" &&
    typeof message.content === "string" &&
    message.content.trim(),
  );
}

function buildVisionQuestion({ instructions, messages, imagePrompt }) {
  const rows = [];
  if (typeof instructions === "string" && instructions.trim()) {
    rows.push(`تعليمات المساعد:\n${instructions.trim().slice(0, 5000)}`);
  }

  const conversation = normalizeMessages(messages)
    .slice(-8)
    .map((message) => {
      const role = message.role === "assistant" ? "المساعد" : "المستخدم";
      return `${role}: ${message.content.trim()}`;
    });

  if (conversation.length) {
    rows.push(`طلب المستخدم وسياق المحادثة:\n${conversation.join("\n")}`);
  } else if (typeof imagePrompt === "string" && imagePrompt.trim()) {
    rows.push(imagePrompt.trim());
  }

  rows.push(
    "حلل الصورة الفعلية المرفقة. اذكر العناصر والنصوص الواضحة، وافصل بين ما تراه وما لا تستطيع التأكد منه. لا تخترع تفاصيل.",
  );

  return rows.join("\n\n").slice(0, 12000);
}

/**
 * Run text chat or image analysis. Images are analysed one by one by Moondream
 * when Gemini is unavailable, then combined into one user-facing answer.
 */
export async function runTextOrVisionWithFallback({
  request,
  env,
  messages = [],
  instructions = "",
  imageDataUrls = [],
  imagePrompt = "",
  maxOutputTokens = 1200,
} = {}) {
  const images = Array.isArray(imageDataUrls)
    ? imageDataUrls.filter((item) => typeof item === "string" && item.trim())
    : [];
  const cleanMessages = normalizeMessages(messages);
  const forcedFallback = isForcedFallback(request);
  let geminiFailure = null;

  if (!forcedFallback && isGeminiConfigured(env)) {
    try {
      const result = await generateGeminiText({
        env,
        messages: cleanMessages,
        instructions,
        imageDataUrls: images,
        imagePrompt,
        maxOutputTokens,
      });

      if (typeof result?.answer === "string" && result.answer.trim()) {
        return {
          answer: result.answer.trim(),
          provider: "gemini",
          fallback: false,
          fallbackReason: null,
          model: result.model || null,
          raw: result.raw,
        };
      }

      geminiFailure = {
        code: "GEMINI_EMPTY_RESPONSE",
        message: "Gemini returned no usable answer.",
      };
    } catch (error) {
      geminiFailure = normalizeProviderError(error);
    }
  } else if (!forcedFallback) {
    geminiFailure = {
      code: "GEMINI_NOT_CONFIGURED",
      message: "Gemini is not configured.",
    };
  }

  if (images.length === 0) {
    try {
      const result = await generateWorkersText({
        env,
        messages: cleanMessages,
        prompt: imagePrompt,
        systemInstruction: instructions,
        maxOutputTokens,
      });

      const answer =
        typeof result?.answer === "string"
          ? result.answer.trim()
          : "";

      if (!answer) {
        const error = new Error("WORKERS_TEXT_EMPTY");
        error.code = "WORKERS_TEXT_EMPTY";
        throw error;
      }

      return {
        answer,
        provider: "cloudflare-workers-ai",
        fallback: true,
        fallbackReason: geminiFailure || forcedFallbackReason(),
        model: result.model || null,
        raw: result.raw,
      };
    } catch (error) {
      // index.js releases the request's reserved Credits before returning
      // this exact code to Flutter. The client may then offer a user retry.
      const wrapped = new Error("ALL_AI_PROVIDERS_FAILED");
      wrapped.code = "ALL_AI_PROVIDERS_FAILED";
      wrapped.cause = {
        message: getErrorCode(error),
      };
      throw wrapped;
    }
  }

  if (!isWorkersAIConfigured(env)) {
    const error = new Error("WORKERS_AI_BINDING_MISSING");
    error.code = "WORKERS_AI_BINDING_MISSING";
    throw error;
  }

  const question = buildVisionQuestion({
    instructions,
    messages: cleanMessages,
    imagePrompt,
  });

  const answers = [];
  try {
    for (let index = 0; index < images.length; index += 1) {
      const result = await generateMoondreamVision({
        env,
        imageDataUrl: images[index],
        question,
      });

      if (result.answer) answers.push(result.answer);
    }
  } catch (error) {
    const wrapped = new Error("ALL_AI_PROVIDERS_FAILED");
    wrapped.code = "ALL_AI_PROVIDERS_FAILED";
    wrapped.cause = {
      message: getErrorCode(error),
    };
    throw wrapped;
  }

  if (answers.length === 0) {
    const error = new Error("MOONDREAM_VISION_EMPTY_RESPONSE");
    error.code = "MOONDREAM_VISION_EMPTY_RESPONSE";
    throw error;
  }

  const answer = answers.length === 1
    ? answers[0]
    : answers.map((item, index) => `الصورة ${index + 1}:\n${item}`).join("\n\n");

  return {
    answer,
    provider: "cloudflare-workers-ai",
    fallback: true,
    fallbackReason: geminiFailure || forcedFallbackReason(),
    model: MOONDREAM_VISION_MODEL,
    raw: {
      imageCount: images.length,
      analyzedImages: answers.length,
      results: answers,
    },
  };
}

/** Keep current image creation/editing path intact. */
export async function runImageWithFallback({
  request,
  env,
  prompt = "",
  imageDataUrls = [],
  aspectRatio = "1:1",
  imageSize = "1K",
} = {}) {
  const forcedFallback = isForcedFallback(request);
  let geminiFailure = null;

  if (!forcedFallback && isGeminiConfigured(env)) {
    try {
      const result = await generateGeminiImage({
        env,
        prompt,
        imageDataUrls,
        aspectRatio,
        imageSize,
      });

      if (result?.imageDataUrl) {
        return {
          imageDataUrl: result.imageDataUrl,
          mimeType: result.mimeType || "image/png",
          provider: "gemini",
          fallback: false,
          fallbackReason: null,
          model: result.model || null,
          text: result.text || "",
          raw: result.raw,
        };
      }

      geminiFailure = {
        code: "GEMINI_NO_IMAGE_RESULT",
        message: "Gemini returned no usable generated image.",
      };
    } catch (error) {
      geminiFailure = normalizeProviderError(error);
    }
  } else if (!forcedFallback) {
    geminiFailure = {
      code: "GEMINI_NOT_CONFIGURED",
      message: "Gemini is not configured.",
    };
  }

  const result = await generateWorkersImage({ env, prompt });
  if (!result?.imageDataUrl) {
    const error = new Error("WORKERS_IMAGE_EMPTY");
    error.code = "WORKERS_IMAGE_EMPTY";
    throw error;
  }

  return {
    imageDataUrl: result.imageDataUrl,
    mimeType: result.mimeType || "image/jpeg",
    provider: "cloudflare-workers-ai",
    fallback: true,
    fallbackReason: geminiFailure || forcedFallbackReason(),
    model: result.model || null,
    text: "",
    raw: result.raw,
  };
}

export function getAIStatus(env) {
  const geminiConfigured = isGeminiConfigured(env);
  const workersConfigured = isWorkersAIConfigured(env);
  const workersModels = getWorkersAIModels(env) || {};

  return {
    ok: geminiConfigured || workersConfigured,
    primary: "gemini",
    fallback: "cloudflare-workers-ai",
    gemini: {
      configured: geminiConfigured,
      models: getGeminiModels(env),
    },
    workersAI: {
      configured: workersConfigured,
      models: {
        ...workersModels,
        vision: MOONDREAM_VISION_MODEL,
      },
    },
    capabilities: {
      text: geminiConfigured || workersConfigured,
      vision: geminiConfigured || workersConfigured,
      imageGeneration: geminiConfigured || workersConfigured,
    },
  };
}
