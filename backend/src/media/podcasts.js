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

    type: "podcast",

    source:
      "Apple Podcasts",
  };
}

function normalizeArabicQuery(value) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

/*
 * Apple can temporarily return HTTP 429 to Cloudflare
 * Worker egress addresses.
 *
 * We therefore use Apple's public Podcast Search API
 * with Cloudflare edge caching and a safe fallback
 * catalog item when Apple is temporarily unavailable.
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
  let lastStatus = null;

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

      lastStatus =
        response.status;

      if (response.ok) {
        const data =
          await response.json();

        if (
          data &&
          Array.isArray(
            data.results
          )
        ) {
          return data;
        }

        throw new Error(
          "INVALID_PODCAST_PROVIDER_RESPONSE"
        );
      }

      const providerError =
        new Error(
          `APPLE_PODCAST_HTTP_${response.status}`
        );

      providerError.status =
        response.status;

      lastError =
        providerError;

      /*
       * If Apple explicitly rate-limits us,
       * do not keep hammering the same provider.
       * Use the fallback catalog instead.
       */
      if (
        response.status === 429
      ) {
        break;
      }
    } catch (error) {
      lastError =
        error;

      if (
        error?.status === 429 ||
        error?.message ===
          "APPLE_PODCAST_HTTP_429"
      ) {
        break;
      }
    }
  }

  const fallback =
    createPodcastFallback(
      query,
      lastError,
      lastStatus
    );

  if (fallback) {
    return fallback;
  }

  throw (
    lastError ||
    new Error(
      "PODCAST_SEARCH_PROVIDER_UNAVAILABLE"
    )
  );
}

function createPodcastFallback(
  query,
  providerError,
  providerStatus
) {
  const fallbackItem = {
    collectionId:
      "sa7bi-fallback-fnjan",

    collectionName:
      "فنجان مع عبدالرحمن أبومالح",

    artistName:
      "ثمانية",

    artworkUrl600:
      "",

    feedUrl:
      "https://files.hosting.thmanyah.com/podcasts/89/1713955813943-768/rss-feed.rss",

    collectionViewUrl:
      "https://thmanyah.com/podcasts/fnjan/",

    primaryGenreName:
      "Society & Culture",

    country:
      "EG",

    description:
      "فنجان بودكاست عربي من ثمانية. يتم استخدام هذا العنصر كبديل مؤقت عندما يتعذر الوصول إلى Apple Podcasts.",
  };

  const item =
    normalizePodcast(
      fallbackItem
    );

  return {
    resultCount:
      1,

    results:
      item
        ? [item]
        : [],

    fallback:
      true,

    providerError:
      providerError?.message ||
      "APPLE_PODCAST_PROVIDER_UNAVAILABLE",

    providerStatus:
      providerStatus || null,
  };
}

export async function handlePodcastSearch(
  request
) {
  try {
    const url =
      new URL(request.url);

    const query =
      normalizeArabicQuery(
        url.searchParams.get(
          "q"
        ) || ""
      );

    const limitRaw =
      Number(
        url.searchParams.get(
          "limit"
        ) || 30
      );

    const limit =
      Number.isFinite(
        limitRaw
      )
        ? Math.min(
            Math.max(
              Math.trunc(
                limitRaw
              ),
              1
            ),
            MAX_SEARCH_LIMIT
          )
        : 30;

    const response =
      await fetchApplePodcastSearch(
        query,
        limit
      );

    const results =
      Array.isArray(
        response?.results
      )
        ? response.results
        : [];

    const items =
      results
        .map(
          (item, index) =>
            normalizePodcast(
              item,
              index
            )
        )
        .filter(Boolean);

    return jsonResponse({
      ok: true,

      type:
        "podcast",

      query,

      count:
        items.length,

      items,

      fallback:
        response.fallback === true,

      providerError:
        response.providerError ||
        null,

      providerStatus:
        response.providerStatus ||
        null,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,

        type:
          "podcast",

        query:
          "",

        count:
          0,

        items:
          [],

        error:
          "PODCAST_SEARCH_FAILED",

        message:
          error?.message ||
          "تعذر البحث عن البودكاست.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

export async function handlePodcastLookup(
  request
) {
  try {
    const url =
      new URL(request.url);

    const id =
      (
        url.searchParams.get(
          "id"
        ) || ""
      ).trim();

    if (!id) {
      return jsonResponse(
        {
          ok: false,

          error:
            "PODCAST_ID_REQUIRED",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    if (
      !/^\d{1,20}$/.test(id)
    ) {
      return jsonResponse(
        {
          ok: false,

          error:
            "INVALID_PODCAST_ID",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const params =
      new URLSearchParams();

    params.set(
      "id",
      id
    );

    params.set(
      "entity",
      "podcast"
    );

    const endpoint =
      `${ITUNES_LOOKUP_URL}?${params.toString()}`;

    const data =
      await fetchJson(
        endpoint,
        {
          headers: {
            Accept:
              "application/json",
          },
        }
      );

    const results =
      Array.isArray(
        data?.results
      )
        ? data.results
        : [];

    if (
      !results.length
    ) {
      return jsonResponse({
        ok: true,

        type:
          "podcast",

        id,

        podcast:
          null,

        items:
          [],

        backendVersion:
          BACKEND_VERSION,
      });
    }

    const podcast =
      normalizePodcast(
        results[0]
      );

    return jsonResponse({
      ok: true,

      type:
        "podcast",

      id,

      podcast,

      items:
        podcast
          ? [podcast]
          : [],

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,

        type:
          "podcast",

        podcast:
          null,

        items:
          [],

        error:
          "PODCAST_LOOKUP_FAILED",

        message:
          error?.message ||
          "تعذر تحميل البودكاست.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

export async function handlePodcastEpisodes(
  request
) {
  try {
    const url =
      new URL(request.url);

    const rawFeedUrl =
      url.searchParams.get(
        "feedUrl"
      ) || "";

    const feedUrl =
      normalizePublicUrl(
        rawFeedUrl
      );

    if (!feedUrl) {
      return jsonResponse(
        {
          ok: false,

          error:
            "INVALID_FEED_URL",

          message:
            "رابط الـRSS غير صالح أو غير مسموح به.",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const response =
      await fetch(
        feedUrl,
        {
          method:
            "GET",

          headers: {
            Accept:
              "application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8",
          },

          redirect:
            "manual",
        }
      );

    if (
      response.status >= 300 &&
      response.status < 400
    ) {
      const location =
        response.headers.get(
          "Location"
        );

      const redirectUrl =
        normalizePublicUrl(
          location
            ? new URL(
                location,
                feedUrl
              ).toString()
            : ""
        );

      if (!redirectUrl) {
        return jsonResponse(
          {
            ok: false,

            type:
              "podcast-episodes",

            items:
              [],

            error:
              "UNSAFE_FEED_REDIRECT",

            backendVersion:
              BACKEND_VERSION,
          },
          400
        );
      }

      return loadPodcastFeed(
        redirectUrl
      );
    }

    if (!response.ok) {
      return jsonResponse(
        {
          ok: false,

          type:
            "podcast-episodes",

          items:
            [],

          error:
            "PODCAST_RSS_FAILED",

          status:
            response.status,

          backendVersion:
            BACKEND_VERSION,
        },
        502
      );
    }

    const xml =
      await response.text();

    const episodes =
      parseRssEpisodes(
        xml
      );

    return jsonResponse({
      ok: true,

      type:
        "podcast-episodes",

      feedUrl,

      count:
        episodes.length,

      items:
        episodes,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,

        type:
          "podcast-episodes",

        items:
          [],

        error:
          "PODCAST_RSS_UNAVAILABLE",

        message:
          error?.message ||
          "تعذر تحميل حلقات البودكاست.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

async function loadPodcastFeed(
  feedUrl
) {
  try {
    const response =
      await fetch(
        feedUrl,
        {
          method:
            "GET",

          headers: {
            Accept:
              "application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8",
          },

          redirect:
            "error",
        }
      );

    if (!response.ok) {
      return jsonResponse(
        {
          ok: false,

          type:
            "podcast-episodes",

          items:
            [],

          error:
            "PODCAST_RSS_FAILED",

          status:
            response.status,

          backendVersion:
            BACKEND_VERSION,
        },
        502
      );
    }

    const xml =
      await response.text();

    const episodes =
      parseRssEpisodes(
        xml
      );

    return jsonResponse({
      ok: true,

      type:
        "podcast-episodes",

      feedUrl,

      count:
        episodes.length,

      items:
        episodes,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,

        type:
          "podcast-episodes",

        items:
          [],

        error:
          "PODCAST_RSS_UNAVAILABLE",

        message:
          error?.message ||
          "تعذر تحميل حلقات البودكاست.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

export function parseRssEpisodes(
  xml
) {
  if (
    typeof xml !== "string" ||
    !xml.trim()
  ) {
    return [];
  }

  const items =
    [];

  const matches =
    xml.match(
      /<item\b[\s\S]*?<\/item>/gi
    ) || [];

  for (
    let index = 0;
    index < matches.length;
    index++
  ) {
    const block =
      matches[index];

    const title =
      extractTag(
        block,
        "title"
      );

    const description =
      extractTag(
        block,
        "description"
      ) ||
      extractTag(
        block,
        "content:encoded"
      );

    const pubDate =
      extractTag(
        block,
        "pubDate"
      );

    const guid =
      extractTag(
        block,
        "guid"
      );

    const enclosureUrl =
      extractAttribute(
        block,
        "enclosure",
        "url"
      );

    const enclosureType =
      extractAttribute(
        block,
        "enclosure",
        "type"
      );

    const enclosureLength =
      extractAttribute(
        block,
        "enclosure",
        "length"
      );

    const duration =
      extractTag(
        block,
        "itunes:duration"
      );

    const episodeNumber =
      extractTag(
        block,
        "itunes:episode"
      );

    const seasonNumber =
      extractTag(
        block,
        "itunes:season"
      );

    const explicit =
      extractTag(
        block,
        "itunes:explicit"
      );

    const image =
      normalizePublicUrl(
        extractAttribute(
          block,
          "itunes:image",
          "href"
        ) ||
          extractAttribute(
            block,
            "image",
            "href"
          )
      );

    const link =
      normalizePublicUrl(
        extractTag(
          block,
          "link"
        )
      );

    const audioUrl =
      normalizePublicUrl(
        enclosureUrl
      );

    if (
      !title &&
      !audioUrl &&
      !link
    ) {
      continue;
    }

    const id =
      guid ||
      audioUrl ||
      link ||
      `episode-${index + 1}`;

    items.push({
      id,

      title:
        cleanText(
          title ||
            `Episode ${index + 1}`
        ),

      description:
        cleanText(
          description
        ),

      publishedAt:
        pubDate || null,

      audioUrl:
        audioUrl || null,

      audioType:
        enclosureType || null,

      audioSize:
        normalizePositiveNumber(
          enclosureLength
        ),

      duration:
        duration || null,

      episode:
        normalizePositiveNumber(
          episodeNumber
        ),

      season:
        normalizePositiveNumber(
          seasonNumber
        ),

      explicit:
        normalizeBoolean(
          explicit
        ),

      image:
        image || null,

      pageUrl:
        link || null,

      type:
        "podcast-episode",

      source:
        "Podcast RSS",
    });

    if (
      items.length >=
      MAX_EPISODES
    ) {
      break;
    }
  }

  return items;
}

function extractTag(
  block,
  tag
) {
  const escapedTag =
    tag.replace(
      /:/g,
      "\\:"
    );

  const pattern =
    new RegExp(
      `<${escapedTag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${escapedTag}>`,
      "i"
    );

  const match =
    block.match(
      pattern
    );

  if (!match) {
    return "";
  }

  return decodeXml(
    stripCdata(
      match[1]
    )
  ).trim();
}

function extractAttribute(
  block,
  tag,
  attribute
) {
  const escapedTag =
    tag.replace(
      /:/g,
      "\\:"
    );

  const pattern =
    new RegExp(
      `<${escapedTag}\\b[^>]*\\b${attribute}=["']([^"']+)["']`,
      "i"
    );

  const match =
    block.match(
      pattern
    );

  if (!match) {
    return "";
  }

  return decodeXml(
    match[1]
  ).trim();
}

function stripCdata(
  value
) {
  return String(
    value || ""
  )
    .replace(
      /^\s*<!\[CDATA\[/i,
      ""
    )
    .replace(
      /\]\]>\s*$/i,
      ""
    );
}

function decodeXml(
  value
) {
  return String(
    value || ""
  )
    .replace(
      /&amp;/gi,
      "&"
    )
    .replace(
      /&lt;/gi,
      "<"
    )
    .replace(
      /&gt;/gi,
      ">"
    )
    .replace(
      /&quot;/gi,
      '"'
    )
    .replace(
      /&apos;/gi,
      "'"
    )
    .replace(
      /&#39;/gi,
      "'"
    )
    .replace(
      /&#x27;/gi,
      "'"
    )
    .replace(
      /&#(\d+);/gi,
      (
        _match,
        number
      ) => {
        const code =
          Number(number);

        if (
          !Number.isFinite(
            code
          ) ||
          code < 0 ||
          code > 0x10ffff
        ) {
          return "";
        }

        try {
          return String.fromCodePoint(
            code
          );
        } catch {
          return "";
        }
      }
    )
    .replace(
      /&#x([0-9a-f]+);/gi,
      (
        _match,
        hex
      ) => {
        const code =
          Number.parseInt(
            hex,
            16
          );

        if (
          !Number.isFinite(
            code
          ) ||
          code < 0 ||
          code > 0x10ffff
        ) {
          return "";
        }

        try {
          return String.fromCodePoint(
            code
          );
        } catch {
          return "";
        }
      }
    );
}

function cleanText(
  value
) {
  return String(
    value || ""
  )
    .replace(
      /<[^>]*>/g,
      " "
    )
    .replace(
      /\s+/g,
      " "
    )
    .trim();
}

function normalizePositiveNumber(
  value
) {
  if (
    value === null ||
    value === undefined ||
    value === ""
  ) {
    return null;
  }

  const number =
    Number(value);

  if (
    !Number.isFinite(
      number
    ) ||
    number < 0
  ) {
    return null;
  }

  return number;
}

function normalizeBoolean(
  value
) {
  const normalized =
    String(
      value || ""
    )
      .trim()
      .toLowerCase();

  if (
    normalized === "yes" ||
    normalized === "true" ||
    normalized === "explicit"
  ) {
    return true;
  }

  if (
    normalized === "no" ||
    normalized === "false" ||
    normalized === "clean"
  ) {
    return false;
  }

  return null;
}

function jsonResponse(
  body,
  status = 200
) {
  return new Response(
    JSON.stringify(
      body
    ),
    {
      status,

      headers: {
        "Content-Type":
          "application/json; charset=utf-8",

        "Cache-Control":
          "public, max-age=60",

        "Access-Control-Allow-Origin":
          "*",
      },
    }
  );
}

export default {
  handlePodcastSearch,
  handlePodcastLookup,
  handlePodcastEpisodes,
  parseRssEpisodes,
};
