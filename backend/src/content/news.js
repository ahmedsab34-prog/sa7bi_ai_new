// backend/src/content/news.js
// Sa7bi AI Backend - News Module
// Final Backend Version: 6.4.0
//
// Main endpoint:
// GET /v1/news
//
// Sources:
// Google News RSS
// Bing News RSS
//
// Improvements:
// - Multiple RSS sources.
// - Deduplication.
// - Image extraction from RSS.
// - Image fallback from article HTML.
// - Explicit failure response instead of silent empty success.

import {
  json,
  firstMatch,
  stripHtml,
  extractNewsImage,
} from "../utils.js";

const BACKEND_VERSION = "6.4.0";

const MAX_ITEMS = 40;
const MAX_IMAGE_ENRICH = 20;

/* -------------------------------------------------------------------------- */
/* RSS parsing                                                                */
/* -------------------------------------------------------------------------- */

function parseRssItems(
  xml,
  fallbackSource = "News",
) {
  const items = [];

  const blocks =
    String(xml || "").match(
      /<item\b[\s\S]*?<\/item>/gi,
    ) || [];

  for (const block of blocks) {
    const title =
      stripHtml(
        firstMatch(block, [
          /<title[^>]*>([\s\S]*?)<\/title>/i,
        ]),
      );

    const link =
      cleanUrl(
        firstMatch(block, [
          /<link[^>]*>([\s\S]*?)<\/link>/i,
        ]),
      );

    const pubDate =
      firstMatch(block, [
        /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i,
        /<published[^>]*>([\s\S]*?)<\/published>/i,
        /<updated[^>]*>([\s\S]*?)<\/updated>/i,
        /<dc:date[^>]*>([\s\S]*?)<\/dc:date>/i,
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
        ]),
      ) ||
      fallbackSource;

    const image =
      extractNewsImage(block);

    if (!title || !link) {
      continue;
    }

    items.push({
      id: link,
      title: title.trim(),
      link,
      pubDate:
        pubDate?.trim() || "",
      description:
        stripHtml(
          description || "",
        ),
      image:
        image || "",
      imageUrl:
        image || "",
      source,
    });
  }

  return items;
}

/* -------------------------------------------------------------------------- */
/* URL helpers                                                                */
/* -------------------------------------------------------------------------- */

function cleanUrl(value) {
  let result =
    String(value || "")
      .trim();

  if (!result) {
    return "";
  }

  result =
    result
      .replace(/^<!\[CDATA\[/i, "")
      .replace(/\]\]>$/i, "")
      .trim();

  result =
    decodeXml(result);

  if (!/^https?:\/\//i.test(result)) {
    return "";
  }

  return result;
}

function decodeXml(value) {
  return String(value || "")
    .replace(
      /&amp;/gi,
      "&",
    )
    .replace(
      /&quot;/gi,
      '"',
    )
    .replace(
      /&#39;/gi,
      "'",
    )
    .replace(
      /&apos;/gi,
      "'",
    )
    .replace(
      /&lt;/gi,
      "<",
    )
    .replace(
      /&gt;/gi,
      ">",
    );
}

/* -------------------------------------------------------------------------- */
/* RSS fetch                                                                  */
/* -------------------------------------------------------------------------- */

async function fetchRssFeed(url) {
  const response =
    await fetch(
      url,
      {
        method: "GET",

        headers: {
          "User-Agent":
            "Sa7bi-AI/6.4.0",

          Accept:
            "application/rss+xml, application/xml, text/xml, */*",

          "Cache-Control":
            "no-cache",

          Pragma:
            "no-cache",
        },

        redirect: "follow",
      },
    );

  if (!response.ok) {
    throw new Error(
      `RSS_HTTP_${response.status}`,
    );
  }

  return response.text();
}

/* -------------------------------------------------------------------------- */
/* Google News                                                                */
/* -------------------------------------------------------------------------- */

async function fetchGoogleNews() {
  const feeds = [
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",

    "https://news.google.com/rss/search?q=%D9%85%D8%B5%D8%B1&hl=ar&gl=EG&ceid=EG:ar",

    "https://news.google.com/rss/search?q=%D8%AA%D9%83%D9%86%D9%88%D9%84%D9%88%D8%AC%D9%8A%D8%A7&hl=ar&gl=EG&ceid=EG:ar",
  ];

  const all = [];
  const seen = new Set();

  for (const feed of feeds) {
    try {
      const xml =
          await fetchRssFeed(feed);

      const items =
          parseRssItems(
        xml,
        "Google News",
      );

      for (const item of items) {
        if (
          !item.link ||
          seen.has(item.link)
        ) {
          continue;
        }

        seen.add(item.link);
        all.push(item);

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
      // تجربة المصدر التالي.
    }
  }

  return all.slice(
    0,
    MAX_ITEMS,
  );
}

/* -------------------------------------------------------------------------- */
/* Bing News                                                                  */
/* -------------------------------------------------------------------------- */

async function fetchBingNews() {
  const feeds = [
    "https://www.bing.com/news/search?q=Egypt&format=rss&setlang=ar",

    "https://www.bing.com/news/search?q=Egypt%20technology&format=rss&setlang=ar",

    "https://www.bing.com/news/search?q=Egypt%20AI&format=rss&setlang=ar",
  ];

  const all = [];
  const seen = new Set();

  for (const feed of feeds) {
    try {
      const xml =
          await fetchRssFeed(feed);

      const items =
          parseRssItems(
        xml,
        "Bing News",
      );

      for (const item of items) {
        if (
          !item.link ||
          seen.has(item.link)
        ) {
          continue;
        }

        seen.add(item.link);
        all.push(item);

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
      // تجربة المصدر التالي.
    }
  }

  return all.slice(
    0,
    MAX_ITEMS,
  );
}

/* -------------------------------------------------------------------------- */
/* Article image extraction                                                   */
/* -------------------------------------------------------------------------- */

async function fetchArticleImage(url) {
  if (!url) {
    return "";
  }

  try {
    const response =
      await fetch(
        url,
        {
          method: "GET",

          headers: {
            "User-Agent":
              "Mozilla/5.0 (compatible; Sa7bi-AI/6.4.0)",
            Accept:
              "text/html,application/xhtml+xml",
          },

          redirect: "follow",
        },
      );

    if (!response.ok) {
      return "";
    }

    const html =
      await response.text();

    // لا نحتاج الصفحة كاملة.
    const limited =
      html.slice(
        0,
        400000,
      );

    const candidates = [
      /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
      /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["']/i,
    ];

    for (const pattern of candidates) {
      const match =
        limited.match(pattern);

      if (!match?.[1]) {
        continue;
      }

      const image =
        cleanUrl(
          match[1],
        );

      if (image) {
        return image;
      }
    }

    return "";
  } catch (_) {
    return "";
  }
}

/* -------------------------------------------------------------------------- */
/* Image enrichment                                                           */
/* -------------------------------------------------------------------------- */

async function enrichImages(items) {
  const result =
    [...items];

  const targets =
    result
      .filter(
        (item) =>
          !item.image &&
          !item.imageUrl &&
          item.link,
      )
      .slice(
        0,
        MAX_IMAGE_ENRICH,
      );

  await Promise.all(
    targets.map(
      async (item) => {
        const image =
          await fetchArticleImage(
            item.link,
          );

        if (!image) {
          return;
        }

        item.image =
          image;

        item.imageUrl =
          image;
      },
    ),
  );

  return result;
}

/* -------------------------------------------------------------------------- */
/* Merge sources                                                              */
/* -------------------------------------------------------------------------- */

async function fetchAllNews() {
  const google =
    await fetchGoogleNews();

  const seen =
    new Set(
      google.map(
        (item) => item.link,
      ),
    );

  let combined =
    [...google];

  if (
    combined.length <
    MAX_ITEMS
  ) {
    const bing =
      await fetchBingNews();

    for (const item of bing) {
      if (
        !item.link ||
        seen.has(item.link)
      ) {
        continue;
      }

      seen.add(item.link);
      combined.push(item);

      if (
        combined.length >=
        MAX_ITEMS
      ) {
        break;
      }
    }
  }

  return combined.slice(
    0,
    MAX_ITEMS,
  );
}

/* -------------------------------------------------------------------------- */
/* Public endpoint                                                            */
/* -------------------------------------------------------------------------- */

export async function handleNews() {
  try {
    const items =
      await fetchAllNews();

    if (!items.length) {
      return json(
        {
          ok: false,

          error:
            "NEWS_SOURCES_UNAVAILABLE",

          message:
            "مصادر الأخبار غير متاحة حاليًا.",

          items: [],

          count: 0,

          backendVersion:
            BACKEND_VERSION,
        },
        502,
      );
    }

    const enriched =
      await enrichImages(
        items,
      );

    return json({
      ok: true,

      items: enriched,

      count:
        enriched.length,

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

        message:
          "تعذر تحميل الأخبار حاليًا.",

        items: [],

        count: 0,

        backendVersion:
          BACKEND_VERSION,
      },
      502,
    );
  }
}

export {
  parseRssItems,
  fetchRssFeed,
  fetchGoogleNews,
  fetchBingNews,
  fetchArticleImage,
  enrichImages,
  fetchAllNews,
};

export default {
  handleNews,
};
