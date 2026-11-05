// backend/src/content/hadith.js
// Sa7bi AI Backend - Hadith content module.
//
// The upstream provider is treated as an external dependency:
// - One failed book does not hide results from other books.
// - An outage across every requested book returns HTTP 502.
// - A genuine search with no matches remains HTTP 200 / items: [].
// - Provider errors are reported as safe error codes, not fake empty success.

import {
  json,
  normalizeArabic,
} from "../utils.js";

const BACKEND_VERSION = "6.3.0";
const HADITH_API = "https://api.hadith.gading.dev/books";
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const PROVIDER_TIMEOUT_MS = 10000;

const BOOKS = [
  { id: "bukhari", name: "صحيح البخاري" },
  { id: "muslim", name: "صحيح مسلم" },
  { id: "abu-daud", name: "سنن أبي داود" },
  { id: "tirmidzi", name: "جامع الترمذي" },
  { id: "nasai", name: "سنن النسائي" },
  { id: "ibnu-majah", name: "سنن ابن ماجه" },
  { id: "ahmad", name: "مسند أحمد" },
  { id: "darimi", name: "سنن الدارمي" },
  { id: "malik", name: "موطأ مالك" },
];

const FIRST_HADITH_NUMBER = 1;
const MAX_RANGE_SIZE = 300;

function normalizeLimit(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_LIMIT;
  return Math.min(Math.max(Math.floor(parsed), 1), MAX_LIMIT);
}

function findBook(id) {
  return BOOKS.find((book) => book.id === id) || null;
}

function getHadithText(hadith) {
  if (typeof hadith?.arab === "string" && hadith.arab.trim()) {
    return hadith.arab.trim();
  }
  if (typeof hadith?.text === "string" && hadith.text.trim()) {
    return hadith.text.trim();
  }
  return "";
}

function safeProviderError(error) {
  const code = String(error?.code || error?.message || "");

  if (/^HTTP_\d{3}$/.test(code)) return code;
  if (code === "HADITH_PROVIDER_INVALID_RESPONSE") return code;
  if (code === "HADITH_PROVIDER_TIMEOUT") return code;
  if (code === "HADITH_PROVIDER_INVALID_JSON") return code;

  return "HADITH_PROVIDER_UNAVAILABLE";
}

async function fetchBookHadiths(book) {
  // The provider requires an explicit range and limits each request to 300.
  const rangeEnd = FIRST_HADITH_NUMBER + MAX_RANGE_SIZE - 1;
  const endpoint =
    `${HADITH_API}/${encodeURIComponent(book.id)}` +
    `?range=${FIRST_HADITH_NUMBER}-${rangeEnd}`;
  const controller = new AbortController();

  const timeout = setTimeout(
    () => controller.abort(),
    PROVIDER_TIMEOUT_MS,
  );

  try {
    const response = await fetch(endpoint, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        "User-Agent": "Sa7bi-AI/6.3.0",
      },
    });

    if (!response.ok) {
      const error = new Error(`HTTP_${response.status}`);
      error.code = `HTTP_${response.status}`;
      throw error;
    }

    let data;

    try {
      data = await response.json();
    } catch (_) {
      const error = new Error("HADITH_PROVIDER_INVALID_JSON");
      error.code = "HADITH_PROVIDER_INVALID_JSON";
      throw error;
    }

    if (!Array.isArray(data?.data?.hadiths)) {
      const error = new Error("HADITH_PROVIDER_INVALID_RESPONSE");
      error.code = "HADITH_PROVIDER_INVALID_RESPONSE";
      throw error;
    }

    return {
      ok: true,
      hadiths: data.data.hadiths,
      providerError: null,
    };
  } catch (error) {
    const aborted = error?.name === "AbortError";

    return {
      ok: false,
      hadiths: [],
      providerError: aborted
          ? "HADITH_PROVIDER_TIMEOUT"
          : safeProviderError(error),
    };
  } finally {
    clearTimeout(timeout);
  }
}

function normalizeHadith(hadith, book, fallbackNumber) {
  const text = getHadithText(hadith);

  if (!text) return null;

  const number =
      hadith?.number ??
      hadith?.hadithnumber ??
      hadith?.arabicnumber ??
      fallbackNumber ??
      null;

  return {
    id: `${book.id}-${number || fallbackNumber}`,
    number,
    book: book.id,
    bookName: book.name,
    text,
    source: "Hadith API",
    type: "hadith",
  };
}

export async function handleHadithSearch(request) {
  const url = new URL(request.url);

  const query = normalizeArabic(
    url.searchParams.get("q") || "",
  );

  const bookId = (url.searchParams.get("book") || "")
      .trim()
      .toLowerCase();

  const limit = normalizeLimit(
    url.searchParams.get("limit"),
  );

  if (bookId && !findBook(bookId)) {
    return json({
      ok: false,
      error: "UNSUPPORTED_HADITH_BOOK",
      message: "كتاب الحديث المطلوب غير مدعوم.",
      books: BOOKS,
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  const selectedBooks = bookId
      ? [findBook(bookId)]
      : BOOKS;

  const results = [];
  const bookErrors = [];
  const booksChecked = [];

  let successfulBooks = 0;

  for (const book of selectedBooks) {
    if (results.length >= limit) break;

    const providerResult = await fetchBookHadiths(book);

    booksChecked.push(book.id);

    if (!providerResult.ok) {
      bookErrors.push({
        book: book.id,
        error: providerResult.providerError,
      });
      continue;
    }

    successfulBooks += 1;

    let fallbackNumber = 1;

    for (const hadith of providerResult.hadiths) {
      if (results.length >= limit) break;

      const text = getHadithText(hadith);

      if (!text) {
        fallbackNumber += 1;
        continue;
      }

      if (query && !normalizeArabic(text).includes(query)) {
        fallbackNumber += 1;
        continue;
      }

      const item = normalizeHadith(
        hadith,
        book,
        fallbackNumber,
      );

      if (item) results.push(item);

      fallbackNumber += 1;
    }
  }

  // لا نعلن نجاحًا وهميًا إذا فشلت كل الكتب المطلوبة.
  if (successfulBooks === 0) {
    return json({
      ok: false,
      type: "hadith",
      query,
      book: bookId || null,
      count: 0,
      items: [],
      books: BOOKS,
      booksChecked,
      bookErrors,
      error: "HADITH_SOURCES_UNAVAILABLE",
      message: "تعذر الوصول إلى مصدر الأحاديث. حاول التحديث بعد قليل.",
      backendVersion: BACKEND_VERSION,
    }, 502);
  }

  return json({
    ok: true,
    type: "hadith",
    query,
    book: bookId || null,
    count: results.length,
    items: results,
    books: BOOKS,
    booksChecked,
    successfulBooks,
    failedBooks: bookErrors.length,
    warnings: bookErrors,
    backendVersion: BACKEND_VERSION,
  });
}

export async function handleHadithBooks() {
  return json({
    ok: true,
    type: "hadith-books",
    count: BOOKS.length,
    items: BOOKS,
    backendVersion: BACKEND_VERSION,
  });
}

export { BOOKS, fetchBookHadiths };

export default {
  handleHadithSearch,
  handleHadithBooks,
};
