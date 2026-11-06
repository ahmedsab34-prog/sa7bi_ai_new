import assert from "node:assert/strict";

import {
  filterAndNormalizeItems,
  handleNews,
  parseRssItems,
} from "./src/content/news.js";

const originalFetch = globalThis.fetch;

const now = Date.now();

const recentDate = new Date(
  now - 2 * 60 * 60 * 1000,
).toUTCString();

const oldDate = new Date(
  now - 9 * 24 * 60 * 60 * 1000,
).toUTCString();

const farFutureDate = new Date(
  now + 3 * 24 * 60 * 60 * 1000,
).toUTCString();

try {
  // ==========================================================
  // TEST 1: NEWS FRESHNESS FILTER
  // ==========================================================

  const normalized = filterAndNormalizeItems(
    [
      {
        title: "خبر حديث",
        link: "https://example.com/fresh",
        pubDate: recentDate,
      },
      {
        title: "خبر قديم",
        link: "https://example.com/old",
        pubDate: oldDate,
      },
      {
        title: "خبر بتاريخ مستقبلي",
        link: "https://example.com/future",
        pubDate: farFutureDate,
      },
      {
        title: "خبر بلا تاريخ",
        link: "https://example.com/undated",
        pubDate: "",
      },
    ],
    {
      now,
      maxAgeDays: 7,
    },
  );

  assert.deepEqual(
    normalized.items.map((item) => item.title),
    [
      "خبر حديث",
      "خبر بلا تاريخ",
    ],
  );

  assert.equal(
    normalized.stats.staleDiscarded,
    1,
  );

  assert.equal(
    normalized.stats.futureDiscarded,
    1,
  );

  assert.equal(
    normalized.stats.undatedKept,
    1,
  );

  assert.equal(
    normalized.stats.maxAgeDays,
    7,
  );

  // ==========================================================
  // TEST 2: RSS PARSING
  // ==========================================================

  const parsed = parseRssItems(
    `
      <rss>
        <channel>
          <item>
            <title><![CDATA[عنوان تجريبي]]></title>
            <link>https://example.com/story?utm_source=test</link>
            <pubDate>${recentDate}</pubDate>
            <description><![CDATA[وصف الخبر]]></description>
          </item>
        </channel>
      </rss>
    `,
    "مصدر تجريبي",
  );

  assert.equal(parsed.length, 1);

  assert.equal(
    parsed[0].title,
    "عنوان تجريبي",
  );

  assert.equal(
    parsed[0].link,
    "https://example.com/story",
  );

  assert.equal(
    parsed[0].source,
    "مصدر تجريبي",
  );

  // ==========================================================
  // TEST 3: NEWS ENDPOINT RETURNS ONLY FRESH ITEMS
  // ==========================================================

  const rss = `
    <rss>
      <channel>
        <item>
          <title>خبر حديث من الاختبار</title>
          <link>https://example.com/live-fresh</link>
          <pubDate>${recentDate}</pubDate>
          <description>خبر حديث</description>
        </item>

        <item>
          <title>خبر قديم من الاختبار</title>
          <link>https://example.com/live-old</link>
          <pubDate>${oldDate}</pubDate>
          <description>خبر قديم</description>
        </item>
      </channel>
    </rss>
  `;

  let feedCalls = 0;

  globalThis.fetch = async (_url, options = {}) => {
    feedCalls++;

    assert.equal(options.method, "GET");

    assert.match(
      options.headers["Cache-Control"],
      /no-store/,
    );

    assert.match(
      options.headers.Pragma,
      /no-cache/,
    );

    return new Response(
      rss,
      {
        status: 200,
        headers: {
          "Content-Type": "application/rss+xml",
        },
      },
    );
  };

  const response = await handleNews();
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.ok, true);
  assert.ok(feedCalls >= 1);
  assert.ok(body.items.length >= 1);

  assert.ok(
    body.items.every(
      (item) =>
        item.title !== "خبر قديم من الاختبار",
    ),
  );

  assert.ok(
    body.freshness.staleDiscarded >= 1,
  );

  assert.equal(
    body.freshness.maxAgeDays,
    7,
  );

  assert.match(
    response.headers.get("Cache-Control") || "",
    /no-store/,
  );

  // ==========================================================
  // TEST 4: UPSTREAM FAILURE IS NOT FAKE SUCCESS
  // ==========================================================

  globalThis.fetch = async () => {
    return new Response(
      "upstream unavailable",
      { status: 503 },
    );
  };

  const unavailable = await handleNews();
  const unavailableBody = await unavailable.json();

  assert.equal(unavailable.status, 502);
  assert.equal(unavailableBody.ok, false);

  assert.equal(
    unavailableBody.error,
    "NEWS_SOURCES_UNAVAILABLE",
  );

  assert.deepEqual(
    unavailableBody.items,
    [],
  );

  console.log(
    "news provider smoke test: PASS",
  );
} finally {
  globalThis.fetch = originalFetch;
}
