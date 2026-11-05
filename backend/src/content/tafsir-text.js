// Sa7bi AI - Arabic Tafsir Text Provider
// Source: QuranEnc (QuranEnc.com)
//
// This module is additive. The existing MP3Quran Tafsir/audio routes remain
// unchanged; this module provides Arabic tafsir text through separate routes.
// QuranEnc content must be shown with its source attribution and without
// rewriting or modifying the provider's text.

import { json, stripHtml } from "../utils.js";

const BACKEND_VERSION = "6.3.1";
const QURANENC_BASE = "https://quranenc.com/api/v1";
const PROVIDER_TIMEOUT_MS = 9000;
const BOOKS_CACHE_TTL_MS = 30 * 60 * 1000;
const MAX_QUERY_LENGTH = 200;
const MAX_RESULTS = 100;

let cachedArabicBooks = null;
let cachedArabicBooksAt = 0;
let inFlightBooksRequest = null;

function normalizeString(value, maxLength = 500) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function normalizePositiveInt(value, maximum = 114) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > maximum) return 0;
  return parsed;
}

function normalizeKey(value) {
  const key = normalizeString(value, 100).toLowerCase();
  return /^[a-z0-9_-]{2,100}$/.test(key) ? key : "";
}

async function fetchProviderJson(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        "User-Agent": "Sa7bi-AI/6.3.1 (+https://github.com/ahmedsab34-prog/sa7bi_ai_new)",
      },
    });

    if (!response.ok) {
      const error = new Error(`HTTP_${response.status}`);
      error.code = `HTTP_${response.status}`;
      throw error;
    }

    try {
      return await response.json();
    } catch (_) {
      const error = new Error("QURANENC_INVALID_JSON");
      error.code = "QURANENC_INVALID_JSON";
      throw error;
    }
  } catch (error) {
    if (error?.name === "AbortError") {
      const timeoutError = new Error("QURANENC_TIMEOUT");
      timeoutError.code = "QURANENC_TIMEOUT";
      throw timeoutError;
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function extractBookRows(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.tafsirs)) return data.tafsirs;
  if (Array.isArray(data?.result)) return data.result;
  if (Array.isArray(data?.data)) return data.data;
  return [];
}

function normalizeBook(item) {
  if (!item || typeof item !== "object") return null;

  const key = normalizeKey(item.key || item.tafsir_key || item.id);
  const language = normalizeString(
    item.language_iso_code || item.language || item.lang || "ar",
    12,
  ).toLowerCase();

  if (!key || (language && language !== "ar")) return null;

  const name = normalizeString(
    item.title || item.name || item.description || key,
    180,
  );

  return {
    key,
    name,
    description: normalizeString(item.description || "", 500),
    language: "ar",
    version: normalizeString(item.version || "", 60),
    lastUpdate: item.last_update || item.lastUpdate || null,
    source: "QuranEnc",
  };
}

async function getArabicTafsirBooks({ forceRefresh = false } = {}) {
  const cacheIsFresh =
    Array.isArray(cachedArabicBooks) &&
    cachedArabicBooks.length > 0 &&
    Date.now() - cachedArabicBooksAt < BOOKS_CACHE_TTL_MS;

  if (!forceRefresh && cacheIsFresh) return cachedArabicBooks;
  if (!forceRefresh && inFlightBooksRequest) return inFlightBooksRequest;

  const request = (async () => {
    const endpoint = `${QURANENC_BASE}/tafsirs/list/ar?localization=ar`;
    const data = await fetchProviderJson(endpoint);
    const items = extractBookRows(data).map(normalizeBook).filter(Boolean);

    if (!items.length) {
      const error = new Error("QURANENC_TAFSIR_BOOKS_EMPTY");
      error.code = "QURANENC_TAFSIR_BOOKS_EMPTY";
      throw error;
    }

    const unique = [];
    const seen = new Set();

    for (const item of items) {
      if (seen.has(item.key)) continue;
      seen.add(item.key);
      unique.push(item);
    }

    cachedArabicBooks = unique;
    cachedArabicBooksAt = Date.now();

    return unique;
  })();

  if (!forceRefresh) inFlightBooksRequest = request;

  try {
    return await request;
  } finally {
    if (inFlightBooksRequest === request) {
      inFlightBooksRequest = null;
    }
  }
}

function extractTafsirRows(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.result)) return data.result;
  if (Array.isArray(data?.tafsir)) return data.tafsir;
  if (Array.isArray(data?.items)) return data.items;
  if (Array.isArray(data?.data)) return data.data;
  return [];
}

function normalizeTafsirBlock(item, fallbackSura) {
  if (!item || typeof item !== "object") return null;

  const sura = normalizePositiveInt(item.sura || fallbackSura, 114);

  const fromAya = normalizePositiveInt(
    item.from_aya || item.fromAya || item.aya,
    10000,
  );

  const toAya = normalizePositiveInt(
    item.to_aya || item.toAya || item.from_aya || item.aya,
    10000,
  );

  const rawText = normalizeString(
    item.text || item.tafsir || item.content || "",
    20000,
  );

  const text = stripHtml(rawText).trim();

  if (!sura || !fromAya || !text) return null;

  return {
    id: normalizeString(
      String(item.id || `${sura}-${fromAya}-${toAya}`),
      120,
    ),
    sura,
    fromAya,
    toAya: toAya || fromAya,
    type: normalizeString(item.type || "tafsir", 80) || "tafsir",
    text,
    source: "QuranEnc",
  };
}

function providerErrorCode(error) {
  const code = String(error?.code || error?.message || "");

  if (/^HTTP_\d{3}$/.test(code)) return code;
  if (code === "QURANENC_TIMEOUT") return code;
  if (code === "QURANENC_INVALID_JSON") return code;
  if (code === "QURANENC_TAFSIR_BOOKS_EMPTY") return code;

  return "QURANENC_UNAVAILABLE";
}

export async function handleTafsirTextBooks(request) {
  const url = new URL(request.url);
  const forceRefresh = url.searchParams.get("refresh") === "1";

  try {
    const items = await getArabicTafsirBooks({ forceRefresh });

    return json({
      ok: true,
      type: "tafsir-text-books",
      source: "QuranEnc",
      language: "ar",
      count: items.length,
      items,
      backendVersion: BACKEND_VERSION,
    });
  } catch (error) {
    return json({
      ok: false,
      type: "tafsir-text-books",
      source: "QuranEnc",
      language: "ar",
      count: 0,
      items: [],
      error: "TAFSIR_TEXT_BOOKS_UNAVAILABLE",
      providerError: providerErrorCode(error),
      message: "تعذر تحميل قائمة التفاسير النصية حاليًا.",
      backendVersion: BACKEND_VERSION,
    }, 502);
  }
}

export async function handleTafsirText(request) {
  const url = new URL(request.url);

  const key = normalizeKey(url.searchParams.get("key"));
  const suraRaw = url.searchParams.get("sura");
  const sura = normalizePositiveInt(suraRaw, 114);

  const query = normalizeString(
    url.searchParams.get("q") || "",
    MAX_QUERY_LENGTH,
  );

  if (!key) {
    return json({
      ok: false,
      error: "TAFSIR_KEY_REQUIRED",
      message: "اختر كتاب التفسير النصي أولًا.",
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  if (suraRaw !== null && !sura) {
    return json({
      ok: false,
      error: "INVALID_SURA",
      message: "رقم السورة يجب أن يكون من 1 إلى 114.",
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  if (!sura && !query) {
    return json({
      ok: false,
      error: "TAFSIR_TEXT_QUERY_REQUIRED",
      message: "حدد رقم السورة أو اكتب كلمة للبحث في التفسير.",
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  try {
    const books = await getArabicTafsirBooks();
    const book = books.find((item) => item.key === key);

    if (!book) {
      return json({
        ok: false,
        error: "UNSUPPORTED_TAFSIR_KEY",
        message: "كتاب التفسير المختار غير موجود ضمن المصادر العربية المتاحة.",
        backendVersion: BACKEND_VERSION,
      }, 400);
    }

    const endpoint = sura
      ? `${QURANENC_BASE}/tafsir/sura/${encodeURIComponent(key)}/${sura}`
      : `${QURANENC_BASE}/tafsir/search/${encodeURIComponent(key)}?term=${encodeURIComponent(query)}`;

    const data = await fetchProviderJson(endpoint);

    const items = extractTafsirRows(data)
      .map((item) => normalizeTafsirBlock(item, sura))
      .filter(Boolean)
      .slice(0, MAX_RESULTS);

    return json({
      ok: true,
      type: "tafsir-text",
      key,
      tafsirName: book.name,
      sura: sura || null,
      query,
      source: "QuranEnc",
      language: "ar",
      count: items.length,
      items,
      attribution: "المصدر: QuranEnc.com",
      backendVersion: BACKEND_VERSION,
    });
  } catch (error) {
    return json({
      ok: false,
      type: "tafsir-text",
      key,
      sura: sura || null,
      query,
      count: 0,
      items: [],
      error: "TAFSIR_TEXT_UNAVAILABLE",
      providerError: providerErrorCode(error),
      message: "تعذر تحميل نص التفسير من المصدر حاليًا. حاول مرة أخرى لاحقًا.",
      backendVersion: BACKEND_VERSION,
    }, 502);
  }
}

export {
  getArabicTafsirBooks,
  normalizeTafsirBlock,
};

export default {
  handleTafsirTextBooks,
  handleTafsirText,
};
