import {
  json,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

/**
 * جلب الفيديوهات القصيرة.
 *
 * GET /v1/shorts
 *
 * ملاحظة:
 * هذا الملف يحافظ على نفس المصدر الموجود حاليًا
 * في backend/src/index.js، ولا يغيّر واجهة التطبيق.
 */
export async function handleShorts() {
  try {
    const data =
      await fetchJson(
        `${MP3QURAN_BASE}/videos?language=ar`
      );

    const raw =
      Array.isArray(data)
        ? data
        : Array.isArray(
            data?.videos
          )
          ? data.videos
          : [];

    const items =
      raw
        .map(
          (
            item,
            index
          ) => ({
            id:
              item?.id ||
              item?.video_id ||
              `short-${index}`,

            title:
              item?.title ||
              item?.name ||
              "فيديو قصير",

            description:
              item?.description ||
              "",

            thumbnail:
              item?.thumbnail ||
              item?.image ||
              item?.cover ||
              "",

            videoUrl:
              item?.video_url ||
              item?.videoUrl ||
              item?.url ||
              item?.video ||
              "",

            source:
              item?.source ||
              "Sa7bi AI",

            type:
              "short",
          })
        )
        .filter(
          (item) =>
            Boolean(
              item.title ||
                item.thumbnail ||
                item.videoUrl
            )
        )
        .slice(0, 20);

    return json({
      ok: true,

      items,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "SHORTS_FAILED",

        items: [],

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

export default {
  handleShorts,
};
