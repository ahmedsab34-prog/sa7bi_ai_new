const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store"
};

const BACKEND_VERSION = "4.0.0";

const DEFAULT_TEXT_MODEL = "gpt-5.6-luna";
const DEFAULT_IMAGE_MODEL = "gpt-image-2";

const DOWNLOAD_URL =
  "https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/latest/download/sa7bi-ai.apk";

const MAX_BODY_BYTES = 8 * 1024 * 1024;
const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 24000;
const MAX_IMAGE_CHARS = 7 * 1024 * 1024;

const MP3QURAN_BASE = "https://www.mp3quran.net/api/v3";

function headers(extra = {}) {
  return {
    ...CORS_HEADERS,
    ...extra
  };
}

function json(data, status = 200, extra = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: headers({
      "Content-Type": "application/json; charset=utf-8",
      ...extra
    })
  });
}

function text(data, status = 200, extra = {}) {
  return new Response(data, {
    status,
    headers: headers({
      "Content-Type": "text/plain; charset=utf-8",
      ...extra
    })
  });
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
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
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
        return String.fromCodePoint(Number(n));
      } catch {
        return "";
      }
    });
}

function extractNewsImage(description) {
  const value = String(description || "");

  const match =
    value.match(/<img[^>]+src=["']([^"']+)["']/i) ||
    value.match(/<img[^>]+url=["']([^"']+)["']/i);

  return match ? decodeXml(match[1]) : "";
}

function cleanMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  const result = [];
  let total = 0;

  for (const item of messages.slice(-MAX_MESSAGES)) {
    if (!item || typeof item !== "object") {
      continue;
    }

    const role =
      item.role === "assistant" ? "assistant" : "user";

    let content = String(item.content || "").trim();

    if (!content) {
      continue;
    }

    if (content.length > MAX_MESSAGE_CHARS) {
      content = content.substring(0, MAX_MESSAGE_CHARS);
    }

    if (total + content.length > MAX_TOTAL_CHARS) {
      break;
    }

    result.push({
      role,
      content
    });

    total += content.length;
  }

  return result;
}

function isValidImageDataUrl(value) {
  if (typeof value !== "string") {
    return false;
  }

  if (!value.startsWith("data:image/")) {
    return false;
  }

  return value.length <= MAX_IMAGE_CHARS;
}

async function readJsonBody(request) {
  const contentLength = Number(
    request.headers.get("content-length") || "0"
  );

  if (contentLength > MAX_BODY_BYTES) {
    throw new Error("BODY_TOO_LARGE");
  }

  const raw = await request.text();

  if (raw.length > MAX_BODY_BYTES) {
    throw new Error("BODY_TOO_LARGE");
  }

  if (!raw.trim()) {
    return {};
  }

  return JSON.parse(raw);
}

function extractOutputText(data) {
  if (!data) {
    return "";
  }

  if (typeof data.output_text === "string") {
    return data.output_text.trim();
  }

  if (Array.isArray(data.output)) {
    const parts = [];

    for (const item of data.output) {
      if (!item) {
        continue;
      }

      if (Array.isArray(item.content)) {
        for (const content of item.content) {
          if (content && typeof content.text === "string") {
            parts.push(content.text);
          }
        }
      }
    }

    if (parts.length) {
      return parts.join("\n").trim();
    }
  }

  return "";
}

async function callOpenAI(env, body) {
  if (!env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY_MISSING");
  }

  const response = await fetch(
    "https://api.openai.com/v1/responses",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    }
  );

  const raw = await response.text();

  let data;

  try {
    data = JSON.parse(raw);
  } catch {
    data = {
      raw
    };
  }

  if (!response.ok) {
    const message =
      data?.error?.message ||
      data?.message ||
      "OpenAI request failed";

    throw new Error(message);
  }

  return data;
}

async function handleChat(request, env) {
  const body = await readJsonBody(request);

  const messages = cleanMessages(body.messages);

  const imageDataUrl =
    typeof body.imageDataUrl === "string"
      ? body.imageDataUrl
      : "";

  if (!messages.length && !imageDataUrl) {
    return json(
      {
        ok: false,
        error: "EMPTY_MESSAGE"
      },
      400
    );
  }

  if (
    imageDataUrl &&
    !isValidImageDataUrl(imageDataUrl)
  ) {
    return json(
      {
        ok: false,
        error: "INVALID_IMAGE"
      },
      400
    );
  }

  const serviceTitle =
    typeof body.serviceTitle === "string"
      ? body.serviceTitle.substring(0, 200)
      : "صحبي AI";

  const serviceContext =
    typeof body.serviceContext === "string"
      ? body.serviceContext.substring(0, 1000)
      : "";

  const input = [];

  for (const message of messages) {
    input.push({
      role: message.role,
      content: [
        {
          type: "input_text",
          text: message.content
        }
      ]
    });
  }

  if (imageDataUrl) {
    input.push({
      role: "user",
      content: [
        {
          type: "input_text",
          text:
            "حلل الصورة المرفقة بدقة. صف ما يظهر فيها، واقرأ النصوص إن وجدت، وأجب بالعربية بشكل عملي ومفيد."
        },
        {
          type: "input_image",
          image_url: imageDataUrl
        }
      ]
    });
  }

  const systemInstruction = `
أنت "صحبي AI"، مساعد عربي ودود وعملي.

الخدمة الحالية:
${serviceTitle}

سياق الخدمة:
${serviceContext}

قواعد مهمة:
- أجب باللغة العربية ما لم يطلب المستخدم لغة أخرى.
- استخدم اللهجة المصرية عندما تكون مناسبة.
- كن واضحًا ومباشرًا.
- لا تكرر كلام المستخدم بلا فائدة.
- لا تدّعي أنك نفذت شيئًا لم تنفذه.
- إذا كانت المعلومة غير مؤكدة، وضّح ذلك.
- في الخدمات المتخصصة، تصرف كمساعد متخصص في المجال مع الحفاظ على حدود السلامة.
- إذا أرسل المستخدم صورة، حللها بناءً على محتواها الفعلي.
`;

  const model =
    env.OPENAI_MODEL ||
    DEFAULT_TEXT_MODEL;

  const data = await callOpenAI(env, {
    model,
    instructions: systemInstruction,
    input,
    reasoning: {
      effort: "none"
    },
    max_output_tokens: 900
  });

  const answer = extractOutputText(data);

  if (!answer) {
    return json(
      {
        ok: false,
        error: "EMPTY_AI_RESPONSE"
      },
      502
    );
  }

  return json({
    ok: true,
    answer,
    model,
    backendVersion: BACKEND_VERSION
  });
}

async function handleImageGeneration(request, env) {
  if (!env.OPENAI_API_KEY) {
    return json(
      {
        ok: false,
        error: "OPENAI_API_KEY_MISSING"
      },
      500
    );
  }

  const body = await readJsonBody(request);

  const prompt =
    typeof body.prompt === "string"
      ? body.prompt.trim()
      : "";

  if (!prompt) {
    return json(
      {
        ok: false,
        error: "EMPTY_PROMPT"
      },
      400
    );
  }

  const safePrompt = prompt.substring(0, 6000);

  const model =
    env.OPENAI_IMAGE_MODEL ||
    DEFAULT_IMAGE_MODEL;

  const response = await fetch(
    "https://api.openai.com/v1/images/generations",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model,
        prompt: safePrompt,
        size: "1024x1024",
        quality: "low",
        output_format: "png"
      })
    }
  );

  const raw = await response.text();

  let data;

  try {
    data = JSON.parse(raw);
  } catch {
    data = {};
  }

  if (!response.ok) {
    const message =
      data?.error?.message ||
      "Image generation failed";

    return json(
      {
        ok: false,
        error: message
      },
      response.status
    );
  }

  const item =
    Array.isArray(data.data) &&
    data.data.length
      ? data.data[0]
      : null;

  if (!item) {
    return json(
      {
        ok: false,
        error: "NO_IMAGE_RESULT"
      },
      502
    );
  }

  if (item.b64_json) {
    return json({
      ok: true,
      imageDataUrl:
        `data:image/png;base64,${item.b64_json}`,
      model,
      backendVersion: BACKEND_VERSION
    });
  }

  if (item.url) {
    return json({
      ok: true,
      imageUrl: item.url,
      model,
      backendVersion: BACKEND_VERSION
    });
  }

  return json(
    {
      ok: false,
      error: "IMAGE_FORMAT_NOT_SUPPORTED"
    },
    502
  );
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      "User-Agent": "Sa7bi-AI/4.0",
      ...(options.headers || {})
    }
  });

  if (!response.ok) {
    throw new Error(
      `HTTP_${response.status}`
    );
  }

  return await response.json();
}

async function handleAudioSearch(request, env) {
  const url = new URL(request.url);

  const query =
    normalizeArabic(
      url.searchParams.get("q") || ""
    );

  const type =
    (
      url.searchParams.get("type") ||
      "quran"
    ).toLowerCase();

  if (type === "quran") {
    return await handleQuranSearch(query);
  }

  if (type === "adhkar") {
    return await handleAdhkarSearch(query);
  }

  if (type === "music") {
    return await handleAppleSearch(
      query,
      "music"
    );
  }

  if (type === "podcast") {
    return await handleAppleSearch(
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

async function handleQuranSearch(query) {
  try {
    const suwar = await fetchJson(
      `${MP3QURAN_BASE}/suwar?language=ar`
    );

    let items = Array.isArray(suwar)
      ? suwar
      : [];

    if (query) {
      const normalizedQuery =
        normalizeArabic(query);

      items = items.filter((item) => {
        const name =
          normalizeArabic(
            item.name ||
            item.sura_name ||
            ""
          );

        return name.includes(
          normalizedQuery
        );
      });
    }

    return json({
      ok: true,
      type: "quran",
      items: items.slice(0, 100).map((item) => ({
        id:
          item.id ||
          item.sura_id ||
          item.number,
        name:
          item.name ||
          item.sura_name ||
          "سورة",
        type: "quran"
      })),
      backendVersion: BACKEND_VERSION
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

async function handleAdhkarSearch(query) {
  try {
    const response = await fetch(
      "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json",
      {
        headers: {
          "User-Agent": "Sa7bi-AI/4.0"
        }
      }
    );

    if (!response.ok) {
      throw new Error(
        `ADHKAR_HTTP_${response.status}`
      );
    }

    const data = await response.json();

    let groups = Array.isArray(data)
      ? data
      : [];

    const result = [];

    for (const group of groups) {
      if (!group) {
        continue;
      }

      const category =
        group.category ||
        group.name ||
        "أذكار";

      const array =
        Array.isArray(group.array)
          ? group.array
          : Array.isArray(group.content)
            ? group.content
            : [];

      for (const item of array) {
        if (!item) {
          continue;
        }

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
          query &&
          !haystack.includes(
            normalizeArabic(query)
          )
        ) {
          continue;
        }

        result.push({
          id:
            item.id ||
            `${category}-${result.length + 1}`,
          title: category,
          text: textValue,
          repeat:
            item.count ||
            item.repeat ||
            1,
          type: "adhkar"
        });

        if (result.length >= 80) {
          break;
        }
      }

      if (result.length >= 80) {
        break;
      }
    }

    return json({
      ok: true,
      type: "adhkar",
      items: result,
      backendVersion: BACKEND_VERSION
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

async function handleAppleSearch(
  query,
  media
) {
  try {
    const params = new URLSearchParams();

    params.set(
      "term",
      query || (
        media === "podcast"
          ? "Arabic podcast"
          : "Arabic music"
      )
    );

    params.set("country", "eg");
    params.set("media", media);
    params.set("limit", "30");

    const data = await fetchJson(
      `https://itunes.apple.com/search?${params.toString()}`
    );

    const results =
      Array.isArray(data.results)
        ? data.results
        : [];

    const items = results.map((item) => ({
      id:
        item.trackId ||
        item.collectionId ||
        `${media}-${Math.random()}`,
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
      feedUrl:
        item.feedUrl ||
        "",
      collection:
        item.collectionName ||
        "",
      type: media
    }));

    return json({
      ok: true,
      type: media,
      items,
      backendVersion: BACKEND_VERSION
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

async function handleQuranCatalog() {
  try {
    const [recitersData, suwarData] =
      await Promise.all([
        fetchJson(
          `${MP3QURAN_BASE}/reciters?language=ar`
        ),
        fetchJson(
          `${MP3QURAN_BASE}/suwar?language=ar`
        )
      ]);

    const reciters =
      Array.isArray(recitersData)
        ? recitersData
        : [];

    const suwar =
      Array.isArray(suwarData)
        ? suwarData
        : [];

    const output = reciters.map((reciter) => {
      const moshaf =
        Array.isArray(reciter.moshaf)
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
        moshaf: moshaf.map((m) => ({
          id:
            m.id ||
            moshaf.indexOf(m) + 1,
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
        }))
      };
    });

    return json({
      ok: true,
      reciters: output,
      suras: suwar.map((sura) => ({
        id:
          sura.id ||
          sura.sura_id,
        name:
          sura.name ||
          sura.sura_name ||
          "سورة"
      })),
      backendVersion: BACKEND_VERSION
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

async function handleRadioCountries() {
  try {
    const data = await fetchJson(
      "https://de1.api.radio-browser.info/json/countries?hidebroken=true"
    );

    const countries =
      Array.isArray(data)
        ? data
        : [];

    return json({
      ok: true,
      countries: countries
        .filter((item) => item)
        .map((item) => ({
          name:
            item.name ||
            "",
          iso:
            item.iso_3166_1 ||
            item.iso_3166_2 ||
            "",
          stationCount:
            Number(
              item.stationcount || 0
            )
        }))
        .filter(
          (item) =>
            item.name &&
            item.iso
        )
        .sort((a, b) =>
          a.name.localeCompare(
            b.name,
            "ar"
          )
        ),
      backendVersion: BACKEND_VERSION
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

async function handleRadioStations(
  request
) {
  const url = new URL(request.url);

  const country =
    url.searchParams.get("country") ||
    "";

  if (!country) {
    return json(
      {
        ok: false,
        error: "COUNTRY_REQUIRED",
        stations: []
      },
      400
    );
  }

  try {
    const endpoint =
      "https://de1.api.radio-browser.info/json/stations/bycountrycodeexact/" +
      encodeURIComponent(country) +
      "?hidebroken=true&order=clickcount&reverse=true&limit=100";

    const data =
      await fetchJson(endpoint);

    const stations =
      Array.isArray(data)
        ? data
        : [];

    return json({
      ok: true,
      country,
      stations: stations
        .filter(
          (station) =>
            station &&
            (
              station.url_resolved ||
              station.url
            )
        )
        .map((station) => ({
          id:
            station.stationuuid ||
            station.stationId ||
            station.name,
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
              station.bitrate || 0
            )
        })),
      backendVersion: BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "RADIO_STATIONS_FAILED",
        stations: []
      },
      502
    );
  }
}

async function handleShorts() {
  try {
    const data = await fetchJson(
      `${MP3QURAN_BASE}/videos?language=ar`
    );

    const raw =
      Array.isArray(data)
        ? data
        : Array.isArray(data?.videos)
          ? data.videos
          : [];

    const items = raw.map((item, index) => ({
      id:
        item.id ||
        item.video_id ||
        `short-${index}`,
      title:
        item.title ||
        item.name ||
        "فيديو",
      description:
        item.description ||
        "",
      thumbnail:
        item.thumbnail ||
        item.image ||
        item.cover ||
        "",
      videoUrl:
        item.video_url ||
        item.url ||
        item.video ||
        "",
      source:
        item.source ||
        "MP3Quran",
      type: "short"
    }));

    return json({
      ok: true,
      items,
      backendVersion: BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "SHORTS_FAILED",
        items: []
      },
      502
    );
  }
}

function parseRssItems(xml) {
  const items = [];

  const matches =
    String(xml || "").match(
      /<item\b[\s\S]*?<\/item>/gi
    ) || [];

  for (const block of matches) {
    const getTag = (tag) => {
      const regex = new RegExp(
        `<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`,
        "i"
      );

      const match =
        block.match(regex);

      return match
        ? decodeXml(
            match[1]
              .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
              .trim()
          )
        : "";
    };

    const title =
      stripHtml(
        getTag("title")
      );

    const link =
      getTag("link");

    const pubDate =
      getTag("pubDate");

    const description =
      getTag("description");

    const image =
      extractNewsImage(
        description
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
        stripHtml(description),
      image,
      source:
        "Google News"
    });
  }

  return items;
}

async function fetchGoogleNews() {
  const feeds = [
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar",
    "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"
  ];

  for (const feed of feeds) {
    try {
      const response =
        await fetch(feed, {
          headers: {
            "User-Agent":
              "Mozilla/5.0 Sa7bi-AI/4.0"
          }
        });

      if (!response.ok) {
        continue;
      }

      const xml =
        await response.text();

      const items =
        parseRssItems(xml);

      if (items.length) {
        return items;
      }
    } catch {
      // Try next feed.
    }
  }

  return [];
}

async function handleNews() {
  try {
    const items =
      await fetchGoogleNews();

    return json({
      ok: true,
      items: items.slice(0, 40),
      backendVersion: BACKEND_VERSION
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error?.message ||
          "NEWS_FAILED",
        items: []
      },
      502
    );
  }
}

async function handleRoot() {
  return json({
    ok: true,
    app: "Sa7bi AI",
    backendVersion: BACKEND_VERSION,
    status: "online",
    endpoints: {
      chat: "/v1/chat",
      image: "/v1/image",
      news: "/v1/news",
      audio: "/v1/audio/search-v4",
      quran: "/v1/audio/quran",
      radioCountries:
        "/v1/radio/countries",
      radioStations:
        "/v1/radio/stations?country=EG",
      shorts: "/v1/shorts",
      download: "/download"
    }
  });
}

async function handleDownload() {
  return Response.redirect(
    DOWNLOAD_URL,
    302
  );
}

export default {
  async fetch(request, env) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(
          null,
          {
            status: 204,
            headers: headers()
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
        request.method === "GET" &&
        path === "/"
      ) {
        return handleRoot();
      }

      if (
        request.method === "GET" &&
        path === "/download"
      ) {
        return handleDownload();
      }

      if (
        request.method === "GET" &&
        path === "/v1/news"
      ) {
        return handleNews();
      }

      if (
        request.method === "GET" &&
        (
          path === "/v1/audio/search" ||
          path === "/v1/audio/search-v4"
        )
      ) {
        return handleAudioSearch(
          request,
          env
        );
      }

      if (
        request.method === "GET" &&
        path === "/v1/audio/quran"
      ) {
        return handleQuranCatalog();
      }

      if (
        request.method === "GET" &&
        path === "/v1/radio/countries"
      ) {
        return handleRadioCountries();
      }

      if (
        request.method === "GET" &&
        path === "/v1/radio/stations"
      ) {
        return handleRadioStations(
          request
        );
      }

      if (
        request.method === "GET" &&
        path === "/v1/shorts"
      ) {
        return handleShorts();
      }

      if (
        request.method === "POST" &&
        path === "/v1/chat"
      ) {
        return await handleChat(
          request,
          env
        );
      }

      if (
        request.method === "POST" &&
        path === "/v1/image"
      ) {
        return await handleImageGeneration(
          request,
          env
        );
      }

      return json(
        {
          ok: false,
          error: "NOT_FOUND",
          path
        },
        404
      );
    } catch (error) {
      const message =
        error?.message ||
        "INTERNAL_ERROR";

      if (
        message === "BODY_TOO_LARGE"
      ) {
        return json(
          {
            ok: false,
            error: message
          },
          413
        );
      }

      if (
        message === "OPENAI_API_KEY_MISSING"
      ) {
        return json(
          {
            ok: false,
            error: message
          },
          500
        );
      }

      return json(
        {
          ok: false,
          error: message
        },
        500
      );
    }
  }
};
