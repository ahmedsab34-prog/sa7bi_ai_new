// backend/src/content/audio-content.js
// Sa7bi AI Backend - Audio Content Aggregator
// Version: 6.3.0
//
// This module provides one unified entry point for
// religious content while keeping the actual providers
// separated:
//
//   Quran  -> content/quran.js
//   Hadith -> content/hadith.js
//   Tafsir -> content/tafsir.js
//
// IMPORTANT
// ---------
// This file is an aggregator/router only.
// It does not contain API keys or provider secrets.
//
// Dedicated endpoints remain available through index.js:
//   /v1/audio/quran
//   /v1/hadith
//   /v1/tafsir
//
// The unified endpoint is:
//   /v1/religious?type=quran
//   /v1/religious?type=hadith
//   /v1/religious?type=tafsir

/* =========================================================
   IMPORTS
   ========================================================= */

import {
  json,
  normalizeArabic,
} from "../utils.js";

import {
  handleQuranSearch,
} from "./quran.js";

import {
  handleHadithSearch,
} from "./hadith.js";

import {
  handleTafsirSearch,
} from "./tafsir.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const BACKEND_VERSION =
  "6.3.0";

/* =========================================================
   RELIGIOUS CONTENT TYPES
   ========================================================= */

/**
 * Stable list of supported religious content categories.
 *
 * These are internal service identifiers used by the
 * Flutter application and should not depend on UI labels.
 */
const RELIGIOUS_TYPES = [
  {
    id: "quran",
    name: "القرآن الكريم",
    audio: true,
    online: true,
  },

  {
    id: "hadith",
    name: "الحديث",
    audio: true,
    online: true,
  },

  {
    id: "tafsir",
    name: "التفسير",
    audio: true,
    online: true,
  },
];

/* =========================================================
   NORMALIZE RELIGIOUS TYPE
   ========================================================= */

/**
 * Converts Arabic/English user-facing labels into one
 * stable internal service identifier.
 *
 * Examples:
 *
 *   قرآن       -> quran
 *   القرآن     -> quran
 *   quran      -> quran
 *
 *   حديث       -> hadith
 *   أحاديث     -> hadith
 *   hadith     -> hadith
 *
 *   تفسير      -> tafsir
 *   التفسير    -> tafsir
 *   tafsir     -> tafsir
 */
export function normalizeReligiousType(
  value,
) {
  const normalized =
    normalizeArabic(
      value || "",
    )
      .trim()
      .toLowerCase();

  if (
    normalized === "قران" ||
    normalized === "القران" ||
    normalized === "quran"
  ) {
    return "quran";
  }

  if (
    normalized === "حديث" ||
    normalized === "الحديث" ||
    normalized === "احاديث" ||
    normalized === "الاحاديث" ||
    normalized === "hadith"
  ) {
    return "hadith";
  }

  if (
    normalized === "تفسير" ||
    normalized === "التفسير" ||
    normalized === "tafsir"
  ) {
    return "tafsir";
  }

  return "";
}

/* =========================================================
   UNIFIED RELIGIOUS CONTENT SEARCH
   ========================================================= */

/**
 * Unified religious content endpoint.
 *
 * Supported:
 *
 *   /v1/religious?type=quran
 *   /v1/religious?type=hadith
 *   /v1/religious?type=tafsir
 *
 * The original request is forwarded to the dedicated
 * provider handler so its existing query parameters remain
 * available.
 */
export async function handleReligiousContent(
  request,
) {
  try {
    const url =
      new URL(
        request.url,
      );

    const requestedType =
      url.searchParams.get(
        "type",
      ) || "quran";

    const type =
      normalizeReligiousType(
        requestedType,
      );

    if (!type) {
      return json(
        {
          ok: false,

          error:
            "UNSUPPORTED_RELIGIOUS_CONTENT_TYPE",

          message:
            "نوع المحتوى الديني غير مدعوم.",

          supportedTypes:
            RELIGIOUS_TYPES.map(
              (item) => item.id,
            ),

          backendVersion:
            BACKEND_VERSION,
        },
        400,
      );
    }

    switch (type) {
      case "quran":
        return await handleQuranSearch(
          request,
        );

      case "hadith":
        return await handleHadithSearch(
          request,
        );

      case "tafsir":
        return await handleTafsirSearch(
          request,
        );

      default:
        /*
         * This branch should never be reached because
         * normalizeReligiousType() validates the type.
         */
        return json(
          {
            ok: false,

            error:
              "UNSUPPORTED_RELIGIOUS_CONTENT_TYPE",

            supportedTypes:
              RELIGIOUS_TYPES.map(
                (item) => item.id,
              ),

            backendVersion:
              BACKEND_VERSION,
          },
          400,
        );
    }
  } catch (error) {
    /*
     * Do not expose provider internals or stack traces.
     */
    return json(
      {
        ok: false,

        error:
          "RELIGIOUS_CONTENT_SERVICE_UNAVAILABLE",

        message:
          error?.message ||
          "Religious content service unavailable.",

        backendVersion:
          BACKEND_VERSION,
      },
      502,
    );
  }
}

/* =========================================================
   RELIGIOUS CONTENT TYPES ENDPOINT
   ========================================================= */

/**
 * Returns the categories supported by the unified
 * religious-content service.
 *
 * Endpoint:
 *
 *   /v1/religious/types
 */
export async function handleReligiousContentTypes() {
  return json({
    ok: true,

    type:
      "religious-content-types",

    items:
      RELIGIOUS_TYPES.map(
        (item) => ({
          ...item,
        }),
      ),

    backendVersion:
      BACKEND_VERSION,
  });
}

/* =========================================================
   HELPERS
   ========================================================= */

/**
 * Returns whether a normalized religious type is
 * supported.
 */
export function isSupportedReligiousType(
  value,
) {
  return Boolean(
    normalizeReligiousType(
      value,
    ),
  );
}

/**
 * Returns a safe copy of the supported religious types.
 */
export function getReligiousContentTypes() {
  return RELIGIOUS_TYPES.map(
    (item) => ({
      ...item,
    }),
  );
}

/* =========================================================
   DEFAULT EXPORT
   ========================================================= */

export default {
  handleReligiousContent,

  handleReligiousContentTypes,

  normalizeReligiousType,

  isSupportedReligiousType,

  getReligiousContentTypes,
};
