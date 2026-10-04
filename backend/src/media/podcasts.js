// backend/src/media/podcasts.js
// Sa7bi AI Backend
// Podcasts Module

import { fetchJson } from "../utils.js";

const BACKEND_VERSION = "6.3.3";

const ITUNES_SEARCH_URL =
  "https://itunes.apple.com/search";

const ITUNES_LOOKUP_URL =
  "https://itunes.apple.com/lookup";

const MAX_SEARCH_LIMIT = 50;
const MAX_EPISODES = 100;
const MAX_FEED_URL_LENGTH = 4096;

/*
 * مصدر احتياطي حقيقي للبودكاست.
 *
 * نستخدم RSS عام ومباشر بدل إرجاع بيانات وهمية
 * عندما تقوم Apple بإرجاع HTTP 429.
 */
const FALLBACK_PODCASTS = [
  {
    collectionId: "thmanyah-fnjan",
    collectionName:
      "فنجان مع عبدالرحمن أبومالح",
    artistName:
      "ثمانية",
    artworkUrl600:
      "https://thmanyah.com/wp-content/uploads/2024/05/fnjan-cover.jpg",
    feedUrl:
      "https://files.hosting.thmanyah.com/podcasts/89/1713955813943-768/rss-feed.rss",
    collectionViewUrl:
      "https://thmanyah.com/podcasts/fnjan/",
    primaryGenreName:
      "Society & Culture",
    country:
      "EG",
    description:
      "فنجان برنامج حواري من ثمانية.",
  },
];

function normalizePublicUrl(value) {
  if (typeof value !== "string") {
    return "";
  }

  const raw = value.trim();

  if (
    !raw ||
    raw.length > MAX_FEED_URL_LENGTH
  ) {
    return "";
  }

  try {
    const parsed = new URL(raw);

    if (
      parsed.protocol !== "http:" &&
      parsed.protocol !== "https:"
    ) {
      return "";
    }

    if (
      parsed.username ||
      parsed.password
    ) {
      return "";
    }

    const hostname =
      parsed.hostname
        .toLowerCase()
        .trim();

    if (isBlockedHostname(hostname)) {
      return "";
    }

    return parsed.toString();
  } catch {
    return "";
  }
}

function isBlockedHostname(hostname) {
  if (!hostname) {
    return true;
  }

  if (
    hostname === "localhost" ||
    hostname === "localhost.localdomain" ||
    hostname === "0.0.0.0" ||
    hostname === "::" ||
    hostname === "::1"
  ) {
    return true;
  }

  if (
    hostname.endsWith(".localhost") ||
    hostname.endsWith(".local") ||
    hostname.endsWith(".internal") ||
    hostname.endsWith(".lan")
  ) {
    return true;
  }

  return isPrivateIpv4(hostname);
}

function isPrivateIpv4(hostname) {
  const parts = hostname
    .split(".")
    .map((part) => Number(part));

  if (
    parts.length !== 4 ||
    parts.some(
      (part) =>
        !Number.isInteger(part) ||
        part < 0 ||
        part > 255
    )
  ) {
    return false;
  }

  const [a, b] = parts;

  if (a === 10) {
    return true;
  }

  if (a === 127) {
    return true;
  }

  if (
    a === 169 &&
    b === 254
  ) {
    return true;
  }

  if (
    a === 172 &&
    b >= 16 &&
    b <= 31
  ) {
    return true;
  }

  if (
    a === 192 &&
    b === 168
  ) {
    return true;
  }

  return false;
}

function normalizePodcast(
  item,
  index = 0
) {
  if (
    !item ||
    typeof item !== "object"
  ) {
    return null;
  }

  const artwork =
    normalizePublicUrl(
      item.artworkUrl600 ||
        item.artworkUrl100 ||
        item.artworkUrl60 ||
        item.artwork ||
        ""
    );

  const feedUrl =
    normalizePublicUrl(
      item.feedUrl
    );

  const storeUrl =
    normalizePublicUrl(
      item.collectionViewUrl ||
        item.trackViewUrl ||
        item.storeUrl ||
        ""
    );

  return {
    id:
      item.collectionId ??
      item.trackId ??
      `podcast-${index + 1}`,

    title:
      item.collectionName ||
      item.trackName ||
      item.artistName ||
      "Podcast",

    artist:
      item.artistName || "",

    author:
      item.artistName || "",

    artwork:
      artwork || null,

    feedUrl:
      feedUrl || null,

    storeUrl:
      storeUrl || null,

    genre:
      item.primaryGenreName || "",

    country:
      item.country || "EG",

    releaseDate:
      item.releaseDate || null,

    episodeCount:
      Number(
        item.trackCount ||
          item.collectionCount ||
          0
      ),

    description:
      typeof item.description === "string"
        ? item.description
        : "",

    type:
      "podcast",

    source:
      item.source ||
      "Apple Podcasts",
  };
}

function normalizeArabicQuery(value) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

/*
 * Apple Search API يمكن أن يرجع HTTP 429.
 *
 * لا نكرر عشرات الطلبات عند حدوث rate limit.
 * نحاول مصدرين منطقيين فقط، ثم ننتقل إلى
 * الكتالوج الاحتياطي الحقيقي.
 */
async function fetchApplePodcastSearch(
  query,
  limit
) {
  const countries = [
    "eg",
    "us",
  ];

  let lastError = null;

  for (
    let index = 0;
    index < countries.length;
    index++
  ) {
    const country =
      countries[index];

    const params =
      new URLSearchParams();

    params.set(
      "term",
      query || "podcast"
    );

    params.set(
      "country",
      country
    );

    params.set(
      "media",
      "podcast"
    );

    params.set(
      "entity",
      "podcast"
    );

    params.set(
      "limit",
      String(limit)
    );

    const endpoint =
      `${ITUNES_SEARCH_URL}?${params.toString()}`;

    try {
      const response =
        await fetch(
          endpoint,
          {
            method: "GET",

            headers: {
              Accept:
                "application/json",
              "User-Agent":
                "Sa7bi-AI/6.3.3",
            },

            cf: {
              cacheEverything: true,
              cacheTtl: 300,
            },
          }
        );

      /*
       * عند 429 لا معنى لإعادة نفس الطلب
       * من نفس Worker مباشرة.
       */
      if (
        response.status === 429
      ) {
        lastError =
          new Error(
            "APPLE_PODCAST_RATE_LIMITED"
          );

        break;
      }

      if (!response.ok) {
        lastError =
          new Error(
            `APPLE_PODCAST_HTTP_${response.status}`
          );

        continue;
      }

      return await response.json();
    } catch (error) {
      lastError = error;
    }
  }

  throw (
    lastError ||
    new Error(
      "PODCAST_SEARCH_PROVIDER_UNAVAILABLE"
    )
  );
}

function getFallbackPodcasts(
  query,
  limit
) {
  const normalizedQuery =
    normalizeArabicQuery(query);

  const normalizedItems =
    FALLBACK_PODCASTS
      .map(
        (item, index) =>
          normalizePodcast(
            {
              ...item,
              source:
                "RSS Fallback",
            },
            index
          )
      )
      .filter(Boolean);

  if (!normalizedQuery) {
    return normalizedItems
      .slice(0, limit);
  }

  const filtered =
    normalizedItems.filter(
      (item) => {
        const text =
          [
            item.title,
            item.artist,
            item.author,
            item.genre,
            item.description,
          ]
            .join(" ")
            .toLowerCase();

        return (
          text.includes(
            normalizedQuery
          ) ||
          normalizedQuery.includes(
            "podcast"
          ) ||
          normalizedQuery.includes(
            "بودكاست"
          ) ||
          normalizedQuery.includes(
            "فنجان"
          ) ||
          normalizedQuery.includes(
            "ثمانية"
          )
