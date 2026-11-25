// Sa7bi AI Backend - Health & Diagnostics
// Health reports Worker execution; service status never claims an upstream
// service is available unless a live probe has actually been performed.

import { json } from "./utils.js";
import { getAIStatus } from "./ai/ai-router.js";
import { MOONDREAM_VISION_MODEL } from "./ai/moondream-vision.js";

const BACKEND_VERSION = "6.3.1";

function getSourceCommit(env) {
  const value = String(env?.SA7BI_SOURCE_COMMIT || "").trim();
  return value || "unknown";
}

function getSafeAIStatus(env) {
  try {
    return getAIStatus(env);
  } catch (_) {
    return {
      ok: false,
      error: "AI status unavailable",
    };
  }
}

export async function handleHealth(env) {
  const aiStatus = getSafeAIStatus(env);

  return json({
    ok: true,
    service: "Sa7bi AI Backend",
    status: "healthy",
    backendVersion: BACKEND_VERSION,
    sourceCommit: getSourceCommit(env),
    timestamp: new Date().toISOString(),
    ai: aiStatus,
  });
}

export async function handleDiagnostics(env) {
  const aiStatus = getSafeAIStatus(env);

  const geminiConfigured = Boolean(
    env?.GEMINI_API_KEY,
  );

  const openAIConfigured = Boolean(
    env?.OPENAI_API_KEY,
  );

  const workersAIConfigured = Boolean(
    env?.AI &&
    typeof env.AI.run === "function",
  );

  const creditsConfigured = Boolean(
    env?.SA7BI_CREDITS,
  );

  return json({
    ok: true,
    service: "Sa7bi AI Backend",
    backendVersion: BACKEND_VERSION,
    sourceCommit: getSourceCommit(env),
    timestamp: new Date().toISOString(),

    runtime: {
      platform: "Cloudflare Workers",
      environment: "production",
      aiBinding: workersAIConfigured,
      creditsBinding: creditsConfigured,
    },

    providers: {
      gemini: {
        configured: geminiConfigured,
      },
      workersAI: {
        configured: workersAIConfigured,
      },
      openAI: {
        configured: openAIConfigured,
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
        aiStatus?.workersAI?.models?.vision ||
        MOONDREAM_VISION_MODEL,

      workersImage:
        env?.WORKERS_IMAGE_MODEL ||
        "@cf/black-forest-labs/flux-1-schnell",
    },

    ai: aiStatus,
  });
}

const SERVICE_DEFINITIONS = Object.freeze({
  ai: {
    endpoints: [
      "/v1/chat",
      "/v1/image",
    ],
    configured: (env, aiStatus) =>
      Boolean(aiStatus?.ok),
  },

  news: {
    endpoints: [
      "/v1/news",
    ],
  },

  audio: {
    endpoints: [
      "/v1/audio/search",
      "/v1/audio/search-v4",
    ],
  },

  quran: {
    endpoints: [
      "/v1/audio/quran",
    ],
  },

  hadith: {
    endpoints: [
      "/v1/hadith",
      "/v1/hadith/books",
    ],
  },

  tafsir: {
    endpoints: [
      "/v1/tafsir",
      "/v1/tafsir/books",
      "/v1/tafsir/audio",
      "/v1/tafsir-text",
      "/v1/tafsir-text/books",
    ],
  },

  radio: {
    endpoints: [
      "/v1/radio/search",
      "/v1/radio/countries",
      "/v1/radio/country",
      "/v1/radio/station",
      "/v1/radio/stations",
      "/v1/radio/health",
    ],
  },

  podcasts: {
    endpoints: [
      "/v1/podcasts/search",
      "/v1/podcasts/lookup",
      "/v1/podcasts/episodes",
    ],
  },

  shorts: {
    endpoints: [
      "/v1/shorts",
    ],
  },

  downloads: {
    endpoints: [
      "/download",
      "/download/health",
    ],
  },

  credits: {
    endpoints: [
      "/v1/credits",
    ],
    configured: (env) =>
      Boolean(env?.SA7BI_CREDITS),
  },

  rewardedAds: {
    endpoints: [
      "/v1/rewards/admob/ssv",
    ],
    configured: (env) =>
      Boolean(env?.ADMOB_REWARDED_AD_UNIT_ID),
  },
});

export async function handleServiceStatus(env) {
  const aiStatus = getSafeAIStatus(env);

  const serviceDetails = {};
  const services = {};

  let notChecked = 0;

  for (
    const [name, definition]
    of Object.entries(SERVICE_DEFINITIONS)
  ) {
    let configured = null;

    if (typeof definition.configured === "function") {
      configured = definition.configured(
        env,
        aiStatus,
      );
    }

    serviceDetails[name] = {
      routeRegistered: true,
      endpoints: [...definition.endpoints],
      configured,
      available: null,
      availability: "not_checked",
    };

    // Backward-compatible flat field:
    // null means unknown, never false success.
    services[name] = null;

    notChecked += 1;
  }

  return json({
    ok: true,
    service: "Sa7bi AI",
    backendVersion: BACKEND_VERSION,
    sourceCommit: getSourceCommit(env),

    status: "not_checked",
    checkMode: "configuration_only_no_live_upstream_probes",

    services,
    serviceDetails,

    summary: {
      total: Object.keys(SERVICE_DEFINITIONS).length,
      checked: 0,
      notChecked,
      available: null,
    },

    timestamp: new Date().toISOString(),
  });
}

export { BACKEND_VERSION };

export default {
  handleHealth,
  handleDiagnostics,
  handleServiceStatus,
};
