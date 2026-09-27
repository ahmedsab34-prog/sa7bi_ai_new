// backend/src/content/shorts.js
// Sa7bi AI
//
// Short-form video content.
//
// Source:
// MP3Quran public API
//
// Endpoint:
// GET /v1/shorts
//
// The public API returns videos grouped by reciter.
// This file flattens that structure into the stable
// item structure consumed by the Flutter application.
//
// IMPORTANT:
// - No API key is required.
// - No client-side secrets are used.
// - The public endpoint remains behind the Worker.
// - The response shape of /v1/shorts stays stable.

/* =========================================================
   IMPORTS
   ========================================================= */

import {
  json,
  fetchJson,
} from "../utils.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const BACKEND_VERSION =
  "6.3.0";

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

const SHORTS_LIMIT = 20;

/* =========================================================
   HELPERS
   ========================================================= */

/**
 * Convert a possibly relative/HTTP media URL to a
 * usable HTTPS URL.
 *
 * MP3Quran may expose older thumbnail URLs using HTTP.
 * HTTPS is preferred when the host is known.
 */
function normalizeMediaUrl(
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
      url.protocol ===
      "http:" &&
      (
        url.hostname ===
          "mp3quran.de" ||
        url.hostname.endsWith(
          ".mp3quran.de"
        ) ||
        url.hostname ===
          "mp3quran.net" ||
        url.hostname.endsWith(
          ".mp3quran.net"
        )
      )
    ) {
      url.protocol =
        "https:";
    }

    return url.toString();
  } catch {
    return "";
  }
}

/**
 * Convert a video type id to a friendly fallback label.
 *
 * The video API can return video_type as a numeric id.
 * We intentionally do not invent a textual meaning for
 * unknown ids. The reciter name is used as the safe fallback.
 */
function buildTitle({
  reciterName,
  videoType,
  index,
}) {
  const reciter =
    typeof reciterName ===
      "string"
      ? reciterName.trim()
      : "";

  if (reciter) {
    return `نفحة إيمانية مع ${reciter}`;
  }

  if (
    videoType !==
      undefined &&
    videoType !==
      null
  ) {
    return `فيديو إيماني ${videoType}`;
  }

  return `فيديو قصير ${index + 1}`;
}

/**
 * Flatten the nested MP3Quran response.
 *
 * Expected structure:
 *
 * {
 *   videos: [
 *     {
 *       id: 93,
 *       reciter_name: "...",
 *       videos: [
 *         {
 *           id: 15,
 *           video_type: 2,
 *           video_url: "...",
 *           video_thumb_url: "..."
 *         }
 *       ]
 *     }
 *   ]
 * }
 */
function flattenVideos(
  data
) {
  const groups =
    Array.isArray(
      data?.videos
    )
      ? data.videos
      : [];

  const items =
    [];

  for (
    const group of
      groups
  ) {
    const reciterName =
      typeof group?.reciter_name ===
        "string"
        ? group.reciter_name.trim()
        : "";

    const groupId =
      group?.id ??
      "";

    const videos =
      Array.isArray(
        group?.videos
      )
        ? group.videos
        : [];

    for (
      const video of
        videos
    ) {
      if (
        !video ||
        typeof video !==
          "object"
      ) {
        continue;
      }

      const videoUrl =
        normalizeMediaUrl(
          video.video_url ||
            video.videoUrl ||
            video.url ||
            ""
        );

      const thumbnail =
        normalizeMediaUrl(
          video.video_thumb_url ||
            video.thumbnail ||
            video.image ||
            video.cover ||
            ""
        );

      /*
       * A short item without an actual playable
       * video URL is not useful to the application.
       */
      if (!videoUrl) {
        continue;
      }

      const videoId =
        video.id ??
        "";

      const videoType =
        video.video_type ??
        video.videoType ??
        null;

      const id =
        videoId !== ""
          ? `mp3quran-short-${groupId}-${videoId}`
          : `mp3quran-short-${items.length}`;

      items.push({
        id,

        title:
          buildTitle({
            reciterName,
            videoType,
            index:
              items.length,
          }),

        description:
          reciterName
            ? `محتوى قصير من MP3Quran — ${reciterName}`
            : "فيديو قصير",

        thumbnail,

        videoUrl,

        source:
          "MP3Quran",

        sourceUrl:
          "https://www.mp3quran.net/",

        reciter:
          reciterName,

        videoType,

        type:
          "short",
      });

      if (
        items.length >=
        SHORTS_LIMIT
      ) {
        return items;
      }
    }
  }

  return items;
}

/* =========================================================
   HANDLER
   ========================================================= */

/**
 * GET /v1/shorts
 *
 * Returns a stable list of short-form videos for the
 * Home feed's Reels/Shorts strip.
 */
export async function handleShorts() {
  try {
    const data =
      await fetchJson(
        `${MP3QURAN_BASE}/videos?language=ar`
      );

    const items =
      flattenVideos(
        data
      );

    return json({
      ok: true,

      items,

      count:
        items.length,

      source:
        "MP3Quran",

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          "SHORTS_FAILED",

        message:
          error?.message ||
          "تعذر تحميل الفيديوهات القصيرة.",

        items: [],

        count: 0,

        source:
          "MP3Quran",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   DEFAULT EXPORT
   ========================================================= */

export default {
  handleShorts,
};
