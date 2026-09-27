// backend/src/admob-ssv.js
// Sa7bi AI - AdMob Rewarded SSV Verification
//
// IMPORTANT:
// This module verifies AdMob Server-Side Verification callbacks
// before any rewarded credits are added.
//
// Flow:
//
// AdMob
//   ↓
// SSV callback
//   ↓
// verify Google signature
//   ↓
// validate reward data
//   ↓
// extract Sa7bi device ID from custom_data
//   ↓
// Durable Object
//   ↓
// +10 server-authoritative credits
//
// The Flutter application must NEVER be able to directly
// grant rewarded-ad credits.

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
 * Official Google AdMob rewarded SSV public-key endpoint.
 *
 * Google rotates these keys, so we cache them for less than
 * 24 hours.
 */
const ADMOB_PUBLIC_KEYS_URL =
  "https://www.gstatic.com/admob/reward/verifier-keys.json";

/*
 * Google recommends not caching verification keys longer
 * than 24 hours because keys can rotate.
 *
 * We intentionally use 6 hours.
 */
const PUBLIC_KEY_CACHE_TTL_MS =
  6 * 60 * 60 * 1000;

/*
 * Allow some clock/network delay.
 *
 * SSV callbacks can be delayed, so this is deliberately
 * much more generous than a few minutes.
 */
const MAX_CALLBACK_AGE_MS =
  24 * 60 * 60 * 1000;

/*
 * Protect against callbacks that are too far in the future.
 */
const MAX_CALLBACK_FUTURE_MS =
  10 * 60 * 1000;

/*
 * Expected reward item.
 *
 * If you configure another reward item in AdMob,
 * set:
 *
 * ADMOB_REWARD_ITEM=credits
 *
 * or another exact value.
 */
const DEFAULT_REWARD_ITEM =
  "credits";

/*
 * In-memory Worker cache.
 *
 * Each Worker isolate can keep this cache temporarily.
 * If an isolate restarts, keys are fetched again.
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
   STRING / BASE64 HELPERS
   ========================================================= */

function base64ToBytes(value) {
  if (
    typeof value !==
      "string" ||
    !value
  ) {
    throw new Error(
      "BASE64_VALUE_REQUIRED",
    );
  }

  /*
   * AdMob signatures/public keys use URL-safe
   * base64 in some contexts.
   */
  let normalized =
    value
      .replace(/-/g, "+")
      .replace(/_/g, "/");

  while (
    normalized.length % 4 !==
    0
  ) {
    normalized += "=";
  }

  const binary =
    atob(normalized);

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

function bytesToHex(bytes) {
  let output = "";

  for (
    const byte of bytes
  ) {
    output += byte
      .toString(16)
      .padStart(2, "0");
  }

  return output;
}

/* =========================================================
   ADMOB PUBLIC KEY FETCHING
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

        cf: {
          cacheTtl:
            300,
          cacheEverything:
            true,
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

  const keys = new Map();

  for (
    const item of data.keys
  ) {
    if (
      item == null ||
      item.keyId == null
    ) {
      continue;
    }

    const keyId =
      String(
        item.keyId,
      );

    /*
     * Google currently supplies a base64 SPKI representation.
     *
     * Keep PEM as a fallback if Google includes only PEM.
     */
    let base64 =
      typeof item.base64 ===
      "string"
        ? item.base64.trim()
        : "";

    if (
      !base64 &&
      typeof item.pem ===
        "string"
    ) {
      base64 =
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

    if (!base64) {
      continue;
    }

    keys.set(
      keyId,
      base64,
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

  return crypto.subtle.importKey(
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
}

/* =========================================================
   DER ECDSA → RAW P1363
   ========================================================= */

/*
 * Google SSV signatures are ECDSA signatures.
 *
 * Cloudflare Web Crypto expects the IEEE P1363 form:
 *
 * r || s
 *
 * while the callback signature can be DER encoded.
 *
 * This converter accepts the DER form and returns
 * the 64-byte P-256 raw signature.
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

  let offset = 0;

  if (
    der[offset++] !==
    0x30
  ) {
    throw new Error(
      "ECDSA_DER_SEQUENCE_REQUIRED",
    );
  }

  let sequenceLength =
    der[offset++];

  if (
    sequenceLength &
    0x80
  ) {
    const lengthBytes =
      sequenceLength &
      0x7f;

    if (
      lengthBytes <= 0 ||
      lengthBytes > 2 ||
      offset +
        lengthBytes >
        der.length
    ) {
      throw new Error(
        "ECDSA_DER_LENGTH_INVALID",
      );
    }

    sequenceLength = 0;

    for (
      let i = 0;
      i < lengthBytes;
      i += 1
    ) {
      sequenceLength =
        (sequenceLength <<
          8) |
        der[offset++];
    }
  }

  if (
    sequenceLength !==
    der.length - offset
  ) {
    throw new Error(
      "ECDSA_DER_SEQUENCE_LENGTH_INVALID",
    );
  }

  if (
    der[offset++] !==
    0x02
  ) {
    throw new Error(
      "ECDSA_DER_R_REQUIRED",
    );
  }

  let rLength =
    der[offset++];

  if (
    rLength &
    0x80
  ) {
    const lengthBytes =
      rLength &
      0x7f;

    if (
      lengthBytes <= 0 ||
      lengthBytes > 2
    ) {
      throw new Error(
        "ECDSA_DER_R_LENGTH_INVALID",
      );
    }

    rLength = 0;

    for (
      let i = 0;
      i < lengthBytes;
      i += 1
    ) {
      rLength =
        (rLength <<
          8) |
        der[offset++];
    }
  }

  const rStart =
    offset;

  const rEnd =
    rStart +
    rLength;

  if (
    rEnd >
    der.length
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

  offset =
    rEnd;

  if (
    der[offset++] !==
    0x02
  ) {
    throw new Error(
      "ECDSA_DER_S_REQUIRED",
    );
  }

  let sLength =
    der[offset++];

  if (
    sLength &
    0x80
  ) {
    const lengthBytes =
      sLength &
      0x7f;

    if (
      lengthBytes <= 0 ||
      lengthBytes > 2
    ) {
      throw new Error(
        "ECDSA_DER_S_LENGTH_INVALID",
      );
    }

    sLength = 0;

    for (
      let i = 0;
      i < lengthBytes;
      i += 1
    ) {
      sLength =
        (sLength <<
          8) |
        der[offset++];
    }
  }

  const sStart =
    offset;

  const sEnd =
    sStart +
    sLength;

  if (
    sEnd !==
    der.length
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

  /*
   * P-256 integers are exactly 32 bytes.
   *
   * DER can contain a leading zero byte.
   */
  const normalizeInteger =
    (value) => {
      let start = 0;

      while (
        start <
          value.length -
            32 &&
        value[start] ===
          0
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

      const output =
        new Uint8Array(
          32,
        );

      output.set(
        trimmed,
        32 -
          trimmed.length,
      );

      return output;
    };

  const rawR =
    normalizeInteger(r);

  const rawS =
    normalizeInteger(s);

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
   SIGNATURE VERIFICATION
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

function extractSignedContent(
  rawQuery,
) {
  /*
   * Google documents that signature and key_id are the
   * final two query parameters, in that order.
   *
   * We deliberately do NOT rebuild the query string using
   * URLSearchParams because doing so could change escaping
   * or parameter ordering and invalidate the signature.
   */

  const signatureMarker =
    "&signature=";

  const keyIdMarker =
    "&key_id=";

  const signatureIndex =
    rawQuery.lastIndexOf(
      signatureMarker,
    );

  const keyIdIndex =
    rawQuery.lastIndexOf(
      keyIdMarker,
    );

  if (
    signatureIndex < 0 ||
    keyIdIndex < 0
  ) {
    throw new Error(
      "ADMOB_SSV_SIGNATURE_OR_KEY_ID_MISSING",
    );
  }

  /*
   * key_id must be after signature.
   */
  if (
    keyIdIndex <=
    signatureIndex
  ) {
    throw new Error(
      "ADMOB_SSV_PARAMETER_ORDER_INVALID",
    );
  }

  /*
   * There must be no extra data after key_id.
   */
  const signedContent =
    rawQuery.substring(
      0,
      signatureIndex,
    );

  const signatureValue =
    rawQuery.substring(
      signatureIndex +
        signatureMarker.length,
      keyIdIndex,
    );

  const keyIdValue =
    rawQuery.substring(
      keyIdIndex +
        keyIdMarker.length,
    );

  if (
    !signedContent ||
    !signatureValue ||
    !keyIdValue
  ) {
    throw new Error(
      "ADMOB_SSV_SIGNED_DATA_INVALID",
    );
  }

  return {
    signedContent,
    signatureValue,
    keyIdValue,
  };
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

  const keys =
    await getAdMobPublicKeys();

  const base64PublicKey =
    keys.get(
      String(
        keyIdValue,
      ),
    );

  if (
    !base64PublicKey
  ) {
    /*
     * Key rotation can happen.
     *
     * Force one refresh before declaring
     * the key invalid.
     */
    publicKeyCache =
      null;

    const refreshedKeys =
      await getAdMobPublicKeys();

    const refreshedKey =
      refreshedKeys.get(
        String(
          keyIdValue,
        ),
      );

    if (!refreshedKey) {
      throw new Error(
        "ADMOB_SSV_UNKNOWN_KEY_ID",
      );
    }

    return verifyWithPublicKey(
      refreshedKey,
      signedContent,
      signatureValue,
    );
  }

  return verifyWithPublicKey(
    base64PublicKey,
    signedContent,
    signatureValue,
  );
}

async function verifyWithPublicKey(
  base64PublicKey,
  signedContent,
  signatureValue,
) {
  const publicKey =
    await importAdMobPublicKey(
      base64PublicKey,
    );

  const signatureDer =
    base64ToBytes(
      signatureValue,
    );

  const signatureRaw =
    derEcdsaToRaw(
      signatureDer,
    );

  const data =
    new TextEncoder().encode(
      signedContent,
    );

  const valid =
    await crypto.subtle.verify(
      {
        name: "ECDSA",
        hash: "SHA-256",
      },
      publicKey,
      signatureRaw,
      data,
    );

  if (!valid) {
    throw new Error(
      "ADMOB_SSV_SIGNATURE_INVALID",
    );
  }

  return true;
}

/* =========================================================
   CUSTOM DATA
   ========================================================= */

function decodeCustomData(
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
    decodeURIComponent(
      value,
    );

  /*
   * Preferred format:
   *
   * {
   *   "deviceId": "..."
   * }
   *
   * We also accept a plain device ID for simple
   * compatibility/testing.
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
      return {
        deviceId:
          parsed.deviceId
            .trim()
            .substring(0, 128),
      };
    }
  } catch (_) {
    // Fall through to plain string.
  }

  const plain =
    raw.trim();

  if (!plain) {
    throw new Error(
      "ADMOB_SSV_CUSTOM_DATA_INVALID",
    );
  }

  return {
    deviceId:
      plain.substring(
        0,
        128,
      ),
  };
}

/* =========================================================
   CALLBACK VALIDATION
   ========================================================= */

function validateTimestamp(
  timestampValue,
) {
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

function validateReward(
  url,
  env,
) {
  const rewardAmount =
    Number(
      url.searchParams.get(
        "reward_amount",
      ),
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
   * Never trust reward_amount as the amount
   * to add to the user's account.
   *
   * It is only compared against our server policy.
   */
  if (
    rewardAmount !==
    REWARDED_AD_CREDITS
  ) {
    throw new Error(
      "ADMOB_SSV_REWARD_AMOUNT_MISMATCH",
    );
  }

  const configuredItem =
    (
      env?.ADMOB_REWARD_ITEM ||
      DEFAULT_REWARD_ITEM
    )
      .trim();

  const rewardItem =
    (
      url.searchParams.get(
        "reward_item",
      ) || ""
    ).trim();

  if (
    configuredItem &&
    rewardItem !==
      configuredItem
  ) {
    throw new Error(
      "ADMOB_SSV_REWARD_ITEM_MISMATCH",
    );
  }

  return {
    rewardAmount,
    rewardItem,
  };
}

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

  return value
    .trim()
    .substring(0, 256);
}

function validateAdUnit(
  url,
  env,
) {
  const configuredAdUnit =
    (
      env?.ADMOB_REWARDED_AD_UNIT_ID ||
      ""
    ).trim();

  /*
   * If the Worker has an AdMob rewarded ad-unit ID
   * configured, require an exact match.
   *
   * If not configured yet, don't block SSV setup.
   */
  if (!configuredAdUnit) {
    return true;
  }

  const callbackAdUnit =
    (
      url.searchParams.get(
        "ad_unit",
      ) || ""
    ).trim();

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
   * Google SSV callbacks are GET requests.
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
     * 1. Verify cryptographic signature FIRST.
     *
     * Nothing from the callback is trusted before
     * this step succeeds.
     */
    await verifyAdMobSignature(
      request,
    );

    /*
     * 2. Validate timestamp.
     */
    const timestamp =
      validateTimestamp(
        url.searchParams.get(
          "timestamp",
        ),
      );

    /*
     * 3. Validate reward configuration.
     */
    const reward =
      validateReward(
        url,
        env,
      );

    /*
     * 4. Validate configured ad unit.
     */
    validateAdUnit(
      url,
      env,
    );

    /*
     * 5. Extract unique AdMob transaction ID.
     */
    const transactionId =
      validateTransactionId(
        url.searchParams.get(
          "transaction_id",
        ),
      );

    /*
     * 6. Extract Sa7bi device ID from custom_data.
     *
     * The Flutter app will set this before showing
     * the rewarded ad.
     */
    const customData =
      decodeCustomData(
        url.searchParams.get(
          "custom_data",
        ),
      );

    /*
     * 7. Apply reward to the server-authoritative
     * Durable Object.
     *
     * rewardVerifiedAd() itself uses transaction_id
     * as an idempotency key.
     */
    const result =
      await rewardVerifiedAd(
        env,
        {
          deviceId:
            customData.deviceId,

          transactionId,

          source:
            "admob_ssv",
        },
      );

    /*
     * If the reward was already processed, this is still
     * a successful SSV callback.
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

          added:
            Number(
              result.added ??
                REWARDED_AD_CREDITS,
            ),

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
     * Daily limit is a valid rejection.
     *
     * Return a non-2xx response so the event is not
     * falsely reported as successfully credited.
     */
    return errorResponse(
      result?.error ||
        "REWARDED_AD_NOT_GRANTED",
      result?.error ===
        "REWARDED_AD_DAILY_LIMIT"
        ? 409
        : 400,
    );
  } catch (error) {
    /*
     * Do not expose cryptographic details,
     * public keys, or internal exceptions.
     */
    const message =
      error?.message ||
      "ADMOB_SSV_VERIFICATION_FAILED";

    const safeErrors =
      new Set([
        "METHOD_NOT_ALLOWED",

        "ADMOB_SSV_SIGNATURE_OR_KEY_ID_MISSING",
        "ADMOB_SSV_PARAMETER_ORDER_INVALID",
        "ADMOB_SSV_SIGNED_DATA_INVALID",
        "ADMOB_SSV_UNKNOWN_KEY_ID",
        "ADMOB_SSV_SIGNATURE_INVALID",

        "ADMOB_SSV_TIMESTAMP_INVALID",
        "ADMOB_SSV_CALLBACK_TOO_OLD",
        "ADMOB_SSV_CALLBACK_FROM_FUTURE",

        "ADMOB_SSV_REWARD_AMOUNT_INVALID",
        "ADMOB_SSV_REWARD_AMOUNT_MISMATCH",
        "ADMOB_SSV_REWARD_ITEM_MISMATCH",

        "ADMOB_SSV_TRANSACTION_ID_MISSING",

        "ADMOB_SSV_CUSTOM_DATA_MISSING",
        "ADMOB_SSV_CUSTOM_DATA_INVALID",

        "ADMOB_SSV_AD_UNIT_MISMATCH",

        "REWARDED_AD_DAILY_LIMIT",
      ]);

    if (
      safeErrors.has(
        message,
      )
    ) {
      return errorResponse(
        message,
        400,
      );
    }

    return errorResponse(
      "ADMOB_SSV_VERIFICATION_FAILED",
      500,
    );
  }
}

/* =========================================================
   SSV CONFIGURATION INFO
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
        (
          env?.ADMOB_REWARDED_AD_UNIT_ID ||
          ""
        ).trim(),
      ),

    rewardItem:
      (
        env?.ADMOB_REWARD_ITEM ||
        DEFAULT_REWARD_ITEM
      ).trim(),
  };
}

/* =========================================================
   TEST HELPERS
   ========================================================= */

/*
 * These helpers are intentionally not used to grant credits.
 *
 * They are useful for diagnostics/tests without exposing
 * any reward-grant bypass.
 */

export function isAdMobSSVRequest(
  request,
) {
  try {
    const url =
      new URL(
        request.url,
      );

    return (
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
