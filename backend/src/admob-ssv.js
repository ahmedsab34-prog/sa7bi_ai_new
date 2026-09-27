// backend/src/admob-ssv.js
// Sa7bi AI - AdMob Rewarded SSV Verification
//
// Flow:
//
// AdMob
//   ↓
// SSV callback
//   ↓
// verify Google ECDSA signature
//   ↓
// validate timestamp / reward / ad unit / transaction
//   ↓
// extract device ID from custom_data
//   ↓
// Durable Object
//   ↓
// +10 server-authoritative credits
//
// IMPORTANT:
// Flutter must NEVER be able to directly grant rewarded credits.

/* =========================================================
   IMPORTS
   ========================================================= */

import {
  REWARDED_AD_CREDITS,
  REWARDED_AD_DAILY_LIMIT,
  rewardVerifiedAd,
} from "./credits.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const ADMOB_PUBLIC_KEYS_URL =
  "https://www.gstatic.com/admob/reward/verifier-keys.json";

/*
 * Google recommends refreshing rotated keys and not
 * caching them for more than 24 hours.
 *
 * We use a shorter 6-hour Worker cache.
 */
const PUBLIC_KEY_CACHE_TTL_MS =
  6 * 60 * 60 * 1000;

/*
 * SSV callbacks can be delayed.
 *
 * 24 hours is the maximum age accepted by this backend.
 */
const MAX_CALLBACK_AGE_MS =
  24 * 60 * 60 * 1000;

/*
 * Protect against obviously invalid future timestamps.
 */
const MAX_CALLBACK_FUTURE_MS =
  10 * 60 * 1000;

/*
 * Must match the Reward item configured in AdMob.
 *
 * Expected configuration:
 *
 * reward_item = credits
 */
const DEFAULT_REWARD_ITEM =
  "credits";

/*
 * In-memory Worker-isolate cache.
 *
 * It is intentionally not persistent.
 * If the isolate restarts, keys are downloaded again.
 */
let publicKeyCache = null;

/* =========================================================
   RESPONSE HELPERS
   ========================================================= */

function json(
  data,
  status = 200,
) {
  return new Response(
    JSON.stringify(data),
    {
      status,

      headers: {
        "Content-Type":
          "application/json; charset=utf-8",

        "Cache-Control":
          "no-store",
      },
    },
  );
}

function errorResponse(
  error,
  status = 400,
) {
  return json(
    {
      ok: false,
      error,
    },
    status,
  );
}

/* =========================================================
   BASE64URL / BASE64
   ========================================================= */

function base64ToBytes(
  value,
) {
  if (
    typeof value !== "string" ||
    !value
  ) {
    throw new Error(
      "BASE64_VALUE_REQUIRED",
    );
  }

  let normalized =
    value
      .trim()
      .replace(/-/g, "+")
      .replace(/_/g, "/");

  while (
    normalized.length % 4 !==
    0
  ) {
    normalized += "=";
  }

  let binary;

  try {
    binary = atob(
      normalized,
    );
  } catch (_) {
    throw new Error(
      "BASE64_VALUE_INVALID",
    );
  }

  const bytes =
    new Uint8Array(
      binary.length,
    );

  for (
    let index = 0;
    index < binary.length;
    index += 1
  ) {
    bytes[index] =
      binary.charCodeAt(index);
  }

  return bytes;
}

/* =========================================================
   PUBLIC KEY DOWNLOAD
   ========================================================= */

async function fetchAdMobPublicKeys() {
  const response =
    await fetch(
      ADMOB_PUBLIC_KEYS_URL,
      {
        method: "GET",

        headers: {
          Accept:
            "application/json",
        },
      },
    );

  if (!response.ok) {
    throw new Error(
      `ADMOB_PUBLIC_KEYS_HTTP_${response.status}`,
    );
  }

  const data =
    await response.json();

  if (
    !data ||
    !Array.isArray(
      data.keys,
    )
  ) {
    throw new Error(
      "ADMOB_PUBLIC_KEYS_INVALID",
    );
  }

  const keys =
    new Map();

  for (
    const item of data.keys
  ) {
    if (
      !item ||
      item.keyId ===
        undefined ||
      item.keyId ===
        null
    ) {
      continue;
    }

    const keyId =
      String(
        item.keyId,
      );

    /*
     * Google currently provides a base64 SPKI
     * representation and also a PEM representation.
     *
     * Prefer base64, use PEM as fallback.
     */
    let base64Key =
      typeof item.base64 ===
        "string"
        ? item.base64.trim()
        : "";

    if (
      !base64Key &&
      typeof item.pem ===
        "string"
    ) {
      base64Key =
        item.pem
          .replace(
            /-----BEGIN PUBLIC KEY-----/g,
            "",
          )
          .replace(
            /-----END PUBLIC KEY-----/g,
            "",
          )
          .replace(
            /\s+/g,
            "",
          );
    }

    if (!base64Key) {
      continue;
    }

    keys.set(
      keyId,
      base64Key,
    );
  }

  if (
    keys.size === 0
  ) {
    throw new Error(
      "ADMOB_PUBLIC_KEYS_EMPTY",
    );
  }

  return {
    keys,

    fetchedAt:
      Date.now(),
  };
}

/* =========================================================
   PUBLIC KEY CACHE
   ========================================================= */

async function getAdMobPublicKeys() {
  const now =
    Date.now();

  if (
    publicKeyCache &&
    now -
      publicKeyCache.fetchedAt <
      PUBLIC_KEY_CACHE_TTL_MS
  ) {
    return publicKeyCache.keys;
  }

  const loaded =
    await fetchAdMobPublicKeys();

  publicKeyCache =
    loaded;

  return loaded.keys;
}

/* =========================================================
   PUBLIC KEY IMPORT
   ========================================================= */

async function importAdMobPublicKey(
  base64Key,
) {
  const keyBytes =
    base64ToBytes(
      base64Key,
    );

  try {
    return await crypto.subtle.importKey(
      "spki",

      keyBytes,

      {
        name: "ECDSA",

        namedCurve:
          "P-256",
      },

      false,

      [
        "verify",
      ],
    );
  } catch (_) {
    throw new Error(
      "ADMOB_PUBLIC_KEY_IMPORT_FAILED",
    );
  }
}

/* =========================================================
   DER ECDSA → P1363
   ========================================================= */

/*
 * Google SSV uses an ECDSA DER signature.
 *
 * Cloudflare Web Crypto verification uses the
 * IEEE P1363 representation for ECDSA:
 *
 *     r || s
 *
 * Therefore:
 *
 *     DER sequence
 *          ↓
 *     32-byte R + 32-byte S
 *          ↓
 *     64-byte P1363
 */

function readDerLength(
  bytes,
  state,
) {
  if (
    state.offset >=
    bytes.length
  ) {
    throw new Error(
      "ECDSA_DER_LENGTH_MISSING",
    );
  }

  let length =
    bytes[
      state.offset++
    ];

  if (
    (length & 0x80) ===
    0
  ) {
    return length;
  }

  const count =
    length & 0x7f;

  if (
    count <= 0 ||
    count > 2 ||
    state.offset +
      count >
      bytes.length
  ) {
    throw new Error(
      "ECDSA_DER_LENGTH_INVALID",
    );
  }

  length = 0;

  for (
    let index = 0;
    index < count;
    index += 1
  ) {
    length =
      (length << 8) |
      bytes[
        state.offset++
      ];
  }

  return length;
}

function normalizeDerInteger(
  value,
) {
  let start = 0;

  /*
   * Remove DER sign-padding zeroes.
   */
  while (
    start <
      value.length - 1 &&
    value[start] === 0
  ) {
    start += 1;
  }

  const trimmed =
    value.slice(
      start,
    );

  if (
    trimmed.length >
    32
  ) {
    throw new Error(
      "ECDSA_INTEGER_TOO_LARGE",
    );
  }

  const result =
    new Uint8Array(
      32,
    );

  result.set(
    trimmed,

    32 -
      trimmed.length,
  );

  return result;
}

function derEcdsaToRaw(
  der,
) {
  if (
    !(der instanceof
      Uint8Array)
  ) {
    throw new Error(
      "ECDSA_SIGNATURE_INVALID",
    );
  }

  if (
    der.length < 8
  ) {
    throw new Error(
      "ECDSA_SIGNATURE_TOO_SHORT",
    );
  }

  const state = {
    offset: 0,
  };

  /*
   * SEQUENCE
   */
  if (
    der[
      state.offset++
    ] !== 0x30
  ) {
    throw new Error(
      "ECDSA_DER_SEQUENCE_REQUIRED",
    );
  }

  const sequenceLength =
    readDerLength(
      der,
      state,
    );

  const sequenceEnd =
    state.offset +
    sequenceLength;

  if (
    sequenceEnd !==
    der.length
  ) {
    throw new Error(
      "ECDSA_DER_SEQUENCE_LENGTH_INVALID",
    );
  }

  /*
   * INTEGER R
   */
  if (
    der[
      state.offset++
    ] !== 0x02
  ) {
    throw new Error(
      "ECDSA_DER_R_REQUIRED",
    );
  }

  const rLength =
    readDerLength(
      der,
      state,
    );

  const rStart =
    state.offset;

  const rEnd =
    rStart +
    rLength;

  if (
    rEnd >
    sequenceEnd
  ) {
    throw new Error(
      "ECDSA_DER_R_OUT_OF_RANGE",
    );
  }

  const r =
    der.slice(
      rStart,
      rEnd,
    );

  state.offset =
    rEnd;

  /*
   * INTEGER S
   */
  if (
    der[
      state.offset++
    ] !== 0x02
  ) {
    throw new Error(
      "ECDSA_DER_S_REQUIRED",
    );
  }

  const sLength =
    readDerLength(
      der,
      state,
    );

  const sStart =
    state.offset;

  const sEnd =
    sStart +
    sLength;

  if (
    sEnd !==
    sequenceEnd
  ) {
    throw new Error(
      "ECDSA_DER_S_OUT_OF_RANGE",
    );
  }

  const s =
    der.slice(
      sStart,
      sEnd,
    );

  const rawR =
    normalizeDerInteger(
      r,
    );

  const rawS =
    normalizeDerInteger(
      s,
    );

  const raw =
    new Uint8Array(
      64,
    );

  raw.set(
    rawR,
    0,
  );

  raw.set(
    rawS,
    32,
  );

  return raw;
}

/* =========================================================
   RAW QUERY STRING
   ========================================================= */

function getRawQueryString(
  request,
) {
  const url =
    new URL(
      request.url,
    );

  return url.search.substring(
    1,
  );
}

/* =========================================================
   SSV SIGNATURE EXTRACTION
   ========================================================= */

/*
 * According to Google's SSV format, the final two query
 * parameters are always:
 *
 *     signature
 *     key_id
 *
 * in that order.
 *
 * The part before "&signature=" is the exact data that
 * must be verified.
 *
 * DO NOT use URLSearchParams to rebuild the signed content.
 * Rebuilding can change escaping/order and invalidate
 * the signature.
 */

function extractSignedContent(
  rawQuery,
) {
  if (
    typeof rawQuery !==
      "string" ||
    !rawQuery
  ) {
    throw new Error(
      "ADMOB_SSV_QUERY_MISSING",
    );
  }

  const signatureMarker =
    "signature=";

  const keyIdMarker =
    "key_id=";

  /*
   * Find the signature parameter.
   *
   * It should be preceded by '&' unless it is the first
   * parameter, which is not expected for a normal SSV URL.
   */
  const signatureIndex =
    rawQuery.lastIndexOf(
      `&${signatureMarker}`,
    );

  if (
    signatureIndex < 0
  ) {
    throw new Error(
      "ADMOB_SSV_SIGNATURE_MISSING",
    );
  }

  /*
   * Everything before "&signature=" is signed.
   */
  const signedContent =
    rawQuery.substring(
      0,
      signatureIndex,
    );

  if (
    !signedContent
  ) {
    throw new Error(
      "ADMOB_SSV_SIGNED_DATA_INVALID",
    );
  }

  /*
   * Everything after "&signature=" should be:
   *
   *     SIGNATURE&key_id=NUMBER
   */
  const signatureAndKey =
    rawQuery.substring(
      signatureIndex +
        1 +
        signatureMarker.length,
    );

  const keyIdSeparator =
    `&${keyIdMarker}`;

  const keyIdIndex =
    signatureAndKey.lastIndexOf(
      keyIdSeparator,
    );

  if (
    keyIdIndex < 0
  ) {
    throw new Error(
      "ADMOB_SSV_KEY_ID_MISSING",
    );
  }

  const signatureValue =
    signatureAndKey.substring(
      0,
      keyIdIndex,
    );

  const keyIdValue =
    signatureAndKey.substring(
      keyIdIndex +
        keyIdSeparator.length,
    );

  if (
    !signatureValue ||
    !keyIdValue
  ) {
    throw new Error(
      "ADMOB_SSV_SIGNATURE_OR_KEY_ID_INVALID",
    );
  }

  /*
   * There must be no extra '&' after key_id.
   */
  if (
    keyIdValue.includes("&")
  ) {
    throw new Error(
      "ADMOB_SSV_KEY_ID_NOT_FINAL",
    );
  }

  /*
   * The key ID is numeric.
   */
  if (
    !/^\d+$/.test(
      keyIdValue,
    )
  ) {
    throw new Error(
      "ADMOB_SSV_KEY_ID_INVALID",
    );
  }

  return {
    signedContent,

    signatureValue,

    keyIdValue,
  };
}

/* =========================================================
   SIGNATURE VERIFICATION
   ========================================================= */

async function verifyWithPublicKey(
  base64PublicKey,
  signedContent,
  signatureValue,
) {
  const publicKey =
    await importAdMobPublicKey(
      base64PublicKey,
    );

  const derSignature =
    base64ToBytes(
      signatureValue,
    );

  const rawSignature =
    derEcdsaToRaw(
      derSignature,
    );

  /*
   * IMPORTANT:
   * signedContent is the original query-string bytes.
   * Do not URL-decode or rebuild it.
   */
  const data =
    new TextEncoder().encode(
      signedContent,
    );

  let valid = false;

  try {
    valid =
      await crypto.subtle.verify(
        {
          name: "ECDSA",

          hash: "SHA-256",
        },

        publicKey,

        rawSignature,

        data,
      );
  } catch (_) {
    throw new Error(
      "ADMOB_SSV_SIGNATURE_CHECK_FAILED",
    );
  }

  if (!valid) {
    throw new Error(
      "ADMOB_SSV_SIGNATURE_INVALID",
    );
  }

  return true;
}

async function verifyAdMobSignature(
  request,
) {
  const rawQuery =
    getRawQueryString(
      request,
    );

  const {
    signedContent,
    signatureValue,
    keyIdValue,
  } =
    extractSignedContent(
      rawQuery,
    );

  let keys =
    await getAdMobPublicKeys();

  let publicKey =
    keys.get(
      String(
        keyIdValue,
      ),
    );

  /*
   * If the key is unknown, force one immediate refresh.
   *
   * This handles Google key rotation without waiting
   * for the six-hour local cache to expire.
   */
  if (!publicKey) {
    publicKeyCache =
      null;

    keys =
      await getAdMobPublicKeys();

    publicKey =
      keys.get(
        String(
          keyIdValue,
        ),
      );
  }

  if (!publicKey) {
    throw new Error(
      "ADMOB_SSV_UNKNOWN_KEY_ID",
    );
  }

  await verifyWithPublicKey(
    publicKey,

    signedContent,

    signatureValue,
  );

  return {
    keyId:
      String(
        keyIdValue,
      ),
  };
}

/* =========================================================
   CUSTOM DATA
   ========================================================= */

/*
 * Google passes the string supplied by the app through
 * the custom_data query parameter.
 *
 * URLSearchParams.get() already performs the URL
 * percent-decoding required for a normal query value.
 *
 * Therefore we intentionally do NOT call decodeURIComponent()
 * a second time.
 */

function extractDeviceIdFromCustomData(
  value,
) {
  if (
    typeof value !==
      "string" ||
    !value.trim()
  ) {
    throw new Error(
      "ADMOB_SSV_CUSTOM_DATA_MISSING",
    );
  }

  const raw =
    value.trim();

  /*
   * Preferred Sa7bi format:
   *
   * {
   *   "deviceId": "...",
   *   "source": "sa7bi_rewarded_ad"
   * }
   */
  try {
    const parsed =
      JSON.parse(
        raw,
      );

    if (
      parsed &&
      typeof parsed.deviceId ===
        "string" &&
      parsed.deviceId.trim()
    ) {
      return parsed.deviceId
        .trim()
        .substring(0, 128);
    }
  } catch (_) {
    /*
     * A plain string is also accepted for compatibility.
     */
  }

  /*
   * Plain device ID fallback.
   */
  return raw.substring(
    0,
    128,
  );
}

/* =========================================================
   TIMESTAMP VALIDATION
   ========================================================= */

function validateTimestamp(
  timestampValue,
) {
  if (
    typeof timestampValue !==
      "string" &&
    typeof timestampValue !==
      "number"
  ) {
    throw new Error(
      "ADMOB_SSV_TIMESTAMP_INVALID",
    );
  }

  const timestamp =
    Number(
      timestampValue,
    );

  if (
    !Number.isFinite(
      timestamp,
    ) ||
    timestamp <= 0
  ) {
    throw new Error(
      "ADMOB_SSV_TIMESTAMP_INVALID",
    );
  }

  const now =
    Date.now();

  if (
    timestamp <
    now -
      MAX_CALLBACK_AGE_MS
  ) {
    throw new Error(
      "ADMOB_SSV_CALLBACK_TOO_OLD",
    );
  }

  if (
    timestamp >
    now +
      MAX_CALLBACK_FUTURE_MS
  ) {
    throw new Error(
      "ADMOB_SSV_CALLBACK_FROM_FUTURE",
    );
  }

  return timestamp;
}

/* =========================================================
   REWARD VALIDATION
   ========================================================= */

function validateReward(
  url,
  env,
) {
  const rewardAmountRaw =
    url.searchParams.get(
      "reward_amount",
    );

  const rewardAmount =
    Number(
      rewardAmountRaw,
    );

  if (
    !Number.isInteger(
      rewardAmount,
    )
  ) {
    throw new Error(
      "ADMOB_SSV_REWARD_AMOUNT_INVALID",
    );
  }

  /*
   * The callback amount must match our configured
   * AdMob reward amount.
   *
   * We NEVER use the callback value as the amount
   * to credit.
   */
  if (
    rewardAmount !==
    REWARDED_AD_CREDITS
  ) {
    throw new Error(
      "ADMOB_SSV_REWARD_AMOUNT_MISMATCH",
    );
  }

  const configuredRewardItem =
    String(
      env?.ADMOB_REWARD_ITEM ||
        DEFAULT_REWARD_ITEM,
    ).trim();

  const callbackRewardItem =
    String(
      url.searchParams.get(
        "reward_item",
      ) || "",
    ).trim();

  if (
    !callbackRewardItem
  ) {
    throw new Error(
      "ADMOB_SSV_REWARD_ITEM_MISSING",
    );
  }

  if (
    callbackRewardItem !==
    configuredRewardItem
  ) {
    throw new Error(
      "ADMOB_SSV_REWARD_ITEM_MISMATCH",
    );
  }

  return {
    rewardAmount,

    rewardItem:
      callbackRewardItem,
  };
}

/* =========================================================
   TRANSACTION VALIDATION
   ========================================================= */

function validateTransactionId(
  value,
) {
  if (
    typeof value !==
      "string" ||
    !value.trim()
  ) {
    throw new Error(
      "ADMOB_SSV_TRANSACTION_ID_MISSING",
    );
  }

  const transactionId =
    value.trim();

  /*
   * Google describes transaction_id as a unique
   * hex-encoded identifier.
   *
   * We allow up to 256 characters while requiring
   * a safe identifier format.
   */
  if (
    transactionId.length >
    256
  ) {
    throw new Error(
      "ADMOB_SSV_TRANSACTION_ID_INVALID",
    );
  }

  if (
    !/^[a-fA-F0-9]+$/.test(
      transactionId,
    )
  ) {
    throw new Error(
      "ADMOB_SSV_TRANSACTION_ID_INVALID",
    );
  }

  return transactionId;
}

/* =========================================================
   AD UNIT VALIDATION
   ========================================================= */

function validateAdUnit(
  url,
  env,
) {
  const configuredAdUnit =
    String(
      env?.ADMOB_REWARDED_AD_UNIT_ID ||
        "",
    ).trim();

  /*
   * If the Worker secret/variable is not configured yet,
   * allow the callback.
   *
   * Once configured, enforce exact matching.
   */
  if (
    !configuredAdUnit
  ) {
    return true;
  }

  const callbackAdUnit =
    String(
      url.searchParams.get(
        "ad_unit",
      ) || "",
    ).trim();

  if (
    !callbackAdUnit
  ) {
    throw new Error(
      "ADMOB_SSV_AD_UNIT_MISSING",
    );
  }

  if (
    callbackAdUnit !==
    configuredAdUnit
  ) {
    throw new Error(
      "ADMOB_SSV_AD_UNIT_MISMATCH",
    );
  }

  return true;
}

/* =========================================================
   MAIN SSV HANDLER
   ========================================================= */

export async function handleAdMobSSV(
  request,
  env,
) {
  /*
   * Google sends SSV callbacks as GET requests.
   */
  if (
    request.method !==
    "GET"
  ) {
    return errorResponse(
      "METHOD_NOT_ALLOWED",
      405,
    );
  }

  try {
    const url =
      new URL(
        request.url,
      );

    /*
     * -------------------------------------------------------
     * STEP 1
     * Verify Google's cryptographic signature.
     *
     * Nothing is rewarded before this succeeds.
     * -------------------------------------------------------
     */
    await verifyAdMobSignature(
      request,
    );

    /*
     * -------------------------------------------------------
     * STEP 2
     * Validate timestamp.
     * -------------------------------------------------------
     */
    const timestamp =
      validateTimestamp(
        url.searchParams.get(
          "timestamp",
        ),
      );

    /*
     * -------------------------------------------------------
     * STEP 3
     * Validate reward amount + reward item.
     * -------------------------------------------------------
     */
    const reward =
      validateReward(
        url,
        env,
      );

    /*
     * -------------------------------------------------------
     * STEP 4
     * Validate the rewarded ad unit if configured.
     * -------------------------------------------------------
     */
    validateAdUnit(
      url,
      env,
    );

    /*
     * -------------------------------------------------------
     * STEP 5
     * Validate unique AdMob transaction ID.
     * -------------------------------------------------------
     */
    const transactionId =
      validateTransactionId(
        url.searchParams.get(
          "transaction_id",
        ),
      );

    /*
     * -------------------------------------------------------
     * STEP 6
     * Extract Sa7bi device ID.
     * -------------------------------------------------------
     */
    const deviceId =
      extractDeviceIdFromCustomData(
        url.searchParams.get(
          "custom_data",
        ),
      );

    if (!deviceId) {
      throw new Error(
        "ADMOB_SSV_DEVICE_ID_INVALID",
      );
    }

    /*
     * -------------------------------------------------------
     * STEP 7
     * Give the verified reward to the Durable Object.
     *
     * credits.js guarantees:
     *
     * - server-authoritative reward
     * - exactly +10 credits
     * - maximum 5 rewarded ads/day
     * - transaction idempotency
     * -------------------------------------------------------
     */
    const result =
      await rewardVerifiedAd(
        env,
        {
          deviceId,

          transactionId,

          source:
            "admob_ssv",
        },
      );

    /*
     * A repeated SSV callback is still a successful
     * callback because the original transaction was
     * already processed.
     */
    if (
      result?.ok === true
    ) {
      return json(
        {
          ok: true,

          rewarded:
            result.rewarded ===
            true,

          alreadyRewarded:
            result.alreadyRewarded ===
            true,

          transactionId,

          /*
           * This value is always server policy.
           * Never trust rewardAmount from the client.
           */
          added:
            Number(
              result.added ??
                REWARDED_AD_CREDITS,
            ),

          rewardItem:
            reward.rewardItem,

          balance:
            result.balance ??
            null,

          dailyLimit:
            REWARDED_AD_DAILY_LIMIT,

          timestamp,
        },
        200,
      );
    }

    /*
     * Daily limit is an intentional rejection.
     *
     * Other reward failures are also not reported as
     * successful credits.
     */
    if (
      result?.error ===
      "REWARDED_AD_DAILY_LIMIT"
    ) {
      return errorResponse(
        "REWARDED_AD_DAILY_LIMIT",
        409,
      );
    }

    return errorResponse(
      result?.error ||
        "REWARDED_AD_NOT_GRANTED",
      400,
    );
  } catch (error) {
    const message =
      error?.message ||
      "ADMOB_SSV_VERIFICATION_FAILED";

    /*
     * Only expose safe validation errors.
     *
     * Never expose public-key internals or cryptographic
     * implementation details to the caller.
     */
    const safeErrors =
      new Set([
        "METHOD_NOT_ALLOWED",

        "ADMOB_SSV_QUERY_MISSING",

        "ADMOB_SSV_SIGNATURE_MISSING",

        "ADMOB_SSV_KEY_ID_MISSING",

        "ADMOB_SSV_SIGNED_DATA_INVALID",

        "ADMOB_SSV_SIGNATURE_OR_KEY_ID_INVALID",

        "ADMOB_SSV_KEY_ID_NOT_FINAL",

        "ADMOB_SSV_KEY_ID_INVALID",

        "ADMOB_SSV_UNKNOWN_KEY_ID",

        "ADMOB_SSV_SIGNATURE_INVALID",

        "ADMOB_SSV_TIMESTAMP_INVALID",

        "ADMOB_SSV_CALLBACK_TOO_OLD",

        "ADMOB_SSV_CALLBACK_FROM_FUTURE",

        "ADMOB_SSV_REWARD_AMOUNT_INVALID",

        "ADMOB_SSV_REWARD_AMOUNT_MISMATCH",

        "ADMOB_SSV_REWARD_ITEM_MISSING",

        "ADMOB_SSV_REWARD_ITEM_MISMATCH",

        "ADMOB_SSV_TRANSACTION_ID_MISSING",

        "ADMOB_SSV_TRANSACTION_ID_INVALID",

        "ADMOB_SSV_CUSTOM_DATA_MISSING",

        "ADMOB_SSV_AD_UNIT_MISSING",

        "ADMOB_SSV_AD_UNIT_MISMATCH",

        "ADMOB_SSV_DEVICE_ID_INVALID",

        "REWARDED_AD_DAILY_LIMIT",
      ]);

    if (
      safeErrors.has(
        message,
      )
    ) {
      return errorResponse(
        message,

        message ===
          "METHOD_NOT_ALLOWED"
          ? 405
          : message ===
              "REWARDED_AD_DAILY_LIMIT"
            ? 409
            : 400,
      );
    }

    /*
     * Key download failure, crypto import failure,
     * malformed signature, or another internal issue.
     */
    return errorResponse(
      "ADMOB_SSV_VERIFICATION_FAILED",
      500,
    );
  }
}

/* =========================================================
   SSV STATUS
   ========================================================= */

export function getAdMobSSVStatus(
  env,
) {
  return {
    enabled: true,

    verification:
      "google_signature",

    rewardCredits:
      REWARDED_AD_CREDITS,

    dailyLimit:
      REWARDED_AD_DAILY_LIMIT,

    customData:
      "device_id",

    transactionId:
      "idempotent",

    publicKeyCacheHours:
      PUBLIC_KEY_CACHE_TTL_MS /
      (60 * 60 * 1000),

    maxCallbackAgeHours:
      MAX_CALLBACK_AGE_MS /
      (60 * 60 * 1000),

    adUnitConfigured:
      Boolean(
        String(
          env?.ADMOB_REWARDED_AD_UNIT_ID ||
            "",
        ).trim(),
      ),

    rewardItem:
      String(
        env?.ADMOB_REWARD_ITEM ||
          DEFAULT_REWARD_ITEM,
      ).trim(),
  };
}

/* =========================================================
   REQUEST DETECTION
   ========================================================= */

export function isAdMobSSVRequest(
  request,
) {
  try {
    const url =
      new URL(
        request.url,
      );

    return (
      request.method ===
        "GET" &&
      url.searchParams.has(
        "signature",
      ) &&
      url.searchParams.has(
        "key_id",
      ) &&
      url.searchParams.has(
        "transaction_id",
      )
    );
  } catch (_) {
    return false;
  }
}
