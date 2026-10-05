// backend/src/media/audio.js
// Sa7bi AI Backend
//
// General audio search module.
//
// Supported:
// - Quran
// - Legacy Adhkar search
// - Music metadata/search
// - Podcast metadata/search
//
// Dedicated religious content endpoints are handled separately:
// - /v1/hadith
// - /v1/tafsir
// - /v1/tafsir/audio
//
// Main routes:
// GET /v1/audio/search
// GET /v1/audio/search-v4
//
// No private API keys are required.

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

import {
  handleQuranSearch,
} from "../content/quran.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const BACKEND_VERSION =
  "6.3.0";

const ADHKAR_URL =
  "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json";

const ITUNES_SEARCH_URL =
  "https://itunes.apple.com/search";

const DEEZER_SEARCH_URL =
  "https://api.deezer.com/search";

const MAX_ADHKAR_RESULTS =
  80;

const MAX_APPLE_RESULTS =
  30;

const MAX_DEEZER_RESULTS =
  30;

/* =========================================================
   MAIN AUDIO SEARCH
   ========================================================= */

/**
 * General audio search endpoint.
 *
 * Supported:
 *
 * /v1/audio/search?type=quran&q=الفاتحة
 * /v1/audio/search?type=adhkar&q=الصباح
 * /v1/audio/search?type=music&q=عمرو دياب
 * /v1/audio/search?type=podcast&q=تكنولوجيا
 *
 * The same handler is also exposed through:
 *
 * /v1/audio/search-v4
 */
export async function handleAudioSearch(
  request
) {
  try {
    const url =
      new URL(
        request.url
      );

    const rawQuery =
      url.searchParams.get(
        "q"
      ) || "";

    const query =
      normalizeArabic(
        rawQuery
      );

    const type =
      (
        url.searchParams.get(
          "type"
        ) || "quran"
      )
        .trim()
        .toLowerCase();

    switch (
      type
    ) {
      case "quran":
        return await handleQuranSearch(
          query
        );

      case "adhkar":
      case "azkar":
        return await handleAdhkarSearch(
          query
        );

      case "music":
        return await handleMusicSearch(
          query
        );

      case "podcast":
      case "podcasts":
        return await handleAppleSearch(
          query,
          "podcast"
        );

      /*
       * Hadith and Tafsir have their own dedicated
       * endpoints and are intentionally not routed
       * through this legacy general-audio handler.
       */
      case "hadith":
        return json(
          {
            ok: false,

            type:
              "hadith",

            error:
              "USE_HADITH_ENDPOINT",

            endpoint:
              "/v1/hadith",

            backendVersion:
              BACKEND_VERSION,
          },
          400
        );

      case "tafsir":
        return json(
          {
            ok: false,

            type:
              "tafsir",

            error:
              "USE_TAFSIR_ENDPOINT",

            endpoint:
              "/v1/tafsir",

            backendVersion:
              BACKEND_VERSION,
          },
          400
        );

      default:
        return json({
          ok: true,

          type,

          query:
            rawQuery.trim(),

          count:
            0,

          items: [],

          backendVersion:
            BACKEND_VERSION,
        });
    }
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "audio",

        error:
          "AUDIO_SEARCH_FAILED",

        message:
          error?.message ||
          "تعذر تنفيذ البحث الصوتي.",

        items: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   MUSIC SEARCH WITH FALLBACK
   ========================================================= */

/**
 * Music search strategy:
 *
 * 1. Try Apple Search first.
 * 2. If Apple fails or returns no usable results,
 *    try Deezer public Search API.
 *
 * This prevents a temporary Apple 429/provider failure
 * from making music search appear completely broken.
 *
 * Deezer is used only as a metadata/preview fallback.
 * It does not proxy or host full copyrighted tracks.
 */
export async function handleMusicSearch(
  query = ""
) {
  let appleResult;

  try {
    appleResult =
      await handleAppleSearchData(
        query,
        "music"
      );

    if (
      appleResult.ok &&
      Array.isArray(
        appleResult.items
      ) &&
      appleResult.items.length >
        0
    ) {
      return json(
        appleResult
      );
    }
  } catch {
    /*
     * Apple failed.
     * Continue to Deezer fallback.
     */
  }

  try {
    const deezerResult =
      await handleDeezerMusicSearch(
        query
      );

    if (
      deezerResult.ok &&
      Array.isArray(
        deezerResult.items
      ) &&
      deezerResult.items.length >
        0
    ) {
      return json(
        deezerResult
      );
    }

    /*
     * If both providers returned no results,
     * return a normal empty result instead of
     * exposing an internal provider failure.
     */
    return json({
      ok: true,

      type:
        "music",

      query,

      count:
        0,

      items: [],

      backendVersion:
        BACKEND_VERSION,

      provider:
        "none",
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "music",

        query,

        count:
          0,

        items: [],

        error:
          "MUSIC_PROVIDERS_UNAVAILABLE",

        message:
          error?.message ||
          "تعذر تحميل نتائج الموسيقى حاليًا.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   DEEZER MUSIC FALLBACK
   ========================================================= */

/**
 * Search Deezer's public catalog.
 *
 * The public search endpoint does not require an API key
 * for catalog searches.
 *
 * Returned preview URLs are short previews supplied by
 * Deezer. We do not proxy full tracks through the Worker.
 */
async function handleDeezerMusicSearch(
  query = ""
) {
  const params =
    new URLSearchParams();

  params.set(
    "q",
    query ||
      "music"
  );

  params.set(
    "limit",
    String(
      MAX_DEEZER_RESULTS
    )
  );

  const endpoint =
    `${DEEZER_SEARCH_URL}?${params.toString()}`;

  const data =
    await fetchJson(
      endpoint
    );

  const rawResults =
    Array.isArray(
      data?.data
    )
      ? data.data
      : [];

  const items =
    rawResults
      .map(
        (
          item,
          index
        ) =>
          normalizeDeezerResult(
            item,
            index
          )
      )
      .filter(
        Boolean
      );

  return {
    ok: true,

    type:
      "music",

    query,

    count:
      items.length,

    items,

    backendVersion:
      BACKEND_VERSION,

    provider:
      "Deezer",
  };
}

/**
 * Normalize one Deezer track.
 */
function normalizeDeezerResult(
  item,
  index
) {
  if (
    !item ||
    typeof item !==
      "object"
  ) {
    return null;
  }

  const artwork =
    normalizeHttpUrl(
      item.album?.cover_xl ||
        item.album?.cover_big ||
        item.album?.cover_medium ||
        item.artist?.picture_xl ||
        item.artist?.picture_big ||
        null
    );

  const previewUrl =
    normalizeHttpUrl(
      item.preview
    );

  const storeUrl =
    normalizeHttpUrl(
      item.link
    );

  const artistName =
    typeof item.artist?.name ===
      "string"
      ? item.artist.name
      : "";

  const albumTitle =
    typeof item.album?.title ===
      "string"
      ? item.album.title
      : "";

  const title =
    typeof item.title ===
      "string"
      ? item.title
      : (
          typeof item.title_short ===
            "string"
            ? item.title_short
            : "Music"
        );

  /*
   * Do not expose an item that has neither a usable
   * title nor a usable media/store URL.
   */
  if (
    !title.trim() &&
    !previewUrl &&
    !storeUrl
  ) {
    return null;
  }

  return {
    id:
      item.id ??
      `deezer-${index + 1}`,

    title:
      title.trim(),

    artist:
      artistName,

    collection:
      albumTitle,

    artwork:
      artwork || null,

    previewUrl:
      previewUrl || null,

    storeUrl:
      storeUrl || null,

    feedUrl:
      null,

    releaseDate:
      null,

    genre:
      "",

    country:
      "EG",

    type:
      "music",

    source:
      "Deezer",
  };
}

/* =========================================================
   ADHKAR
   ========================================================= */

/**
 * Legacy Adhkar search.
 *
 * Kept for compatibility with older Flutter builds.
 *
 * The current religious UI should use:
 * - Hadith
 * - Tafsir
 *
 * instead of treating Adhkar as a primary section.
 */
export async function handleAdhkarSearch(
  query = ""
) {
  try {
    const data =
      await fetchJson(
        ADHKAR_URL
      );

    if (
      !Array.isArray(
        data
      )
    ) {
      return json({
        ok: true,

        type:
          "adhkar",

        query,

        count:
          0,

        items: [],

        backendVersion:
          BACKEND_VERSION,
      });
    }

    const normalizedQuery =
      normalizeArabic(
        query
      );

    const items = [];

    for (
      const group
      of data
    ) {
      if (
        !group ||
        typeof group !==
          "object"
      ) {
        continue;
      }

      const category =
        typeof group.category ===
          "string"
          ? group.category
          : (
              group.name ||
              group.title ||
              ""
            );

      const entries =
        Array.isArray(
          group.array
        )
          ? group.array
          : Array.isArray(
              group.content
            )
            ? group.content
            : [];

      for (
        const entry
        of entries
      ) {
        if (!entry) {
          continue;
        }

        const text =
          typeof entry ===
            "string"
            ? entry
            : (
                entry.content ||
                entry.text ||
                entry.zekr ||
                entry.description ||
                ""
              );

        if (
          typeof text !==
            "string" ||
          !text.trim()
        ) {
          continue;
        }

        const normalizedText =
          normalizeArabic(
            text
          );

        const normalizedCategory =
          normalizeArabic(
            category
          );

        if (
          normalizedQuery &&
          !normalizedText.includes(
            normalizedQuery
          ) &&
          !normalizedCategory.includes(
            normalizedQuery
          )
        ) {
          continue;
        }

        const audioUrl =
          normalizeHttpUrl(
            entry.audio ||
              entry.audioUrl ||
              null
          );

        items.push({
          id:
            entry.id ??
            `${items.length + 1}`,

          title:
            entry.title ||
            category ||
            "ذكر",

          category,

          text:
            text.trim(),

          repeat:
            entry.count ??
            entry.repeat ??
            entry.repetition ??
            null,

          audioUrl:
            audioUrl ||
            null,

          source:
            "Adhkar JSON",

          type:
            "adhkar",
        });

        if (
          items.length >=
          MAX_ADHKAR_RESULTS
        ) {
          break;
        }
      }

      if (
        items.length >=
        MAX_ADHKAR_RESULTS
      ) {
        break;
      }
    }

    return json({
      ok: true,

      type:
        "adhkar",

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
          "adhkar",

        query,

        count:
          0,

        items: [],

        error:
          "ADHKAR_PROVIDER_UNAVAILABLE",

        message:
          error?.message ||
          "تعذر تحميل الأذكار.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   APPLE MUSIC / PODCAST SEARCH
   ========================================================= */

/**
 * Public Apple metadata search.
 *
 * This endpoint returns metadata and public preview/store
 * URLs where supplied by Apple.
 *
 * It does NOT attempt to proxy copyrighted audio through
 * our Worker.
 *
 * media:
 * - music
 * - podcast
 */
export async function handleAppleSearch(
  query = "",
  media = "music"
) {
  const result =
    await handleAppleSearchData(
      query,
      media
    );

  return json(
    result,
    result.ok
      ? 200
      : 502
  );
}

/**
 * Internal Apple search implementation.
 *
 * Kept separate so the music fallback can inspect
 * the result without creating an intermediate Response.
 */
async function handleAppleSearchData(
  query = "",
  media = "music"
) {
  try {
    const normalizedMedia =
      media === "podcast"
        ? "podcast"
        : "music";

    const params =
      new URLSearchParams();

    params.set(
      "term",
      query ||
        (
          normalizedMedia ===
            "podcast"
            ? "podcast"
            : "music"
        )
    );

    params.set(
      "country",
      "eg"
    );

    params.set(
      "limit",
      String(
        MAX_APPLE_RESULTS
      )
    );

    params.set(
      "media",
      normalizedMedia
    );

    if (
      normalizedMedia ===
      "podcast"
    ) {
      params.set(
        "entity",
        "podcast"
      );
    } else {
      params.set(
        "entity",
        "song"
      );
    }

    const endpoint =
      `${ITUNES_SEARCH_URL}?${params.toString()}`;

    const data =
      await fetchJson(
        endpoint
      );

    const rawResults =
      Array.isArray(
        data?.results
      )
        ? data.results
        : [];

    const items =
      rawResults
        .map(
          (
            item,
            index
          ) =>
            normalizeAppleResult(
              item,
              index,
              normalizedMedia
            )
        )
        .filter(
          Boolean
        );

    return {
      ok: true,

      type:
        normalizedMedia,

      query,

      count:
        items.length,

      items,

      backendVersion:
        BACKEND_VERSION,

      provider:
        "Apple Search",
    };
  } catch (error) {
    return {
      ok: false,

      type:
        media === "podcast"
          ? "podcast"
          : "music",

      query,

      count:
        0,

      items: [],

      error:
        "APPLE_AUDIO_PROVIDER_UNAVAILABLE",

      message:
        error?.message ||
        "تعذر تحميل نتائج الصوت.",

      backendVersion:
        BACKEND_VERSION,

      provider:
        "Apple Search",
    };
  }
}

/* =========================================================
   APPLE RESULT NORMALIZATION
   ========================================================= */

/**
 * Normalize one Apple Search API result.
 */
function normalizeAppleResult(
  item,
  index,
  media
) {
  if (
    !item ||
    typeof item !==
      "object"
  ) {
    return null;
  }

  const isPodcast =
    media ===
    "podcast";

  const artwork =
    normalizeHttpUrl(
      item.artworkUrl600 ||
        item.artworkUrl100 ||
        item.artworkUrl60 ||
        null
    );

  const previewUrl =
    normalizeHttpUrl(
      item.previewUrl
    );

  const storeUrl =
    normalizeHttpUrl(
      item.trackViewUrl ||
        item.collectionViewUrl ||
        null
    );

  const feedUrl =
    normalizeHttpUrl(
      item.feedUrl
    );

  return {
    id:
      item.trackId ??
      item.collectionId ??
      `${media}-${index + 1}`,

    title:
      isPodcast
        ? (
            item.trackName ||
            item.collectionName ||
            item.artistName ||
            "Podcast"
          )
        : (
            item.trackName ||
            item.collectionName ||
            "Music"
          ),

    artist:
      item.artistName ||
      "",

    collection:
      item.collectionName ||
      "",

    artwork:
      artwork ||
      null,

    previewUrl:
      previewUrl ||
      null,

    storeUrl:
      storeUrl ||
      null,

    feedUrl:
      feedUrl ||
      null,

    releaseDate:
      item.releaseDate ||
      null,

    genre:
      item.primaryGenreName ||
      "",

    country:
      item.country ||
      "EG",

    type:
      media,

    source:
      "Apple Search",
  };
}

/* =========================================================
   URL SAFETY
   ========================================================= */

/**
 * Only allow normal public HTTP/HTTPS URLs.
 *
 * These URLs are returned to the Flutter client as
 * third-party media/navigation URLs.
 */
function normalizeHttpUrl(
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
    const parsed =
      new URL(raw);

    if (
      parsed.protocol !==
        "http:" &&
      parsed.protocol !==
        "https:"
    ) {
      return "";
    }

    /*
     * Do not return credentials embedded in URLs.
     */
    if (
      parsed.username ||
      parsed.password
    ) {
      return "";
    }

    return parsed.toString();
  } catch {
    return "";
  }
}

/* =========================================================
   EXPORTS
   ========================================================= */

export default {
  handleAudioSearch,
  handleAdhkarSearch,
  handleAppleSearch,
};
