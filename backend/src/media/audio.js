// backend/src/media/audio.js
// Sa7bi AI Backend - Audio Search Module
// Version: 6.0.0

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

import {
  handleQuranSearch,
} from "../content/quran.js";

const BACKEND_VERSION = "6.0.0";

const ADHKAR_URL =
  "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json";

const ITUNES_SEARCH_URL =
  "https://itunes.apple.com/search";

/**
 * Main audio search handler.
 *
 * Supported types:
 * - quran
 * - adhkar
 * - music
 * - podcast
 */
export async function handleAudioSearch(request) {
  try {
    const url = new URL(request.url);

    const query = normalizeArabic(
      url.searchParams.get("q") || ""
    );

    const type = (
      url.searchParams.get("type") || "quran"
    ).toLowerCase().trim();

    switch (type) {
      case "quran":
        return await handleQuranSearch(query);

      case "adhkar":
        return await handleAdhkarSearch(query);

      case "music":
        return await handleAppleSearch(
          query,
          "music"
        );

      case "podcast":
      case "podcasts":
        return await handleAppleSearch(
          query,
          "podcast"
        );

      default:
        return json({
          ok: true,
          type,
          query,
          items: [],
          backendVersion: BACKEND_VERSION,
        });
    }
  } catch (error) {
    return json(
      {
        ok: false,
        error: "Audio search failed",
        message: error?.message || "Unknown error",
        backendVersion: BACKEND_VERSION,
      },
      500
    );
  }
}

/**
 * Adhkar search.
 *
 * This is kept for backward compatibility with the
 * existing /v1/audio endpoint.
 */
export async function handleAdhkarSearch(query = "") {
  try {
    const data = await fetchJson(ADHKAR_URL);

    if (!Array.isArray(data)) {
      return json({
        ok: true,
        type: "adhkar",
        query,
        items: [],
        backendVersion: BACKEND_VERSION,
      });
    }

    const normalizedQuery = normalizeArabic(query);

    const items = [];

    for (const group of data) {
      if (!group || typeof group !== "object") {
        continue;
      }

      const category =
        group.category ||
        group.name ||
        group.title ||
        "";

      const entries =
        Array.isArray(group.array)
          ? group.array
          : Array.isArray(group.content)
            ? group.content
            : [];

      for (const entry of entries) {
        if (!entry) {
          continue;
        }

        const text =
          typeof entry === "string"
            ? entry
            : entry.content ||
              entry.text ||
              entry.zekr ||
              entry.description ||
              "";

        if (!text) {
          continue;
        }

        const normalizedText =
          normalizeArabic(text);

        const normalizedCategory =
          normalizeArabic(category);

        if (
          normalizedQuery &&
          !normalizedText.includes(normalizedQuery) &&
          !normalizedCategory.includes(normalizedQuery)
        ) {
          continue;
        }

        items.push({
          id:
            entry.id ??
            `${items.length + 1}`,

          title:
            entry.title ||
            category ||
            "ذكر",

          category,

          text,

          repeat:
            entry.count ??
            entry.repeat ??
            entry.repetition ??
            null,

          audioUrl:
            entry.audio ||
            entry.audioUrl ||
            null,

          source:
            "Adhkar JSON",
        });

        if (items.length >= 80) {
          break;
        }
      }

      if (items.length >= 80) {
        break;
      }
    }

    return json({
      ok: true,
      type: "adhkar",
      query,
      count: items.length,
      items,
      backendVersion: BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        type: "adhkar",
        query,
        items: [],
        error: "Failed to load adhkar",
        message:
          error?.message || "Unknown error",
        backendVersion: BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Music / Podcast search through Apple iTunes Search API.
 *
 * We keep this provider because it gives us metadata,
 * artwork and preview/store/feed URLs without exposing
 * any private API key.
 */
export async function handleAppleSearch(
  query = "",
  media = "music"
) {
  try {
    const params = new URLSearchParams();

    params.set(
      "term",
      query || (media === "podcast" ? "podcast" : "music")
    );

    params.set("country", "eg");
    params.set("limit", "30");

    if (media === "podcast") {
      params.set("media", "podcast");
    } else {
      params.set("media", "music");
    }

    const response = await fetch(
      `${ITUNES_SEARCH_URL}?${params.toString()}`,
      {
        method: "GET",
        headers: {
          Accept: "application/json",
        },
      }
    );

    if (!response.ok) {
      throw new Error(
        `Apple Search API returned ${response.status}`
      );
    }

    const data = await response.json();

    const rawResults = Array.isArray(
      data?.results
    )
      ? data.results
      : [];

    const items = rawResults.map(
      (item, index) => {
        const isPodcast =
          media === "podcast";

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
            item.artworkUrl100 ||
            item.artworkUrl600 ||
            item.artworkUrl60 ||
            null,

          previewUrl:
            item.previewUrl ||
            null,

          storeUrl:
            item.trackViewUrl ||
            item.collectionViewUrl ||
            null,

          feedUrl:
            item.feedUrl ||
            null,

          releaseDate:
            item.releaseDate ||
            null,

          genre:
            item.primaryGenreName ||
            "",

          type: media,

          source: "Apple Search",
        };
      }
    );

    return json({
      ok: true,
      type: media,
      query,
      count: items.length,
      items,
      backendVersion: BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        type: media,
        query,
        items: [],
        error: "Audio provider unavailable",
        message:
          error?.message || "Unknown error",
        backendVersion: BACKEND_VERSION,
      },
      502
    );
  }
}

export default {
  handleAudioSearch,
  handleAdhkarSearch,
  handleAppleSearch,
};
