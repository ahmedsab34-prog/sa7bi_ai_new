// backend/src/health.js
// Sa7bi AI Backend - Health & Diagnostics Module
// Version: 6.0.0

import {
  json,
} from "./utils.js";

import {
  getAIStatus,
} from "./ai/ai-router.js";

const BACKEND_VERSION = "6.0.0";

/**
 * Basic Worker health check.
 */
export async function handleHealth(
  env
) {
  let aiStatus = null;

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

/**
 * Detailed diagnostics endpoint.
 *
 * This endpoint must NEVER return secret values.
 * It only reports whether required services/configuration
 * are present and which provider is configured.
 */
export async function handleDiagnostics(
  env
) {
  let aiStatus = null;

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
      env?.AI
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

      aiBinding:
        workersAIConfigured,

      environment:
        "production",
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

/**
 * Public-safe service status.
 *
 * This is intentionally smaller than diagnostics and
 * does not expose provider configuration details.
 */
export async function handleServiceStatus(
  env
) {
  let aiStatus = null;

  try {
    aiStatus =
      getAIStatus(env);
  } catch (_) {
    aiStatus = {
      ok: false,
    };
  }

  return json({
    ok: true,

    service:
      "Sa7bi AI",

    backendVersion:
      BACKEND_VERSION,

    services: {
      ai:
        Boolean(
          aiStatus?.ok
        ),

      news: true,

      audio: true,

      quran: true,

      radio: true,

      podcasts: true,

      shorts: true,

      downloads: true,
    },

    timestamp:
      new Date().toISOString(),
  });
}

export default {
  handleHealth,
  handleDiagnostics,
  handleServiceStatus,
};
