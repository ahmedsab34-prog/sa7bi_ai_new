import {
  json,
  firstMatch,
  stripHtml,
  extractNewsImage,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

/**
 * Parse RSS XML into normalized news items.
 */
function parseRssItems(xml) {
  const items = [];

  const blocks =
    String(xml || "").match(
      /<item\b[\s\S]*?<\/item>/gi
    ) || [];

  for (const block of blocks) {
    const title =
      stripHtml(
        firstMatch(block, [
          /<title[^>]*>([\s\S]*?)<\/title>/i,
        ])
      );

    const link =
      firstMatch(block, [
        /<link[^>]*>([\s\S]*?)<\/link>/i,
      ]);

    const pubDate =
      firstMatch(block, [
        /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i,
        /<published[^>]*>([\s\S]*?)<\/published>/i,
        /<updated[^>]*>([\s\S]*?)<\/updated>/i,
      ]);

    const description =
      firstMatch(block, [
        /<description[^>]*>([\s\S]*?)<\/description>/i,
        /<summary[^>]*>([\s\S]*?)<\/summary>/i,
        /<content[^>]*>([\s\S]*?)<\/content>/i,
      ]);

    const source =
      firstMatch(block, [
        /<source[^>]*>([\s\S]*?)<\/source>/i,
      ]) || "Google News";

    const image =
      extractNewsImage(block);

    if (!title || !link) {
      continue;
    }

    items.push({
      id: link,
      title,
      link,
      pubDate,
      description:
        stripHtml(description),
      image,
      imageUrl: image,
      source,
    });
  }

  return items;
}

/**
 * Fetch one RSS feed.
 */
async function fetchRssFeed(url) {
  const response =
    await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 Sa7bi-AI/6.0.0",
        Accept:
          "application/rss+xml, application/xml, text/xml, */*",
      },
    });

  if (!response.ok) {
    throw new Error(
      `RSS_HTTP_${response.status}`
    );
  }

  return response.text();
}

/**
 * Fetch Google News feeds.
 *
 * We use several feeds so the home screen
 * does not depend on one search topic only.
 */
async function fetchGoogleNews() {
  const feeds = [
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",

    "https://news.google.com/rss/search?q=مصر&hl=ar&gl=EG&ceid=EG:ar",

    "https://news.google.com/rss/search?q=تكنولوجيا&hl=ar&gl=EG&ceid=EG:ar",
  ];

  const all = [];

  const seen =
    new Set();

  for (const feed of feeds) {
    try {
      const xml =
        await fetchRssFeed(feed);

      const items =
        parseRssItems(xml);

      for (const item of items) {
        if (
          seen.has(item.link)
        ) {
          continue;
        }

        seen.add(item.link);

        all.push(item);

        if (all.length >= 40) {
          break;
        }
      }

      if (all.length >= 40) {
        break;
      }
    } catch (_) {
      // Continue with the next feed.
    }
  }

  return all;
}

/**
 * Main news endpoint.
 *
 * GET /v1/news
 */
export async function handleNews() {
  try {
    const items =
      await fetchGoogleNews();

    return json({
      ok: true,

      items:
        items.slice(0, 40),

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "NEWS_FAILED",

        items: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Parse RSS items for possible reuse
 * by future news sources.
 */
export {
  parseRssItems,
  fetchGoogleNews,
};
