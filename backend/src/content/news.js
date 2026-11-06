import {
  json,
  firstMatch,
  stripHtml,
  extractNewsImage,
} from "../utils.js";

const BACKEND_VERSION = "6.4.1";
const MAX_ITEMS = 40;
const MAX_NEWS_AGE_DAYS = 7;
const MAX_FUTURE_SKEW_MS = 24 * 60 * 60 * 1000;
const RSS_TIMEOUT_MS = 6500;
const USER_AGENT = "Sa7bi-AI-News/6.4.1";
const DAY_MS = 24 * 60 * 60 * 1000;

function decodeXml(value) {
  return String(value || "")
    .replace(/^<!\[CDATA\[/i, "")
    .replace(/\]\]>$/i, "")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

function cleanUrl(value) {
  const raw = decodeXml(value).trim();
  if (!raw) return "";

  try {
    const uri = new URL(raw);

    if (
      uri.protocol !== "https:" &&
      uri.protocol !== "http:"
    ) {
      return "";
    }

    uri.hash = "";

    for (const key of [...uri.searchParams.keys()]) {
      const lower = key.toLowerCase();

      if (
        lower.startsWith("utm_") ||
        [
          "fbclid",
          "gclid",
          "dclid",
          "mc_cid",
          "mc_eid",
          "igshid",
          "ref",
          "ref_src",
          "source",
          "si",
        ].includes(lower)
      ) {
        uri.searchParams.delete(key);
      }
    }

    if (uri.pathname.length > 1) {
      uri.pathname = uri.pathname.replace(/\/+$/, "");
    }

    return uri.toString();
  } catch (_) {
    return "";
  }
}

function parsePublishedDate(value) {
  const raw = String(value || "").trim();

  if (!raw) return null;

  const timestamp = Date.parse(raw);

  return Number.isFinite(timestamp)
    ? timestamp
    : null;
}

function normalizeTitle(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[\u064B-\u065F\u0670\u0640]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[^\u0600-\u06FFa-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function parseRssItems(
  xml,
  fallbackSource = "News",
) {
  const blocks =
    String(xml || "").match(
      /<item\b[\s\S]*?<\/item>/gi,
    ) || [];

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
        /<guid[^>]*>([\s\S]*?)<\/guid>/i,
      ]),
    );

    const pubDate = decodeXml(
      firstMatch(block, [
        /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i,
        /<published[^>]*>([\s\S]*?)<\/published>/i,
        /<updated[^>]*>([\s\S]*?)<\/updated>/i,
        /<dc:date[^>]*>([\s\S]*?)<\/dc:date>/i,
      ]),
    ).trim();

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

    const image = extractNewsImage(block) || "";

    if (!title || !link) continue;

    items.push({
      id: link,
      title: title.trim(),
      link,
      pubDate,
      description: stripHtml(
        decodeXml(description || ""),
      ),
      image,
      imageUrl: image,
      source: String(source).trim() || fallbackSource,
    });
  }

  return items;
}

async function fetchRssFeed(url) {
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "User-Agent": USER_AGENT,
      Accept:
        "application/rss+xml, application/xml, text/xml, */*",
      "Cache-Control": "no-cache, no-store, max-age=0",
      Pragma: "no-cache",
    },
    redirect: "follow",
    signal: AbortSignal.timeout(RSS_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new Error(`RSS_HTTP_${response.status}`);
  }

  return response.text();
}

async function fetchFeedsInParallel(
  feeds,
  sourceName,
) {
  const results = await Promise.allSettled(
    feeds.map(async (url) => {
      const xml = await fetchRssFeed(url);
      return parseRssItems(xml, sourceName);
    }),
  );

  const items = [];

  for (const result of results) {
    if (result.status === "fulfilled") {
      items.push(...result.value);
    }
  }

  return items;
}

export async function fetchGoogleNews() {
  return fetchFeedsInParallel(
    [
      "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",
      "https://news.google.com/rss/search?q=%D9%85%D8%B5%D8%B1&hl=ar&gl=EG&ceid=EG:ar",
      "https://news.google.com/rss/search?q=%D8%AA%D9%83%D9%86%D9%88%D9%84%D9%88%D8%AC%D9%8A%D8%A7&hl=ar&gl=EG&ceid=EG:ar",
    ],
    "Google News",
  );
}

export async function fetchBingNews() {
  return fetchFeedsInParallel(
    [
      "https://www.bing.com/news/search?q=Egypt&format=rss&setlang=ar",
      "https://www.bing.com/news/search?q=Egypt%20technology&format=rss&setlang=ar",
      "https://www.bing.com/news/search?q=Egypt%20AI&format=rss&setlang=ar",
    ],
    "Bing News",
  );
}

/**
 * تصفية الأخبار القديمة والمستقبلية، وإزالة التكرار،
 * وترتيب الأخبار الأحدث أولًا.
 *
 * الأخبار التي لا يحمل مصدرها تاريخ نشر تظل موجودة،
 * لكنها تظهر بعد الأخبار ذات التاريخ المعروف.
 */
export function filterAndNormalizeItems(
  input,
  {
    now = Date.now(),
    maxAgeDays = MAX_NEWS_AGE_DAYS,
  } = {},
) {
  const currentTime = Number.isFinite(now)
    ? now
    : Date.now();

  const safeAgeDays =
    Number.isFinite(maxAgeDays) && maxAgeDays > 0
      ? maxAgeDays
      : MAX_NEWS_AGE_DAYS;

  const cutoff =
    currentTime - safeAgeDays * DAY_MS;

  const futureLimit =
    currentTime + MAX_FUTURE_SKEW_MS;

  const byLink = new Set();
  const byTitle = new Set();
  const cleaned = [];

  const stats = {
    staleDiscarded: 0,
    futureDiscarded: 0,
    undatedKept: 0,
  };

  for (const item of input) {
    const title = String(item.title || "").trim();
    const link = cleanUrl(item.link);
    const titleKey = normalizeTitle(title);

    if (!title || !link || !titleKey) {
      continue;
    }

    const publishedAt =
      parsePublishedDate(item.pubDate);

    if (
      publishedAt != null &&
      publishedAt < cutoff
    ) {
      stats.staleDiscarded++;
      continue;
    }

    if (
      publishedAt != null &&
      publishedAt > futureLimit
    ) {
      stats.futureDiscarded++;
      continue;
    }

    if (
      byLink.has(link) ||
      byTitle.has(titleKey)
    ) {
      continue;
    }

    byLink.add(link);
    byTitle.add(titleKey);

    if (publishedAt == null) {
      stats.undatedKept++;
    }

    cleaned.push({
      ...item,
      id: link,
      title,
      link,
      source:
        String(item.source || "الأخبار").trim() ||
        "الأخبار",
      pubDate: String(item.pubDate || "").trim(),
      description:
        String(item.description || "").trim(),
      image: String(
        item.image || item.imageUrl || "",
      ).trim(),
      imageUrl: String(
        item.imageUrl || item.image || "",
      ).trim(),
      _publishedAt: publishedAt,
    });
  }

  cleaned.sort((a, b) => {
    if (
      a._publishedAt == null &&
      b._publishedAt != null
    ) {
      return 1;
    }

    if (
      a._publishedAt != null &&
      b._publishedAt == null
    ) {
      return -1;
    }

    if (
      a._publishedAt != null &&
      b._publishedAt != null
    ) {
      return b._publishedAt - a._publishedAt;
    }

    return 0;
  });

  const limited = cleaned
    .slice(0, MAX_ITEMS)
    .map(({ _publishedAt, ...item }) => item);

  const latestTimestamp =
    cleaned.find(
      (item) => item._publishedAt != null,
    )?._publishedAt ?? null;

  return {
    items: limited,
    stats: {
      ...stats,
      maxAgeDays: safeAgeDays,
      latestPublishedAt:
        latestTimestamp == null
          ? null
          : new Date(latestTimestamp).toISOString(),
    },
  };
}

/**
 * نفس الدالة القديمة للتوافق مع أي مستهلك آخر.
 */
export function normalizeAndSortItems(input) {
  return filterAndNormalizeItems(input).items;
}

export async function fetchAllNewsWithStats({
  now = Date.now(),
  maxAgeDays = MAX_NEWS_AGE_DAYS,
} = {}) {
  const [googleResult, bingResult] =
    await Promise.allSettled([
      fetchGoogleNews(),
      fetchBingNews(),
    ]);

  const google =
    googleResult.status === "fulfilled"
      ? googleResult.value
      : [];

  const bing =
    bingResult.status === "fulfilled"
      ? bingResult.value
      : [];

  const rawItems = [...google, ...bing];

  const normalized = filterAndNormalizeItems(
    rawItems,
    {
      now,
      maxAgeDays,
    },
  );

  const failedSources =
    Number(googleResult.status === "rejected") +
    Number(bingResult.status === "rejected");

  return {
    ...normalized,
    rawCount: rawItems.length,
    failedSources,
  };
}

/**
 * يحافظ على واجهة fetchAllNews القديمة.
 */
export async function fetchAllNews(options) {
  const result = await fetchAllNewsWithStats(options);
  return result.items;
}

export async function handleNews() {
  const refreshedAt = new Date().toISOString();

  try {
    const result = await fetchAllNewsWithStats();

    const freshness = {
      ...result.stats,
      rawItemsReceived: result.rawCount,
      sourceGroupsFailed: result.failedSources,
    };

    if (!result.items.length) {
      const noFreshNews = result.rawCount > 0;

      return json(
        {
          ok: false,
          error: noFreshNews
            ? "NO_FRESH_NEWS_AVAILABLE"
            : "NEWS_SOURCES_UNAVAILABLE",
          message: noFreshNews
            ? "المصادر أعادت أخبارًا قديمة أو غير صالحة؛ لم نعرضها باعتبارها أخبارًا جديدة."
            : "مصادر الأخبار غير متاحة حاليًا.",
          items: [],
          count: 0,
          backendVersion: BACKEND_VERSION,
          refreshedAt,
          freshness,
        },
        502,
        {
          "Cache-Control": "no-store, max-age=0",
        },
      );
    }

    return json(
      {
        ok: true,
        items: result.items,
        count: result.items.length,
        backendVersion: BACKEND_VERSION,
        refreshedAt,
        freshness,
      },
      200,
      {
        "Cache-Control": "no-store, max-age=0",
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
        refreshedAt,
      },
      502,
      {
        "Cache-Control": "no-store, max-age=0",
      },
    );
  }
}

export {
  fetchRssFeed,
  normalizeTitle,
  parsePublishedDate,
  MAX_NEWS_AGE_DAYS,
};

export default {
  handleNews,
};
