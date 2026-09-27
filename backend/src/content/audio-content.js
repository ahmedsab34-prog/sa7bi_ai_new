// backend/src/content/audio-content.js
// Sa7bi AI Backend - Audio Content Aggregator
// Version: 6.0.0

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

const BACKEND_VERSION = "6.0.0";

/**
 * Unified religious audio/content search.
 *
 * Supported:
 *
 * type=quran
 * type=hadith
 * type=tafsir
 */
export async function handleReligiousContent(
  request
) {
  try {
    const url =
      new URL(request.url);

    const type =
      (
        url.searchParams.get(
          "type"
        ) || "quran"
      )
        .trim()
        .toLowerCase();

    switch (type) {
      case "quran":
        return await handleQuranSearch(
          request
        );

      case "hadith":
        return await handleHadithSearch(
          request
        );

      case "tafsir":
        return await handleTafsirSearch(
          request
        );

      default:
        return json(
          {
            ok: false,

            error:
              "Unsupported religious content type",

            supportedTypes: [
              "quran",
              "hadith",
              "tafsir",
            ],

            backendVersion:
              BACKEND_VERSION,
          },
          400
        );
    }
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          "Religious content service unavailable",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Return the available religious content
 * categories for the Flutter application.
 */
export async function handleReligiousContentTypes() {
  return json({
    ok: true,

    type:
      "religious-content-types",

    items: [
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
    ],

    backendVersion:
      BACKEND_VERSION,
  });
}

/**
 * Normalize a user-selected religious category.
 *
 * This helper allows the Flutter side to pass Arabic
 * labels without making the backend depend on exact
 * UI wording.
 */
export function normalizeReligiousType(
  value
) {
  const normalized =
    normalizeArabic(
      value || ""
    );

  if (
    normalized ===
      "قران" ||
    normalized ===
      "القران" ||
    normalized ===
      "quran"
  ) {
    return "quran";
  }

  if (
    normalized ===
      "حديث" ||
    normalized ===
      "الحديث" ||
    normalized ===
      "احاديث" ||
    normalized ===
      "hadith"
  ) {
    return "hadith";
  }

  if (
    normalized ===
      "تفسير" ||
    normalized ===
      "التفسير" ||
    normalized ===
      "tafsir"
  ) {
    return "tafsir";
  }

  return "";
}

export default {
  handleReligiousContent,
  handleReligiousContentTypes,
  normalizeReligiousType,
};
