// backend/src/index.js
// Sa7bi AI Backend
// Modular Integration - Version 6.0.0

/* =========================================================
   CORE / UTILS
   ========================================================= */

import {
  headers,
  json,
  readJsonBody,
  cleanMessages,
  isValidImageDataUrl,
  getRequestLimits,
} from "./utils.js";

/* =========================================================
   AI
   ========================================================= */

import {
  runTextOrVisionWithFallback,
  runImageWithFallback,
  getAIStatus,
} from "./ai/ai-router.js";

/* =========================================================
   CONTENT
   ========================================================= */

import {
  handleNews,
} from "./content/news.js";

import {
  handleQuranSearch,
  handleQuranCatalog,
} from "./content/quran.js";

import {
  handleShorts,
} from "./content/shorts.js";

import {
  handleHadithSearch,
  handleHadithBooks,
} from "./content/hadith.js";

import {
  handleTafsirSearch,
  handleTafsirBooks,
  handleTafsirAudio,
} from "./content/tafsir.js";

import {
  handleReligiousContent,
  handleReligiousContentTypes,
} from "./content/audio-content.js";

/* =========================================================
   MEDIA
   ========================================================= */

import {
  handleAudioSearch,
} from "./media/audio.js";

import {
  handleRadioSearch,
  handleRadioCountries,
  handleRadioByCountry,
  handleRadioHealth,
} from "./media/radio.js";

import {
  handlePodcastSearch,
  handlePodcastLookup,
  handlePodcastEpisodes,
} from "./media/podcasts.js";

/* =========================================================
   OTHER SERVICES
   ========================================================= */

import {
  handleDownload,
  handleDownloadHealth,
} from "./downloads.js";

import {
  handleHealth,
  handleDiagnostics,
  handleServiceStatus,
} from "./health.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const BACKEND_VERSION = "6.0.0";

const DOWNLOAD_URL =
  "https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/latest/download/sa7bi-ai.apk";

const MAX_MESSAGES = 20;

const MAX_IMAGES = 4;

const MAX_IMAGE_CHARS =
  8 * 1024 * 1024;

/* =========================================================
   AI INSTRUCTIONS
   ========================================================= */

function buildAIInstructions({
  serviceTitle,
  serviceContext,
}) {
  return `
أنت "صاحبي AI"، مساعد عربي ودود وعملي.

الخدمة الحالية:
${serviceTitle || "صاحبي AI"}

سياق الخدمة:
${serviceContext || "مساعد عام"}

القواعد:
- أجب بالعربية ما لم يطلب المستخدم لغة أخرى.
- استخدم المصرية عندما تكون مناسبة.
- كن واضحًا ومباشرًا.
- لا تكرر كلام المستخدم بلا فائدة.
- لا تدّعي تنفيذ شيء لم تنفذه.
- إذا كانت المعلومة غير مؤكدة وضّح ذلك.
- إذا أرسل المستخدم صورًا فحلل ما يظهر فعليًا فقط.
- لا تخمن تفاصيل غير ظاهرة في الصور.
- إذا طلب المستخدم تعديل أو إنشاء صورة، تعامل مع الطلب كطلب إبداعي واضح.
- في الخدمات المتخصصة قدم مساعدة عملية.
- في الأمور الطبية أو الدينية أو القانونية أو المالية، تجنب الادعاءات غير المؤكدة.
- إذا كان السؤال يحتاج معلومات حديثة وغير متاحة لك، وضح حدود معرفتك.
- لا تكشف مفاتيح API أو الأسرار أو تفاصيل البنية الداخلية للـWorker.
`;
}

/* =========================================================
   CHAT
   ========================================================= */

async function handleChat(
  request,
  env
) {
  const body =
    await readJsonBody(request);

  const messages =
    cleanMessages(
      body.messages
    );

  const imageDataUrls = [];

  /* ---------- Single image ---------- */

  const singleImage =
    typeof body.imageDataUrl === "string"
      ? body.imageDataUrl.trim()
      : "";

  if (singleImage) {
    imageDataUrls.push(
      singleImage
    );
  }

  /* ---------- Multiple images ---------- */

  if (
    Array.isArray(
      body.imageDataUrls
    )
  ) {
    for (
      const item of
        body.imageDataUrls
    ) {
      if (
        typeof item === "string" &&
        item.trim() &&
        !imageDataUrls.includes(
          item.trim()
        )
      ) {
        imageDataUrls.push(
          item.trim()
        );
      }

      if (
        imageDataUrls.length >=
        MAX_IMAGES
      ) {
        break;
      }
    }
  }

  /* ---------- Validate images ---------- */

  for (
    const image of imageDataUrls
  ) {
    if (
      !isValidImageDataUrl(
        image
      )
    ) {
      return json(
        {
          ok: false,
          error:
            "INVALID_IMAGE",
        },
        400
      );
    }
  }

  /* ---------- Empty request ---------- */

  if (
    !messages.length &&
    !imageDataUrls.length
  ) {
    return json(
      {
        ok: false,
        error:
          "EMPTY_MESSAGE",
      },
      400
    );
  }

  /* ---------- Service context ---------- */

  const serviceTitle =
    typeof body.serviceTitle ===
      "string"
      ? body.serviceTitle
          .trim()
          .substring(0, 200)
      : "صاحبي AI";

  const serviceContext =
    typeof body.serviceContext ===
      "string"
      ? body.serviceContext
          .trim()
          .substring(0, 1500)
      : "";

  /* ---------- Vision prompt ---------- */

  const imagePrompt =
    typeof body.imagePrompt ===
        "string" &&
      body.imagePrompt.trim()
      ? body.imagePrompt
          .trim()
          .substring(0, 4000)
      : "حلل الصور المرفقة بدقة، واقرأ أي نص واضح فيها، واشرح الأشياء المهمة الظاهرة.";

  const instructions =
    buildAIInstructions({
      serviceTitle,
      serviceContext,
    });

  /* ---------- AI ---------- */

  const result =
    await runTextOrVisionWithFallback(
      {
        request,
        env,
        messages,
        instructions,
        imageDataUrls,
        imagePrompt,
        maxOutputTokens:
          Number(
            body.maxOutputTokens
          ) || 1200,
      }
    );

  return json({
    ok: true,

    answer:
      result.answer || "",

    provider:
      result.provider || null,

    fallback:
      Boolean(
        result.fallback
      ),

    fallbackReason:
      result.fallbackReason ||
      null,

    model:
      result.model || null,

    backendVersion:
      BACKEND_VERSION,
  });
}

/* =========================================================
   IMAGE GENERATION / EDITING
   ========================================================= */

async function handleImageGeneration(
  request,
  env
) {
  const body =
    await readJsonBody(request);

  const prompt =
    typeof body.prompt ===
      "string"
      ? body.prompt.trim()
      : "";

  if (!prompt) {
    return json(
      {
        ok: false,
        error:
          "EMPTY_PROMPT",
      },
      400
    );
  }

  const imageDataUrls = [];

  /* ---------- Single image ---------- */

  if (
    typeof body.imageDataUrl ===
      "string" &&
    body.imageDataUrl.trim()
  ) {
    imageDataUrls.push(
      body.imageDataUrl.trim()
    );
  }

  /* ---------- Multiple images ---------- */

  if (
    Array.isArray(
      body.imageDataUrls
    )
  ) {
    for (
      const item of
        body.imageDataUrls
    ) {
      if (
        typeof item === "string" &&
        item.trim() &&
        !imageDataUrls.includes(
          item.trim()
        )
      ) {
        imageDataUrls.push(
          item.trim()
        );
      }

      if (
        imageDataUrls.length >=
        MAX_IMAGES
      ) {
        break;
      }
    }
  }

  /* ---------- Validate images ---------- */

  for (
    const image of imageDataUrls
  ) {
    if (
      !isValidImageDataUrl(
        image
      )
    ) {
      return json(
        {
          ok: false,
          error:
            "INVALID_IMAGE",
        },
        400
      );
    }
  }

  const aspectRatio =
    typeof body.aspectRatio ===
        "string" &&
      body.aspectRatio.trim()
      ? body.aspectRatio.trim()
      : "1:1";

  const imageSize =
    typeof body.imageSize ===
        "string" &&
      body.imageSize.trim()
      ? body.imageSize.trim()
      : "1K";

  const result =
    await runImageWithFallback(
      {
        request,
        env,

        prompt:
          prompt.substring(
            0,
            6000
          ),

        imageDataUrls,

        aspectRatio,

        imageSize,
      }
    );

  return json({
    ok: true,

    imageDataUrl:
      result.imageDataUrl || null,

    mimeType:
      result.mimeType || null,

    provider:
      result.provider || null,

    fallback:
      Boolean(
        result.fallback
      ),

    fallbackReason:
      result.fallbackReason ||
      null,

    model:
      result.model || null,

    text:
      result.text || "",

    backendVersion:
      BACKEND_VERSION,
  });
}

/* =========================================================
   ROOT
   ========================================================= */

function handleRoot() {
  return json({
    ok: true,

    app:
      "Sa7bi AI",

    backendVersion:
      BACKEND_VERSION,

    status:
      "online",

    architecture:
      "modular",

    features: {
      chat: true,

      imageAnalysis: true,

      multiImageVision: true,

      videoFrameAnalysis:
        true,

      imageGeneration:
        true,

      imageEditing:
        true,

      news: true,

      audio: true,

      quran: true,

      hadith: true,

      tafsir: true,

      radio: true,

      podcasts: true,

      shorts: true,

      downloads: true,
    },

    ai: {
      primary:
        "gemini",

      fallback:
        "cloudflare_workers_ai",
    },

    endpoints: {
      chat:
        "/v1/chat",

      image:
        "/v1/image",

      news:
        "/v1/news",

      audio:
        "/v1/audio/search-v4",

      quran:
        "/v1/audio/quran",

      hadith:
        "/v1/hadith",

      hadithBooks:
        "/v1/hadith/books",

      tafsir:
        "/v1/tafsir",

      tafsirBooks:
        "/v1/tafsir/books",

      tafsirAudio:
        "/v1/tafsir/audio",

      religious:
        "/v1/religious",

      religiousTypes:
        "/v1/religious/types",

      radio:
        "/v1/radio/search",

      radioCountries:
        "/v1/radio/countries",

      radioCountry:
        "/v1/radio/country?country=EG",

      radioStations:
        "/v1/radio/stations?country=EG",

      radioHealth:
        "/v1/radio/health",

      podcasts:
        "/v1/podcasts/search",

      podcast:
        "/v1/podcasts/lookup",

      podcastEpisodes:
        "/v1/podcasts/episodes",

      shorts:
        "/v1/shorts",

      download:
        "/download",

      downloadHealth:
        "/download/health",

      health:
        "/health",

      serviceStatus:
        "/v1/service-status",

      diagnostics:
        "/v1/diagnostics",
    },

    limits:
      getRequestLimits(),

    apk:
      DOWNLOAD_URL,
  });
}

/* =========================================================
   WORKER ENTRY
   ========================================================= */

export default {
  async fetch(
    request,
    env
  ) {
    try {
      /* =====================================================
         CORS PREFLIGHT
         ===================================================== */

      if (
        request.method ===
        "OPTIONS"
      ) {
        return new Response(
          null,
          {
            status: 204,
            headers:
              headers(),
          }
        );
      }

      const url =
        new URL(
          request.url
        );

      const path =
        url.pathname.replace(
          /\/+$/,
          ""
        ) || "/";

      /* =====================================================
         ROOT
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path === "/"
      ) {
        return handleRoot();
      }

      /* =====================================================
         HEALTH
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path === "/health"
      ) {
        return handleHealth(
          env
        );
      }

      /* =====================================================
         DIAGNOSTICS
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/diagnostics"
      ) {
        return handleDiagnostics(
          env
        );
      }

      /* =====================================================
         SERVICE STATUS
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/service-status"
      ) {
        return handleServiceStatus(
          env
        );
      }

      /* =====================================================
         DOWNLOAD
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path === "/download"
      ) {
        return handleDownload(
          request
        );
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/download/health"
      ) {
        return handleDownloadHealth();
      }

      /* =====================================================
         NEWS
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path === "/v1/news"
      ) {
        return handleNews();
      }

      /* =====================================================
         AUDIO SEARCH
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        (
          path ===
            "/v1/audio/search" ||
          path ===
            "/v1/audio/search-v4"
        )
      ) {
        return handleAudioSearch(
          request
        );
      }

      /* =====================================================
         QURAN
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/audio/quran"
      ) {
        return handleQuranCatalog();
      }

      /* =====================================================
         HADITH
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/hadith"
      ) {
        return handleHadithSearch(
          request
        );
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/hadith/books"
      ) {
        return handleHadithBooks();
      }

      /* =====================================================
         TAFSIR
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/tafsir"
      ) {
        return handleTafsirSearch(
          request
        );
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/tafsir/books"
      ) {
        return handleTafsirBooks();
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/tafsir/audio"
      ) {
        return handleTafsirAudio(
          request
        );
      }

      /* =====================================================
         RELIGIOUS CONTENT AGGREGATOR
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/religious"
      ) {
        return handleReligiousContent(
          request
        );
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/religious/types"
      ) {
        return handleReligiousContentTypes();
      }

      /* =====================================================
         RADIO - GENERAL SEARCH
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/search"
      ) {
        return handleRadioSearch(
          request
        );
      }

      /* =====================================================
         RADIO - COUNTRIES
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/countries"
      ) {
        return handleRadioCountries();
      }

      /* =====================================================
         RADIO - COUNTRY
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/country"
      ) {
        const countryCode =
          url.searchParams.get(
            "country"
          ) ||
          url.searchParams.get(
            "countryCode"
          ) ||
          "";

        const limit =
          Number(
            url.searchParams.get(
              "limit"
            ) || 50
          );

        return handleRadioByCountry(
          countryCode,
          limit
        );
      }

      /* =====================================================
         RADIO - LEGACY STATIONS
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/stations"
      ) {
        /*
         * Keep the old endpoint alive for the
         * current Flutter application.
         */

        return handleRadioSearch(
          request
        );
      }

      /* =====================================================
         RADIO HEALTH
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/health"
      ) {
        return handleRadioHealth();
      }

      /* =====================================================
         PODCAST SEARCH
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/podcasts/search"
      ) {
        return handlePodcastSearch(
          request
        );
      }

      /* =====================================================
         PODCAST LOOKUP
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/podcasts/lookup"
      ) {
        return handlePodcastLookup(
          request
        );
      }

      /* =====================================================
         PODCAST EPISODES
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/podcasts/episodes"
      ) {
        return handlePodcastEpisodes(
          request
        );
      }

      /* =====================================================
         SHORTS
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/shorts"
      ) {
        return handleShorts();
      }

      /* =====================================================
         CHAT
         ===================================================== */

      if (
        request.method ===
          "POST" &&
        path ===
          "/v1/chat"
      ) {
        return handleChat(
          request,
          env
        );
      }

      /* =====================================================
         IMAGE
         ===================================================== */

      if (
        request.method ===
          "POST" &&
        path ===
          "/v1/image"
      ) {
        return handleImageGeneration(
          request,
          env
        );
      }

      /* =====================================================
         404
         ===================================================== */

      return json(
        {
          ok: false,

          error:
            "NOT_FOUND",

          path,

          backendVersion:
            BACKEND_VERSION,
        },
        404
      );
    } catch (error) {
      const message =
        error?.message ||
        "INTERNAL_ERROR";

      /* =====================================================
         REQUEST ERRORS
         ===================================================== */

      if (
        message ===
        "BODY_TOO_LARGE"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          413
        );
      }

      if (
        message ===
        "INVALID_JSON_BODY"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          400
        );
      }

      /* =====================================================
         AI CONFIG ERRORS
         ===================================================== */

      if (
        message ===
        "GEMINI_API_KEY_MISSING"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          500
        );
      }

      if (
        message ===
        "WORKERS_AI_BINDING_MISSING"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          500
        );
      }

      if (
        message ===
        "NO_AI_PROVIDER_CONFIGURED"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          500
        );
      }

      /* =====================================================
         AI PROVIDER FAILURES
         ===================================================== */

      if (
        message ===
          "ALL_AI_PROVIDERS_FAILED" ||
        message ===
          "ALL_IMAGE_PROVIDERS_FAILED"
      ) {
        return json(
          {
            ok: false,

            error:
              message,

            details:
              error?.cause?.message ||
              error?.message ||
              "",
          },
          502
        );
      }

      /* =====================================================
         GENERIC ERROR
         ===================================================== */

      return json(
        {
          ok: false,

          error:
            message,

          backendVersion:
            BACKEND_VERSION,
        },
        500
      );
    }
  },
};
