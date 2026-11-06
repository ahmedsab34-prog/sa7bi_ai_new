import {
  json,
  normalizeArabic,
} from "../utils.js";

const BACKEND_VERSION = "6.3.0";

const HADITH_API = "https://api.hadith.gading.dev/books";
const FAWAZ_CDN =
  "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const PROVIDER_TIMEOUT_MS = 10000;
const FALLBACK_TIMEOUT_MS = 15000;
const MAX_EDITION_BYTES = 20 * 1024 * 1024;
const EDITION_CACHE_TTL_MS = 10 * 60 * 1000;

// نحتفظ بنسخة احتياطية واحدة في الذاكرة لتقليل استهلاكها.
const MAX_CACHED_EDITIONS = 1;

const BOOKS = [
  {
    id: "bukhari",
    name: "صحيح البخاري",
    edition: "ara-bukhari",
  },
  {
    id: "muslim",
    name: "صحيح مسلم",
    edition: "ara-muslim",
  },
  {
    id: "abu-daud",
    name: "سنن أبي داود",
    edition: "ara-abudawud",
  },
  {
    id: "tirmidzi",
    name: "جامع الترمذي",
    edition: "ara-tirmidhi",
  },
  {
    id: "nasai",
    name: "سنن النسائي",
    edition: "ara-nasai",
  },
  {
    id: "ibnu-majah",
    name: "سنن ابن ماجه",
    edition: "ara-ibnmajah",
  },
  {
    id: "ahmad",
    name: "مسند أحمد",
    edition: "ara-ahmad",
  },
  {
    id: "darimi",
    name: "سنن الدارمي",
    edition: "ara-darimi",
  },
  {
    id: "malik",
    name: "موطأ مالك",
    edition: "ara-malik",
  },
];

const editionCache = new Map();

/* -------------------------------------------------------------------------- */
/* BASIC HELPERS                                                              */
/* -------------------------------------------------------------------------- */

function normalizeLimit(value) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return DEFAULT_LIMIT;
  }

  return Math.min(
    Math.max(Math.floor(parsed), 1),
    MAX_LIMIT,
  );
}

function findBook(id) {
  return BOOKS.find(
    (book) => book.id === id,
  ) || null;
}

function getHadithText(hadith) {
  const candidates = [
    hadith?.arab,
    hadith?.arabic,
    hadith?.text?.arabic,
    hadith?.text,
  ];

  for (const candidate of candidates) {
    if (
      typeof candidate === "string" &&
      candidate.trim()
    ) {
      return candidate.trim();
    }
  }

  return "";
}

function safeProviderError(error, fallbackCode) {
  const code = String(
    error?.code || error?.message || "",
  );

  if (/^HTTP_\d{3}$/.test(code)) {
    return code;
  }

  const allowedCodes = new Set([
    "HADITH_PROVIDER_TIMEOUT",
    "HADITH_PROVIDER_INVALID_JSON",
    "HADITH_PROVIDER_INVALID_RESPONSE",
    "HADITH_EDITION_TOO_LARGE",
    "HADITH_CDN_TIMEOUT",
    "HADITH_CDN_INVALID_JSON",
    "HADITH_CDN_INVALID_RESPONSE",
    "HADITH_CDN_EDITION_TOO_LARGE",
  ]);

  if (allowedCodes.has(code)) {
    return code;
  }

  return fallbackCode;
}

function createProviderError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

/* -------------------------------------------------------------------------- */
/* SHARED JSON FETCH                                                          */
/* -------------------------------------------------------------------------- */

async function fetchJsonWithTimeout(
  url,
  {
    timeoutMs,
    maxBytes = 1024 * 1024,
    provider,
  },
) {
  const controller = new AbortController();

  const timer = setTimeout(
    () => controller.abort(),
    timeoutMs,
  );

  try {
    const response = await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        "User-Agent": "Sa7bi-AI/6.3.0",
        "Cache-Control": "no-cache",
      },
    });

    if (!response.ok) {
      throw createProviderError(
        `HTTP_${response.status}`,
      );
    }

    const contentLength = Number(
      response.headers.get("Content-Length") || "0",
    );

    if (
      Number.isFinite(contentLength) &&
      contentLength > maxBytes
    ) {
      throw createProviderError(
        provider === "cdn"
          ? "HADITH_CDN_EDITION_TOO_LARGE"
          : "HADITH_EDITION_TOO_LARGE",
      );
    }

    const raw = await response.text();

    const actualBytes = new TextEncoder()
      .encode(raw)
      .byteLength;

    if (actualBytes > maxBytes) {
      throw createProviderError(
        provider === "cdn"
          ? "HADITH_CDN_EDITION_TOO_LARGE"
          : "HADITH_EDITION_TOO_LARGE",
      );
    }

    try {
      return JSON.parse(raw);
    } catch (_) {
      throw createProviderError(
        provider === "cdn"
          ? "HADITH_CDN_INVALID_JSON"
          : "HADITH_PROVIDER_INVALID_JSON",
      );
    }
  } catch (error) {
    if (error?.name === "AbortError") {
      throw createProviderError(
        provider === "cdn"
          ? "HADITH_CDN_TIMEOUT"
          : "HADITH_PROVIDER_TIMEOUT",
      );
    }

    throw error;
  } finally {
    clearTimeout(timer);
  }
}

/* -------------------------------------------------------------------------- */
/* PRIMARY PROVIDER                                                           */
/* -------------------------------------------------------------------------- */

async function fetchBookHadiths(book) {
  const rangeEnd = 300;

  const endpoint =
    `${HADITH_API}/${encodeURIComponent(book.id)}` +
    `?range=1-${rangeEnd}`;

  try {
    const data = await fetchJsonWithTimeout(
      endpoint,
      {
        timeoutMs: PROVIDER_TIMEOUT_MS,
        maxBytes: 2 * 1024 * 1024,
        provider: "primary",
      },
    );

    const hadiths =
      data?.data?.hadiths ??
      data?.hadiths;

    if (!Array.isArray(hadiths)) {
      throw createProviderError(
        "HADITH_PROVIDER_INVALID_RESPONSE",
      );
    }

    return {
      ok: true,
      hadiths,
      providerError: null,
    };
  } catch (error) {
    return {
      ok: false,
      hadiths: [],
      providerError: safeProviderError(
        error,
        "HADITH_PROVIDER_UNAVAILABLE",
      ),
    };
  }
}

/* -------------------------------------------------------------------------- */
/* BACKUP PROVIDER                                                            */
/* -------------------------------------------------------------------------- */

async function loadFawazEdition(edition) {
  const candidates = [
    `${FAWAZ_CDN}/${encodeURIComponent(edition)}.min.json`,
    `${FAWAZ_CDN}/${encodeURIComponent(edition)}.json`,
  ];

  let lastError = "HADITH_CDN_UNAVAILABLE";

  for (const url of candidates) {
    try {
      const data = await fetchJsonWithTimeout(
        url,
        {
          timeoutMs: FALLBACK_TIMEOUT_MS,
          maxBytes: MAX_EDITION_BYTES,
          provider: "cdn",
        },
      );

      if (!Array.isArray(data?.hadiths)) {
        throw createProviderError(
          "HADITH_CDN_INVALID_RESPONSE",
        );
      }

      return {
        metadata: data.metadata ?? null,
        hadiths: data.hadiths,
      };
    } catch (error) {
      lastError = safeProviderError(
        error,
        "HADITH_CDN_UNAVAILABLE",
      );
    }
  }

  throw createProviderError(lastError);
}

async function getFawazEdition(book) {
  const key = book.edition;

  const cached = editionCache.get(key);

  if (
    cached &&
    cached.expiresAt > Date.now()
  ) {
    return cached.promise;
  }

  if (cached) {
    editionCache.delete(key);
  }

  while (editionCache.size >= MAX_CACHED_EDITIONS) {
    const oldestKey = editionCache.keys().next().value;

    if (oldestKey === undefined) {
      break;
    }

    editionCache.delete(oldestKey);
  }

  const promise = loadFawazEdition(key);

  editionCache.set(key, {
    promise,
    expiresAt: Date.now() + EDITION_CACHE_TTL_MS,
  });

  try {
    return await promise;
  } catch (error) {
    const current = editionCache.get(key);

    if (current?.promise === promise) {
      editionCache.delete(key);
    }

    throw error;
  }
}

async function fetchFawazHadiths(book) {
  try {
    const edition = await getFawazEdition(book);

    return {
      ok: true,
      hadiths: edition.hadiths,
      providerError: null,
    };
  } catch (error) {
    return {
      ok: false,
      hadiths: [],
      providerError: safeProviderError(
        error,
        "HADITH_CDN_UNAVAILABLE",
      ),
    };
  }
}

/* -------------------------------------------------------------------------- */
/* HADITH NORMALIZATION                                                       */
/* -------------------------------------------------------------------------- */

function normalizeHadith(
  hadith,
  book,
  fallbackNumber,
  source,
) {
  const text = getHadithText(hadith);

  if (!text) {
    return null;
  }

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
    source,
    type: "hadith",
  };
}

function filterHadiths(
  rows,
  book,
  query,
  limit,
  source,
) {
  const results = [];

  let fallbackNumber = 1;

  for (const hadith of rows) {
    const text = getHadithText(hadith);

    if (!text) {
      fallbackNumber += 1;
      continue;
    }

    if (
      query &&
      !normalizeArabic(text).includes(query)
    ) {
      fallbackNumber += 1;
      continue;
    }

    const item = normalizeHadith(
      hadith,
      book,
      fallbackNumber,
      source,
    );

    if (item) {
      results.push(item);
    }

    fallbackNumber += 1;

    if (results.length >= limit) {
      break;
    }
  }

  return results;
}

/* -------------------------------------------------------------------------- */
/* PUBLIC HADITH SEARCH                                                       */
/* -------------------------------------------------------------------------- */

export async function handleHadithSearch(request) {
  const url = new URL(request.url);

  const query = normalizeArabic(
    (url.searchParams.get("q") || "").slice(0, 200),
  );

  const bookId = (
    url.searchParams.get("book") || ""
  )
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
      books: BOOKS.map(({ id, name }) => ({
        id,
        name,
      })),
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  const selectedBooks = bookId
    ? [findBook(bookId)]
    : BOOKS;

  const results = [];
  const bookErrors = [];
  const warnings = [];
  const providersUsed = new Set();

  let successfulBooks = 0;

  for (const book of selectedBooks) {
    if (results.length >= limit) {
      break;
    }

    const primary = await fetchBookHadiths(book);

    let selectedRows = null;
    let selectedProvider = "";

    if (primary.ok) {
      const primaryResults = filterHadiths(
        primary.hadiths,
        book,
        query,
        limit - results.length,
        "Hadith API (Gading)",
      );

      // لو البحث لم يجد نتيجة ضمن أول 300 حديث،
      // ننتقل إلى النسخة العربية الكاملة.
      if (
        primaryResults.length > 0 ||
        (!query && primary.hadiths.length > 0)
      ) {
        selectedRows = primaryResults;
        selectedProvider = "gading";
      }
    }

    // المصدر الأساسي تعطل أو لم يجد نتيجة.
    if (selectedRows === null) {
      const fallback = await fetchFawazHadiths(book);

      if (fallback.ok) {
        selectedRows = filterHadiths(
          fallback.hadiths,
          book,
          query,
          limit - results.length,
          "Hadith API (Fawaz Arabic edition)",
        );

        selectedProvider = "fawaz";

        if (!primary.ok) {
          warnings.push({
            book: book.id,
            provider: "gading",
            error: primary.providerError,
            fallback: "fawazahmed0/hadith-api",
          });
        }
      } else {
        bookErrors.push({
          book: book.id,
          error: primary.ok
            ? fallback.providerError
            : primary.providerError,
          primaryError: primary.ok
            ? null
            : primary.providerError,
          fallbackError: fallback.providerError,
        });

        continue;
      }
    }

    successfulBooks += 1;

    providersUsed.add(selectedProvider);

    results.push(...selectedRows);
  }

  // لا نعرض نجاحًا وهميًا عندما تفشل جميع المصادر.
  if (successfulBooks === 0) {
    return json({
      ok: false,
      type: "hadith",
      query,
      book: bookId || null,
      count: 0,
      items: [],
      books: BOOKS.map(({ id, name }) => ({
        id,
        name,
      })),
      booksChecked: selectedBooks.map(
        (book) => book.id,
      ),
      bookErrors,
      error: "HADITH_SOURCES_UNAVAILABLE",
      message:
        "تعذر الوصول إلى مصادر الأحاديث. حاول التحديث بعد قليل.",
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
    books: BOOKS.map(({ id, name }) => ({
      id,
      name,
    })),
    booksChecked: selectedBooks.map(
      (book) => book.id,
    ),
    successfulBooks,
    failedBooks: bookErrors.length,
    providers: [...providersUsed],
    warnings: [
      ...warnings,
      ...bookErrors,
    ],
    backendVersion: BACKEND_VERSION,
  });
}

/* -------------------------------------------------------------------------- */
/* PUBLIC BOOK LIST                                                           */
/* -------------------------------------------------------------------------- */

export async function handleHadithBooks() {
  return json({
    ok: true,
    type: "hadith-books",
    count: BOOKS.length,
    items: BOOKS.map(({ id, name }) => ({
      id,
      name,
    })),
    backendVersion: BACKEND_VERSION,
  });
}

/* -------------------------------------------------------------------------- */
/* EXPORTS                                                                    */
/* -------------------------------------------------------------------------- */

export {
  BOOKS,
  fetchBookHadiths,
  fetchFawazHadiths,
};

export default {
  handleHadithSearch,
  handleHadithBooks,
};
