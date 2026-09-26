const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Cache-Control": "no-store",
};

const BACKEND_VERSION = "5.0.1";
const DEFAULT_TEXT_MODEL = "gpt-5.6-luna";
const DEFAULT_IMAGE_MODEL = "gpt-image-2";

const DOWNLOAD_URL =
  "https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/latest/download/sa7bi-ai.apk";

const MAX_BODY_BYTES = 10 * 1024 * 1024;
const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 24000;
const MAX_IMAGE_CHARS = 8 * 1024 * 1024;
const MAX_IMAGES = 4;

const MP3QURAN_BASE =
  "https://www.mp3quran.net/api/v3";

function headers(extra = {}) {
  return {
    ...CORS_HEADERS,
    ...extra,
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
        ...extra,
      }),
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
    .replace(
      /<!\[CDATA\[([\s\S]*?)\]\]>/gi,
      "$1"
    )
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&apos;/gi, "'")
    .replace(
      /&#(\d+);/g,
      (_, n) => {
        try {
          return String.fromCodePoint(
            Number(n)
          );
        } catch {
          return "";
        }
      }
    )
    .replace(
      /&#x([0-9a-f]+);/gi,
      (_, n) => {
        try {
          return String.fromCodePoint(
            parseInt(n, 16)
          );
        } catch {
          return "";
        }
      }
    );
}

function firstMatch(block, patterns) {
  for (const pattern of patterns) {
    const match = block.match(pattern);

    if (match?.[1]) {
      return decodeXml(
        match[1].trim()
      );
    }
  }

  return "";
}

function extractNewsImage(block) {
  return firstMatch(block, [
    /<media:content[^>]+url=["']([^"']+)["']/i,
    /<media:thumbnail[^>]+url=["']([^"']+)["']/i,
    /<enclosure[^>]+url=["']([^"']+)["']/i,
    /<img[^>]+src=["']([^"']+)["']/i,
  ]);
}

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
      typeof item.content === "string"
        ? item.content.trim()
        : "";

    if (!content) {
      continue;
    }

    content = content.substring(
      0,
      MAX_MESSAGE_CHARS
    );

    if (
      total + content.length >
      MAX_TOTAL_CHARS
    ) {
      break;
    }

    result.push({
      role,
      content,
    });

    total += content.length;
  }

  return result;
}

function isValidImageDataUrl(value) {
  return (
    typeof value === "string" &&
    /^data:image\/[a-z0-9.+-]+;base64,/i.test(
      value
    ) &&
    value.length <= MAX_IMAGE_CHARS
  );
}

async function readJsonBody(request) {
  const contentLength = Number(
    request.headers.get(
      "content-length"
    ) || "0"
  );

  if (
    contentLength >
    MAX_BODY_BYTES
  ) {
    throw new Error(
      "BODY_TOO_LARGE"
    );
  }

  const raw =
    await request.text();

  if (
    raw.length >
    MAX_BODY_BYTES
  ) {
    throw new Error(
      "BODY_TOO_LARGE"
    );
  }

  if (!raw.trim()) {
    return {};
  }

  try {
    const data =
      JSON.parse(raw);

    if (
      !data ||
      typeof data !== "object" ||
      Array.isArray(data)
    ) {
      throw new Error();
    }

    return data;
  } catch {
    throw new Error(
      "INVALID_JSON_BODY"
    );
  }
}

function extractOutputText(data) {
  if (
    typeof data?.output_text ===
      "string" &&
    data.output_text.trim()
  ) {
    return data.output_text.trim();
  }

  const parts = [];

  if (
    Array.isArray(data?.output)
  ) {
    for (
      const item of data.output
    ) {
      if (
        !Array.isArray(
          item?.content
        )
      ) {
        continue;
      }

      for (
        const content of
          item.content
      ) {
        if (
          typeof content?.text ===
          "string"
        ) {
          parts.push(
            content.text
          );
        }
      }
    }
  }

  return parts.join("\n").trim();
}

async function callOpenAI(
  env,
  body
) {
  if (!env.OPENAI_API_KEY) {
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
            "application/json",
        },
        body: JSON.stringify(
          body
        ),
      }
    );

  const raw =
    await response.text();

  let data;

  try {
    data = JSON.parse(raw);
  } catch {
    data = { raw };
  }

  if (!response.ok) {
    throw new Error(
      data?.error?.message ||
        data?.message ||
        `OpenAI HTTP ${response.status}`
    );
  }

  return data;
}

function buildImageInput(
  imageDataUrls,
  prompt
) {
  const content = [
    {
      type: "input_text",
      text: prompt,
    },
  ];

  for (
    const imageUrl of
      imageDataUrls.slice(
        0,
        MAX_IMAGES
      )
  ) {
    if (
      isValidImageDataUrl(
        imageUrl
      )
    ) {
      content.push({
        type: "input_image",
        image_url: imageUrl,
      });
    }
  }

  return {
    role: "user",
    content,
  };
}

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

  const imageDataUrls = [];

  const singleImage =
    typeof body.imageDataUrl ===
    "string"
      ? body.imageDataUrl.trim()
      : "";

  if (singleImage) {
    imageDataUrls.push(
      singleImage
    );
  }

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
        typeof item ===
          "string" &&
        item.trim() &&
        !imageDataUrls.includes(
          item.trim()
        )
      ) {
        imageDataUrls.push(
          item.trim()
        );
      }

      if (
        imageDataUrls.length >=
        MAX_IMAGES
      ) {
        break;
      }
    }
  }

  for (
    const image of imageDataUrls
  ) {
    if (
      !isValidImageDataUrl(
        image
      )
    ) {
      return json(
        {
          ok: false,
          error:
            "INVALID_IMAGE",
        },
        400
      );
    }
  }

  if (
    !messages.length &&
    !imageDataUrls.length
  ) {
    return json(
      {
        ok: false,
        error:
          "EMPTY_MESSAGE",
      },
      400
    );
  }

  const serviceTitle =
    typeof body.serviceTitle ===
    "string"
      ? body.serviceTitle
          .trim()
          .substring(0, 200)
      : "صاحبي AI";

  const serviceContext =
    typeof body.serviceContext ===
    "string"
      ? body.serviceContext
          .trim()
          .substring(0, 1500)
      : "";

  const imagePrompt =
    typeof body.imagePrompt ===
        "string" &&
      body.imagePrompt.trim()
      ? body.imagePrompt
          .trim()
          .substring(0, 4000)
      : "حلل الصور المرفقة بدقة، واقرأ أي نص واضح فيها، واشرح الأشياء المهمة الظاهرة.";

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
- إذا كانت المعلومة غير مؤكدة وضّح ذلك.
- إذا أرسل المستخدم صورًا فحلل ما يظهر فعليًا فقط، ولا تخمن تفاصيل غير ظاهرة.
- في الخدمات المتخصصة قدم مساعدة عملية مع الالتزام بالسلامة.
`;

  const input =
    messages.map(
      (message) => ({
        role: message.role,
        content: [
          {
            type:
              "input_text",
            text:
              message.content,
          },
        ],
      })
    );

  if (imageDataUrls.length) {
    input.push(
      buildImageInput(
        imageDataUrls,
        imagePrompt
      )
    );
  }

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
          effort: "none",
        },
        max_output_tokens:
          1200,
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
          "EMPTY_AI_RESPONSE",
      },
      502
    );
  }

  return json({
    ok: true,
    answer,
    model,
    backendVersion:
      BACKEND_VERSION,
  });
}

async function handleImageGeneration(
  request,
  env
) {
  if (!env.OPENAI_API_KEY) {
    return json(
      {
        ok: false,
        error:
          "OPENAI_API_KEY_MISSING",
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
          "EMPTY_PROMPT",
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
            "application/json",
        },
        body: JSON.stringify({
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
            "png",
        }),
      }
    );

  const raw =
    await response.text();

  let data;

  try {
    data = JSON.parse(raw);
  } catch {
    data = {};
  }

  if (!response.ok) {
    return json(
      {
        ok: false,
        error:
          data?.error?.message ||
          `Image API HTTP ${response.status}`,
      },
      response.status
    );
  }

  const item =
    Array.isArray(
      data?.data
    ) &&
    data.data.length
      ? data.data[0]
      : null;

  if (!item) {
    return json(
      {
        ok: false,
        error:
          "NO_IMAGE_RESULT",
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
        BACKEND_VERSION,
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
        BACKEND_VERSION,
    });
  }

  return json(
    {
      ok: false,
      error:
        "IMAGE_FORMAT_NOT_SUPPORTED",
    },
    502
  );
}

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
            "Sa7bi-AI/5.0.1",
          ...(options.headers ||
            {}),
        },
      }
    );

  if (!response.ok) {
    throw new Error(
      `HTTP_${response.status}`
    );
  }

  return response.json();
}

async function handleAudioSearch(
  request
) {
  const url =
    new URL(request.url);

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
      ) || "quran"
    ).toLowerCase();

  if (type === "quran") {
    return handleQuranSearch(
      query
    );
  }

  if (type === "adhkar") {
    return handleAdhkarSearch(
      query
    );
  }

  if (type === "music") {
    return handleAppleSearch(
      query,
      "music"
    );
  }

  if (type === "podcast") {
    return handleAppleSearch(
      query,
      "podcast"
    );
  }

  return json({
    ok: true,
    type,
    items: [],
    backendVersion:
      BACKEND_VERSION,
  });
}

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
      items =
        items.filter(
          (item) =>
            normalizeArabic(
              item?.name ||
                item?.sura_name ||
                ""
            ).includes(
              query
            )
        );
    }

    return json({
      ok: true,
      type: "quran",
      items: items
        .slice(0, 100)
        .map((item) => ({
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
      },
      502
    );
  }
}

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
              "Sa7bi-AI/5.0.1",
          },
        }
      );

    if (!response.ok) {
      throw new Error(
        `ADHKAR_HTTP_${response.status}`
      );
    }

    const data =
      await response.json();

    const result = [];
    const queryNormalized =
      normalizeArabic(query);

    for (
      const group of
        Array.isArray(data)
          ? data
          : []
    ) {
      if (!group) continue;

      const category =
        group.category ||
        group.name ||
        "أذكار";

      const list =
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
        const item of list
      ) {
        if (!item) continue;

        const textValue =
          item.content ||
          item.text ||
          item.zekr ||
          "";

        if (!textValue) {
          continue;
        }

        const haystack =
          normalizeArabic(
            `${category} ${textValue}`
          );

        if (
          queryNormalized &&
          !haystack.includes(
            queryNormalized
          )
        ) {
          continue;
        }

        result.push({
          id:
            item.id ||
            `adhkar-${result.length + 1}`,
          title:
            category,
          text:
            textValue,
          repeat:
            item.count ||
            item.repeat ||
            1,
          type:
            "adhkar",
        });

        if (
          result.length >= 80
        ) {
          break;
        }
      }

      if (
        result.length >= 80
      ) {
        break;
      }
    }

    return json({
      ok: true,
      type: "adhkar",
      items: result,
      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "ADHKAR_SEARCH_FAILED",
        items: [],
      },
      502
    );
  }
}

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
      "30"
    );

    const data =
      await fetchJson(
        `https://itunes.apple.com/search?${params.toString()}`
      );

    const results =
      Array.isArray(
        data?.results
      )
        ? data.results
        : [];

    const items =
      results.map(
        (item) => ({
          id:
            item.trackId ||
            item.collectionId ||
            `${media}-${item.wrapperType || "item"}-${item.artistName || "0"}`,
          title:
            item.trackName ||
            item.collectionName ||
            item.trackCensoredName ||
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
          storeUrl:
            item.trackViewUrl ||
            item.collectionViewUrl ||
            "",
          feedUrl:
            item.feedUrl ||
            "",
          collection:
            item.collectionName ||
            "",
          type:
            media,
        })
      );

    return json({
      ok: true,
      type: media,
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
          "APPLE_SEARCH_FAILED",
        items: [],
      },
      502
    );
  }
}

async function handleQuranCatalog() {
  try {
    const [
      recitersData,
      suwarData,
    ] =
      await Promise.all([
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
            reciter.id ||
            reciter.reciter_id ||
            reciter.name ||
            "",
          name:
            reciter.name ||
            "قارئ",
          moshaf:
            (
              Array.isArray(
                reciter.moshaf
              )
                ? reciter.moshaf
                : []
            ).map(
              (m, index) => ({
                id:
                  m.id ||
                  `${reciter.id || "reciter"}-${index + 1}`,
                name:
                  m.name ||
                  "رواية",
                server:
                  m.server ||
                  m.url ||
                  "",
                surahTotal:
                  Number(
                    m.surah_total ||
                      m.surahTotal ||
                      114
                  ),
                suras:
                  m.suras ||
                  "",
              })
            ),
        })
      );

    return json({
      ok: true,
      reciters:
        output,
      suras:
        suwar
          .map(
            (sura) => ({
              id:
                Number(
                  sura.id ||
                    sura.sura_id ||
                    sura.number ||
                    0
                ),
              name:
                sura.name ||
                sura.sura_name ||
                "سورة",
            })
          )
          .filter(
            (sura) =>
              sura.id >= 1 &&
              sura.id <= 114
          ),
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
      },
      502
    );
  }
}

async function handleRadioCountries() {
  try {
    const data =
      await fetchJson(
        "https://de1.api.radio-browser.info/json/countries?hidebroken=true"
      );

    const countries =
      Array.isArray(data)
        ? data
        : [];

    return json({
      ok: true,
      countries:
        countries
          .map(
            (item) => ({
              name:
                item?.name ||
                "",
              iso:
                item?.iso_3166_1 ||
                item?.iso_3166_2 ||
                "",
              stationCount:
                Number(
                  item?.stationcount ||
                    0
                ),
            })
          )
          .filter(
            (item) =>
              item.name &&
              item.iso
          )
          .sort(
            (a, b) =>
              a.name.localeCompare(
                b.name,
                "ar"
              )
          ),
      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "RADIO_COUNTRIES_FAILED",
        countries: [],
      },
      502
    );
  }
}

async function handleRadioStations(
  request
) {
  const url =
    new URL(request.url);

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
        stations: [],
      },
      400
    );
  }

  try {
    const endpoint =
      `https://de1.api.radio-browser.info/json/stations/bycountrycodeexact/${encodeURIComponent(country)}?hidebroken=true&order=clickcount&reverse=true&limit=100`;

    const data =
      await fetchJson(
        endpoint
      );

    const stations =
      Array.isArray(data)
        ? data
        : [];

    return json({
      ok: true,
      country,
      stations:
        stations
          .filter(
            (station) =>
              station &&
              (
                station.url_resolved ||
                station.url
              )
          )
          .map(
            (station) => ({
              id:
                station.stationuuid ||
                station.name ||
                "",
              name:
                station.name ||
                "محطة إذاعية",
              streamUrl:
                station.url_resolved ||
                station.url ||
                "",
              homepage:
                station.homepage ||
                "",
              favicon:
                station.favicon ||
                "",
              tags:
                station.tags ||
                "",
              codec:
                station.codec ||
                "",
              bitrate:
                Number(
                  station.bitrate ||
                    0
                ),
            })
          ),
      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "RADIO_STATIONS_FAILED",
        stations: [],
      },
      502
    );
  }
}

async function handleShorts() {
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
          (item, index) => ({
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
            item.title ||
            item.thumbnail ||
            item.videoUrl
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
      },
      502
    );
  }
}

function parseRssItems(xml) {
  const items = [];

  const blocks =
    String(xml || "")
      .match(
        /<item\b[\s\S]*?<\/item>/gi
      ) || [];

  for (
    const block of blocks
  ) {
    const title =
      stripHtml(
        firstMatch(
          block,
          [
            /<title[^>]*>([\s\S]*?)<\/title>/i,
          ]
        )
      );

    const link =
      firstMatch(
        block,
        [
          /<link[^>]*>([\s\S]*?)<\/link>/i,
        ]
      );

    const pubDate =
      firstMatch(
        block,
        [
          /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i,
          /<published[^>]*>([\s\S]*?)<\/published>/i,
        ]
      );

    const description =
      firstMatch(
        block,
        [
          /<description[^>]*>([\s\S]*?)<\/description>/i,
          /<summary[^>]*>([\s\S]*?)<\/summary>/i,
        ]
      );

    const source =
      firstMatch(
        block,
        [
          /<source[^>]*>([\s\S]*?)<\/source>/i,
        ]
      ) || "Google News";

    const image =
      extractNewsImage(
        block
      );

    if (!title || !link) {
      continue;
    }

    items.push({
      id: link,
      title,
      link,
      pubDate,
      description:
        stripHtml(
          description
        ),
      image,
      imageUrl: image,
      source,
    });
  }

  return items;
}

async function fetchGoogleNews() {
  const feeds = [
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",
    "https://news.google.com/rss/search?q=مصر&hl=ar&gl=EG&ceid=EG:ar",
    "https://news.google.com/rss/search?q=تكنولوجيا&hl=ar&gl=EG&ceid=EG:ar",
  ];

  const all = [];
  const seen =
    new Set();

  for (
    const feed of feeds
  ) {
    try {
      const response =
        await fetch(
          feed,
          {
            headers: {
              "User-Agent":
                "Mozilla/5.0 Sa7bi-AI/5.0.1",
            },
          }
        );

      if (!response.ok) {
        continue;
      }

      const items =
        parseRssItems(
          await response.text()
        );

      for (
        const item of items
      ) {
        if (
          seen.has(item.link)
        ) {
          continue;
        }

        seen.add(item.link);
        all.push(item);

        if (
          all.length >= 40
        ) {
          break;
        }
      }

      if (
        all.length >= 40
      ) {
        break;
      }
    } catch (_) {
      // Try the next feed.
    }
  }

  return all;
}

async function handleNews() {
  try {
    const items =
      await fetchGoogleNews();

    return json({
      ok: true,
      items:
        items.slice(0, 40),
      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "NEWS_FAILED",
        items: [],
      },
      502
    );
  }
}

function handleHealth() {
  return json({
    ok: true,
    status: "online",
    app: "Sa7bi AI",
    backendVersion:
      BACKEND_VERSION,
  });
}

function handleRoot() {
  return json({
    ok: true,
    app: "Sa7bi AI",
    backendVersion:
      BACKEND_VERSION,
    status: "online",

    features: {
      chat: true,
      imageAnalysis: true,
      multiImageVision: true,
      videoFrameAnalysis: true,
      imageGeneration: true,
      news: true,
      audio: true,
      radio: true,
      shorts: true,
    },

    endpoints: {
      chat: "/v1/chat",
      image: "/v1/image",
      news: "/v1/news",
      audio:
        "/v1/audio/search-v4",
      quran:
        "/v1/audio/quran",
      radioCountries:
        "/v1/radio/countries",
      radioStations:
        "/v1/radio/stations?country=EG",
      shorts:
        "/v1/shorts",
      download:
        "/download",
      health:
        "/health",
    },
  });
}

function handleDownload() {
  return Response.redirect(
    DOWNLOAD_URL,
    302
  );
}

export default {
  async fetch(
    request,
    env
  ) {
    try {
      if (
        request.method ===
        "OPTIONS"
      ) {
        return new Response(
          null,
          {
            status: 204,
            headers:
              headers(),
          }
        );
      }

      const url =
        new URL(request.url);

      const path =
        url.pathname.replace(
          /\/+$/,
          ""
        ) || "/";

      if (
        request.method ===
          "GET" &&
        path === "/"
      ) {
        return handleRoot();
      }

      if (
        request.method ===
          "GET" &&
        path === "/health"
      ) {
        return handleHealth();
      }

      if (
        request.method ===
          "GET" &&
        path === "/download"
      ) {
        return handleDownload();
      }

      if (
        request.method ===
          "GET" &&
        path === "/v1/news"
      ) {
        return handleNews();
      }

      if (
        request.method ===
          "GET" &&
        (
          path ===
            "/v1/audio/search" ||
          path ===
            "/v1/audio/search-v4"
        )
      ) {
        return handleAudioSearch(
          request
        );
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/audio/quran"
      ) {
        return handleQuranCatalog();
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/countries"
      ) {
        return handleRadioCountries();
      }

      if (
        request.method ===
          "GET" &&
        path ===
          "/v1/radio/stations"
      ) {
        return handleRadioStations(
          request
        );
      }

      if (
        request.method ===
          "GET" &&
        path === "/v1/shorts"
      ) {
        return handleShorts();
      }

      if (
        request.method ===
          "POST" &&
        path === "/v1/chat"
      ) {
        return handleChat(
          request,
          env
        );
      }

      if (
        request.method ===
          "POST" &&
        path === "/v1/image"
      ) {
        return handleImageGeneration(
          request,
          env
        );
      }

      return json(
        {
          ok: false,
          error:
            "NOT_FOUND",
          path,
        },
        404
      );
    } catch (error) {
      const message =
        error?.message ||
        "INTERNAL_ERROR";

      if (
        message ===
        "BODY_TOO_LARGE"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          413
        );
      }

      if (
        message ===
        "INVALID_JSON_BODY"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          400
        );
      }

      if (
        message ===
        "OPENAI_API_KEY_MISSING"
      ) {
        return json(
          {
            ok: false,
            error: message,
          },
          500
        );
      }

      return json(
        {
          ok: false,
          error: message,
        },
        500
      );
    }
  },
};
