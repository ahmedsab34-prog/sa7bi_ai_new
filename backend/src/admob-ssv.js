// backend/src/admob-ssv.js
// Sa7bi AI - Final AdMob Rewarded SSV Verification
//
// FINAL REWARD FLOW
// -----------------
//
// Flutter
//   ↓
// AdMob Rewarded Ad
//   ↓
// Google AdMob SSV
//   ↓
// /v1/rewards/admob/ssv
//   ↓
// Verify Google ECDSA signature
//   ↓
// Validate reward / timestamp / ad unit / transaction
//   ↓
// Extract Sa7bi device ID from custom_data
//   ↓
// credits.js
//   ↓
// SQLite Durable Object
//   ↓
// +10 server-authoritative credits
//
// IMPORTANT
// ---------
// Flutter NEVER grants credits directly.
//
// The client-side onUserEarnedReward callback is only
// a UI/event signal.
//
// The actual credit is granted ONLY after Google's
// server-side verification callback is cryptographically
// verified.

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

/*
 * Official Google AdMob SSV public-key endpoint.
 */
const ADMOB_PUBLIC_KEYS_URL =
  "https://www.gstatic.com/admob/reward/verifier-keys.json";

/*
 * Google rotates verification keys.
 *
 * We refresh our Worker-isolate cache every 6 hours,
 * which is safely below Google's 24-hour maximum.
 */
const PUBLIC_KEY_CACHE_TTL_MS =
  6 * 60 * 60 * 1000;

/*
 * Maximum accepted callback age.
 *
 * This prevents very old signed callbacks from being
 * accepted indefinitely.
 */
const MAX_CALLBACK_AGE_MS =
  24 * 60 * 60 * 1000;

/*
 * Protect against timestamps that are clearly from the
 * future because of malformed requests or clock issues.
 */
const MAX_CALLBACK_FUTURE_MS =
  10 * 60 * 1000;

/*
 * This is the reward item configured for Sa7bi's
 * rewarded-ad unit.
 */
const DEFAULT_REWARD_ITEM =
  "credits";

/*
 * Public keys are cached only inside the current Worker
 * isolate. The cache is intentionally not persistent.
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
   BASE64 / BASE64URL → BYTES
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
    normalized.length % 4 !== 0
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
   FETCH GOOGLE ADMOB PUBLIC KEYS
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
      item.keyId === undefined ||
      item.keyId === null
    ) {
      continue;
    }

    const keyId =
      String(
        item.keyId,
      );

    /*
     * Google provides the public key in base64
     * and PEM representations.
     *
     * Prefer the SPKI base64 representation.
     */
    let base64Key =
      typeof item.base64 ===
        "string"
        ? item.base64.trim()
        : "";

    if (
      !base64Key &&
      typeof item.pem === "string"
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
   IMPORT GOOGLE PUBLIC KEY
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
   DER LENGTH READER
   ========================================================= */

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

  /*
   * Short-form DER length.
   */
  if (
    (length & 0x80) === 0
  ) {
    return length;
  }

  /*
   * Long-form DER length.
   *
   * We only need small lengths for an ECDSA signature.
   */
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

/* =========================================================
   NORMALIZE DER INTEGER
   ========================================================= */

function normalizeDerInteger(
  value,
) {
  let start = 0;

  /*
   * Remove DER sign-padding zero bytes.
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
    trimmed.length > 32
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

/* =========================================================
   DER ECDSA → P1363
   ========================================================= */

/*
 * AdMob SSV signatures use DER-encoded ECDSA.
 *
 * Web Crypto ECDSA verification uses the IEEE P1363
 * representation:
 *
 *     R || S
 *
 * for a P-256 signature:
 *
 *     32-byte R + 32-byte S = 64 bytes
 */
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
   ORIGINAL QUERY STRING
   ========================================================= */

/**
 * Returns the original raw query string.
 *
 * This is deliberately NOT reconstructed with
 * URLSearchParams because Google's signature covers the
 * exact query-string content and ordering.
 */
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
   EXTRACT SIGNED CONTENT
   ========================================================= */

/**
 * Google's SSV callback places:
 *
 *   signature
 *   key_id
 *
 * at the end of the query string.
 *
 * Everything before "&signature=" is the signed content.
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
   * Preserve the exact bytes before the signature.
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
   * Remaining content:
   *
   * signatureValue&key_id=123
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
   * key_id must be the final parameter.
   */
  if (
    keyIdValue.includes("&")
  ) {
    throw new Error(
      "ADMOB_SSV_KEY_ID_NOT_FINAL",
    );
  }

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
   VERIFY SIGNATURE WITH PUBLIC KEY
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
   * The signed data is the original query string.
   *
   * No decodeURIComponent().
   * No URLSearchParams reconstruction.
   * No parameter sorting.
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

/* =========================================================
   VERIFY GOOGLE ADMOB SSV
   ========================================================= */

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
   * If Google rotated the key and our six-hour cache
   * does not know it yet, refresh once immediately.
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
   CUSTOM DATA → DEVICE ID
   ========================================================= */

/**
 * Flutter sends:
 *
 * {
 *   "deviceId": "...",
 *   "source": "sa7bi_rewarded_ad"
 * }
 *
 * Google passes that string back as custom_data.
 *
 * URLSearchParams.get() already decodes the normal query
 * parameter, so we do not decode it twice.
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
     * Plain device ID fallback.
     */
  }

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
   * The callback amount MUST equal our server policy.
   *
   * We never blindly trust the callback value as the
   * amount to add.
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
   * Google documents transaction_id as a unique
   * hexadecimal identifier.
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
  /*
   * We intentionally read this from configuration rather
   * than hard-coding the AdMob unit ID into the verifier.
   */
  const configuredAdUnit =
    String(
      env?.ADMOB_REWARDED_AD_UNIT_ID ||
        "",
    ).trim();

  /*
   * If it is not configured yet, verification can still
   * operate using Google's cryptographic signature and
   * the other server validations.
   *
   * Once configured, exact matching is enforced.
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
   MAIN ADMOB SSV HANDLER
   ========================================================= */

export async function handleAdMobSSV(
  request,
  env,
) {
  /*
   * AdMob SSV uses GET callbacks.
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
     * Cryptographically verify the callback with Google's
     * public key.
     *
     * NOTHING is rewarded before this succeeds.
     * -------------------------------------------------------
     */
    await verifyAdMobSignature(
      request,
    );

    /*
     * -------------------------------------------------------
     * STEP 2
     * Validate callback timestamp.
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
     * Validate configured reward.
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
     * Validate rewarded ad unit when configured.
     * -------------------------------------------------------
     */
    validateAdUnit(
      url,
      env,
    );

    /*
     * -------------------------------------------------------
     * STEP 5
     * Validate transaction ID.
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
     * Get Sa7bi device ID.
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
     * Server-authoritative reward.
     *
     * credits.js handles:
     *
     * - exactly +10 credits
     * - daily reward limit
     * - transaction idempotency
     * - SQLite atomicity
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
     * Repeated Google callback:
     *
     * The original transaction has already been processed.
     *
     * This is treated as successful/idempotent handling.
     */
    if (
      result?.ok === true
    ) {
      return json(
        {
          ok: true,

          rewarded:
            result.rewarded === true,

          alreadyRewarded:
            result.alreadyRewarded ===
            true,

          transactionId,

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
     * Daily limit is a valid server-side business rule,
     * not a cryptographic failure.
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
     * Only known/safe validation errors are returned.
     *
     * Internal cryptographic/network/storage details are
     * deliberately hidden.
     */
    const safeErrors =
      new Set([
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
          "REWARDED_AD_DAILY_LIMIT"
          ? 409
          : 400,
      );
    }

    return errorResponse(
      "ADMOB_SSV_VERIFICATION_FAILED",
      500,
    );
  }
}

/* =========================================================
   STATUS
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
   SSV REQUEST DETECTION
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
      request.method === "GET" &&
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
