
import {
  json,
  firstMatch,
  stripHtml,
  extractNewsImage,
} from "../utils.js";

const BACKEND_VERSION = "6.4.1";
const MAX_ITEMS = 40;
const RSS_TIMEOUT_MS = 5000;

/* Parse RSS items */
function parseRssItems(xml, fallbackSource = "News") {
  const blocks =
    String(xml || "").match(/<item\b[\s\S]*?<\/item>/gi) || [];

  const items = [];

  for (const block of blocks) {
    const title = stripHtml(
      firstMatch(block, [
        /<title[^>]*>([\s\S]*?)<\/title>/i,
      ]),
    );

    const link = cleanUrl(
      firstMatch(block, [
        /<link[^>]*>([\s\S]*?)<\/link>/i,
      ]),
    );

    const pubDate = firstMatch(block, [
      /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i,
      /<published[^>]*>([\s\S]*?)<\/published>/i,
      /<updated[^>]*>([\s\S]*?)<\/updated>/i,
      /<dc:date[^>]*>([\s\S]*?)<\/dc:date>/i,
    ]);

    const description = firstMatch(block, [
      /<description[^>]*>([\s\S]*?)<\/description>/i,
      /<summary[^>]*>([\s\S]*?)<\/summary>/i,
      /<content[^>]*>([\s\S]*?)<\/content>/i,
    ]);

    const source =
      stripHtml(
        firstMatch(block, [
          /<source[^>]*>([\s\S]*?)<\/source>/i,
        ]),
      ) || fallbackSource;

    const image = extractNewsImage(block);

    if (!title || !link) continue;

    items.push({
      id: link,
      title: title.trim(),
      link,
      pubDate: pubDate?.trim() || "",
      description: stripHtml(description || ""),
      image: image || "",
      imageUrl: image || "",
      source,
    });
  }

  return items;
}

/* URL helpers */
function cleanUrl(value) {
  let result = String(value || "").trim();

  if (!result) return "";

  result = result
    .replace(/^<!\[CDATA\[/i, "")
    .replace(/\]\]>$/i, "")
    .trim();

  result = decodeXml(result);

  return /^https?:\/\//i.test(result) ? result : "";
}

function decodeXml(value) {
  return String(value || "")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

/* Fetch a feed with a strict timeout */
async function fetchRssFeed(url) {
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "User-Agent": "Sa7bi-AI/6.4.1",
      Accept: "application/rss+xml, application/xml, text/xml, */*",
    },
    redirect: "follow",
    signal: AbortSignal.timeout(RSS_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new Error(`RSS_HTTP_${response.status}`);
  }

  return response.text();
}

/* Fetch feeds concurrently and deduplicate results */
async function fetchFeedsInParallel(feeds, sourceName) {
  const results = await Promise.allSettled(
    feeds.map(async (url) => {
      const xml = await fetchRssFeed(url);
      return parseRssItems(xml, sourceName);
    }),
  );

  const items = [];
  const seen = new Set();

  for (const result of results) {
    if (result.status !== "fulfilled") continue;

    for (const item of result.value) {
      if (!item.link || seen.has(item.link)) continue;

      seen.add(item.link);
      items.push(item);

      if (items.length >= MAX_ITEMS) {
        return items;
      }
    }
  }

  return items;
}

async function fetchGoogleNews() {
  const feeds = [
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",
    "https://news.google.com/rss/search?q=%D9%85%D8%B5%D8%B1&hl=ar&gl=EG&ceid=EG:ar",
    "https://news.google.com/rss/search?q=%D8%AA%D9%83%D9%86%D9%88%D9%84%D9%88%D8%AC%D9%8A%D8%A7&hl=ar&gl=EG&ceid=EG:ar",
  ];

  return fetchFeedsInParallel(feeds, "Google News");
}

async function fetchBingNews() {
  const feeds = [
    "https://www.bing.com/news/search?q=Egypt&format=rss&setlang=ar",
    "https://www.bing.com/news/search?q=Egypt%20technology&format=rss&setlang=ar",
    "https://www.bing.com/news/search?q=Egypt%20AI&format=rss&setlang=ar",
  ];

  return fetchFeedsInParallel(feeds, "Bing News");
}

/* Aggregate both providers */
async function fetchAllNews() {
  const [googleResult, bingResult] = await Promise.allSettled([
    fetchGoogleNews(),
    fetchBingNews(),
  ]);

  const google =
    googleResult.status === "fulfilled" ? googleResult.value : [];
  const bing =
    bingResult.status === "fulfilled" ? bingResult.value : [];

  const combined = [];
  const seen = new Set();

  for (const item of [...google, ...bing]) {
    if (!item.link || seen.has(item.link)) continue;

    seen.add(item.link);
    combined.push(item);

    if (combined.length >= MAX_ITEMS) break;
  }

  return combined;
}

/*
 * Important:
 * Do not fetch each article page just to discover an optional image
 * before returning the news list. That extra work can cause timeouts
 * on weak mobile data or Wi-Fi.
 *
 * Images already present in RSS remain available. Missing images
 * are optional and must not block the news response.
 */
export async function handleNews() {
  try {
    const items = await fetchAllNews();

    if (!items.length) {
      return json(
        {
          ok: false,
          error: "NEWS_SOURCES_UNAVAILABLE",
          message: "مصادر الأخبار غير متاحة حاليًا.",
          items: [],
          count: 0,
          backendVersion: BACKEND_VERSION,
        },
        502,
        {
          "Cache-Control": "no-store",
        },
      );
    }

    return json(
      {
        ok: true,
        items,
        count: items.length,
        backendVersion: BACKEND_VERSION,
      },
      200,
      {
        "Cache-Control":
          "public, max-age=30, s-maxage=60, stale-while-revalidate=180",
      },
    );
  } catch (error) {
    return json(
      {
        ok: false,
        error: error?.message || "NEWS_FAILED",
        message: "تعذر تحميل الأخبار حاليًا.",
        items: [],
        count: 0,
        backendVersion: BACKEND_VERSION,
      },
      502,
      {
        "Cache-Control": "no-store",
      },
    );
  }
}

export {
  parseRssItems,
  fetchRssFeed,
  fetchGoogleNews,
  fetchBingNews,
  fetchAllNews,
};

export default {
  handleNews,
};
