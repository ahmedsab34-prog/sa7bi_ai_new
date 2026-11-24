import assert from "node:assert/strict";

import worker from "./src/index.js";

const originalFetch = globalThis.fetch;

const recentDate = new Date(
  Date.now() - 60 * 60 * 1000,
).toUTCString();

const rss = `
  <rss>
    <channel>
      <item>
        <title>خبر تجريبي حديث لاختبار مسار الأخبار</title>
        <link>https://example.com/news-router-smoke</link>
        <pubDate>${recentDate}</pubDate>
        <description>اختبار تمرير الطلب إلى معالج الأخبار</description>
      </item>
    </channel>
  </rss>
`;

const requestedFeeds = [];

try {
  globalThis.fetch = async (url, options = {}) => {
    requestedFeeds.push(String(url));

    assert.equal(options.method, "GET");

    return new Response(rss, {
      status: 200,
      headers: {
        "Content-Type": "application/rss+xml",
      },
    });
  };

  // TEST 1:
  // يجب أن يصل category=sports إلى handleNews.
  const sportsResponse = await worker.fetch(
    new Request(
      "https://worker.example/v1/news?category=sports",
    ),
    {},
  );

  const sportsBody = await sportsResponse.json();

  assert.equal(sportsResponse.status, 200);
  assert.equal(sportsBody.ok, true);
  assert.equal(sportsBody.category, "sports");
  assert.ok(sportsBody.items.length > 0);

  assert.ok(
    requestedFeeds.some((url) =>
      decodeURIComponent(url).includes("رياضة"),
    ),
    "Sports category must reach the upstream RSS query",
  );

  // TEST 2:
  // يجب أن يصل category=technology إلى المعالج.
  requestedFeeds.length = 0;

  const technologyResponse = await worker.fetch(
    new Request(
      "https://worker.example/v1/news?category=technology",
    ),
    {},
  );

  const technologyBody = await technologyResponse.json();

  assert.equal(technologyResponse.status, 200);
  assert.equal(technologyBody.ok, true);
  assert.equal(technologyBody.category, "technology");
  assert.ok(technologyBody.items.length > 0);

  assert.ok(
    requestedFeeds.some((url) =>
      decodeURIComponent(url).includes("الذكاء الاصطناعي"),
    ),
    "Technology category must reach the upstream RSS query",
  );

  // TEST 3:
  // يجب أن يعمل طلب الأخبار العام دون تصنيف.
  requestedFeeds.length = 0;

  const generalResponse = await worker.fetch(
    new Request(
      "https://worker.example/v1/news?refresh=router-smoke-test",
    ),
    {},
  );

  const generalBody = await generalResponse.json();

  assert.equal(generalResponse.status, 200);
  assert.equal(generalBody.ok, true);
  assert.equal(generalBody.category, null);
  assert.ok(generalBody.items.length > 0);

  // TEST 4:
  // يجب رفض التصنيف غير المدعوم.
  const invalidResponse = await worker.fetch(
    new Request(
      "https://worker.example/v1/news?category=not-supported",
    ),
    {},
  );

  const invalidBody = await invalidResponse.json();

  assert.equal(invalidResponse.status, 400);
  assert.equal(
    invalidBody.error,
    "UNSUPPORTED_NEWS_CATEGORY",
  );

  console.log("news router smoke test: PASS");
} finally {
  globalThis.fetch = originalFetch;
}
