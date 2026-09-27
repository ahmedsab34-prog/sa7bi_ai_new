// backend/src/credits-router.js
// Sa7bi AI - Credits Router
//
// This module keeps the public Worker routing logic separate
// from the Durable Object credit ledger.
//
// Important:
// - credits.js = actual server-side credit ledger
// - credits-router.js = HTTP/request-level integration
// - index.js = main Worker route dispatcher
//
// Rewarded-ad credit is intentionally NOT exposed here yet.
// It will be enabled only after AdMob server-side verification
// is connected.

import {
  CREDIT_COSTS,
  getServerCredits,
  reserveCredits,
  commitCredits,
  releaseCredits,
} from "./credits.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

export const CREDIT_DEVICE_HEADER =
  "X-Sa7bi-Device-Id";

export const CREDIT_REQUEST_HEADER =
  "X-Sa7bi-Request-Id";

/* =========================================================
   DEVICE ID
   ========================================================= */

export function getCreditDeviceId(
  request,
  body = {},
) {
  const headerValue =
    request.headers.get(
      CREDIT_DEVICE_HEADER,
    );

  if (
    typeof headerValue ===
      "string" &&
    headerValue.trim()
  ) {
    return headerValue
      .trim()
      .substring(0, 128);
  }

  const bodyValue =
    body?.deviceId ??
    body?.device_id ??
    "";

  if (
    typeof bodyValue ===
      "string" &&
    bodyValue.trim()
  ) {
    return bodyValue
      .trim()
      .substring(0, 128);
  }

  return "";
}

/* =========================================================
   REQUEST ID
   ========================================================= */

export function getCreditRequestId(
  request,
  body = {},
) {
  const headerValue =
    request.headers.get(
      CREDIT_REQUEST_HEADER,
    );

  if (
    typeof headerValue ===
      "string" &&
    headerValue.trim()
  ) {
    return headerValue
      .trim()
      .substring(0, 128);
  }

  const bodyValue =
    body?.requestId ??
    body?.request_id ??
    "";

  if (
    typeof bodyValue ===
      "string" &&
    bodyValue.trim()
  ) {
    return bodyValue
      .trim()
      .substring(0, 128);
  }

  /*
   * The client should normally send its own
   * stable request ID.
   *
   * This fallback prevents accidental duplicate
   * requests from sharing the same reservation.
   */
  return crypto.randomUUID();
}

/* =========================================================
   OPERATION NORMALIZATION
   ========================================================= */

export function normalizeCreditOperation(
  value,
) {
  if (
    typeof value !==
    "string"
  ) {
    return "";
  }

  return value
    .trim()
    .toLowerCase();
}

/* =========================================================
   OPERATION → COST
   ========================================================= */

export function getCreditCost(
  operation,
) {
  const normalized =
    normalizeCreditOperation(
      operation,
    );

  return (
    CREDIT_COSTS[
      normalized
    ] ?? null
  );
}

/* =========================================================
   CHAT OPERATION
   ========================================================= */

export function getChatCreditOperation(
  body = {},
  imageDataUrls = [],
) {
  /*
   * Video analysis has priority.
   *
   * A video request may contain extracted
   * frames/images, but its credit cost is
   * still the video-analysis cost.
   */
  if (
    body?.mediaType ===
      "video" ||
    body?.media_type ===
      "video" ||
    body?.videoAnalysis ===
      true ||
    body?.video_analysis ===
      true
  ) {
    return "video_analysis";
  }

  /*
   * Any image attached to a normal chat
   * request means image analysis.
   */
  if (
    Array.isArray(
      imageDataUrls,
    ) &&
    imageDataUrls.length > 0
  ) {
    return "image_analysis";
  }

  /*
   * Normal text request.
   */
  return "text";
}

/* =========================================================
   IMAGE OPERATION
   ========================================================= */

export function getImageCreditOperation(
  imageDataUrls = [],
) {
  if (
    Array.isArray(
      imageDataUrls,
    ) &&
    imageDataUrls.length > 0
  ) {
    return "image_edit";
  }

  return "image_generation";
}

/* =========================================================
   BASIC VALIDATION
   ========================================================= */

export function requireCreditIdentity(
  request,
  body = {},
) {
  const deviceId =
    getCreditDeviceId(
      request,
      body,
    );

  if (!deviceId) {
    return {
      ok: false,

      error:
        "DEVICE_ID_REQUIRED",

      message:
        "A stable Sa7bi device identifier is required.",
    };
  }

  return {
    ok: true,
    deviceId,
  };
}

/* =========================================================
   BALANCE
   ========================================================= */

export async function handleCreditsBalance(
  request,
  env,
) {
  const identity =
    requireCreditIdentity(
      request,
    );

  if (!identity.ok) {
    return identity;
  }

  const balance =
    await getServerCredits(
      env,
      identity.deviceId,
    );

  return {
    ok: true,

    deviceId:
      identity.deviceId,

    ...balance,
  };
}

/* =========================================================
   RESERVE
   ========================================================= */

export async function reserveAIRequestCredits(
  request,
  env,
  {
    body = {},
    operation,
    requestId,
  } = {},
) {
  const identity =
    requireCreditIdentity(
      request,
      body,
    );

  if (!identity.ok) {
    return identity;
  }

  const normalizedOperation =
    normalizeCreditOperation(
      operation,
    );

  const cost =
    getCreditCost(
      normalizedOperation,
    );

  if (cost === null) {
    return {
      ok: false,

      error:
        "UNKNOWN_CREDIT_OPERATION",

      operation:
        normalizedOperation,
    };
  }

  const finalRequestId =
    requestId ||
    getCreditRequestId(
      request,
      body,
    );

  const result =
    await reserveCredits(
      env,
      {
        deviceId:
          identity.deviceId,

        operation:
          normalizedOperation,

        requestId:
          finalRequestId,
      },
    );

  return {
    ...result,

    deviceId:
      identity.deviceId,

    requestId:
      finalRequestId,

    operation:
      normalizedOperation,

    creditCost:
      cost,
  };
}

/* =========================================================
   COMMIT
   ========================================================= */

export async function commitAIRequestCredits(
  request,
  env,
  {
    body = {},
    requestId,
  } = {},
) {
  const identity =
    requireCreditIdentity(
      request,
      body,
    );

  if (!identity.ok) {
    return identity;
  }

  const finalRequestId =
    requestId ||
    getCreditRequestId(
      request,
      body,
    );

  const result =
    await commitCredits(
      env,
      {
        deviceId:
          identity.deviceId,

        requestId:
          finalRequestId,
      },
    );

  return {
    ...result,

    deviceId:
      identity.deviceId,

    requestId:
      finalRequestId,
  };
}

/* =========================================================
   RELEASE
   ========================================================= */

export async function releaseAIRequestCredits(
  request,
  env,
  {
    body = {},
    requestId,
  } = {},
) {
  const identity =
    requireCreditIdentity(
      request,
      body,
    );

  if (!identity.ok) {
    return identity;
  }

  const finalRequestId =
    requestId ||
    getCreditRequestId(
      request,
      body,
    );

  const result =
    await releaseCredits(
      env,
      {
        deviceId:
          identity.deviceId,

        requestId:
          finalRequestId,
      },
    );

  return {
    ...result,

    deviceId:
      identity.deviceId,

    requestId:
      finalRequestId,
  };
}

/* =========================================================
   REQUEST CREDIT CONTEXT
   ========================================================= */

export function buildCreditContext(
  request,
  body = {},
  operation = "",
) {
  const identity =
    requireCreditIdentity(
      request,
      body,
    );

  if (!identity.ok) {
    return identity;
  }

  const normalizedOperation =
    normalizeCreditOperation(
      operation,
    );

  const creditCost =
    getCreditCost(
      normalizedOperation,
    );

  if (
    creditCost === null
  ) {
    return {
      ok: false,

      error:
        "UNKNOWN_CREDIT_OPERATION",

      operation:
        normalizedOperation,
    };
  }

  return {
    ok: true,

    deviceId:
      identity.deviceId,

    requestId:
      getCreditRequestId(
        request,
        body,
      ),

    operation:
      normalizedOperation,

    creditCost,
  };
}

/* =========================================================
   FULL AI CREDIT FLOW
   ========================================================= */

/*
 * This helper documents the intended lifecycle:
 *
 *     reserve
 *       ↓
 *     AI request
 *       ↓
 *   ┌───┴────┐
 *   │        │
 * success   failure
 *   │        │
 * commit   release
 *
 * The actual AI execution remains in index.js/ai-router.js.
 *
 * This module only handles the credit side.
 */

/* =========================================================
   CREDIT ERROR RESPONSE
   ========================================================= */

export function creditErrorStatus(
  result,
) {
  if (!result) {
    return 500;
  }

  switch (
    result.error
  ) {
    case "DEVICE_ID_REQUIRED":
      return 400;

    case "REQUEST_ID_REQUIRED":
      return 400;

    case "UNKNOWN_CREDIT_OPERATION":
      return 400;

    case "REQUEST_ALREADY_FINALIZED":
      return 409;

    case "RESERVATION_NOT_FOUND":
      return 409;

    case "RESERVATION_NOT_ACTIVE":
      return 409;

    case "RESERVATION_EXPIRED":
      return 409;

    case "REQUEST_ALREADY_COMMITTED":
      return 409;

    case "INSUFFICIENT_CREDITS":
      return 402;

    default:
      return 500;
  }
}

/* =========================================================
   SAFE CREDIT SUMMARY
   ========================================================= */

export function getSafeCreditSummary(
  result,
) {
  if (!result) {
    return null;
  }

  const balance =
    result.balance;

  if (!balance) {
    return null;
  }

  return {
    credits:
      Number(
        balance.credits ??
          0,
      ),

    availableCredits:
      Number(
        balance.availableCredits ??
          0,
      ),

    reservedCredits:
      Number(
        balance.reservedCredits ??
          0,
      ),

    rewardedAdsToday:
      Number(
        balance.rewardedAdsToday ??
          0,
      ),

    rewardedAdDailyLimit:
      Number(
        balance.rewardedAdDailyLimit ??
          0,
      ),

    remainingRewardedAds:
      Number(
        balance.remainingRewardedAds ??
          0,
      ),

    rewardedAdCredits:
      Number(
        balance.rewardedAdCredits ??
          0,
      ),
  };
}
