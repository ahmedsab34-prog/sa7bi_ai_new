import assert from "node:assert/strict";

import {
  handleHadithSearch,
  handleHadithBooks,
} from "./src/content/hadith.js";

const originalFetch = globalThis.fetch;

async function call(query = "") {
  return handleHadithSearch(
    new Request(
      `https://worker.test/v1/hadith${query}`,
    ),
  );
}

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

try {
  // ==========================================================
  // TEST 1: PRIMARY PROVIDER
  // ==========================================================

  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));

    assert.equal(
      requested.hostname,
      "api.hadith.gading.dev",
    );

    assert.equal(
      requested.pathname,
      "/books/bukhari",
    );

    assert.equal(
      requested.searchParams.get("range"),
      "1-300",
    );

    return jsonResponse({
      data: {
        hadiths: [
          {
            number: 1,
            arab: "إنما الأعمال بالنيات",
          },
        ],
      },
    });
  };

  const primary = await call(
    "?book=bukhari&limit=3",
  );

  const primaryBody = await primary.json();

  assert.equal(primary.status, 200);
  assert.equal(primaryBody.ok, true);
  assert.equal(primaryBody.count, 1);

  assert.equal(
    primaryBody.items[0].book,
    "bukhari",
  );

  assert.equal(
    primaryBody.items[0].text,
    "إنما الأعمال بالنيات",
  );

  assert.deepEqual(
    primaryBody.providers,
    ["gading"],
  );

  // ==========================================================
  // TEST 2: FULL ARABIC EDITION FALLBACK
  // ==========================================================

  let fallbackCalls = 0;

  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));

    if (
      requested.hostname === "api.hadith.gading.dev"
    ) {
      return jsonResponse({
        data: {
          hadiths: [
            {
              number: 1,
              arab: "إنما الأعمال بالنيات",
            },
          ],
        },
      });
    }

    assert.equal(
      requested.hostname,
      "cdn.jsdelivr.net",
    );

    assert.equal(
      requested.pathname,
      "/gh/fawazahmed0/hadith-api@1/editions/ara-bukhari.min.json",
    );

    fallbackCalls += 1;

    return jsonResponse({
      metadata: {
        name: "Sahih al-Bukhari",
      },
      hadiths: [
        {
          hadithnumber: 1,
          arabicnumber: 1,
          text: "إنما الأعمال بالنيات",
        },
        {
          hadithnumber: 2,
          arabicnumber: 2,
          text: "الصبر ضياء",
        },
      ],
    });
  };

  const fullEdition = await call(
    "?book=bukhari&q=الصبر&limit=3",
  );

  const fullEditionBody = await fullEdition.json();

  assert.equal(fullEdition.status, 200);
  assert.equal(fullEditionBody.ok, true);
  assert.equal(fullEditionBody.count, 1);

  assert.equal(
    fullEditionBody.items[0].number,
    2,
  );

  assert.equal(
    fullEditionBody.items[0].text,
    "الصبر ضياء",
  );

  assert.deepEqual(
    fullEditionBody.providers,
    ["fawaz"],
  );

  assert.equal(fallbackCalls, 1);

  // ==========================================================
  // TEST 3: NO MATCH IS NOT AN OUTAGE
  // ==========================================================

  const noMatch = await call(
    "?book=bukhari&q=لفظ_غير_موجود&limit=3",
  );

  const noMatchBody = await noMatch.json();

  assert.equal(noMatch.status, 200);
  assert.equal(noMatchBody.ok, true);
  assert.equal(noMatchBody.count, 0);

  assert.equal(
    fallbackCalls,
    1,
    "The cached Arabic edition should be reused.",
  );

  // ==========================================================
  // TEST 4: ABU DAWUD EDITION MAPPING
  // ==========================================================

  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));

    if (
      requested.hostname === "api.hadith.gading.dev"
    ) {
      return new Response(
        "primary unavailable",
        { status: 503 },
      );
    }

    assert.equal(
      requested.pathname,
      "/gh/fawazahmed0/hadith-api@1/editions/ara-abudawud.min.json",
    );

    return jsonResponse({
      hadiths: [
        {
          hadithnumber: 1,
          text: "حديث تجريبي من أبي داود",
        },
      ],
    });
  };

  const abuDaud = await call(
    "?book=abu-daud&limit=1",
  );

  const abuDaudBody = await abuDaud.json();

  assert.equal(abuDaud.status, 200);

  assert.equal(
    abuDaudBody.items[0].book,
    "abu-daud",
  );

  assert.equal(
    abuDaudBody.items[0].text,
    "حديث تجريبي من أبي داود",
  );

  assert.equal(
    abuDaudBody.warnings[0].fallback,
    "fawazahmed0/hadith-api",
  );

  // ==========================================================
  // TEST 5: BOTH PROVIDERS FAIL
  // ==========================================================

  globalThis.fetch = async () => {
    return new Response(
      "upstream unavailable",
      { status: 503 },
    );
  };

  const unavailable = await call(
    "?book=muslim&limit=1",
  );

  const unavailableBody = await unavailable.json();

  assert.equal(unavailable.status, 502);
  assert.equal(unavailableBody.ok, false);

  assert.equal(
    unavailableBody.error,
    "HADITH_SOURCES_UNAVAILABLE",
  );

  assert.equal(
    unavailableBody.bookErrors[0].primaryError,
    "HTTP_503",
  );

  assert.equal(
    unavailableBody.bookErrors[0].fallbackError,
    "HTTP_503",
  );

  // ==========================================================
  // TEST 6: FLUTTER-COMPATIBLE BOOK LIST
  // ==========================================================

  const booksResponse = await handleHadithBooks();

  const booksBody = await booksResponse.json();

  assert.equal(booksResponse.status, 200);
  assert.equal(booksBody.ok, true);

  assert.ok(
    booksBody.items.some(
      (book) => book.id === "abu-daud",
    ),
  );

  console.log(
    "hadith provider smoke test: PASS",
  );
} finally {
  globalThis.fetch = originalFetch;
}
