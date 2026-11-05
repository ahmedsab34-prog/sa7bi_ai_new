import assert from "node:assert/strict";

import {
  handleHadithSearch,
} from "./src/content/hadith.js";

const originalFetch = globalThis.fetch;

async function call(query = "") {
  const url = `https://worker.test/v1/hadith${query}`;
  return handleHadithSearch(new Request(url));
}

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

try {
  // The provider requires a bounded range. Verify both path and range.
  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));
    assert.equal(requested.pathname, "/books/bukhari");
    assert.equal(requested.searchParams.get("range"), "1-300");

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

  const success = await call("?book=bukhari&limit=3");
  const successBody = await success.json();

  assert.equal(success.status, 200);
  assert.equal(successBody.ok, true);
  assert.equal(successBody.count, 1);
  assert.equal(successBody.items[0].book, "bukhari");
  assert.equal(
    successBody.items[0].text,
    "إنما الأعمال بالنيات",
  );

  // A real search with no matching text is an empty success, not an outage.
  const noMatch = await call(
    "?book=bukhari&q=كلمة_غير_موجودة",
  );

  const noMatchBody = await noMatch.json();

  assert.equal(noMatch.status, 200);
  assert.equal(noMatchBody.ok, true);
  assert.equal(noMatchBody.count, 0);

  // Correct provider slug for Sunan Abi Dawud.
  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));
    assert.equal(requested.pathname, "/books/abu-daud");
    assert.equal(requested.searchParams.get("range"), "1-300");

    return jsonResponse({
      data: {
        hadiths: [
          {
            number: 1,
            arab: "حديث تجريبي من أبي داود",
          },
        ],
      },
    });
  };

  const abuDaud = await call("?book=abu-daud&limit=1");
  const abuDaudBody = await abuDaud.json();

  assert.equal(abuDaud.status, 200);
  assert.equal(abuDaudBody.items[0].book, "abu-daud");

  // Provider outage must never be reported as an empty successful search.
  globalThis.fetch = async () =>
    new Response("upstream unavailable", {
      status: 503,
      headers: {
        "Content-Type": "text/plain",
      },
    });

  const unavailable = await call("?book=bukhari");
  const unavailableBody = await unavailable.json();

  assert.equal(unavailable.status, 502);
  assert.equal(unavailableBody.ok, false);
  assert.equal(
    unavailableBody.error,
    "HADITH_SOURCES_UNAVAILABLE",
  );
  assert.equal(
    unavailableBody.bookErrors[0].error,
    "HTTP_503",
  );

  console.log("hadith provider smoke test: PASS");
} finally {
  globalThis.fetch = originalFetch;
}
