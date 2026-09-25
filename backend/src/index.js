const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store"
};

const BACKEND_VERSION = "4.5.0";

const DEFAULT_TEXT_MODEL = "gpt-5.6-luna";
const DEFAULT_IMAGE_MODEL = "gpt-image-2";

const DOWNLOAD_URL =
  "https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/latest/download/sa7bi-ai.apk";

const MAX_BODY_BYTES = 12 * 1024 * 1024;

const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 24000;

const MAX_IMAGE_CHARS = 2 * 1024 * 1024;
const MAX_IMAGE_COUNT = 6;

const MAX_RADIO_STATIONS = 120;

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

const RADIO_BROWSER_BASE =
  "https://de1.api.radio-browser.info";

function headers(extra = {}) {
  return {
    ...CORS_HEADERS,
    ...extra
  };
}

function json(data, status = 200, extra = {}) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: headers({
        "Content-Type":
          "application/json; charset=utf-8",
        ...extra
      })
    }
  );
}

function normalizeArabic(value) {
  return String(value || "")
    .replace(/\u0640/g, "")
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function stripHtml(value) {
  return String(value || "")
    .replace(
      /<script[\s\S]*?<\/script>/gi,
      ""
    )
    .replace(
      /<style[\s\S]*?<\/style>/gi,
      ""
    )
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function decodeXml(value) {
  return String(value || "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => {
      try {
        return String.fromCodePoint(
          Number(n)
        );
      } catch {
        return "";
      }
    });
}

function isHttpUrl(value) {
  if (
    typeof value !== "string" ||
    !value.trim()
  ) {
    return false;
  }

  try {
    const url = new URL(
      value.trim()
    );

    return (
      url.protocol === "http:" ||
      url.protocol === "https:"
    );
  } catch {
    return false;
  }
}

/* ============================================================
   REQUEST BODY
============================================================ */

async function readJsonBody(request) {
  const contentLength = Number(
    request.headers.get(
      "content-length"
    ) || "0"
  );

  if (
    contentLength > MAX_BODY_BYTES
  ) {
    throw new Error(
      "BODY_TOO_LARGE"
    );
  }

  const raw =
    await request.text();

  if (
    raw.length > MAX_BODY_BYTES
  ) {
    throw new Error(
      "BODY_TOO_LARGE"
    );
  }

  if (!raw.trim()) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    throw new Error(
      "INVALID_JSON"
    );
  }
}

/* ============================================================
   CHAT HELPERS
============================================================ */

function cleanMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  const result = [];
  let total = 0;

  for (
    const item of messages.slice(
      -MAX_MESSAGES
    )
  ) {
    if (
      !item ||
      typeof item !== "object"
    ) {
      continue;
    }

    const role =
      item.role === "assistant"
        ? "assistant"
        : "user";

    let content =
      String(
        item.content || ""
      ).trim();

    if (!content) {
      continue;
    }

    if (
      content.length >
      MAX_MESSAGE_CHARS
    ) {
      content =
        content.substring(
          0,
          MAX_MESSAGE_CHARS
        );
    }

    if (
      total + content.length >
      MAX_TOTAL_CHARS
    ) {
      break;
    }

    result.push({
      role,
      content
    });

    total +=
      content.length;
  }

  return result;
}

function isValidImageDataUrl(
  value
) {
  if (
    typeof value !== "string"
  ) {
    return false;
  }

  if (
    !value.startsWith(
      "data:image/"
    )
  ) {
    return false;
  }

  return (
    value.length <=
    MAX_IMAGE_CHARS
  );
}

function extractImageDataUrls(
  body
) {
  const result = [];

  if (
    Array.isArray(
      body.imageDataUrls
    )
  ) {
    for (
      const item of
        body.imageDataUrls
    ) {
      if (
        !isValidImageDataUrl(
          item
        )
      ) {
        continue;
      }

      result.push(item);

      if (
        result.length >=
        MAX_IMAGE_COUNT
      ) {
        break;
      }
    }
  }

  if (
    result.length === 0 &&
    typeof body.imageDataUrl ===
      "string" &&
    body.imageDataUrl.trim()
  ) {
    if (
      isValidImageDataUrl(
        body.imageDataUrl
      )
    ) {
      result.push(
        body.imageDataUrl
      );
    }
  }

  return result;
}

/* ============================================================
   OPENAI
============================================================ */

function extractOutputText(data) {
  if (!data) {
    return "";
  }

  if (
    typeof data.output_text ===
    "string"
  ) {
    return data.output_text.trim();
  }

  if (
    Array.isArray(data.output)
  ) {
    const parts = [];

    for (
      const item of data.output
    ) {
      if (
        !item ||
        !Array.isArray(
          item.content
        )
      ) {
        continue;
      }

      for (
        const content of
          item.content
      ) {
        if (
          content &&
          typeof content.text ===
            "string"
        ) {
          parts.push(
            content.text
          );
        }
      }
    }

    return parts
      .join("\n")
      .trim();
  }

  return "";
}

async function callOpenAI(
  env,
  body
) {
  if (
    !env.OPENAI_API_KEY
  ) {
    throw new Error(
      "OPENAI_API_KEY_MISSING"
    );
  }

  const response =
    await fetch(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",

        headers: {
          Authorization:
            `Bearer ${env.OPENAI_API_KEY}`,

          "Content-Type":
            "application/json"
        },

        body:
          JSON.stringify(body)
      }
    );

  const raw =
    await response.text();

  let data;

  try {
    data =
      JSON.parse(raw);
  } catch {
    data = {
      raw
    };
  }

  if (!response.ok) {
    throw new Error(
      data?.error?.message ||
      data?.message ||
      "OPENAI_REQUEST_FAILED"
    );
  }

  return data;
}

/* ============================================================
   CHAT / VISION
============================================================ */

async function handleChat(
  request,
  env
) {
  const body =
    await readJsonBody(
      request
    );

  const messages =
    cleanMessages(
      body.messages
    );

  const images =
    extractImageDataUrls(
      body
    );

  if (
    messages.length === 0 &&
    images.length === 0
  ) {
    return json(
      {
        ok: false,
        error:
          "EMPTY_MESSAGE"
      },
      400
    );
  }

  if (
    Array.isArray(
      body.imageDataUrls
    ) &&
    body.imageDataUrls.length >
      0 &&
    images.length === 0
  ) {
    return json(
      {
        ok: false,
        error:
          "INVALID_IMAGES"
      },
      400
    );
  }

  const serviceTitle =
    typeof body.serviceTitle ===
    "string"
      ? body.serviceTitle.substring(
          0,
          200
        )
      : "صاحبي AI";

  const serviceContext =
    typeof body.serviceContext ===
    "string"
      ? body.serviceContext.substring(
          0,
          1200
        )
      : "";

  const input = [];

  for (
    const message of messages
  ) {
    input.push({
      role: message.role,

      content: [
        {
          type:
            "input_text",

          text:
            message.content
        }
      ]
    });
  }

  if (
    images.length > 0
  ) {
    const content = [
      {
        type:
          "input_text",

        text:
          images.length === 1
            ? "حلل الصورة المرفقة فعليًا بدقة. صف ما يظهر فيها، اقرأ النصوص إن وجدت، وقدم إجابة عربية عملية. لا تخمن الأشياء غير الواضحة."
            : "الصور المرفقة عبارة عن لقطات متتابعة من نفس المحتوى أو الفيديو. حللها معًا واربط المعلومات الظاهرة بينها. لا تدّعي أنك شاهدت كل ثانية من الفيديو."
      }
    ];

    for (
      const image of images
    ) {
      content.push({
        type:
          "input_image",

        image_url:
          image
      });
    }

    input.push({
      role:
        "user",

      content
    });
  }

  const instructions = `
أنت "صاحبي AI"، مساعد عربي ودود وعملي.

الخدمة الحالية:
${serviceTitle}

سياق الخدمة:
${serviceContext}

القواعد:
- أجب بالعربية ما لم يطلب المستخدم لغة أخرى.
- استخدم المصرية عندما تكون مناسبة.
- كن واضحًا ومباشرًا.
- لا تكرر كلام المستخدم بلا فائدة.
- لا تدّعي تنفيذ شيء لم تنفذه.
- إذا كانت المعلومة غير مؤكدة فاذكر ذلك.
- في الخدمات المتخصصة تصرف كمساعد متخصص.
- حلل الصور الفعلية المرسلة.
- إذا كانت الصور لقطات من فيديو، تعامل معها كلقطات متتابعة.
- لا تدّعي أنك شاهدت كل ثانية من الفيديو.
- لا تخمن التفاصيل غير الواضحة.
- حافظ على سياق المحادثة.
`;

  const model =
    env.OPENAI_MODEL ||
    DEFAULT_TEXT_MODEL;

  const data =
    await callOpenAI(
      env,
      {
        model,

        instructions,

        input,

        reasoning: {
          effort:
            "none"
        },

        max_output_tokens:
          1200
      }
    );

  const answer =
    extractOutputText(
      data
    );

  if (!answer) {
    return json(
      {
        ok: false,
        error:
          "EMPTY_AI_RESPONSE"
      },
      502
    );
  }

  return json({
    ok: true,

    answer,

    model,

    backendVersion:
      BACKEND_VERSION
  });
}

/* ============================================================
   IMAGE GENERATION
============================================================ */

async function handleImageGeneration(
  request,
  env
) {
  if (
    !env.OPENAI_API_KEY
  ) {
    return json(
      {
        ok: false,
        error:
          "OPENAI_API_KEY_MISSING"
      },
      500
    );
  }

  const body =
    await readJsonBody(
      request
    );

  const prompt =
    typeof body.prompt ===
    "string"
      ? body.prompt.trim()
      : "";

  if (!prompt) {
    return json(
      {
        ok: false,
        error:
          "EMPTY_PROMPT"
      },
      400
    );
  }

  const model =
    env.OPENAI_IMAGE_MODEL ||
    DEFAULT_IMAGE_MODEL;

  const response =
    await fetch(
      "https://api.openai.com/v1/images/generations",
      {
        method: "POST",

        headers: {
          Authorization:
            `Bearer ${env.OPENAI_API_KEY}`,

          "Content-Type":
            "application/json"
        },

        body:
          JSON.stringify({
            model,

            prompt:
              prompt.substring(
                0,
                6000
              ),

            size:
              "1024x1024",

            quality:
              "low",

            output_format:
              "png"
          })
      }
    );

  const raw =
    await response.text();

  let data;

  try {
    data =
      JSON.parse(raw);
  } catch {
    data = {};
  }

  if (!response.ok) {
    return json(
      {
        ok: false,

        error:
          data?.error?.message ||
          "IMAGE_GENERATION_FAILED"
      },
      response.status
    );
  }

  const item =
    Array.isArray(
      data.data
    ) &&
    data.data.length > 0
      ? data.data[0]
      : null;

  if (!item) {
    return json(
      {
        ok: false,
        error:
          "NO_IMAGE_RESULT"
      },
      502
    );
  }

  if (
    typeof item.b64_json ===
      "string" &&
    item.b64_json.trim()
  ) {
    return json({
      ok: true,

      imageDataUrl:
        `data:image/png;base64,${item.b64_json}`,

      model,

      backendVersion:
        BACKEND_VERSION
    });
  }

  if (
    typeof item.url ===
      "string" &&
    item.url.trim()
  ) {
    return json({
      ok: true,

      imageUrl:
        item.url.trim(),

      model,

      backendVersion:
        BACKEND_VERSION
    });
  }

  return json(
    {
      ok: false,
      error:
        "IMAGE_FORMAT_NOT_SUPPORTED"
    },
    502
  );
}

/* ============================================================
   EXTERNAL JSON
============================================================ */

async function fetchJson(
  url,
  options = {}
) {
  const response =
    await fetch(
      url,
      {
        ...options,

        headers: {
          "User-Agent":
            "Sa7bi-AI/4.5.0",

          ...(options.headers ||
            {})
        },

        cache:
          "no-store"
      }
    );

  if (!response.ok) {
    throw new Error(
      `HTTP_${response.status}`
    );
  }

  return response.json();
}

/* ============================================================
   AUDIO SEARCH
============================================================ */

async function handleAudioSearch(
  request
) {
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

  const type =
    (
      url.searchParams.get(
        "type"
      ) ||
      "quran"
    ).toLowerCase();

  if (
    type === "quran"
  ) {
    return handleQuranSearch(
      query
    );
  }

  if (
    type === "adhkar"
  ) {
    return handleAdhkarSearch(
      query
    );
  }

  if (
    type === "music"
  ) {
    return handleAppleSearch(
      query,
      "music"
    );
  }

  if (
    type === "podcast"
  ) {
    return handleAppleSearch(
      query,
      "podcast"
    );
  }

  return json({
    ok: true,

    items: [],

    type
  });
}

/* ============================================================
   QURAN SEARCH
============================================================ */

async function handleQuranSearch(
  query
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

    if (query) {
      const q =
        normalizeArabic(
          query
        );

      items =
        items.filter(
          item =>
            normalizeArabic(
              item.name ||
              item.sura_name ||
              ""
            ).includes(q)
        );
    }

    return json({
      ok: true,

      type:
        "quran",

      items:
        items
          .slice(0, 114)
          .map(
            item => ({
              id:
                item.id ||
                item.sura_id ||
                item.number,

              title:
                item.name ||
                item.sura_name ||
                "سورة",

              name:
                item.name ||
                item.sura_name ||
                "سورة",

              type:
                "quran"
            })
          ),

      backendVersion:
        BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "QURAN_SEARCH_FAILED",

        items: []
      },
      502
    );
  }
}

/* ============================================================
   ADHKAR
============================================================ */

async function handleAdhkarSearch(
  query
) {
  try {
    const response =
      await fetch(
        "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json",
        {
          headers: {
            "User-Agent":
              "Sa7bi-AI/4.5.0"
          },

          cache:
            "no-store"
        }
      );

    if (!response.ok) {
      throw new Error(
        `ADHKAR_HTTP_${response.status}`
      );
    }

    const data =
      await response.json();

    const groups =
      Array.isArray(data)
        ? data
        : [];

    const result = [];

    const q =
      normalizeArabic(
        query
      );

    for (
      const group of groups
    ) {
      if (!group) {
        continue;
      }

      const category =
        group.category ||
        group.name ||
        "أذكار";

      const array =
        Array.isArray(
          group.array
        )
          ? group.array
          : Array.isArray(
              group.content
            )
            ? group.content
            : [];

      for (
        const item of array
      ) {
        if (!item) {
          continue;
        }

        const value =
          item.content ||
          item.text ||
          item.zekr ||
          "";

        if (!value) {
          continue;
        }

        const haystack =
          normalizeArabic(
            `${category} ${value}`
          );

        if (
          q &&
          !haystack.includes(q)
        ) {
          continue;
        }

        const audio =
          item.audio ||
          item.audioUrl ||
          item.url ||
          "";

        result.push({
          id:
            item.id ||
            `adhkar-${
              result.length + 1
            }`,

          title:
            category,

          text:
            value,

          repeat:
            item.count ||
            item.repeat ||
            1,

          url:
            isHttpUrl(audio)
              ? audio
              : "",

          audio:
            isHttpUrl(audio)
              ? audio
              : "",

          type:
            "adhkar"
        });

        if (
          result.length >=
          80
        ) {
          break;
        }
      }

      if (
        result.length >=
        80
      ) {
        break;
      }
    }

    return json({
      ok: true,

      type:
        "adhkar",

      items:
        result,

      backendVersion:
        BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "ADHKAR_SEARCH_FAILED",

        items: []
      },
      502
    );
  }
}

/* ============================================================
   PODCAST RSS
============================================================ */

function extractPodcastEpisode(
  xml
) {
  const blocks =
    String(xml || "")
      .match(
        /<item\b[\s\S]*?<\/item>/gi
      ) || [];

  for (
    const block of blocks
  ) {
    const titleMatch =
      block.match(
        /<title(?:\s[^>]*)?>([\s\S]*?)<\/title>/i
      );

    const enclosureMatch =
      block.match(
        /<enclosure[^>]+url=["']([^"']+)["']/i
      );

    if (!enclosureMatch) {
      continue;
    }

    const url =
      decodeXml(
        enclosureMatch[1]
      ).trim();

    if (
      !isHttpUrl(url)
    ) {
      continue;
    }

    const title =
      titleMatch
        ? stripHtml(
            decodeXml(
              titleMatch[1]
            )
          )
        : "حلقة بودكاست";

    return {
      url,
      title
    };
  }

  return null;
}

async function resolvePodcastAudio(
  feedUrl
) {
  if (
    !isHttpUrl(feedUrl)
  ) {
    return null;
  }

  try {
    const response =
      await fetch(
        feedUrl,
        {
          headers: {
            "User-Agent":
              "Sa7bi-AI/4.5.0"
          },

          cache:
            "no-store"
        }
      );

    if (!response.ok) {
      return null;
    }

    const xml =
      await response.text();

    return extractPodcastEpisode(
      xml
    );
  } catch {
    return null;
  }
}

/* ============================================================
   APPLE MUSIC / PODCAST
============================================================ */

async function handleAppleSearch(
  query,
  media
) {
  try {
    const params =
      new URLSearchParams();

    params.set(
      "term",
      query ||
        (
          media === "podcast"
            ? "Arabic podcast"
            : "Arabic music"
        )
    );

    params.set(
      "country",
      "eg"
    );

    params.set(
      "media",
      media
    );

    params.set(
      "limit",
      media === "podcast"
        ? "12"
        : "30"
    );

    const data =
      await fetchJson(
        `https://itunes.apple.com/search?${params.toString()}`
      );

    const results =
      Array.isArray(
        data.results
      )
        ? data.results
        : [];

    if (
      media === "podcast"
    ) {
      const items =
        await Promise.all(
          results.map(
            async item => {
              const feedUrl =
                item.feedUrl ||
                "";

              const episode =
                await resolvePodcastAudio(
                  feedUrl
                );

              const audioUrl =
                episode?.url ||
                item.previewUrl ||
                "";

              return {
                id:
                  item.collectionId ||
                  item.trackId ||
                  `podcast-${Date.now()}-${Math.random()}`,

                title:
                  episode?.title ||
                  item.trackName ||
                  item.collectionName ||
                  "بودكاست",

                artist:
                  item.artistName ||
                  "",

                artwork:
                  item.artworkUrl600 ||
                  item.artworkUrl100 ||
                  "",

                previewUrl:
                  item.previewUrl ||
                  "",

                url:
                  isHttpUrl(
                    audioUrl
                  )
                    ? audioUrl
                    : "",

                feedUrl,

                collection:
                  item.collectionName ||
                  "",

                storeUrl:
                  item.collectionViewUrl ||
                  item.trackViewUrl ||
                  "",

                type:
                  "podcast"
              };
            }
          )
        );

      return json({
        ok: true,

        type:
          "podcast",

        items:
          items.filter(
            item =>
              item.title
          ),

        backendVersion:
          BACKEND_VERSION
      });
    }

    const items =
      results.map(
        item => ({
          id:
            item.trackId ||
            item.collectionId ||
            `music-${Date.now()}-${Math.random()}`,

          title:
            item.trackName ||
            item.collectionName ||
            "بدون عنوان",

          artist:
            item.artistName ||
            "",

          artwork:
            item.artworkUrl600 ||
            item.artworkUrl100 ||
            "",

          previewUrl:
            item.previewUrl ||
            "",

          url:
            isHttpUrl(
              item.previewUrl ||
              ""
            )
              ? item.previewUrl
              : "",

          feedUrl:
            item.feedUrl ||
            "",

          collection:
            item.collectionName ||
            "",

          storeUrl:
            item.trackViewUrl ||
            item.collectionViewUrl ||
            "",

          type:
            "music"
        })
      )
      .filter(
        item =>
          item.title
      );

    return json({
      ok: true,

      type:
        "music",

      items,

      backendVersion:
        BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "APPLE_SEARCH_FAILED",

        items: []
      },
      502
    );
  }
}

/* ============================================================
   QURAN CATALOG
============================================================ */

async function handleQuranCatalog() {
  try {
    const [
      recitersData,
      suwarData
    ] =
      await Promise.all([
        fetchJson(
          `${MP3QURAN_BASE}/reciters?language=ar`
        ),

        fetchJson(
          `${MP3QURAN_BASE}/suwar?language=ar`
        )
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

    return json({
      ok: true,

      reciters:
        reciters.map(
          reciter => {
            const moshaf =
              Array.isArray(
                reciter.moshaf
              )
                ? reciter.moshaf
                : [];

            return {
              id:
                reciter.id ||
                reciter.reciter_id ||
                reciter.name,

              name:
                reciter.name ||
                "قارئ",

              letter:
                reciter.letter ||
                "",

              moshaf:
                moshaf
                  .map(
                    (
                      m,
                      index
                    ) => ({
                      id:
                        m.id ||
                        index + 1,

                      name:
                        m.name ||
                        "رواية",

                      server:
                        m.server ||
                        "",

                      surahTotal:
                        m.surah_total ||
                        m.surahTotal ||
                        114,

                      suras:
                        m.suras ||
                        ""
                    })
                  )
                  .filter(
                    m =>
                      isHttpUrl(
                        m.server
                      )
                  )
            };
          }
        )
        .filter(
          reciter =>
            reciter.moshaf
              .length > 0
        ),

      suras:
        suwar
          .map(
            sura => ({
              id:
                sura.id ||
                sura.sura_id,

              name:
                sura.name ||
                sura.sura_name ||
                "سورة"
            })
          )
          .filter(
            sura =>
              Number(sura.id) >= 1 &&
              Number(sura.id) <=
                114
          ),

      backendVersion:
        BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "QURAN_CATALOG_FAILED",

        reciters: [],

        suras: []
      },
      502
    );
  }
}

/* ============================================================
   RADIO COUNTRIES
============================================================ */

async function handleRadioCountries() {
  try {
    const data =
      await fetchJson(
        `${RADIO_BROWSER_BASE}/json/countries?hidebroken=true`
      );

    const countries =
      Array.isArray(data)
        ? data
        : [];

    return json({
      ok: true,

      countries:
        countries
          .filter(Boolean)
          .map(
            item => {
              const code =
                item.iso_3166_1 ||
                item.iso_3166_2 ||
                "";

              return {
                name:
                  item.name ||
                  "",

                code,

                iso:
                  code,

                stationCount:
                  Number(
                    item.stationcount ||
                    0
                  )
              };
            }
          )
          .filter(
            item =>
              item.name &&
              item.code
          )
          .sort(
            (a, b) =>
              b.stationCount -
              a.stationCount
          ),

      backendVersion:
        BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          error?.message ||
          "RADIO_COUNTRIES_FAILED",

        countries: []
      },
      502
    );
  }
}

/* ============================================================
   RADIO STATIONS
============================================================ */

async function handleRadioStations(
  request
) {
  const url =
    new URL(
      request.url
    );

  const country =
    (
      url.searchParams.get(
        "country"
      ) || ""
    ).trim();

  if (!country) {
    return json(
      {
        ok: false,

        error:
          "COUNTRY_REQUIRED",

        stations: []
      },
      400
    );
  }

  try {
    const endpoint =
      `${
