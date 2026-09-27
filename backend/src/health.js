// backend/src/health.js
// Sa7bi AI Backend - Health & Diagnostics
// Final Backend Version: 6.3.0

import {
  json,
} from "./utils.js";

import {
  getAIStatus,
} from "./ai/ai-router.js";

const BACKEND_VERSION = "6.3.0";

/* -------------------------------------------------------------------------- */
/* Health check                                                               */
/* -------------------------------------------------------------------------- */

/**
 * Basic public Worker health check.
 *
 * This endpoint:
 * - confirms that the Worker is running
 * - reports the backend version
 * - reports safe AI provider status
 *
 * It NEVER exposes secrets.
 */
export async function handleHealth(
  env
) {
  let aiStatus;

  try {
    aiStatus =
      getAIStatus(env);
  } catch (_) {
    aiStatus = {
      ok: false,
      error:
        "AI status unavailable",
    };
  }

  return json({
    ok: true,

    service:
      "Sa7bi AI Backend",

    status:
      "healthy",

    backendVersion:
      BACKEND_VERSION,

    timestamp:
      new Date().toISOString(),

    ai:
      aiStatus,
  });
}

/* -------------------------------------------------------------------------- */
/* Detailed diagnostics                                                       */
/* -------------------------------------------------------------------------- */

/**
 * Detailed diagnostics for backend testing.
 *
 * IMPORTANT:
 * This endpoint reports configuration state only.
 * It NEVER returns:
 * - Gemini API keys
 * - OpenAI API keys
 * - AdMob secrets
 * - Durable Object data
 * - request data
 * - user data
 */
export async function handleDiagnostics(
  env
) {
  let aiStatus;

  try {
    aiStatus =
      getAIStatus(env);
  } catch (_) {
    aiStatus = {
      ok: false,
      error:
        "Unable to read AI status",
    };
  }

  const geminiConfigured =
    Boolean(
      env?.GEMINI_API_KEY
    );

  const openAIConfigured =
    Boolean(
      env?.OPENAI_API_KEY
    );

  const workersAIConfigured =
    Boolean(
      env?.AI &&
      typeof env.AI.run ===
        "function"
    );

  const creditsConfigured =
    Boolean(
      env?.SA7BI_CREDITS
    );

  return json({
    ok: true,

    service:
      "Sa7bi AI Backend",

    backendVersion:
      BACKEND_VERSION,

    timestamp:
      new Date().toISOString(),

    runtime: {
      platform:
        "Cloudflare Workers",

      environment:
        "production",

      aiBinding:
        workersAIConfigured,

      creditsBinding:
        creditsConfigured,
    },

    providers: {
      gemini: {
        configured:
          geminiConfigured,
      },

      workersAI: {
        configured:
          workersAIConfigured,
      },

      openAI: {
        configured:
          openAIConfigured,
      },
    },

    models: {
      geminiText:
        env?.GEMINI_TEXT_MODEL ||
        "gemini-3.8-flash",

      geminiImage:
        env?.GEMINI_IMAGE_MODEL ||
        "gemini-3.1-flash-image",

      workersText:
        env?.WORKERS_TEXT_MODEL ||
        "@cf/meta/llama-3.3-70b-instruct-fp8-fast",

      workersVision:
        env?.WORKERS_VISION_MODEL ||
        "@cf/meta/llama-3.2-11b-vision-instruct",

      workersImage:
        env?.WORKERS_IMAGE_MODEL ||
        "@cf/black-forest-labs/flux-1-schnell",
    },

    ai:
      aiStatus,
  });
}

/* -------------------------------------------------------------------------- */
/* Public service status                                                      */
/* -------------------------------------------------------------------------- */

/**
 * Small public-safe status endpoint.
 *
 * The Flutter app can use this to determine whether
 * the backend services are available.
 *
 * No provider secrets or internal configuration
 * are returned here.
 */
export async function handleServiceStatus(
  env
) {
  let aiStatus;

  try {
    aiStatus =
      getAIStatus(env);
  } catch (_) {
    aiStatus = {
      ok: false,
    };
  }

  const aiAvailable =
    Boolean(
      aiStatus?.ok
    );

  return json({
    ok: true,

    service:
      "Sa7bi AI",

    backendVersion:
      BACKEND_VERSION,

    services: {
      ai:
        aiAvailable,

      news: true,

      audio: true,

      quran: true,

      hadith: true,

      tafsir: true,

      radio: true,

      podcasts: true,

      shorts: true,

      downloads: true,

      credits: true,

      rewardedAds: true,
    },

    timestamp:
      new Date().toISOString(),
  });
}

/* -------------------------------------------------------------------------- */
/* Exports                                                                    */
/* -------------------------------------------------------------------------- */

export {
  BACKEND_VERSION,
};

export default {
  handleHealth,
  handleDiagnostics,
  handleServiceStatus,
};
