// backend/src/credits-router.js
// Sa7bi AI - Final Credits Router
//
// FINAL ARCHITECTURE
// ------------------
// credits.js
//   = server-authoritative credit ledger
//   = SQLite Durable Object
//
// credits-router.js
//   = HTTP/request-level credit integration
//
// index.js
//   = main Worker route dispatcher
//
// admob-ssv.js
//   = Google AdMob Server-Side Verification
//   = the ONLY public reward path
//
// IMPORTANT
// ---------
// Rewarded-ad credits are NOT granted from the client
// and are NOT exposed through a normal client reward route.
//
// The Flutter app only:
//   1. shows the rewarded ad
//   2. sends its stable device ID through custom_data
//   3. waits for Google's verified SSV callback
//
// Google SSV -> admob-ssv.js -> credits.js
//
// This prevents the client from simply calling an endpoint
// and giving itself free credits.

/* =========================================================
   IMPORTS
   ========================================================= */

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

/**
 * Reads the stable Sa7bi device identifier.
 *
 * Preferred:
 *   X-Sa7bi-Device-Id
 *
 * Fallback:
 *   body.deviceId
 *   body.device_id
 *
 * The ID is limited to 128 characters.
 */
export function getCreditDeviceId(
  request,
  body = {},
) {
  const headerValue =
    request.headers.get(
      CREDIT_DEVICE_HEADER,
    );

  if (
    typeof headerValue === "string" &&
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
    typeof bodyValue === "string" &&
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

/**
 * Reads the request ID used for credit idempotency.
 *
 * Preferred:
 *   X-Sa7bi-Request-Id
 *
 * Fallback:
 *   body.requestId
 *   body.request_id
 *
 * If the client does not provide one, a UUID is generated.
 *
 * The Flutter client normally sends a UUID for every AI
 * request, so retries of the same request can be identified.
 */
export function getCreditRequestId(
  request,
  body = {},
) {
  const headerValue =
    request.headers.get(
      CREDIT_REQUEST_HEADER,
    );

  if (
    typeof headerValue === "string" &&
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
    typeof bodyValue === "string" &&
    bodyValue.trim()
  ) {
    return bodyValue
      .trim()
      .substring(0, 128);
  }

  return crypto.randomUUID();
}

/* =========================================================
   OPERATION NORMALIZATION
   ========================================================= */

export function normalizeCreditOperation(
  value,
) {
  if (
    typeof value !== "string"
  ) {
    return "";
  }

  return value
    .trim()
    .toLowerCase();
}

/* =========================================================
   OPERATION → CREDIT COST
   ========================================================= */

/**
 * Returns the configured server-side cost.
 *
 * CREDIT_COSTS remains the single source of truth.
 */
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
   CHAT → CREDIT OPERATION
   ========================================================= */

/**
 * Determines the credit operation for /v1/chat.
 *
 * Priority:
 *
 * 1. Video analysis
 * 2. Image analysis
 * 3. Normal text
 *
 * This means a video request remains a video operation
 * even if extracted frames/images are also supplied.
 */
export function getChatCreditOperation(
  body = {},
  imageDataUrls = [],
) {
  if (
    body?.mediaType === "video" ||
    body?.media_type === "video" ||
    body?.videoAnalysis === true ||
    body?.video_analysis === true
  ) {
    return "video_analysis";
  }

  if (
    Array.isArray(imageDataUrls) &&
    imageDataUrls.length > 0
  ) {
    return "image_analysis";
  }

  return "text";
}

/* =========================================================
   IMAGE → CREDIT OPERATION
   ========================================================= */

/**
 * Determines whether /v1/image is:
 *
 *   image_generation
 *
 * or:
 *
 *   image_edit
 */
export function getImageCreditOperation(
  imageDataUrls = [],
) {
  if (
    Array.isArray(imageDataUrls) &&
    imageDataUrls.length > 0
  ) {
    return "image_edit";
  }

  return "image_generation";
}

/* =========================================================
   CREDIT IDENTITY VALIDATION
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
      error: "DEVICE_ID_REQUIRED",
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
   GET SERVER BALANCE
   ========================================================= */

/**
 * Reads the authoritative balance from the Durable Object.
 *
 * The client-side cached balance is never treated as the
 * source of truth.
 */
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
   RESERVE AI CREDITS
   ========================================================= */

/**
 * Reservation lifecycle:
 *
 *       RESERVE
 *          |
 *          v
 *       AI WORK
 *       /     \
 *      /       \
 * SUCCESS     FAILURE
 *    |           |
 *    v           v
 * COMMIT      RELEASE
 *
 * Credits are therefore not permanently consumed merely
 * because a request started.
 */
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
   COMMIT AI CREDITS
   ========================================================= */

/**
 * Called ONLY after a successful AI response.
 */
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
   RELEASE AI CREDITS
   ========================================================= */

/**
 * Called when the AI request fails after reservation.
 *
 * The reserved credits are returned.
 */
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
   BUILD CREDIT CONTEXT
   ========================================================= */

/**
 * Creates the normalized server-side context used by
 * higher-level Worker routing.
 */
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
   CREDIT ERROR → HTTP STATUS
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

/**
 * Returns only safe balance fields intended for the app UI.
 *
 * Internal Durable Object details are never exposed.
 */
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
        balance.credits ?? 0,
      ),

    availableCredits:
      Number(
        balance.availableCredits ?? 0,
      ),

    reservedCredits:
      Number(
        balance.reservedCredits ?? 0,
      ),

    rewardedAdsToday:
      Number(
        balance.rewardedAdsToday ?? 0,
      ),

    rewardedAdDailyLimit:
      Number(
        balance.rewardedAdDailyLimit ?? 0,
      ),

    remainingRewardedAds:
      Number(
        balance.remainingRewardedAds ?? 0,
      ),

    rewardedAdCredits:
      Number(
        balance.rewardedAdCredits ?? 0,
      ),
  };
}
