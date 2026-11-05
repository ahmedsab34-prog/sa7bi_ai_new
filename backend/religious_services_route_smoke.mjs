import assert from "node:assert/strict";

import worker from "./src/index-v2.js";

const originalFetch = globalThis.fetch;

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

async function workerGet(path) {
  const request = new Request(
    `https://worker.test${path}`,
    {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
    },
  );

  const response = await worker.fetch(request, {});
  const body = await response.json();

  return {
    response,
    body,
  };
}

try {
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));

    // HADITH PROVIDER
    if (url.hostname === "api.hadith.gading.dev") {
      assert.equal(
        url.pathname,
        "/books/bukhari",
        "Hadith route must use the selected book slug.",
      );

      assert.equal(
        url.searchParams.get("range"),
        "1-300",
        "Hadith route must request a supported range.",
      );

      return jsonResponse({
        data: {
          hadiths: [
            {
              number: 1,
              arab: "إنما الأعمال بالنيات",
            },
            {
              number: 2,
              arab: "الدين النصيحة",
            },
          ],
        },
      });
    }

    // RADIO BROWSER PROVIDER
    if (
      url.hostname.endsWith("api.radio-browser.info")
    ) {
      assert.equal(
        url.pathname,
        "/json/stations/search",
      );

      assert.equal(
        url.searchParams.get("countrycode"),
        "EG",
      );

      assert.equal(
        url.searchParams.get("is_https"),
        "true",
        "Radio requests must ask the provider for HTTPS streams.",
      );

      return jsonResponse([
        {
          stationuuid: "route-smoke-radio-1",
          name: "Sa7bi Test Radio",
          url: "https://radio.example.test/live",
          url_resolved: "https://radio.example.test/live",
          country: "Egypt",
          countrycode: "EG",
          codec: "MP3",
          bitrate: 128,
          lastcheckok: 1,
        },
        {
          stationuuid: "route-smoke-radio-2",
          name: "Unsafe HTTP Radio",
          url: "http://radio.example.test/live",
          url_resolved: "http://radio.example.test/live",
          country: "Egypt",
          countrycode: "EG",
          lastcheckok: 1,
        },
      ]);
    }

    // QURANENC PROVIDER
    if (url.hostname === "quranenc.com") {
      if (
        url.pathname ===
        "/api/v1/tafsirs/list/ar"
      ) {
        return jsonResponse({
          tafsirs: [
            {
              key: "arabic_saadi",
              language_iso_code: "ar",
              title: "تفسير السعدي",
              description: "تفسير عربي",
              version: "1.0",
            },
          ],
        });
      }

      if (
        url.pathname ===
        "/api/v1/tafsir/sura/arabic_saadi/1"
      ) {
        return jsonResponse({
          result: [
            {
              id: 1,
              sura: 1,
              from_aya: 1,
              to_aya: 7,
              type: "tafsir",
              text: "<p>نص تفسير اختباري من المصدر.</p>",
            },
          ],
        });
      }
    }

    throw new Error(
      `Unexpected provider request: ${url.toString()}`,
    );
  };

  // ----------------------------------------------------------
  // HADITH ROUTE THROUGH index-v2
  // ----------------------------------------------------------

  const hadithResult = await workerGet(
    "/v1/hadith?book=bukhari&limit=3",
  );

  assert.equal(hadithResult.response.status, 200);
  assert.equal(hadithResult.body.ok, true);
  assert.equal(
    hadithResult.body.items.length,
    2,
  );
  assert.equal(
    hadithResult.body.items[0].text,
    "إنما الأعمال بالنيات",
  );

  // ----------------------------------------------------------
  // RADIO ROUTE THROUGH index-v2
  // ----------------------------------------------------------

  const radioResult = await workerGet(
    "/v1/radio/stations?country=EG&limit=10",
  );

  assert.equal(radioResult.response.status, 200);
  assert.equal(radioResult.body.ok, true);
  assert.equal(
    radioResult.body.stations.length,
    1,
    "Only the valid HTTPS station should be returned.",
  );
  assert.equal(
    radioResult.body.stations[0].streamUrl,
    "https://radio.example.test/live",
  );

  // ----------------------------------------------------------
  // QURANENC TAFSIR BOOKS ROUTE THROUGH index-v2
  // ----------------------------------------------------------

  const tafsirBooksResult = await workerGet(
    "/v1/tafsir-text/books",
  );

  assert.equal(
    tafsirBooksResult.response.status,
    200,
  );
  assert.equal(
    tafsirBooksResult.body.ok,
    true,
  );
  assert.equal(
    tafsirBooksResult.body.items[0].key,
    "arabic_saadi",
  );

  // ----------------------------------------------------------
  // QURANENC TAFSIR CONTENT ROUTE THROUGH index-v2
  // ----------------------------------------------------------

  const tafsirResult = await workerGet(
    "/v1/tafsir-text?key=arabic_saadi&sura=1",
  );

  assert.equal(tafsirResult.response.status, 200);
  assert.equal(tafsirResult.body.ok, true);
  assert.equal(tafsirResult.body.items.length, 1);
  assert.equal(
    tafsirResult.body.items[0].text,
    "نص تفسير اختباري من المصدر.",
  );
  assert.equal(
    tafsirResult.body.items[0].source,
    "QuranEnc",
  );

  console.log(
    "PASS: Hadith, Radio and QuranEnc Tafsir routes through index-v2.",
  );
} finally {
  globalThis.fetch = originalFetch;
}
