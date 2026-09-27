// backend/src/content/tafsir.js
// Sa7bi AI Backend - Tafsir Module
// Version: 6.0.0

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

/**
 * Get available Tafsir editions.
 *
 * Example:
 * /v1/tafsir/books
 */
export async function handleTafsirBooks() {
  try {
    const endpoint =
      `${MP3QURAN_BASE}/tafasir?language=ar`;

    const data =
      await fetchJson(endpoint);

    const raw =
      Array.isArray(data?.tafasir)
        ? data.tafasir
        : [];

    const items =
      raw.map((item, index) => ({
        id:
          item.id ??
          index + 1,

        name:
          item.name ||
          `تفسير ${index + 1}`,

        url:
          item.url ||
          null,

        language:
          "ar",

        source:
          "MP3Quran",
      }));

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

        items: [],

        error:
          "Unable to load Tafsir books",

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
 * Get Tafsir for a specific Tafsir edition
 * and optionally a specific Surah.
 *
 * Examples:
 *
 * /v1/tafsir?tafsir=1
 * /v1/tafsir?tafsir=1&sura=2
 */
export async function handleTafsirSearch(
  request
) {
  try {
    const url =
      new URL(request.url);

    const tafsirId =
      url.searchParams.get(
        "tafsir"
      );

    const suraRaw =
      url.searchParams.get(
        "sura"
      );

    const query =
      normalizeArabic(
        url.searchParams.get(
          "q"
        ) || ""
      );

    if (!tafsirId) {
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

    const tafsirNumber =
      Number(tafsirId);

    if (
      !Number.isInteger(
        tafsirNumber
      ) ||
      tafsirNumber <= 0
    ) {
      return json(
        {
          ok: false,

          error:
            "Invalid Tafsir ID",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    let sura = null;

    if (suraRaw) {
      const parsedSura =
        Number(suraRaw);

      if (
        !Number.isInteger(
          parsedSura
        ) ||
        parsedSura < 1 ||
        parsedSura > 114
      ) {
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
        parsedSura;
    }

    const params =
      new URLSearchParams();

    params.set(
      "tafsir",
      String(tafsirNumber)
    );

    params.set(
      "language",
      "ar"
    );

    if (sura !== null) {
      params.set(
        "sura",
        String(sura)
      );
    }

    const endpoint =
      `${MP3QURAN_BASE}/tafsir?${params.toString()}`;

    const data =
      await fetchJson(endpoint);

    const raw =
      data?.tafasir;

    const items =
      normalizeTafsirResponse(
        raw,
        query
      );

    return json({
      ok: true,

      type:
        "tafsir",

      tafsir:
        tafsirNumber,

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
          "Tafsir service unavailable",

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
 * Normalize MP3Quran Tafsir response.
 *
 * Their response groups Tafsir entries under
 * a "sora" object keyed by Surah number.
 */
function normalizeTafsirResponse(
  data,
  query = ""
) {
  if (
    !data ||
    typeof data !== "object"
  ) {
    return [];
  }

  const results = [];

  const tafsirName =
    data.name ||
    "";

  const sora =
    data.sora;

  if (
    !sora ||
    typeof sora !== "object"
  ) {
    return [];
  }

  for (
    const [suraKey, entries]
    of Object.entries(sora)
  ) {
    if (
      !Array.isArray(entries)
    ) {
      continue;
    }

    for (
      const entry of entries
    ) {
      if (
        !entry ||
        typeof entry !== "object"
      ) {
        continue;
      }

      const title =
        entry.name ||
        "";

      const normalizedTitle =
        normalizeArabic(
          title
        );

      const normalizedTafsirName =
        normalizeArabic(
          tafsirName
        );

      if (
        query &&
        !normalizedTitle.includes(
          query
        ) &&
        !normalizedTafsirName.includes(
          query
        )
      ) {
        continue;
      }

      results.push({
        id:
          entry.id ??
          null,

        tafsirId:
          entry.tafsir_id ??
          null,

        tafsirName,

        sura:
          Number(
            entry.sura_id ??
            suraKey
          ) || null,

        suraName:
          title,

        audioUrl:
          entry.url ||
          null,

        source:
          "MP3Quran",

        type:
          "tafsir",
      });
    }
  }

  return results;
}

/**
 * Get Tafsir audio for one Surah.
 *
 * This is useful for the application's audio
 * player and background playback system.
 *
 * Example:
 * /v1/tafsir/audio?tafsir=1&sura=114
 */
export async function handleTafsirAudio(
  request
) {
  try {
    const url =
      new URL(request.url);

    const tafsirId =
      Number(
        url.searchParams.get(
          "tafsir"
        )
      );

    const sura =
      Number(
        url.searchParams.get(
          "sura"
        )
      );

    if (
      !Number.isInteger(
        tafsirId
      ) ||
      tafsirId <= 0
    ) {
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

    if (
      !Number.isInteger(
        sura
      ) ||
      sura < 1 ||
      sura > 114
    ) {
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
      String(tafsirId)
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
      await fetchJson(endpoint);

    const items =
      normalizeTafsirResponse(
        data?.tafasir
      );

    const audio =
      items.find(
        (item) =>
          Boolean(
            item.audioUrl
          )
      ) || null;

    return json({
      ok: true,

      type:
        "tafsir-audio",

      tafsir:
        tafsirId,

      sura,

      audioUrl:
        audio?.audioUrl ||
        null,

      item:
        audio,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "tafsir-audio",

        audioUrl:
          null,

        error:
          "Unable to load Tafsir audio",

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

export default {
  handleTafsirBooks,
  handleTafsirSearch,
  handleTafsirAudio,
};
