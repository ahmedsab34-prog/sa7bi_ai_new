// backend/src/content/news.js
// Sa7bi AI Backend - News Module
// Final Backend Version: 6.3.0
//
// Main endpoint:
// GET /v1/news
//
// Source:
// Google News RSS
//
// The Worker fetches public RSS feeds and normalizes
// them into a stable structure for the Flutter app.

import {
  json,
  firstMatch,
  stripHtml,
  extractNewsImage,
} from "../utils.js";

const BACKEND_VERSION = "6.3.0";

const MAX_ITEMS = 40;

/* -------------------------------------------------------------------------- */
/* RSS parsing                                                                */
/* -------------------------------------------------------------------------- */

/**
 * Parse RSS/XML items into a stable news structure.
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
      stripHtml(
        firstMatch(block, [
          /<source[^>]*>([\s\S]*?)<\/source>/i,
        ])
      ) || "Google News";

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
      image: image || "",
      imageUrl: image || "",
      source,
    });
  }

  return items;
}

/* -------------------------------------------------------------------------- */
/* RSS fetch                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Fetch one public RSS feed.
 */
async function fetchRssFeed(url) {
  const response =
    await fetch(
      url,
      {
        method: "GET",

        headers: {
          "User-Agent":
            "Sa7bi-AI/6.3.0",
          Accept:
            "application/rss+xml, application/xml, text/xml, */*",
        },

        redirect:
          "follow",
      }
    );

  if (!response.ok) {
    throw new Error(
      `RSS_HTTP_${response.status}`
    );
  }

  return response.text();
}

/* -------------------------------------------------------------------------- */
/* Google News                                                                */
/* -------------------------------------------------------------------------- */

/**
 * Fetch several Google News RSS feeds.
 *
 * We use:
 * - general Egypt/Arabic news
 * - Egypt search
 * - technology search
 *
 * Results are deduplicated by article URL.
 */
async function fetchGoogleNews() {
  const feeds = [
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",

    "https://news.google.com/rss/search?q=%D9%85%D8%B5%D8%B1&hl=ar&gl=EG&ceid=EG:ar",

    "https://news.google.com/rss/search?q=%D8%AA%D9%83%D9%86%D9%88%D9%84%D9%88%D8%AC%D9%8A%D8%A7&hl=ar&gl=EG&ceid=EG:ar",
  ];

  const all = [];

  const seen =
    new Set();

  for (
    const feed of feeds
  ) {
    try {
      const xml =
        await fetchRssFeed(
          feed
        );

      const items =
        parseRssItems(
          xml
        );

      for (
        const item of items
      ) {
        if (
          !item.link ||
          seen.has(
            item.link
          )
        ) {
          continue;
        }

        seen.add(
          item.link
        );

        all.push(
          item
        );

        if (
          all.length >=
          MAX_ITEMS
        ) {
          break;
        }
      }

      if (
        all.length >=
        MAX_ITEMS
      ) {
        break;
      }
    } catch (_) {
      /*
       * One feed failing must not make the
       * entire news service unavailable.
       */
    }
  }

  return all.slice(
    0,
    MAX_ITEMS
  );
}

/* -------------------------------------------------------------------------- */
/* Public endpoint                                                            */
/* -------------------------------------------------------------------------- */

/**
 * GET /v1/news
 */
export async function handleNews() {
  try {
    const items =
      await fetchGoogleNews();

    return json({
      ok: true,

      items,

      count:
        items.length,

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

        count: 0,

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Exports                                                                    */
/* -------------------------------------------------------------------------- */

export {
  parseRssItems,
  fetchRssFeed,
  fetchGoogleNews,
};

export default {
  handleNews,
};
