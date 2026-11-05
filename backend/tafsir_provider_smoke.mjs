import assert from "node:assert/strict";

import {
  handleTafsirText,
  handleTafsirTextBooks,
} from "./src/content/tafsir-text.js";

const originalFetch = globalThis.fetch;

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

try {
  // Arabic book catalogue is normalized and cached.
  let calls = 0;

  globalThis.fetch = async (url) => {
    calls += 1;

    assert.match(
      String(url),
      /tafsirs\/list\/ar\?localization=ar/,
    );

    return jsonResponse({
      tafsirs: [
        {
          key: "arabic_saadi",
          language_iso_code: "ar",
          title: "تفسير السعدي",
          description: "تفسير ميسر باللغة العربية",
          version: "1.0",
        },
        {
          key: "english_saheeh",
          language_iso_code: "en",
          title: "English translation",
        },
      ],
    });
  };

  const booksResponse = await handleTafsirTextBooks(
    new Request("https://worker.test/v1/tafsir-text/books"),
  );

  const books = await booksResponse.json();

  assert.equal(booksResponse.status, 200);
  assert.equal(books.ok, true);
  assert.equal(books.count, 1);
  assert.equal(books.items[0].key, "arabic_saadi");
  assert.equal(books.items[0].name, "تفسير السعدي");

  const cachedBooksResponse = await handleTafsirTextBooks(
    new Request("https://worker.test/v1/tafsir-text/books"),
  );

  assert.equal(cachedBooksResponse.status, 200);
  assert.equal(
    calls,
    1,
    "book list should be cached within the Worker isolate",
  );

  // A complete sura response is normalized without inventing text.
  globalThis.fetch = async (url) => {
    const value = String(url);

    if (value.includes("tafsirs/list")) {
      return jsonResponse({
        tafsirs: [
          {
            key: "arabic_saadi",
            language_iso_code: "ar",
            title: "تفسير السعدي",
          },
        ],
      });
    }

    assert.match(
      value,
      /tafsir\/sura\/arabic_saadi\/1$/,
    );

    return jsonResponse({
      result: [
        {
          id: 1,
          sura: 1,
          from_aya: 1,
          to_aya: 1,
          type: "tafsir",
          text: "<p>هذا نص تفسير اختباري من المصدر.</p>",
        },
      ],
    });
  };

  const suraResponse = await handleTafsirText(
    new Request(
      "https://worker.test/v1/tafsir-text?key=arabic_saadi&sura=1",
    ),
  );

  const sura = await suraResponse.json();

  assert.equal(suraResponse.status, 200);
  assert.equal(sura.ok, true);
  assert.equal(sura.count, 1);
  assert.equal(
    sura.items[0].text,
    "هذا نص تفسير اختباري من المصدر.",
  );
  assert.equal(sura.items[0].fromAya, 1);
  assert.equal(
    sura.attribution,
    "المصدر: QuranEnc.com",
  );

  // Search endpoint is used only when no sura is supplied.
  globalThis.fetch = async (url) => {
    const value = String(url);

    if (value.includes("tafsirs/list")) {
      return jsonResponse({
        tafsirs: [
          {
            key: "arabic_saadi",
            language_iso_code: "ar",
            title: "تفسير السعدي",
          },
        ],
      });
    }

    assert.match(
      value,
      /tafsir\/search\/arabic_saadi\?term=/,
    );

    return jsonResponse({
      result: [
        {
          id: 2,
          sura: 2,
          from_aya: 5,
          to_aya: 6,
          text: "نتيجة بحث عربية.",
        },
      ],
    });
  };

  const searchResponse = await handleTafsirText(
    new Request(
      "https://worker.test/v1/tafsir-text?key=arabic_saadi&q=%D8%A7%D9%84%D8%B1%D8%AD%D9%85%D8%A9",
    ),
  );

  const search = await searchResponse.json();

  assert.equal(searchResponse.status, 200);
  assert.equal(search.ok, true);
  assert.equal(search.items[0].sura, 2);

  // Invalid key and missing selector are rejected before the tafsir call.
  const invalidKey = await handleTafsirText(
    new Request(
      "https://worker.test/v1/tafsir-text?key=unknown_key&sura=1",
    ),
  );

  assert.equal(invalidKey.status, 400);
  assert.equal(
    (await invalidKey.json()).error,
    "UNSUPPORTED_TAFSIR_KEY",
  );

  const missingSelector = await handleTafsirText(
    new Request(
      "https://worker.test/v1/tafsir-text?key=arabic_saadi",
    ),
  );

  assert.equal(missingSelector.status, 400);
  assert.equal(
    (await missingSelector.json()).error,
    "TAFSIR_TEXT_QUERY_REQUIRED",
  );

  const invalidSura = await handleTafsirText(
    new Request(
      "https://worker.test/v1/tafsir-text?key=arabic_saadi&sura=115",
    ),
  );

  assert.equal(invalidSura.status, 400);
  assert.equal(
    (await invalidSura.json()).error,
    "INVALID_SURA",
  );

  // Upstream failures are surfaced as 502; they are not reported as empty success.
  globalThis.fetch = async () =>
    jsonResponse(
      { error: "upstream unavailable" },
      503,
    );

  const failedResponse = await handleTafsirTextBooks(
    new Request(
      "https://worker.test/v1/tafsir-text/books?refresh=1",
    ),
  );

  assert.equal(failedResponse.status, 502);
  assert.equal(
    (await failedResponse.json()).error,
    "TAFSIR_TEXT_BOOKS_UNAVAILABLE",
  );

  console.log(
    "PASS: QuranEnc Arabic tafsir books, cache, sura, search, validation and upstream failure",
  );
} finally {
  globalThis.fetch = originalFetch;
}
