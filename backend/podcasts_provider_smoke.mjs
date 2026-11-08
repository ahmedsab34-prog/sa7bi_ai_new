
import assert from "node:assert/strict";

import {
  handlePodcastSearch,
  handlePodcastEpisodes,
  parseRssEpisodes,
} from "./src/media/podcasts.js";

const originalFetch = globalThis.fetch;

function jsonResponse(value, status = 200) {
  return new Response(
    JSON.stringify(value),
    {
      status,
      headers: {
        "Content-Type": "application/json",
      },
    },
  );
}

async function search(query = "بودكاست") {
  return handlePodcastSearch(
    new Request(
      `https://worker.test/v1/podcasts/search?q=${encodeURIComponent(query)}&limit=5`,
    ),
  );
}

try {
  // ==========================================================
  // TEST 1: REAL APPLE PODCAST SEARCH
  // ==========================================================

  let appleCalls = 0;

  globalThis.fetch = async (url, options = {}) => {
    appleCalls++;

    const requested = new URL(String(url));

    assert.equal(
      requested.hostname,
      "itunes.apple.com",
    );

    assert.equal(
      requested.pathname,
      "/search",
    );

    assert.equal(
      requested.searchParams.get("media"),
      "podcast",
    );

    assert.equal(
      requested.searchParams.get("entity"),
      "podcast",
    );

    assert.equal(options.method, "GET");

    return jsonResponse({
      resultCount: 1,
      results: [
        {
          collectionId: 123456,
          collectionName: "بودكاست تجريبي",
          artistName: "صاحب الاختبار",
          artworkUrl600:
            "https://images.example.com/podcast.jpg",
          feedUrl:
            "https://feeds.example.com/podcast.rss",
          collectionViewUrl:
            "https://podcasts.example.com/show/123456",
          primaryGenreName: "Education",
          country: "EG",
          trackCount: 12,
        },
      ],
    });
  };

  const realResponse = await search();
  const realBody = await realResponse.json();

  assert.equal(realResponse.status, 200);
  assert.equal(realBody.ok, true);
  assert.equal(realBody.fallback, false);
  assert.equal(realBody.count, 1);
  assert.equal(appleCalls, 1);

  assert.equal(
    realBody.items[0].title,
    "بودكاست تجريبي",
  );

  assert.equal(
    realBody.items[0].feedUrl,
    "https://feeds.example.com/podcast.rss",
  );

  assert.equal(
    realBody.items[0].source,
    "Apple Podcasts",
  );

  // ==========================================================
  // TEST 2: APPLE HTTP 429
  // ==========================================================

  let rateLimitCalls = 0;

  globalThis.fetch = async (url) => {
    rateLimitCalls++;

    const requested = new URL(String(url));

    assert.equal(
      requested.hostname,
      "itunes.apple.com",
    );

    return new Response(
      "Too Many Requests",
      {
        status: 429,
      },
    );
  };

  const limitedResponse = await search();
  const limitedBody = await limitedResponse.json();

  assert.equal(limitedResponse.status, 200);
  assert.equal(limitedBody.ok, true);

  assert.equal(
    limitedBody.fallback,
    true,
    "429 fallback must be explicitly identified.",
  );

  assert.equal(
    limitedBody.providerStatus,
    429,
  );

  assert.equal(
    limitedBody.providerError,
    "APPLE_PODCAST_HTTP_429",
  );

  assert.equal(
    rateLimitCalls,
    1,
    "Do not continue hammering Apple after HTTP 429.",
  );

  assert.ok(
    limitedBody.items.length > 0,
    "The fallback catalog should remain available.",
  );

  assert.ok(
    limitedBody.items[0].feedUrl,
    "Fallback item must have a usable RSS feed URL.",
  );

  // ==========================================================
  // TEST 3: EMPTY PROVIDER RESULTS ARE NOT FALLBACK SUCCESS
  // ==========================================================

  globalThis.fetch = async () =>
    jsonResponse({
      resultCount: 0,
      results: [],
    });

  const emptyResponse = await search(
    "query-with-no-results",
  );

  const emptyBody = await emptyResponse.json();

  assert.equal(emptyResponse.status, 200);
  assert.equal(emptyBody.ok, true);
  assert.equal(emptyBody.fallback, false);
  assert.equal(emptyBody.count, 0);

  assert.deepEqual(
    emptyBody.items,
    [],
  );

  // ==========================================================
  // TEST 4: RSS EPISODE PARSING
  // ==========================================================

  const rss = `
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
      xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <item>
          <title><![CDATA[الحلقة الأولى]]></title>
          <description><![CDATA[وصف الحلقة التجريبية]]></description>
          <pubDate>Sun, 08 Nov 2026 10:00:00 GMT</pubDate>
          <guid>episode-001</guid>
          <enclosure
            url="https://audio.example.com/episode-001.mp3"
            type="audio/mpeg"
            length="1234567" />
          <itunes:duration>1800</itunes:duration>
          <itunes:episode>1</itunes:episode>
          <itunes:season>1</itunes:season>
          <itunes:explicit>false</itunes:explicit>
        </item>
      </channel>
    </rss>
  `;

  const parsed = parseRssEpisodes(rss);

  assert.equal(parsed.length, 1);

  assert.equal(
    parsed[0].title,
    "الحلقة الأولى",
  );

  assert.equal(
    parsed[0].audioUrl,
    "https://audio.example.com/episode-001.mp3",
  );

  assert.equal(
    parsed[0].audioType,
    "audio/mpeg",
  );

  assert.equal(
    parsed[0].duration,
    "1800",
  );

  assert.equal(
    parsed[0].episode,
    1,
  );

  assert.equal(
    parsed[0].season,
    1,
  );

  assert.equal(
    parsed[0].explicit,
    false,
  );

  // ==========================================================
  // TEST 5: PODCAST EPISODES ENDPOINT
  // ==========================================================

  globalThis.fetch = async (url, options = {}) => {
    const requested = new URL(String(url));

    assert.equal(
      requested.hostname,
      "feeds.example.com",
    );

    assert.equal(
      requested.pathname,
      "/podcast.rss",
    );

    assert.equal(options.method, "GET");

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

  const episodesResponse = await handlePodcastEpisodes(
    new Request(
      "https://worker.test/v1/podcasts/episodes?feedUrl=https%3A%2F%2Ffeeds.example.com%2Fpodcast.rss",
    ),
  );

  const episodesBody = await episodesResponse.json();

  assert.equal(episodesResponse.status, 200);
  assert.equal(episodesBody.ok, true);
  assert.equal(episodesBody.count, 1);

  assert.equal(
    episodesBody.items[0].title,
    "الحلقة الأولى",
  );

  assert.equal(
    episodesBody.items[0].audioUrl,
    "https://audio.example.com/episode-001.mp3",
  );

  // ==========================================================
  // TEST 6: REJECT PRIVATE / LOCAL FEED URL
  // ==========================================================

  let unsafeFeedFetchCalls = 0;

  globalThis.fetch = async () => {
    unsafeFeedFetchCalls++;

    return new Response(
      rss,
      { status: 200 },
    );
  };

  const unsafeResponse = await handlePodcastEpisodes(
    new Request(
      "https://worker.test/v1/podcasts/episodes?feedUrl=http%3A%2F%2F127.0.0.1%2Fprivate.rss",
    ),
  );

  const unsafeBody = await unsafeResponse.json();

  assert.equal(unsafeResponse.status, 400);

  assert.equal(
    unsafeBody.error,
    "INVALID_FEED_URL",
  );

  assert.equal(
    unsafeFeedFetchCalls,
    0,
    "Private feed URLs must never be fetched.",
  );

  // ==========================================================
  // TEST 7: INVALID FEED URL
  // ==========================================================

  const invalidResponse = await handlePodcastEpisodes(
    new Request(
      "https://worker.test/v1/podcasts/episodes?feedUrl=file%3A%2F%2F%2Fetc%2Fpasswd",
    ),
  );

  assert.equal(invalidResponse.status, 400);

  assert.equal(
    (await invalidResponse.json()).error,
    "INVALID_FEED_URL",
  );

  console.log(
    "podcasts provider smoke test: PASS",
  );
} finally {
  globalThis.fetch = originalFetch;
}
