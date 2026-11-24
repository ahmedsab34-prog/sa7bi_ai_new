
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const workerEntryPath = new URL(
  "./src/index-v2.js",
  import.meta.url,
);

const wranglerConfigPath = new URL(
  "./wrangler.toml",
  import.meta.url,
);

const workerEntry = await readFile(
  workerEntryPath,
  "utf8",
);

const wranglerConfig = await readFile(
  wranglerConfigPath,
  "utf8",
);

// TEST 1:
// تأكيد أن ملف التشغيل الفعلي هو index-v2.js.
assert.match(
  wranglerConfig,
  /^\s*main\s*=\s*["']src\/index-v2\.js["']/m,
  "Wrangler must use src/index-v2.js as its entry point",
);

// TEST 2:
// التأكد من استيراد معالج الأخبار.
assert.match(
  workerEntry,
  /import\s*\{\s*handleNews\s*\}\s*from\s*["']\.\/content\/news\.js["']/,
  "Worker entry point must import handleNews",
);

// TEST 3:
// التأكد من أن مسار الأخبار يمرر request كاملًا.
const newsRoutePattern =
  /if\s*\(\s*request\.method\s*===\s*["']GET["']\s*&&\s*path\s*===\s*["']\/v1\/news["']\s*\)\s*\{\s*return\s+handleNews\(request\);\s*\}/s;

assert.match(
  workerEntry,
  newsRoutePattern,
  "GET /v1/news must call handleNews(request)",
);

// TEST 4:
// التأكد من عدم وجود استدعاء قديم بلا request
// داخل مسار الأخبار في ملف التشغيل الفعلي.
const newsRouteStart = workerEntry.indexOf(
  'path === "/v1/news"',
);

assert.notEqual(
  newsRouteStart,
  -1,
  "News route must exist in the active Worker entry point",
);

const newsRouteBlock = workerEntry.slice(
  newsRouteStart,
  newsRouteStart + 250,
);

assert.doesNotMatch(
  newsRouteBlock,
  /handleNews\(\s*\)/,
  "News route must not call handleNews() without request",
);

console.log(
  "news router contract smoke test: PASS",
);
