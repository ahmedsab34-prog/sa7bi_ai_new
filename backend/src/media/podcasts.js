// backend/src/media/podcasts.js
// Sa7bi AI Backend - Podcasts Module
// Version: 6.0.0

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

const ITUNES_SEARCH_URL =
  "https://itunes.apple.com/search";

const ITUNES_LOOKUP_URL =
  "https://itunes.apple.com/lookup";

/**
 * Normalize podcast search result.
 */
function normalizePodcast(item, index = 0) {
  if (!item || typeof item !== "object") {
    return null;
  }

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
      item.artistName ||
      "",

    author:
      item.artistName ||
      "",

    artwork:
      item.artworkUrl600 ||
      item.artworkUrl100 ||
      item.artworkUrl60 ||
      null,

    feedUrl:
      item.feedUrl ||
      null,

    storeUrl:
      item.collectionViewUrl ||
      item.trackViewUrl ||
      null,

    genre:
      item.primaryGenreName ||
      "",

    country:
      item.country ||
      "",

    releaseDate:
      item.releaseDate ||
      null,

    episodeCount:
      Number(
        item.trackCount ||
        item.collectionCount ||
        0
      ),

    description:
      item.description ||
      "",

    type:
      "podcast",

    source:
      "Apple Podcasts",
  };
}

/**
 * Search podcasts.
 *
 * Example:
 *
 * /v1/podcasts?q=technology
 */
export async function handlePodcastSearch(
  request
) {
  try {
    const url =
      new URL(request.url);

    const query =
      normalizeArabic(
        url.searchParams.get("q") ||
        ""
      );

    const limitRaw =
      Number(
        url.searchParams.get("limit") ||
        30
      );

    const limit =
      Math.min(
        Math.max(limitRaw, 1),
        50
      );

    const params =
      new URLSearchParams();

    params.set(
      "term",
      query || "podcast"
    );

    params.set(
      "country",
      "eg"
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

    const data =
      await fetchJson(endpoint);

    const results =
      Array.isArray(
        data?.results
      )
        ? data.results
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

    return json({
      ok: true,

      type:
        "podcast",

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
          "podcast",

        query:
          "",

        items: [],

        error:
          "Podcast provider unavailable",

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
 * Lookup a specific podcast by ID.
 */
export async function handlePodcastLookup(
  request
) {
  try {
    const url =
      new URL(request.url);

    const id =
      url.searchParams.get(
        "id"
      );

    if (!id) {
      return json(
        {
          ok: false,

          error:
            "Podcast id is required",

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
      await fetchJson(endpoint);

    const results =
      Array.isArray(
        data?.results
      )
        ? data.results
        : [];

    if (!results.length) {
      return json(
        {
          ok: true,

          type:
            "podcast",

          id,

          podcast:
            null,

          items: [],

          backendVersion:
            BACKEND_VERSION,
        }
      );
    }

    const podcast =
      normalizePodcast(
        results[0]
      );

    return json({
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
    return json(
      {
        ok: false,

        type:
          "podcast",

        error:
          "Unable to load podcast",

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
 * Fetch the RSS feed of a podcast.
 *
 * This is useful for getting actual episodes instead
 * of treating the podcast itself as one audio item.
 */
export async function handlePodcastEpisodes(
  request
) {
  try {
    const url =
      new URL(request.url);

    const feedUrl =
      url.searchParams.get(
        "feedUrl"
      );

    if (!feedUrl) {
      return json(
        {
          ok: false,

          error:
            "feedUrl is required",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    let parsed;

    try {
      parsed =
        new URL(feedUrl);
    } catch (_) {
      return json(
        {
          ok: false,

          error:
            "Invalid feedUrl",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    if (
      parsed.protocol !==
        "http:" &&
      parsed.protocol !==
        "https:"
    ) {
      return json(
        {
          ok: false,

          error:
            "Only HTTP and HTTPS feeds are supported",

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const response =
      await fetch(
        parsed.toString(),
        {
          method:
            "GET",

          headers: {
            Accept:
              "application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8",
          },

          redirect:
            "follow",
        }
      );

    if (!response.ok) {
      throw new Error(
        `Podcast RSS returned ${response.status}`
      );
    }

    const xml =
      await response.text();

    const episodes =
      parseRssEpisodes(
        xml
      );

    return json({
      ok: true,

      type:
        "podcast-episodes",

      feedUrl:
        parsed.toString(),

      count:
        episodes.length,

      items:
        episodes,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "podcast-episodes",

        items: [],

        error:
          "Unable to load podcast episodes",

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
 * Basic RSS parser for podcast episodes.
 *
 * The parser intentionally avoids external XML
 * dependencies so it can run directly in Workers.
 */
export function parseRssEpisodes(
  xml
) {
  if (
    typeof xml !==
      "string" ||
    !xml
  ) {
    return [];
  }

  const items = [];

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

    const enclosure =
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

    const duration =
      extractTag(
        block,
        "itunes:duration"
      );

    const image =
      extractAttribute(
        block,
        "itunes:image",
        "href"
      ) ||
      extractAttribute(
        block,
        "image",
        "href"
      );

    const link =
      extractTag(
        block,
        "link"
      );

    if (
      !title &&
      !enclosure &&
      !link
    ) {
      continue;
    }

    items.push({
      id:
        guid ||
        `episode-${index + 1}`,

      title:
        title ||
        `Episode ${index + 1}`,

      description:
        description ||
        "",

      publishedAt:
        pubDate ||
        null,

      audioUrl:
        enclosure ||
        null,

      audioType:
        enclosureType ||
        null,

      duration:
        duration ||
        null,

      image:
        image ||
        null,

      pageUrl:
        link ||
        null,

      type:
        "podcast-episode",

      source:
        "Podcast RSS",
    });

    if (
      items.length >=
      100
    ) {
      break;
    }
  }

  return items;
}

/**
 * Extract XML tag content.
 */
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
    block.match(pattern);

  if (!match) {
    return "";
  }

  return decodeXml(
    stripCdata(
      match[1]
    )
  ).trim();
}

/**
 * Extract an XML attribute from an opening tag.
 */
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
    block.match(pattern);

  return match
    ? decodeXml(
        match[1]
      ).trim()
    : "";
}

/**
 * Remove CDATA wrapper.
 */
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

/**
 * Basic XML entity decoding.
 */
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
    );
}

export default {
  handlePodcastSearch,
  handlePodcastLookup,
  handlePodcastEpisodes,
  parseRssEpisodes,
};
