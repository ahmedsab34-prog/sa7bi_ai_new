/**
 * Sa7bi AI
 * AI Provider Router
 *
 * Primary provider:
 *   Gemini
 *
 * Automatic fallback:
 *   Cloudflare Workers AI
 *
 * This file:
 * - Routes text requests.
 * - Routes image/vision requests.
 * - Routes image generation requests.
 * - Supports forced fallback testing.
 * - Never exposes API keys.
 */

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

/* =========================================================
   ERROR HELPERS
   ========================================================= */

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

/* =========================================================
   FORCE FALLBACK
   ========================================================= */

/**
 * Used only for testing.
 *
 * Supported:
 *   Header:
 *     X-Sa7bi-Force-Fallback: 1
 *
 *   Query:
 *     ?provider=workers
 *     ?provider=workers-ai
 *     ?provider=fallback
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

/* =========================================================
   TEXT / VISION ROUTER
   ========================================================= */

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

  /* -------------------------------------------------------
     PRIMARY: GEMINI
     ------------------------------------------------------- */

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

      return {
        answer:
          result.answer || "",

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

  /* -------------------------------------------------------
     FALLBACK: WORKERS AI
     ------------------------------------------------------- */

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

    return {
      answer:
        result.answer || "",

      provider:
        "cloudflare-workers-ai",

      fallback:
        true,

      fallbackReason:
        geminiFailure || {
          code:
            "FORCED_FALLBACK",

          message:
            "Workers AI fallback was explicitly requested.",
        },

      model:
        result.model || null,

      raw:
        result.raw,
    };
  }

  /* -------------------------------------------------------
     VISION FALLBACK
     -------------------------------------------------------

     Gemini can analyze multiple images in one request.

     The Workers AI vision provider is called one image
     at a time here. The individual answers are combined
     into one final answer.
  */

  if (
    !isWorkersAIConfigured(env)
  ) {
    throw new Error(
      "WORKERS_AI_BINDING_MISSING"
    );
  }

  const visionAnswers = [];

  for (
    let index = 0;
    index < images.length;
    index += 1
  ) {
    const image =
      images[index];

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
          image,
        ],

        maxOutputTokens,
      });

    visionAnswers.push(
      result.answer || ""
    );
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
              `الصورة ${index + 1}:
${answer}`
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
      geminiFailure || {
        code:
          "FORCED_FALLBACK",

        message:
          "Workers AI fallback was explicitly requested.",
      },

    model:
      getWorkersAIModels(
        env
      ).vision,

    raw: {
      imageCount:
        images.length,

      results:
        visionAnswers,
    },
  };
}

/* =========================================================
   IMAGE GENERATION ROUTER
   ========================================================= */

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

  /* -------------------------------------------------------
     PRIMARY: GEMINI IMAGE
     ------------------------------------------------------- */

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

      return {
        imageDataUrl:
          result.imageDataUrl ||
          null,

        mimeType:
          result.mimeType ||
          null,

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

  /* -------------------------------------------------------
     FALLBACK: FLUX / WORKERS AI
     ------------------------------------------------------- */

  const result =
    await generateWorkersImage({
      env,

      prompt,
    });

  return {
    imageDataUrl:
      result.imageDataUrl ||
      null,

    mimeType:
      result.mimeType ||
      null,

    provider:
      "cloudflare-workers-ai",

    fallback:
      true,

    fallbackReason:
      geminiFailure || {
        code:
          "FORCED_FALLBACK",

        message:
          "Workers AI image fallback was explicitly requested.",
      },

    model:
      result.model ||
      null,

    text:
      "",

    raw:
      result.raw,
  };
}

/* =========================================================
   AI STATUS
   ========================================================= */

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
