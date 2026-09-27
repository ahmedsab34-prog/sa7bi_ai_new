// backend/src/content/quran.js
// Sa7bi AI Backend
//
// Quran content module.
//
// Source:
// MP3Quran public API
//
// Endpoints:
// GET /v1/audio/search?q=...
// GET /v1/audio/quran
//
// Responsibilities:
// - Quran Surah search
// - Quran reciters catalog
// - Moshaf / narration information
// - Surah list
// - Reliable MP3 URL construction
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

const MAX_SURAS = 114;

const MAX_RECITERS = 500;

/* =========================================================
   HELPERS
   ========================================================= */

/**
 * Convert a value into a valid Surah number.
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
 * Normalize a public media/server URL.
 */
function normalizeServerUrl(
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

    return url.toString()
      .replace(
        /\/+$/,
        ""
      );
  } catch {
    return "";
  }
}

/**
 * Normalize a reciter's Moshaf list.
 */
function normalizeMoshafList(
  reciter
) {
  const raw =
    Array.isArray(
      reciter?.moshaf
    )
      ? reciter.moshaf
      : [];

  return raw
    .map(
      (
        moshaf,
        index
      ) => {
        const server =
          normalizeServerUrl(
            moshaf?.server ||
              moshaf?.url ||
              ""
          );

        const totalRaw =
          Number(
            moshaf?.surah_total ??
              moshaf?.surahTotal ??
              MAX_SURAS
          );

        const surahTotal =
          Number.isInteger(
            totalRaw
          ) &&
          totalRaw > 0 &&
          totalRaw <=
            MAX_SURAS
            ? totalRaw
            : MAX_SURAS;

        return {
          id:
            moshaf?.id ||
            `${reciter?.id || "reciter"}-${index + 1}`,

          name:
            typeof moshaf?.name ===
              "string" &&
            moshaf.name.trim()
              ? moshaf.name.trim()
              : "رواية",

          server,

          surahTotal,

          suras:
            typeof moshaf?.suras ===
              "string"
              ? moshaf.suras
              : "",
        };
      }
    )
    .filter(
      (
        moshaf
      ) =>
        Boolean(
          moshaf.server
        )
    );
}

/**
 * Normalize reciters returned by MP3Quran.
 */
function normalizeReciters(
  data
) {
  const raw =
    Array.isArray(data)
      ? data
      : [];

  return raw
    .slice(
      0,
      MAX_RECITERS
    )
    .map(
      (
        reciter,
        index
      ) => {
        const id =
          reciter?.id ||
          reciter?.reciter_id ||
          reciter?.name ||
          `reciter-${index + 1}`;

        const name =
          typeof reciter?.name ===
            "string" &&
          reciter.name.trim()
            ? reciter.name.trim()
            : "قارئ";

        return {
          id,

          name,

          moshaf:
            normalizeMoshafList(
              reciter
            ),
        };
      }
    )
    .filter(
      (
        reciter
      ) =>
        Boolean(
          reciter.name
        )
    );
}

/**
 * Normalize the Surah catalog.
 */
function normalizeSuras(
  data
) {
  const raw =
    Array.isArray(data)
      ? data
      : [];

  return raw
    .map(
      (
        sura
      ) => {
        const id =
          normalizeSurahId(
            sura?.id ||
              sura?.sura_id ||
              sura?.number
          );

        const name =
          typeof sura?.name ===
            "string" &&
          sura.name.trim()
            ? sura.name.trim()
            : "سورة";

        return {
          id,

          title:
            name,

          name,

          type:
            "quran",
        };
      }
    )
    .filter(
      (
        sura
      ) =>
        sura.id >= 1 &&
        sura.id <=
          MAX_SURAS
    );
}

/* =========================================================
   QURAN SEARCH
   ========================================================= */

/**
 * Search Quran Surahs.
 *
 * GET /v1/audio/search?q=...
 *
 * The existing Flutter application can use this endpoint
 * with type=quran without requiring any change to the
 * response contract.
 */
export async function handleQuranSearch(
  query = ""
) {
  try {
    const data =
      await fetchJson(
        `${MP3QURAN_BASE}/suwar?language=ar`
      );

    let items =
      normalizeSuras(
        data
      );

    const normalizedQuery =
      normalizeArabic(
        query
      );

    if (
      normalizedQuery
    ) {
      items =
        items.filter(
          (
            item
          ) =>
            normalizeArabic(
              item.name
            ).includes(
              normalizedQuery
            )
        );
    }

    return json({
      ok: true,

      type:
        "quran",

      query:
        typeof query ===
          "string"
          ? query.trim()
          : "",

      count:
        items.length,

      items:
        items.slice(
          0,
          MAX_SURAS
        ),

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "quran",

        error:
          "QURAN_SEARCH_FAILED",

        message:
          error?.message ||
          "تعذر تحميل سور القرآن.",

        items: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   QURAN CATALOG
   ========================================================= */

/**
 * Get Quran reciters and Surahs.
 *
 * GET /v1/audio/quran
 *
 * The Flutter app can use:
 *
 * reciters
 *   -> moshaf
 *       -> server
 *       -> suras
 *
 * and:
 *
 * suras
 */
export async function handleQuranCatalog() {
  try {
    const [
      recitersData,
      suwarData,
    ] =
      await Promise.all([
        fetchJson(
          `${MP3QURAN_BASE}/reciters?language=ar`
        ),

        fetchJson(
          `${MP3QURAN_BASE}/suwar?language=ar`
        ),
      ]);

    const reciters =
      normalizeReciters(
        recitersData
      );

    const suras =
      normalizeSuras(
        suwarData
      );

    return json({
      ok: true,

      type:
        "quran-catalog",

      reciters,

      suras,

      count:
        suras.length,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "quran-catalog",

        error:
          "QURAN_CATALOG_FAILED",

        message:
          error?.message ||
          "تعذر تحميل قائمة القراء والسور.",

        reciters: [],

        suras: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   AUDIO URL
   ========================================================= */

/**
 * Build the MP3 URL for one Surah.
 *
 * MP3Quran commonly uses:
 *
 * server + 001.mp3
 * server + 002.mp3
 * ...
 * server + 114.mp3
 *
 * Example:
 *
 * buildQuranAudioUrl(
 *   "https://server.example/",
 *   2
 * )
 *
 * =>
 * https://server.example/002.mp3
 */
export function buildQuranAudioUrl(
  server,
  surahId
) {
  const cleanServer =
    normalizeServerUrl(
      server
    );

  const id =
    normalizeSurahId(
      surahId
    );

  if (
    !cleanServer ||
    !id
  ) {
    return "";
  }

  const padded =
    String(id).padStart(
      3,
      "0"
    );

  return `${cleanServer}/${padded}.mp3`;
}

/* =========================================================
   EXPORTS
   ========================================================= */

export default {
  handleQuranSearch,
  handleQuranCatalog,
  buildQuranAudioUrl,
};
