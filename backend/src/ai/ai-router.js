// backend/src/ai/ai-router.js
// Sa7bi AI - AI Provider Router
//
// Architecture:
//   Flutter App
//       ↓
//   Cloudflare Worker
//       ↓
//   Gemini (Primary)
//       ↓ on failure/unavailable
//   Cloudflare Workers AI (Fallback)
//
// Responsibilities:
// - Text generation routing
// - Vision/image analysis routing
// - Image generation routing
// - Automatic Gemini → Workers AI fallback
// - Explicit fallback testing
// - Provider/capability status
//
// Security:
// - No API keys are exposed here.
// - Gemini key is read only by gemini.js from Worker secrets.
// - Workers AI uses the Cloudflare AI binding.

/* -------------------------------------------------------------------------- */
/* Providers                                                                  */
/* -------------------------------------------------------------------------- */

import {
  generateGeminiText,
  generateGeminiImage,
  isGeminiConfigured,
  getGeminiModels,
} from "./gemini.js";

import {
  generateWorkersText,
  generateWorkersVision,
  generateWorkersImage,
  isWorkersAIConfigured,
  getWorkersAIModels,
} from "./workers-ai.js";

/* -------------------------------------------------------------------------- */
/* Error helpers                                                              */
/* -------------------------------------------------------------------------- */

function getErrorCode(error) {
  return (
    error?.code ||
    error?.name ||
    "AI_PROVIDER_ERROR"
  );
}

function getErrorMessage(error) {
  return (
    error?.message ||
    String(error) ||
    "Unknown AI provider error"
  );
}

function normalizeProviderError(error) {
  return {
    code: getErrorCode(error),
    message: getErrorMessage(error),
  };
}

/* -------------------------------------------------------------------------- */
/* Provider selection                                                         */
/* -------------------------------------------------------------------------- */

/**
 * Force Workers AI for testing.
 *
 * Supported:
 *
 * Header:
 *   X-Sa7bi-Force-Fallback: 1
 *
 * Query:
 *   ?provider=workers
 *   ?provider=workers-ai
 *   ?provider=fallback
 *
 * This is intentionally a test mechanism.
 * It does not expose any provider credentials.
 */
function isForcedFallback(request) {
  if (!request) {
    return false;
  }

  try {
    const headerValue =
      request.headers.get(
        "X-Sa7bi-Force-Fallback"
      ) || "";

    const normalizedHeader =
      headerValue
        .trim()
        .toLowerCase();

    if (
      normalizedHeader === "1" ||
      normalizedHeader === "true" ||
      normalizedHeader === "yes"
    ) {
      return true;
    }

    const url =
      new URL(request.url);

    const provider =
      (
        url.searchParams.get(
          "provider"
        ) || ""
      )
        .trim()
        .toLowerCase();

    return (
      provider === "workers" ||
      provider === "workers-ai" ||
      provider === "fallback"
    );
  } catch {
    return false;
  }
}

/**
 * Create the standard fallback reason.
 */
function forcedFallbackReason() {
  return {
    code: "FORCED_FALLBACK",
    message:
      "Workers AI fallback was explicitly requested.",
  };
}

/* -------------------------------------------------------------------------- */
/* Text / Vision router                                                       */
/* -------------------------------------------------------------------------- */

export async function runTextOrVisionWithFallback({
  request,
  env,
  messages = [],
  instructions = "",
  imageDataUrls = [],
  imagePrompt = "",
  maxOutputTokens = 1200,
} = {}) {
  const images =
    Array.isArray(imageDataUrls)
      ? imageDataUrls.filter(
          (item) =>
            typeof item === "string" &&
            item.trim()
        )
      : [];

  const forcedFallback =
    isForcedFallback(request);

  let geminiFailure = null;

  /* ------------------------------------------------------------------------ */
  /* Primary: Gemini                                                          */
  /* ------------------------------------------------------------------------ */

  if (
    !forcedFallback &&
    isGeminiConfigured(env)
  ) {
    try {
      const result =
        await generateGeminiText({
          env,
          messages,
          instructions,
          imageDataUrls: images,
          imagePrompt,
          maxOutputTokens,
        });

      if (
        typeof result?.answer === "string" &&
        result.answer.trim()
      ) {
        return {
          answer:
            result.answer.trim(),

          provider:
            "gemini",

          fallback:
            false,

          fallbackReason:
            null,

          model:
            result.model || null,

          raw:
            result.raw,
        };
      }

      geminiFailure = {
        code:
          "GEMINI_EMPTY_RESPONSE",

        message:
          "Gemini returned no usable answer.",
      };
    } catch (error) {
      geminiFailure =
        normalizeProviderError(
          error
        );
    }
  } else if (!forcedFallback) {
    geminiFailure = {
      code:
        "GEMINI_NOT_CONFIGURED",

      message:
        "Gemini is not configured.",
    };
  }

  /* ------------------------------------------------------------------------ */
  /* Fallback: Workers AI text                                                */
  /* ------------------------------------------------------------------------ */

  if (!images.length) {
    const result =
      await generateWorkersText({
        env,
        messages,
        prompt: imagePrompt,
        systemInstruction:
          instructions,
        maxOutputTokens,
      });

    const answer =
      typeof result?.answer ===
        "string"
        ? result.answer.trim()
        : "";

    if (!answer) {
      throw new Error(
        "WORKERS_TEXT_EMPTY"
      );
    }

    return {
      answer,

      provider:
        "cloudflare-workers-ai",

      fallback:
        true,

      fallbackReason:
        geminiFailure ||
        forcedFallbackReason(),

      model:
        result.model || null,

      raw:
        result.raw,
    };
  }

  /* ------------------------------------------------------------------------ */
  /* Fallback: Workers AI Vision                                              */
  /* ------------------------------------------------------------------------ */
  //
  // Gemini can receive multiple images in a single request.
  //
  // The Workers AI vision provider is intentionally called
  // once per image. This keeps the provider request shape
  // compatible with the configured Llama Vision model.
  //

  if (
    !isWorkersAIConfigured(env)
  ) {
    const error =
      new Error(
        "WORKERS_AI_BINDING_MISSING"
      );

    error.code =
      "WORKERS_AI_BINDING_MISSING";

    throw error;
  }

  const visionAnswers = [];

  for (
    let index = 0;
    index < images.length;
    index += 1
  ) {
    const result =
      await generateWorkersVision({
        env,

        messages,

        prompt:
          imagePrompt ||
          "حلل الصورة المرفقة بدقة، واقرأ النصوص الواضحة فيها، واشرح الأشياء المهمة الظاهرة فقط دون تخمين.",

        systemInstruction:
          instructions,

        imageDataUrls: [
          images[index],
        ],

        maxOutputTokens,
      });

    const answer =
      typeof result?.answer ===
        "string"
        ? result.answer.trim()
        : "";

    if (answer) {
      visionAnswers.push(
        answer
      );
    }
  }

  if (!visionAnswers.length) {
    const error =
      new Error(
        "WORKERS_VISION_EMPTY"
      );

    error.code =
      "WORKERS_VISION_EMPTY";

    throw error;
  }

  const combinedAnswer =
    visionAnswers.length === 1
      ? visionAnswers[0]
      : visionAnswers
          .map(
            (
              answer,
              index
            ) =>
              `الصورة ${index + 1}:\n${answer}`
          )
          .join("\n\n");

  return {
    answer:
      combinedAnswer,

    provider:
      "cloudflare-workers-ai",

    fallback:
      true,

    fallbackReason:
      geminiFailure ||
      forcedFallbackReason(),

    model:
      getWorkersAIModels(
        env
      ).vision,

    raw: {
      imageCount:
        images.length,

      analyzedImages:
        visionAnswers.length,

      results:
        visionAnswers,
    },
  };
}

/* -------------------------------------------------------------------------- */
/* Image generation router                                                   */
/* -------------------------------------------------------------------------- */

export async function runImageWithFallback({
  request,
  env,
  prompt = "",
  imageDataUrls = [],
  aspectRatio = "1:1",
  imageSize = "1K",
} = {}) {
  const forcedFallback =
    isForcedFallback(request);

  let geminiFailure = null;

  /* ------------------------------------------------------------------------ */
  /* Primary: Gemini Image                                                    */
  /* ------------------------------------------------------------------------ */

  if (
    !forcedFallback &&
    isGeminiConfigured(env)
  ) {
    try {
      const result =
        await generateGeminiImage({
          env,

          prompt,

          imageDataUrls,

          aspectRatio,

          imageSize,
        });

      if (
        result?.imageDataUrl
      ) {
        return {
          imageDataUrl:
            result.imageDataUrl,

          mimeType:
            result.mimeType ||
            "image/png",

          provider:
            "gemini",

          fallback:
            false,

          fallbackReason:
            null,

          model:
            result.model ||
            null,

          text:
            result.text ||
            "",

          raw:
            result.raw,
        };
      }

      geminiFailure = {
        code:
          "GEMINI_NO_IMAGE_RESULT",

        message:
          "Gemini returned no usable generated image.",
      };
    } catch (error) {
      geminiFailure =
        normalizeProviderError(
          error
        );
    }
  } else if (!forcedFallback) {
    geminiFailure = {
      code:
        "GEMINI_NOT_CONFIGURED",

      message:
        "Gemini is not configured.",
    };
  }

  /* ------------------------------------------------------------------------ */
  /* Fallback: Workers AI / FLUX                                             */
  /* ------------------------------------------------------------------------ */

  const result =
    await generateWorkersImage({
      env,
      prompt,
    });

  if (!result?.imageDataUrl) {
    const error =
      new Error(
        "WORKERS_IMAGE_EMPTY"
      );

    error.code =
      "WORKERS_IMAGE_EMPTY";

    throw error;
  }

  return {
    imageDataUrl:
      result.imageDataUrl,

    mimeType:
      result.mimeType ||
      "image/jpeg",

    provider:
      "cloudflare-workers-ai",

    fallback:
      true,

    fallbackReason:
      geminiFailure ||
      forcedFallbackReason(),

    model:
      result.model ||
      null,

    text:
      "",

    raw:
      result.raw,
  };
}

/* -------------------------------------------------------------------------- */
/* AI status                                                                  */
/* -------------------------------------------------------------------------- */

export function getAIStatus(env) {
  const geminiConfigured =
    isGeminiConfigured(env);

  const workersConfigured =
    isWorkersAIConfigured(env);

  return {
    ok:
      geminiConfigured ||
      workersConfigured,

    primary:
      "gemini",

    fallback:
      "cloudflare-workers-ai",

    gemini: {
      configured:
        geminiConfigured,

      models:
        getGeminiModels(
          env
        ),
    },

    workersAI: {
      configured:
        workersConfigured,

      models:
        getWorkersAIModels(
          env
        ),
    },

    capabilities: {
      text:
        geminiConfigured ||
        workersConfigured,

      vision:
        geminiConfigured ||
        workersConfigured,

      imageGeneration:
        geminiConfigured ||
        workersConfigured,
    },
  };
}
