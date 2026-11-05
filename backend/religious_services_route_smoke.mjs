import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

// This smoke test validates route registration without importing the Worker
// entry point. The Cloudflare Worker runtime uses platform-specific modules
// which Node.js cannot load directly (for example cloudflare:workers).
// Provider behavior is tested separately by the Hadith, Radio and Tafsir
// provider smoke tests.

const [baseWorkerSource, extendedWorkerSource] = await Promise.all([
  readFile(new URL("./src/index.js", import.meta.url), "utf8"),
  readFile(new URL("./src/index-v2.js", import.meta.url), "utf8"),
]);

function getRouteBlock(source, routePath, label) {
  const marker = `path === "${routePath}"`;
  const position = source.indexOf(marker);

  assert.notEqual(
    position,
    -1,
    `${label}: route ${routePath} is not registered.`,
  );

  return source.slice(
    Math.max(0, position - 180),
    Math.min(source.length, position + 900),
  );
}

function assertGetRoute(source, routePath, handlerName, label) {
  const block = getRouteBlock(source, routePath, label);

  assert.match(
    block,
    /request\.method\s*===\s*"GET"/,
    `${label}: ${routePath} must be a GET route.`,
  );

  assert.ok(
    block.includes(`return ${handlerName}(`),
    `${label}: ${routePath} must dispatch to ${handlerName}.`,
  );
}

// Core Worker provider routes.
const coreRoutes = [
  ["/v1/hadith", "handleHadithSearch"],
  ["/v1/hadith/books", "handleHadithBooks"],
  ["/v1/tafsir", "handleTafsirSearch"],
  ["/v1/tafsir/books", "handleTafsirBooks"],
  ["/v1/tafsir/audio", "handleTafsirAudio"],
  ["/v1/radio/search", "handleRadioSearch"],
  ["/v1/radio/countries", "handleRadioCountries"],
  ["/v1/radio/country", "handleRadioByCountry"],
  ["/v1/radio/station", "handleRadioStationClick"],
  ["/v1/radio/stations", "handleRadioSearch"],
  ["/v1/radio/health", "handleRadioHealth"],
];

for (const [routePath, handlerName] of coreRoutes) {
  assertGetRoute(
    baseWorkerSource,
    routePath,
    handlerName,
    "Core Worker",
  );
}

// QuranEnc text routes are additive and live in the extended Worker entry.
const tafsirTextRoutes = [
  ["/v1/tafsir-text/books", "handleTafsirTextBooks"],
  ["/v1/tafsir-text", "handleTafsirText"],
];

for (const [routePath, handlerName] of tafsirTextRoutes) {
  assertGetRoute(
    extendedWorkerSource,
    routePath,
    handlerName,
    "Extended Worker",
  );
}

// Confirm the extended Worker delegates all other API routes to index.js.
assert.match(
  extendedWorkerSource,
  /from\s+["']\.\/index\.js["']/,
  "Extended Worker must import the core Worker entry point.",
);

assert.ok(
  extendedWorkerSource.includes("return worker.fetch(request, env, ctx);"),
  "Extended Worker must delegate unhandled routes to the core Worker.",
);

// Confirm the route handlers are connected to their real provider modules.
assert.match(
  baseWorkerSource,
  /handleHadithSearch[\s\S]*?from\s+["']\.\/content\/hadith\.js["']/,
  "Hadith handler must be imported from the Hadith provider module.",
);

assert.match(
  baseWorkerSource,
  /handleTafsirSearch[\s\S]*?from\s+["']\.\/content\/tafsir\.js["']/,
  "MP3Quran Tafsir handler must be imported from the Tafsir provider module.",
);

assert.match(
  baseWorkerSource,
  /handleRadioSearch[\s\S]*?from\s+["']\.\/media\/radio\.js["']/,
  "Radio handlers must be imported from the Radio provider module.",
);

assert.match(
  extendedWorkerSource,
  /handleTafsirText[\s\S]*?from\s+["']\.\/content\/tafsir-text\.js["']/,
  "QuranEnc text handlers must be imported from the Tafsir text provider module.",
);

console.log(
  "religious services route wiring smoke test: PASS " +
  "(route registration verified; provider behavior is tested separately).",
);
