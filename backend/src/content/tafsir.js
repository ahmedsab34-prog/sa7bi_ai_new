// backend/src/content/tafsir.js
// Sa7bi AI Backend
//
// Tafsir content + audio module.
//
// Source:
// MP3Quran public API
//
// Endpoints used:
// GET /v1/tafsir/books
// GET /v1/tafsir?tafsir=1&sura=114
// GET /v1/tafsir/audio?tafsir=1&sura=114
//
// MP3Quran provides:
// - available Tafsir editions
// - Tafsir Surah data
// - Tafsir audio URLs
//
// No API keys are required here.

/* =========================================================
   IMPORTS
   ========================================================= */

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const BACKEND_VERSION =
  "6.3.0";

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

const MAX_SURAS =
  114;

const MAX_BOOKS =
  200;

const MAX_RESULTS =
  300;

/* =========================================================
   HELPERS
   ========================================================= */

/**
 * Normalize and validate a Tafsir ID.
 */
function normalizeTafsirId(
  value
) {
  const id =
    Number(value);

  if (
    !Number.isInteger(id) ||
    id <= 0
  ) {
    return 0;
  }

  return id;
}

/**
 * Normalize and validate a Surah number.
 */
function normalizeSurahId(
  value
) {
  const id =
    Number(value);

  if (
    !Number.isInteger(id) ||
    id < 1 ||
    id > MAX_SURAS
  ) {
    return 0;
  }

  return id;
}

/**
 * Normalize a public HTTP/HTTPS URL.
 *
 * Tafsir audio is returned by MP3Quran,
 * so only normal public HTTP(S) URLs are accepted.
 */
function normalizePublicUrl(
  value
) {
  if (
    typeof value !==
      "string"
  ) {
    return "";
  }

  const raw =
    value.trim();

  if (!raw) {
    return "";
  }

  try {
    const url =
      new URL(raw);

    if (
      url.protocol !==
        "http:" &&
      url.protocol !==
        "https:"
    ) {
      return "";
    }

    return url.toString();
  } catch {
    return "";
  }
}

/**
 * Normalize the Tafsir editions list.
 */
function normalizeTafsirBooks(
  data
) {
  const raw =
    Array.isArray(
      data?.tafasir
    )
      ? data.tafasir
      : [];

  return raw
    .slice(
      0,
      MAX_BOOKS
    )
    .map(
      (
        item,
        index
      ) => {
        const id =
          normalizeTafsirId(
            item?.id
          );

        const name =
          typeof item?.name ===
            "string" &&
          item.name.trim()
            ? item.name.trim()
            : `تفسير ${index + 1}`;

        const url =
          normalizePublicUrl(
            item?.url
          );

        return {
          id:
            id ||
            index + 1,

          name,

          url,

          language:
            "ar",

          source:
            "MP3Quran",

          type:
            "tafsir",
        };
      }
    )
    .filter(
      (
        item
      ) =>
        item.id > 0
    );
}

/**
 * Normalize one Tafsir entry.
 */
function normalizeTafsirEntry(
  entry,
  suraKey,
  tafsirName
) {
  if (
    !entry ||
    typeof entry !==
      "object"
  ) {
    return null;
  }

  const sura =
    normalizeSurahId(
      entry?.sura_id ??
        suraKey
    );

  if (!sura) {
    return null;
  }

  const title =
    typeof entry?.name ===
      "string" &&
    entry.name.trim()
      ? entry.name.trim()
      : `سورة رقم ${sura}`;

  const audioUrl =
    normalizePublicUrl(
      entry?.url
    );

  const id =
    entry?.id ??
    null;

  const tafsirId =
    normalizeTafsirId(
      entry?.tafsir_id
    ) ||
    null;

  return {
    id,

    tafsirId,

    tafsirName:
      tafsirName ||
      "",

    sura,

    suraName:
      title,

    audioUrl:
      audioUrl ||
      null,

    source:
      "MP3Quran",

    language:
      "ar",

    type:
      "tafsir",
  };
}

/**
 * Normalize the Tafsir response returned by
 * MP3Quran /api/v3/tafsir.
 *
 * Current response structure:
 *
 * {
 *   tafasir: {
 *     name: "...",
 *     sora: {
 *       "114": [
 *         {
 *           id: 114,
 *           tafsir_id: 1,
 *           name: "...",
 *           url: "...",
 *           sura_id: 114
 *         }
 *       ]
 *     }
 *   }
 * }
 */
function normalizeTafsirResponse(
  data,
  query = ""
) {
  if (
    !data ||
    typeof data !==
      "object"
  ) {
    return [];
  }

  const tafsirName =
    typeof data?.name ===
      "string"
      ? data.name.trim()
      : "";

  const sora =
    data?.sora;

  if (
    !sora ||
    typeof sora !==
      "object"
  ) {
    return [];
  }

  const normalizedQuery =
    normalizeArabic(
      query
    );

  const results = [];

  for (
    const [
      suraKey,
      entries
    ] of Object.entries(
      sora
    )
  ) {
    if (
      !Array.isArray(
        entries
      )
    ) {
      continue;
    }

    for (
      const entry
      of entries
    ) {
      const normalized =
        normalizeTafsirEntry(
          entry,
          suraKey,
          tafsirName
        );

      if (!normalized) {
        continue;
      }

      if (
        normalizedQuery
      ) {
        const searchableText =
          normalizeArabic(
            [
              normalized.suraName,
              normalized.tafsirName,
              String(
                normalized.sura
              ),
            ]
              .filter(
                Boolean
              )
              .join(" ")
          );

        if (
          !searchableText.includes(
            normalizedQuery
          )
        ) {
          continue;
        }
      }

      results.push(
        normalized
      );

      if (
        results.length >=
        MAX_RESULTS
      ) {
        return results;
      }
    }
  }

  return results;
}

/* =========================================================
   TAFSIR BOOKS
   ========================================================= */

/**
 * Get all available Tafsir editions.
 *
 * GET /v1/tafsir/books
 */
export async function handleTafsirBooks() {
  try {
    const endpoint =
      `${MP3QURAN_BASE}/tafasir?language=ar`;

    const data =
      await fetchJson(
        endpoint
      );

    const items =
      normalizeTafsirBooks(
        data
      );

    return json({
      ok: true,

      type:
        "tafsir-books",

      count:
        items.length,

      items,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "tafsir-books",

        count:
          0,

        items: [],

        error:
          "TAFSIR_BOOKS_FAILED",

        message:
          error?.message ||
          "تعذر تحميل قائمة التفاسير.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   TAFSIR SEARCH / CONTENT
   ========================================================= */

/**
 * Get Tafsir content.
 *
 * Required:
 *   tafsir
 *
 * Optional:
 *   sura
 *   q
 *
 * Examples:
 *
 * /v1/tafsir?tafsir=1
 * /v1/tafsir?tafsir=1&sura=114
 * /v1/tafsir?tafsir=1&q=الناس
 */
export async function handleTafsirSearch(
  request
) {
  try {
    const url =
      new URL(
        request.url
      );

    const tafsirRaw =
      url.searchParams.get(
        "tafsir"
      );

    const suraRaw =
      url.searchParams.get(
        "sura"
      );

    const query =
      typeof url.searchParams.get(
        "q"
      ) === "string"
        ? url.searchParams
            .get("q")
            .trim()
        : "";

    const tafsir =
      normalizeTafsirId(
        tafsirRaw
      );

    if (!tafsir) {
      return json(
        {
          ok: false,

          error:
            "tafsir is required",

          hint:
            "Use /v1/tafsir/books to get available Tafsir IDs",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    let sura =
      null;

    if (
      suraRaw !== null &&
      suraRaw !== ""
    ) {
      const normalized =
        normalizeSurahId(
          suraRaw
        );

      if (!normalized) {
        return json(
          {
            ok: false,

            error:
              "Sura must be between 1 and 114",

            backendVersion:
              BACKEND_VERSION,
          },
          400
        );
      }

      sura =
        normalized;
    }

    const params =
      new URLSearchParams();

    params.set(
      "tafsir",
      String(tafsir)
    );

    params.set(
      "language",
      "ar"
    );

    if (
      sura !== null
    ) {
      params.set(
        "sura",
        String(sura)
      );
    }

    const endpoint =
      `${MP3QURAN_BASE}/tafsir?${params.toString()}`;

    const data =
      await fetchJson(
        endpoint
      );

    const items =
      normalizeTafsirResponse(
        data?.tafasir,
        query
      );

    return json({
      ok: true,

      type:
        "tafsir",

      tafsir,

      sura,

      query,

      count:
        items.length,

      items,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "tafsir",

        items: [],

        error:
          "TAFSIR_SEARCH_FAILED",

        message:
          error?.message ||
          "تعذر تحميل التفسير.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   TAFSIR AUDIO
   ========================================================= */

/**
 * Get the Tafsir audio URL for one Tafsir
 * and one Surah.
 *
 * GET /v1/tafsir/audio?tafsir=1&sura=114
 *
 * MP3Quran supplies the actual audio URL in
 * the Tafsir response. We do not construct or
 * invent an audio URL ourselves.
 */
export async function handleTafsirAudio(
  request
) {
  try {
    const url =
      new URL(
        request.url
      );

    const tafsir =
      normalizeTafsirId(
        url.searchParams.get(
          "tafsir"
        )
      );

    const sura =
      normalizeSurahId(
        url.searchParams.get(
          "sura"
        )
      );

    if (!tafsir) {
      return json(
        {
          ok: false,

          error:
            "Valid tafsir ID is required",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    if (!sura) {
      return json(
        {
          ok: false,

          error:
            "Sura must be between 1 and 114",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const params =
      new URLSearchParams();

    params.set(
      "tafsir",
      String(tafsir)
    );

    params.set(
      "sura",
      String(sura)
    );

    params.set(
      "language",
      "ar"
    );

    const endpoint =
      `${MP3QURAN_BASE}/tafsir?${params.toString()}`;

    const data =
      await fetchJson(
        endpoint
      );

    const items =
      normalizeTafsirResponse(
        data?.tafasir
      );

    const audioItem =
      items.find(
        (
          item
        ) =>
          item.sura ===
            sura &&
          Boolean(
            item.audioUrl
          )
      ) ||
      null;

    return json({
      ok: true,

      type:
        "tafsir-audio",

      tafsir,

      sura,

      available:
        Boolean(
          audioItem?.audioUrl
        ),

      audioUrl:
        audioItem?.audioUrl ||
        null,

      item:
        audioItem,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "tafsir-audio",

        available:
          false,

        audioUrl:
          null,

        item:
          null,

        error:
          "TAFSIR_AUDIO_FAILED",

        message:
          error?.message ||
          "تعذر تحميل صوت التفسير.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   EXPORTS
   ========================================================= */

export default {
  handleTafsirBooks,
  handleTafsirSearch,
  handleTafsirAudio,
};
