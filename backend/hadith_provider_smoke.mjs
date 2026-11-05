
import assert from "node:assert/strict";

import {
  handleHadithSearch,
} from "./src/content/hadith.js";

const originalFetch = globalThis.fetch;

async function call(query = "") {
  const url = `https://worker.test/v1/hadith${query}`;
  return handleHadithSearch(new Request(url));
}

try {
  // مصدر يعمل ويرجع حديثًا عربيًا.
  globalThis.fetch = async () => new Response(JSON.stringify({
    data: {
      hadiths: [
        {
          number: 1,
          arab: "إنما الأعمال بالنيات",
        },
      ],
    },
  }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
    },
  });

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

  // المصدر يعمل لكن نص البحث غير موجود.
  const noMatch = await call(
    "?book=bukhari&q=كلمة_غير_موجودة",
  );

  const noMatchBody = await noMatch.json();

  assert.equal(noMatch.status, 200);
  assert.equal(noMatchBody.ok, true);
  assert.equal(noMatchBody.count, 0);

  // المصدر متعطل: يجب ألا يرجع نجاحًا وهميًا.
  globalThis.fetch = async () => new Response(
    "upstream unavailable",
    {
      status: 503,
      headers: {
        "Content-Type": "text/plain",
      },
    },
  );

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
