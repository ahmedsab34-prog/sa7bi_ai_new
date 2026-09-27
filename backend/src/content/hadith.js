// backend/src/content/hadith.js
// Sa7bi AI Backend - Hadith Module
// Version: 6.0.0

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

const HADITH_API =
  "https://api.hadith.gading.dev/books";

/**
 * Supported books from the public Hadith API.
 */
const BOOKS = [
  {
    id: "bukhari",
    name: "صحيح البخاري",
  },
  {
    id: "muslim",
    name: "صحيح مسلم",
  },
  {
    id: "abudawud",
    name: "سنن أبي داود",
  },
  {
    id: "tirmidzi",
    name: "جامع الترمذي",
  },
  {
    id: "nasai",
    name: "سنن النسائي",
  },
  {
    id: "ibnu-majah",
    name: "سنن ابن ماجه",
  },
  {
    id: "ahmad",
    name: "مسند أحمد",
  },
];

/**
 * Search hadith.
 *
 * Supported:
 *
 * /v1/hadith?q=الصلاة
 * /v1/hadith?book=bukhari
 * /v1/hadith?book=muslim&q=الإيمان
 */
export async function handleHadithSearch(
  request
) {
  try {
    const url =
      new URL(request.url);

    const query =
      normalizeArabic(
        url.searchParams.get("q") ||
        ""
      );

    const book =
      (
        url.searchParams.get(
          "book"
        ) || ""
      )
        .trim()
        .toLowerCase();

    const limitRaw =
      Number(
        url.searchParams.get(
          "limit"
        ) || 20
      );

    const limit =
      Math.min(
        Math.max(
          limitRaw,
          1
        ),
        50
      );

    if (
      book &&
      !BOOKS.some(
        (item) =>
          item.id === book
      )
    ) {
      return json(
        {
          ok: false,

          error:
            "Unsupported hadith book",

          books:
            BOOKS,

          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const selectedBooks =
      book
        ? BOOKS.filter(
            (item) =>
              item.id === book
          )
        : BOOKS;

    const results = [];

    /**
     * Fetch only a limited number of books so the
     * Worker does not make an unnecessarily large
     * number of external requests.
     */
    for (
      const selectedBook of selectedBooks
    ) {
      if (
        results.length >=
        limit
      ) {
        break;
      }

      try {
        const endpoint =
          `${HADITH_API}/${encodeURIComponent(selectedBook.id)}`;

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

        for (
          const hadith of hadiths
        ) {
          if (
            results.length >=
            limit
          ) {
            break;
          }

          const text =
            hadith?.arab ||
            hadith?.text ||
            "";

          if (!text) {
            continue;
          }

          const normalizedText =
            normalizeArabic(
              text
            );

          if (
            query &&
            !normalizedText.includes(
              query
            )
          ) {
            continue;
          }

          results.push({
            id:
              `${selectedBook.id}-${hadith.number || results.length + 1}`,

            number:
              hadith.number ||
              null,

            book:
              selectedBook.id,

            bookName:
              selectedBook.name,

            text,

            source:
              "Hadith API",
          });
        }
      } catch (_) {
        // If one book fails, continue with the
        // remaining books.
      }
    }

    return json({
      ok: true,

      type:
        "hadith",

      query,

      book:
        book || null,

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
        ok: false,

        type:
          "hadith",

        items: [],

        error:
          "Hadith service unavailable",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Return the supported Hadith books.
 */
export async function handleHadithBooks() {
  return json({
    ok: true,

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

export default {
  handleHadithSearch,
  handleHadithBooks,
};
