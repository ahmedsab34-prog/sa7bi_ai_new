// backend/src/content/hadith.js
// Sa7bi AI Backend
//
// Hadith content module.
//
// Source:
// Hadith API
//
// Endpoints:
// GET /v1/hadith
// GET /v1/hadith/books
//
// Notes:
// - No API key is stored here.
// - The public API is accessed only by the Worker.
// - A failure in one book does not terminate the whole search.
// - The response contract remains compatible with the Flutter app.

/* =========================================================
   IMPORTS
   ========================================================= */

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

/* =========================================================
   CONSTANTS
   ========================================================= */

const BACKEND_VERSION =
  "6.3.0";

const HADITH_API =
  "https://api.hadith.gading.dev/books";

const DEFAULT_LIMIT = 20;

const MAX_LIMIT = 50;

/* =========================================================
   BOOKS
   ========================================================= */

const BOOKS = [
  {
    id:
      "bukhari",

    name:
      "صحيح البخاري",
  },

  {
    id:
      "muslim",

    name:
      "صحيح مسلم",
  },

  {
    id:
      "abudawud",

    name:
      "سنن أبي داود",
  },

  {
    id:
      "tirmidzi",

    name:
      "جامع الترمذي",
  },

  {
    id:
      "nasai",

    name:
      "سنن النسائي",
  },

  {
    id:
      "ibnu-majah",

    name:
      "سنن ابن ماجه",
  },

  {
    id:
      "ahmad",

    name:
      "مسند أحمد",
  },
];

/* =========================================================
   HELPERS
   ========================================================= */

/**
 * Normalize the requested result limit.
 */
function normalizeLimit(
  value
) {
  const parsed =
    Number(value);

  if (
    !Number.isFinite(
      parsed
    )
  ) {
    return DEFAULT_LIMIT;
  }

  return Math.min(
    Math.max(
      Math.floor(parsed),
      1
    ),
    MAX_LIMIT
  );
}

/**
 * Find a supported book.
 */
function findBook(
  id
) {
  return BOOKS.find(
    (book) =>
      book.id === id
  );
}

/**
 * Extract the Arabic hadith text from an API item.
 */
function getHadithText(
  hadith
) {
  if (
    typeof hadith?.arab ===
      "string"
  ) {
    return hadith.arab.trim();
  }

  if (
    typeof hadith?.text ===
      "string"
  ) {
    return hadith.text.trim();
  }

  return "";
}

/**
 * Fetch one Hadith book safely.
 *
 * Returns [] instead of throwing so one unavailable
 * book does not break a multi-book search.
 */
async function fetchBookHadiths(
  book
) {
  const endpoint =
    `${HADITH_API}/${encodeURIComponent(book.id)}`;

  try {
    const data =
      await fetchJson(
        endpoint
      );

    const hadiths =
      Array.isArray(
        data?.data?.hadiths
      )
        ? data.data.hadiths
        : [];

    return hadiths;
  } catch {
    return [];
  }
}

/**
 * Convert an API hadith into the stable response
 * format used by Sa7bi AI.
 */
function normalizeHadith(
  hadith,
  book,
  fallbackNumber
) {
  const text =
    getHadithText(
      hadith
    );

  if (!text) {
    return null;
  }

  const number =
    hadith?.number ??
    fallbackNumber ??
    null;

  return {
    id:
      `${book.id}-${number || fallbackNumber}`,

    number,

    book:
      book.id,

    bookName:
      book.name,

    text,

    source:
      "Hadith API",

    type:
      "hadith",
  };
}

/* =========================================================
   SEARCH
   ========================================================= */

/**
 * Search Hadith.
 *
 * Examples:
 *
 * /v1/hadith?q=الصلاة
 * /v1/hadith?book=bukhari
 * /v1/hadith?book=muslim&q=الإيمان
 * /v1/hadith?limit=20
 */
export async function handleHadithSearch(
  request
) {
  try {
    const url =
      new URL(
        request.url
      );

    const query =
      normalizeArabic(
        url.searchParams.get(
          "q"
        ) || ""
      );

    const bookId =
      (
        url.searchParams.get(
          "book"
        ) || ""
      )
        .trim()
        .toLowerCase();

    const limit =
      normalizeLimit(
        url.searchParams.get(
          "limit"
        )
      );

    /* -----------------------------------------------------
       BOOK VALIDATION
       ----------------------------------------------------- */

    if (
      bookId &&
      !findBook(
        bookId
      )
    ) {
      return json(
        {
          ok:
            false,

          error:
            "UNSUPPORTED_HADITH_BOOK",

          message:
            "كتاب الحديث المطلوب غير مدعوم.",

          books:
            BOOKS,

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const selectedBooks =
      bookId
        ? [
            findBook(
              bookId
            ),
          ]
        : BOOKS;

    const results =
      [];

    /* -----------------------------------------------------
       SEARCH SELECTED BOOKS
       ----------------------------------------------------- */

    for (
      const book of
        selectedBooks
    ) {
      if (
        results.length >=
        limit
      ) {
        break;
      }

      const hadiths =
        await fetchBookHadiths(
          book
        );

      let fallbackNumber =
        1;

      for (
        const hadith of
          hadiths
      ) {
        if (
          results.length >=
          limit
        ) {
          break;
        }

        const text =
          getHadithText(
            hadith
          );

        if (!text) {
          fallbackNumber +=
            1;

          continue;
        }

        /*
         * Arabic normalization is used only for
         * comparison. The original hadith text is
         * returned unchanged.
         */
        if (
          query &&
          !normalizeArabic(
            text
          ).includes(
            query
          )
        ) {
          fallbackNumber +=
            1;

          continue;
        }

        const item =
          normalizeHadith(
            hadith,
            book,
            fallbackNumber
          );

        if (item) {
          results.push(
            item
          );
        }

        fallbackNumber +=
          1;
      }
    }

    return json({
      ok:
        true,

      type:
        "hadith",

      query,

      book:
        bookId || null,

      count:
        results.length,

      items:
        results,

      books:
        BOOKS,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok:
          false,

        type:
          "hadith",

        items: [],

        books:
          BOOKS,

        error:
          "HADITH_SERVICE_UNAVAILABLE",

        message:
          error?.message ||
          "تعذر تحميل الأحاديث.",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/* =========================================================
   BOOK CATALOG
   ========================================================= */

/**
 * Return the supported Hadith books.
 *
 * GET /v1/hadith/books
 */
export async function handleHadithBooks() {
  return json({
    ok:
      true,

    type:
      "hadith-books",

    count:
      BOOKS.length,

    items:
      BOOKS,

    backendVersion:
      BACKEND_VERSION,
  });
}

/* =========================================================
   EXPORTS
   ========================================================= */

export {
  BOOKS,
};

export default {
  handleHadithSearch,
  handleHadithBooks,
};
