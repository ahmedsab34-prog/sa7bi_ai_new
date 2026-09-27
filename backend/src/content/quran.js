import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

/**
 * البحث عن السور.
 *
 * GET /v1/audio/search?q=...
 * type=quran
 */
export async function handleQuranSearch(
  query = ""
) {
  try {
    const data =
      await fetchJson(
        `${MP3QURAN_BASE}/suwar?language=ar`
      );

    let items =
      Array.isArray(data)
        ? data
        : [];

    const normalizedQuery =
      normalizeArabic(query);

    if (normalizedQuery) {
      items =
        items.filter((item) =>
          normalizeArabic(
            item?.name ||
              item?.sura_name ||
              ""
          ).includes(
            normalizedQuery
          )
        );
    }

    return json({
      ok: true,

      type: "quran",

      items:
        items
          .slice(0, 100)
          .map((item) => ({
            id:
              item?.id ||
              item?.sura_id ||
              item?.number ||
              0,

            title:
              item?.name ||
              item?.sura_name ||
              "سورة",

            name:
              item?.name ||
              item?.sura_name ||
              "سورة",

            type: "quran",
          })),

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "QURAN_SEARCH_FAILED",

        items: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * جلب قائمة القراء والسور.
 *
 * GET /v1/audio/quran
 */
export async function handleQuranCatalog() {
  try {
    const [
      recitersData,
      suwarData,
    ] = await Promise.all([
      fetchJson(
        `${MP3QURAN_BASE}/reciters?language=ar`
      ),

      fetchJson(
        `${MP3QURAN_BASE}/suwar?language=ar`
      ),
    ]);

    const reciters =
      Array.isArray(
        recitersData
      )
        ? recitersData
        : [];

    const suwar =
      Array.isArray(
        suwarData
      )
        ? suwarData
        : [];

    const output =
      reciters.map(
        (reciter) => ({
          id:
            reciter?.id ||
            reciter?.reciter_id ||
            reciter?.name ||
            "",

          name:
            reciter?.name ||
            "قارئ",

          moshaf:
            (
              Array.isArray(
                reciter?.moshaf
              )
                ? reciter.moshaf
                : []
            ).map(
              (
                moshaf,
                index
              ) => ({
                id:
                  moshaf?.id ||
                  `${reciter?.id || "reciter"}-${index + 1}`,

                name:
                  moshaf?.name ||
                  "رواية",

                server:
                  moshaf?.server ||
                  moshaf?.url ||
                  "",

                surahTotal:
                  Number(
                    moshaf?.surah_total ||
                      moshaf?.surahTotal ||
                      114
                  ),

                suras:
                  moshaf?.suras ||
                  "",
              })
            ),
        })
      );

    const suras =
      suwar
        .map(
          (sura) => ({
            id:
              Number(
                sura?.id ||
                  sura?.sura_id ||
                  sura?.number ||
                  0
              ),

            name:
              sura?.name ||
              sura?.sura_name ||
              "سورة",
          })
        )
        .filter(
          (sura) =>
            sura.id >= 1 &&
            sura.id <= 114
        );

    return json({
      ok: true,

      reciters:
        output,

      suras,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "QURAN_CATALOG_FAILED",

        reciters: [],

        suras: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * بناء رابط ملف السورة عند الحاجة.
 *
 * بعض روايات MP3Quran تستخدم:
 * server + رقم السورة بصيغة ثلاثية.
 */
export function buildQuranAudioUrl(
  server,
  surahId
) {
  const cleanServer =
    String(server || "")
      .trim()
      .replace(/\/+$/, "");

  const id =
    Number(surahId);

  if (
    !cleanServer ||
    !Number.isInteger(id) ||
    id < 1 ||
    id > 114
  ) {
    return "";
  }

  const padded =
    String(id).padStart(3, "0");

  return `${cleanServer}/${padded}.mp3`;
}
