// backend/src/index.js
// Sa7bi AI Backend
// Modular Integration - Version 6.2.0

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
} from "./ai/ai-router.js";

/* =========================================================
   CREDITS
   ========================================================= */

import {
  Sa7biCredits,
} from "./credits.js";

import {
  getCreditDeviceId,
  getCreditRequestId,
  getChatCreditOperation,
  getImageCreditOperation,
  handleCreditsBalance,
  reserveAIRequestCredits,
  commitAIRequestCredits,
  releaseAIRequestCredits,
  getSafeCreditSummary,
} from "./credits-router.js";

/* =========================================================
   ADMOB REWARDED ADS - SERVER SIDE VERIFICATION
   ========================================================= */

import {
  handleAdMobSSV,
  getAdMobSSVStatus,
} from "./admob-ssv.js";

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

const BACKEND_VERSION =
  "6.2.0";

const DOWNLOAD_URL =
  "https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/latest/download/sa7bi-ai.apk";

const MAX_IMAGES = 4;

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
   CREDIT ERROR HELPER
   ========================================================= */

function creditErrorResponse(
  result,
) {
  if (!result) {
    return json(
      {
        ok: false,
        error:
          "CREDIT_SYSTEM_ERROR",
      },
      500,
    );
  }

  let status = 500;

  switch (
    result.error
  ) {
    case "DEVICE_ID_REQUIRED":
      status = 400;
      break;

    case "REQUEST_ID_REQUIRED":
      status = 400;
      break;

    case "UNKNOWN_CREDIT_OPERATION":
      status = 400;
      break;

    case "INSUFFICIENT_CREDITS":
      status = 402;
      break;

    case "REQUEST_ALREADY_FINALIZED":
      status = 409;
      break;

    case "RESERVATION_NOT_FOUND":
      status = 409;
      break;

    case "RESERVATION_NOT_ACTIVE":
      status = 409;
      break;

    case "RESERVATION_EXPIRED":
      status = 409;
      break;

    case "REQUEST_ALREADY_COMMITTED":
      status = 409;
      break;

    default:
      status = 500;
  }

  return json(
    {
      ok: false,

      error:
        result.error ||
        "CREDIT_SYSTEM_ERROR",

      required:
        result.required,

      available:
        result.available,

      credits:
        getSafeCreditSummary(
          result,
        ),

      requestId:
        result.requestId ||
        null,

      operation:
        result.operation ||
        null,

      creditCost:
        result.creditCost ??
        result.cost ??
        null,
    },
    status,
  );
}

/* =========================================================
   CHAT
   ========================================================= */

async function handleChat(
  request,
  env,
) {
  const body =
    await readJsonBody(
      request,
    );

  const messages =
    cleanMessages(
      body.messages,
    );

  const imageDataUrls = [];

  /* ---------- Single image ---------- */

  const singleImage =
    typeof body.imageDataUrl ===
    "string"
      ? body.imageDataUrl.trim()
      : "";

  if (singleImage) {
    imageDataUrls.push(
      singleImage,
    );
  }

  /* ---------- Multiple images ---------- */

  if (
    Array.isArray(
      body.imageDataUrls,
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
          item.trim(),
        )
      ) {
        imageDataUrls.push(
          item.trim(),
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
    const image of
      imageDataUrls
  ) {
    if (
      !isValidImageDataUrl(
        image,
      )
    ) {
      return json(
        {
          ok: false,
          error:
            "INVALID_IMAGE",
        },
        400,
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
      400,
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

  /* =======================================================
     CREDIT PREPARATION
     ======================================================= */

  const creditOperation =
    getChatCreditOperation(
      body,
      imageDataUrls,
    );

  const deviceId =
    getCreditDeviceId(
      request,
      body,
    );

  const requestId =
    getCreditRequestId(
      request,
      body,
    );

  if (!deviceId) {
    return json(
      {
        ok: false,

        error:
          "DEVICE_ID_REQUIRED",

        message:
          "تطبيق صاحبي AI يحتاج معرفًا ثابتًا للجهاز لإدارة رصيد الذكاء الاصطناعي بأمان.",
      },
      400,
    );
  }

  /* =======================================================
     RESERVE CREDITS
     ======================================================= */

  const creditReservation =
    await reserveAIRequestCredits(
      request,
      env,
      {
        body,

        operation:
          creditOperation,

        requestId,
      },
    );

  if (
    !creditReservation.ok
  ) {
    return creditErrorResponse(
      creditReservation,
    );
  }

  const reservationRequestId =
    creditReservation.requestId ||
    requestId;

  /* =======================================================
     AI INSTRUCTIONS
     ======================================================= */

  const instructions =
    buildAIInstructions({
      serviceTitle,
      serviceContext,
    });

  /* =======================================================
     AI EXECUTION
     ======================================================= */

  let result;

  try {
    result =
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
              body.maxOutputTokens,
            ) || 1200,
        },
      );
  } catch (error) {
    await releaseAIRequestCredits(
      request,
      env,
      {
        body,
        requestId:
          reservationRequestId,
      },
    );

    throw error;
  }

  /* =======================================================
     EMPTY AI RESULT
     ======================================================= */

  if (
    !result ||
    typeof result.answer !==
      "string" ||
    !result.answer.trim()
  ) {
    await releaseAIRequestCredits(
      request,
      env,
      {
        body,
        requestId:
          reservationRequestId,
      },
    );

    return json(
      {
        ok: false,

        error:
          "EMPTY_AI_RESPONSE",
      },
      502,
    );
  }

  /* =======================================================
     COMMIT CREDITS
     ======================================================= */

  const creditCommit =
    await commitAIRequestCredits(
      request,
      env,
      {
        body,

        requestId:
          reservationRequestId,
      },
    );

  if (
    !creditCommit.ok
  ) {
    return json(
      {
        ok: false,

        error:
          creditCommit.error ||
          "CREDIT_COMMIT_FAILED",

        requestId:
          reservationRequestId,

        answer:
          result.answer || "",
      },
      500,
    );
  }

  /* =======================================================
     SUCCESS
     ======================================================= */

  return json({
    ok: true,

    answer:
      result.answer || "",

    provider:
      result.provider || null,

    fallback:
      Boolean(
        result.fallback,
      ),

    fallbackReason:
      result.fallbackReason ||
      null,

    model:
      result.model || null,

    backendVersion:
      BACKEND_VERSION,

    credits:
      getSafeCreditSummary(
        creditCommit,
      ),

    creditOperation,

    creditCost:
      creditCommit.cost ??
      creditReservation.cost ??
      null,

    requestId:
      reservationRequestId,
  });
}

/* =========================================================
   IMAGE GENERATION / EDITING
   ========================================================= */

async function handleImageGeneration(
  request,
  env,
) {
  const body =
    await readJsonBody(
      request,
    );

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
      400,
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
      body.imageDataUrl.trim(),
    );
  }

  /* ---------- Multiple images ---------- */

  if (
    Array.isArray(
      body.imageDataUrls,
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
          item.trim(),
        )
      ) {
        imageDataUrls.push(
          item.trim(),
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
    const image of
      imageDataUrls
  ) {
    if (
      !isValidImageDataUrl(
        image,
      )
    ) {
      return json(
        {
          ok: false,
          error:
            "INVALID_IMAGE",
        },
        400,
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

  /* =======================================================
     CREDIT PREPARATION
     ======================================================= */

  const creditOperation =
    getImageCreditOperation(
      imageDataUrls,
    );

  const deviceId =
    getCreditDeviceId(
      request,
      body,
    );

  const requestId =
    getCreditRequestId(
      request,
      body,
    );

  if (!deviceId) {
    return json(
      {
        ok: false,

        error:
          "DEVICE_ID_REQUIRED",

        message:
          "تطبيق صاحبي AI يحتاج معرفًا ثابتًا للجهاز لإدارة رصيد الذكاء الاصطناعي بأمان.",
      },
      400,
    );
  }

  /* =======================================================
     RESERVE CREDITS
     ======================================================= */

  const creditReservation =
    await reserveAIRequestCredits(
      request,
      env,
      {
        body,

        operation:
          creditOperation,

        requestId,
      },
    );

  if (
    !creditReservation.ok
  ) {
    return creditErrorResponse(
      creditReservation,
    );
  }

  const reservationRequestId =
    creditReservation.requestId ||
    requestId;

  /* =======================================================
     AI IMAGE EXECUTION
     ======================================================= */

  let result;

  try {
    result =
      await runImageWithFallback(
        {
          request,
          env,

          prompt:
            prompt.substring(
              0,
              6000,
            ),

          imageDataUrls,

          aspectRatio,

          imageSize,
        },
      );
  } catch (error) {
    await releaseAIRequestCredits(
      request,
      env,
      {
        body,
        requestId:
          reservationRequestId,
      },
    );

    throw error;
  }

  /* =======================================================
     EMPTY IMAGE RESULT
     ======================================================= */

  if (
    !result ||
    typeof result.imageDataUrl !==
      "string" ||
    !result.imageDataUrl.trim()
  ) {
    await releaseAIRequestCredits(
      request,
      env,
      {
        body,
        requestId:
          reservationRequestId,
      },
    );

    return json(
      {
        ok: false,

        error:
          "EMPTY_IMAGE_RESPONSE",
      },
      502,
    );
  }

  /* =======================================================
     COMMIT CREDITS
     ======================================================= */

  const creditCommit =
    await commitAIRequestCredits(
      request,
      env,
      {
        body,

        requestId:
          reservationRequestId,
      },
    );

  if (
    !creditCommit.ok
  ) {
    return json(
      {
        ok: false,

        error:
          creditCommit.error ||
          "CREDIT_COMMIT_FAILED",

        requestId:
          reservationRequestId,
      },
      500,
    );
  }

  /* =======================================================
     SUCCESS
     ======================================================= */

  return json({
    ok: true,

    imageDataUrl:
      result.imageDataUrl ||
      null,

    mimeType:
      result.mimeType ||
      null,

    provider:
      result.provider ||
      null,

    fallback:
      Boolean(
        result.fallback,
      ),

    fallbackReason:
      result.fallbackReason ||
      null,

    model:
      result.model ||
      null,

    text:
      result.text ||
      "",

    backendVersion:
      BACKEND_VERSION,

    credits:
      getSafeCreditSummary(
        creditCommit,
      ),

    creditOperation,

    creditCost:
      creditCommit.cost ??
      creditReservation.cost ??
      null,

    requestId:
      reservationRequestId,
  });
}

/* =========================================================
   CREDITS API
   ========================================================= */

async function handleCredits(
  request,
  env,
) {
  try {
    const result =
      await handleCreditsBalance(
        request,
        env,
      );

    if (!result.ok) {
      return creditErrorResponse(
        result,
      );
    }

    return json(
      {
        ...result,

        backendVersion:
          BACKEND_VERSION,
      },
    );
  } catch (error) {
    const message =
      error?.message ||
      "CREDIT_SYSTEM_ERROR";

    if (
      message ===
      "DEVICE_ID_REQUIRED"
    ) {
      return json(
        {
          ok: false,

          error:
            "DEVICE_ID_REQUIRED",
        },
        400,
      );
    }

    if (
      message ===
      "SA7BI_CREDITS_BINDING_MISSING"
    ) {
      return json(
        {
          ok: false,

          error:
            message,
        },
        500,
      );
    }

    return json(
      {
        ok: false,

        error:
          message,
      },
      500,
    );
  }
}

/* =========================================================
   ROOT
   ========================================================= */

function handleRoot(
  env,
) {
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

      credits: true,

      rewardedAds:
        true,
    },

    ai: {
      primary:
        "gemini",

      fallback:
        "cloudflare_workers_ai",
    },

    credits: {
      serverAuthoritative:
        true,

      rewardedAds:
        "admob_ssv_verified",

      rewardVerification:
        "google_signature",

      rewardCredits:
        10,

      dailyRewardedAds:
        5,
    },

    rewardedAds:
      getAdMobSSVStatus(
        env,
      ),

    endpoints: {
      chat:
        "/v1/chat",

      image:
        "/v1/image",

      credits:
        "/v1/credits",

      rewardedAdSSV:
        "/v1/rewards/admob/ssv",

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
    env,
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
          },
        );
      }

      const url =
        new URL(
          request.url,
        );

      const path =
        url.pathname.replace(
          /\/+$/,
          "",
        ) || "/";

      /* =====================================================
         ROOT
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path === "/"
      ) {
        return handleRoot(
          env,
        );
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
          env,
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
          env,
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
          env,
        );
      }

      /* =====================================================
         CREDITS
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/credits"
      ) {
        return handleCredits(
          request,
          env,
        );
      }

      /* =====================================================
         ADMOB REWARDED ADS SSV
         
         IMPORTANT:
         This endpoint is called by AdMob, NOT Flutter.
         
         The module verifies:
         - Google signature
         - key_id
         - timestamp
         - reward amount
         - reward item
         - ad unit when configured
         - transaction_id
         - custom_data/device ID
         
         Only after successful verification are credits
         sent to the Durable Object.
         ===================================================== */

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/rewards/admob/ssv"
      ) {
        return handleAdMobSSV(
          request,
          env,
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
          request,
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
          request,
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
          request,
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
          request,
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
          request,
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
          request,
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
          request,
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
            "country",
          ) ||
          url.searchParams.get(
            "countryCode",
          ) ||
          "";

        const limit =
          Number(
            url.searchParams.get(
              "limit",
            ) || 50,
          );

        return handleRadioByCountry(
          countryCode,
          limit,
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
        return handleRadioSearch(
          request,
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
          request,
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
          request,
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
          request,
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
          env,
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
          env,
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
        404,
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
          413,
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
          400,
        );
      }

      /* =====================================================
         CREDIT CONFIG ERRORS
         ===================================================== */

      if (
        message ===
        "SA7BI_CREDITS_BINDING_MISSING"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          500,
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
          500,
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
          500,
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
          500,
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
          502,
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
        500,
      );
    }
  },
};

/* =========================================================
   DURABLE OBJECT EXPORT
   ========================================================= */

export {
  Sa7biCredits,
};
