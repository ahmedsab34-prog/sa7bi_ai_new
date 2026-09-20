const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store"
};

const BACKEND_VERSION = "3.2.0";

const DEFAULT_TEXT_MODEL = "gpt-5.6-luna";
const DEFAULT_IMAGE_MODEL = "gpt-image-2";

/*
 * Permanent APK distribution link.
 *
 * The app itself always uses:
 * https://sa7bi-ai-new.ahmedsab34.workers.dev/download
 *
 * This Worker redirects to the latest GitHub Release asset.
 *
 * IMPORTANT:
 * Every future release should contain an APK asset with this exact name:
 * sa7bi-ai.apk
 *
 * Therefore the app/Worker does not need to be changed for every new APK.
 */
const APK_DOWNLOAD_URL =
  "https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/latest/download/sa7bi-ai.apk";

const MAX_BODY_BYTES = 8 * 1024 * 1024;
const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 24000;
const MAX_IMAGE_CHARS = 7 * 1024 * 1024;

function json(data, status = 200, extraHeaders = {}) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": "application/json; charset=utf-8",
        ...extraHeaders
      }
    }
  );
}

function cleanMessages(messages) {
  if (!Array.isArray(messages)) {
    return null;
  }

  if (
    messages.length === 0 ||
    messages.length > MAX_MESSAGES
  ) {
    return null;
  }

  let total = 0;
  const result = [];

  for (const message of messages) {
    const role = message?.role?.toString();
    const content = message?.content?.toString().trim();

    if (
      role !== "user" &&
      role !== "assistant"
    ) {
      return null;
    }

    if (!content) {
      return null;
    }

    if (content.length > MAX_MESSAGE_CHARS) {
      return null;
    }

    total += content.length;

    if (total > MAX_TOTAL_CHARS) {
      return null;
    }

    result.push({
      role,
      content
    });
  }

  return result;
}

function isValidImageDataUrl(value) {
  if (typeof value !== "string") {
    return false;
  }

  if (value.length > MAX_IMAGE_CHARS) {
    return false;
  }

  return /^data:image\/(jpeg|jpg|png|webp);base64,/i.test(
    value
  );
}

function extractOutputText(data) {
  if (
    typeof data?.output_text === "string" &&
    data.output_text.trim()
  ) {
    return data.output_text.trim();
  }

  const output = Array.isArray(data?.output)
    ? data.output
    : [];

  const parts = [];

  for (const item of output) {
    const content = Array.isArray(item?.content)
      ? item.content
      : [];

    for (const part of content) {
      if (
        typeof part?.text === "string" &&
        part.text.trim()
      ) {
        parts.push(part.text.trim());
      }
    }
  }

  return parts.join("\n").trim();
}

function normalizeArabic(value) {
  return value
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[إأآا]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/ؤ/g, "و")
    .replace(/ئ/g, "ي")
    .replace(/ـ/g, "")
    .replace(/\s+/g, " ");
}

function decodeXml(value) {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'");
}

function stripHtml(value) {
  return value
    .replace(/<[^>]*>/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function extractNewsImage(itemXml) {
  const content = itemXml.match(
    /<media:content[^>]+url=["']([^"']+)["'][^>]*>/i
  );

  if (content?.[1]) {
    return decodeXml(content[1]);
  }

  const thumbnail = itemXml.match(
    /<media:thumbnail[^>]+url=["']([^"']+)["'][^>]*>/i
  );

  if (thumbnail?.[1]) {
    return decodeXml(thumbnail[1]);
  }

  const enclosure = itemXml.match(
    /<enclosure[^>]+url=["']([^"']+)["'][^>]*>/i
  );

  if (enclosure?.[1]) {
    return decodeXml(enclosure[1]);
  }

  return "";
}

async function readJsonBody(request) {
  const contentLength =
    Number(request.headers.get("content-length") || "0");

  if (
    Number.isFinite(contentLength) &&
    contentLength > MAX_BODY_BYTES
  ) {
    throw new Error("Request is too large");
  }

  const raw = await request.text();

  if (raw.length > MAX_BODY_BYTES) {
    throw new Error("Request is too large");
  }

  if (!raw.trim()) {
    throw new Error("Empty request");
  }

  return JSON.parse(raw);
}

async function callOpenAI(env, body) {
  return fetch(
    "https://api.openai.com/v1/responses",
    {
      method: "POST",
      headers: {
        "Authorization":
          `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    }
  );
}

async function handleChat(request, env) {
  let body;

  try {
    body = await readJsonBody(request);
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error.message === "Request is too large"
            ? "Request is too large"
            : "Invalid JSON"
      },
      error.message === "Request is too large"
        ? 413
        : 400
    );
  }

  const messages =
    cleanMessages(body?.messages);

  if (!messages) {
    return json(
      {
        ok: false,
        error: "Invalid messages."
      },
      400
    );
  }

  const image = body?.image;

  if (
    image !== undefined &&
    !isValidImageDataUrl(image)
  ) {
    return json(
      {
        ok: false,
        error: "Invalid or oversized image."
      },
      400
    );
  }

  const model =
    env.OPENAI_MODEL ||
    DEFAULT_TEXT_MODEL;

  let input = messages;

  if (image) {
    const lastMessage =
      messages[messages.length - 1];

    const previousMessages =
      messages.slice(0, -1);

    input = [
      ...previousMessages.map(
        (message) => ({
          role: message.role,
          content: [
            {
              type: "input_text",
              text: message.content
            }
          ]
        })
      ),
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: lastMessage.content
          },
          {
            type: "input_image",
            image_url: image,
            detail: "auto"
          }
        ]
      }
    ];
  }

  try {
    const response =
      await callOpenAI(
        env,
        {
          model,
          instructions: [
            "أنت صاحبي AI.",
            "أنت مساعد عربي ودود وذكي وقريب من المستخدم.",
            "استخدم العربية افتراضيًا.",
            "كن واضحًا ومباشرًا.",
            "لا تطل الرد بدون داعٍ.",
            "لا تدّعي أنك نفذت شيئًا لم تنفذه.",
            "لا تخترع معلومات.",
            "إذا كانت المعلومة غير مؤكدة وضح ذلك.",
            "عند تحليل صورة صف فقط ما يظهر بوضوح.",
            "لا تستنتج معلومات شخصية غير ظاهرة."
          ].join(" "),
          reasoning: {
            effort: "none"
          },
          max_output_tokens: 900,
          input
        }
      );

    if (!response.ok) {
      let details = null;

      try {
        details = await response.json();
      } catch (_) {}

      console.error(
        "OpenAI request failed",
        {
          status: response.status,
          error: details?.error || null
        }
      );

      if (response.status === 429) {
        return json(
          {
            ok: false,
            error:
              "الخدمة مشغولة حاليًا. جرّب بعد لحظات."
          },
          429
        );
      }

      if (
        response.status === 401 ||
        response.status === 403
      ) {
        return json(
          {
            ok: false,
            error:
              "خدمة الذكاء الاصطناعي تحتاج إعداد صلاحية صحيح."
          },
          502
        );
      }

      return json(
        {
          ok: false,
          error:
            details?.error?.message ||
            "AI service temporarily unavailable"
        },
        502
      );
    }

    const data =
      await response.json();

    const reply =
      extractOutputText(data);

    if (!reply) {
      return json(
        {
          ok: false,
          error:
            "AI returned an empty response"
        },
        502
      );
    }

    return json({
      ok: true,
      reply,
      model,
      image_analyzed:
        Boolean(image)
    });
  } catch (error) {
    console.error(
      "OpenAI network error",
      String(error)
    );

    return json(
      {
        ok: false,
        error:
          "AI service temporarily unavailable"
      },
      502
    );
  }
}

async function handleImageGeneration(
  request,
  env
) {
  let body;

  try {
    body = await readJsonBody(request);
  } catch (error) {
    return json(
      {
        ok: false,
        error:
          error.message === "Request is too large"
            ? "Request is too large"
            : "Invalid JSON"
      },
      error.message === "Request is too large"
        ? 413
        : 400
    );
  }

  const prompt =
    body?.prompt?.toString().trim();

  if (!prompt) {
    return json(
      {
        ok: false,
        error: "Image prompt is required"
      },
      400
    );
  }

  if (prompt.length > 8000) {
    return json(
      {
        ok: false,
        error: "Image prompt is too long"
      },
      400
    );
  }

  const model =
    env.OPENAI_IMAGE_MODEL ||
    DEFAULT_IMAGE_MODEL;

  try {
    const response =
      await fetch(
        "https://api.openai.com/v1/images/generations",
        {
          method: "POST",
          headers: {
            "Authorization":
              `Bearer ${env.OPENAI_API_KEY}`,
            "Content-Type":
              "application/json"
          },
          body: JSON.stringify({
            model,
            prompt,
            size: "1024x1024",
            quality: "low",
            output_format: "png"
          })
        }
      );

    if (!response.ok) {
      let details = null;

      try {
        details = await response.json();
      } catch (_) {}

      console.error(
        "Image generation failed",
        {
          status: response.status,
          error: details?.error || null
        }
      );

      if (response.status === 429) {
        return json(
          {
            ok: false,
            error:
              "خدمة إنشاء الصور مشغولة حاليًا. جرّب بعد لحظات."
          },
          429
        );
      }

      if (
        response.status === 401 ||
        response.status === 403
      ) {
        return json(
          {
            ok: false,
            error:
              "خدمة الصور تحتاج إعداد صلاحية صحيح."
          },
          502
        );
      }

      return json(
        {
          ok: false,
          error:
            details?.error?.message ||
            "Image generation temporarily unavailable"
        },
        502
      );
    }

    const data =
      await response.json();

    const imageBase64 =
      data?.data?.[0]?.b64_json;

    if (
      typeof imageBase64 !== "string" ||
      !imageBase64.trim()
    ) {
      return json(
        {
          ok: false,
          error:
            "Image service returned no image"
        },
        502
      );
    }

    return json({
      ok: true,
      image_base64: imageBase64,
      model
    });
  } catch (error) {
    console.error(
      "Image generation network error",
      String(error)
    );

    return json(
      {
        ok: false,
        error:
          "Image service temporarily unavailable"
      },
      502
    );
  }
}

async function handleAudioSearch(request) {
  if (request.method !== "GET") {
    return json(
      {
        ok: false,
        error: "GET required"
      },
      405
    );
  }

  const query =
    new URL(request.url)
      .searchParams
      .get("q")
      ?.trim() || "";

  if (!query) {
    return json(
      {
        ok: false,
        error: "Query is required"
      },
      400
    );
  }

  try {
    const normalizedQuery =
      normalizeArabic(query);

    const [
      suraResponse,
      reciterResponse
    ] = await Promise.all([
      fetch(
        "https://www.mp3quran.net/api/v3/suwar?language=ar"
      ),
      fetch(
        "https://www.mp3quran.net/api/v3/reciters?language=ar"
      )
    ]);

    if (
      !suraResponse.ok ||
      !reciterResponse.ok
    ) {
      return json(
        {
          ok: false,
          error:
            "Audio search source unavailable"
        },
        502
      );
    }

    const suraData =
      await suraResponse.json();

    const reciterData =
      await reciterResponse.json();

    const suwar =
      Array.isArray(suraData?.suwar)
        ? suraData.suwar
        : [];

    const reciters =
      Array.isArray(reciterData?.reciters)
        ? reciterData.reciters
        : [];

    const matchedSuras =
      suwar.filter((sura) => {
        const name =
          normalizeArabic(
            sura?.name || ""
          );

        return (
          name.includes(normalizedQuery) ||
          normalizedQuery.includes(name)
        );
      });

    const matchedReciters =
      reciters.filter((reciter) => {
        const name =
          normalizeArabic(
            reciter?.name || ""
          );

        return (
          name.includes(normalizedQuery) ||
          normalizedQuery.includes(name)
        );
      });

    const selectedSuras =
      matchedSuras.length
        ? matchedSuras.slice(0, 5)
        : suwar.slice(0, 3);

    const selectedReciters =
      matchedReciters.length
        ? matchedReciters.slice(0, 3)
        : reciters.slice(0, 3);

    const results = [];

    for (const sura of selectedSuras) {
      const suraId =
        Number(sura?.id);

      if (
        !Number.isInteger(suraId) ||
        suraId < 1 ||
        suraId > 114
      ) {
        continue;
      }

      for (const reciter of selectedReciters) {
        const moshaf =
          Array.isArray(reciter?.moshaf)
            ? reciter.moshaf[0]
            : null;

        const server =
          String(
            moshaf?.server || ""
          ).trim();

        if (!server) continue;

        const url =
          server.replace(/\/$/, "") +
          "/" +
          String(suraId).padStart(3, "0") +
          ".mp3";

        if (
          !results.some(
            (item) => item.url === url
          )
        ) {
          results.push({
            title:
              `${sura?.name || "سورة"} - ${reciter?.name || "قارئ"}`,
            artist:
              reciter?.name || "قارئ",
            url,
            type: "quran"
          });
        }

        if (results.length >= 12) {
          break;
        }
      }

      if (results.length >= 12) {
        break;
      }
    }

    return json({
      ok: true,
      query,
      source: "MP3Quran",
      items: results
    });
  } catch (error) {
    console.error(
      "Audio search error",
      String(error)
    );

    return json(
      {
        ok: false,
        error:
          "Audio search temporarily unavailable"
      },
      502
    );
  }
}

async function handleNews(request) {
  if (request.method !== "GET") {
    return json(
      {
        ok: false,
        error: "GET required"
      },
      405
    );
  }

  const rssUrl =
    "https://news.google.com/rss?hl=ar&gl=EG&ceid=EG:ar";

  try {
    const response =
      await fetch(
        rssUrl,
        {
          headers: {
            "User-Agent":
              "Sa7biAI/3.2 News Reader"
          }
        }
      );

    if (!response.ok) {
      return json(
        {
          ok: false,
          error:
            "News feed unavailable"
        },
        502
      );
    }

    const xml =
      await response.text();

    const blocks =
      xml.match(
        /<item>[\s\S]*?<\/item>/gi
      ) || [];

    const items = [];

    for (
      const block of blocks.slice(0, 20)
    ) {
      const titleMatch =
        block.match(
          /<title>([\s\S]*?)<\/title>/i
        );

      const linkMatch =
        block.match(
          /<link>([\s\S]*?)<\/link>/i
        );

      const sourceMatch =
        block.match(
          /<source[^>]*>([\s\S]*?)<\/source>/i
        );

      const title =
        stripHtml(
          decodeXml(
            titleMatch?.[1] || ""
          )
        );

      const link =
        decodeXml(
          (linkMatch?.[1] || "").trim()
        );

      const source =
        stripHtml(
          decodeXml(
            sourceMatch?.[1] ||
              "Google News"
          )
        );

      const imageUrl =
        extractNewsImage(block);

      if (title && link) {
        items.push({
          title,
          source:
            source || "Google News",
          link,
          imageUrl
        });
      }
    }

    return json({
      ok: true,
      source: "Google News",
      updated_at:
        new Date().toISOString(),
      items
    });
  } catch (error) {
    console.error(
      "News feed error",
      String(error)
    );

    return json(
      {
        ok: false,
        error:
          "News feed temporarily unavailable"
      },
      502
    );
  }
}

export default {
  async fetch(request, env) {
    const url =
      new URL(request.url);

    if (
      request.method === "OPTIONS"
    ) {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS
      });
    }

    /*
     * Permanent public APK link.
     *
     * The Flutter application points to /download.
     * This endpoint redirects to the latest GitHub Release
     * asset named sa7bi-ai.apk.
     */
    if (
      request.method === "GET" &&
      url.pathname === "/download"
    ) {
      return Response.redirect(
        APK_DOWNLOAD_URL,
        302
      );
    }

    if (
      request.method === "GET" &&
      url.pathname === "/"
    ) {
      const configured =
        Boolean(env.OPENAI_API_KEY);

      return json({
        ok: true,
        service: "Sa7bi AI Backend",
        status:
          configured
            ? "online"
            : "misconfigured",
        ai_configured: configured,
        text_model:
          env.OPENAI_MODEL ||
          DEFAULT_TEXT_MODEL,
        image_model:
          env.OPENAI_IMAGE_MODEL ||
          DEFAULT_IMAGE_MODEL,
        download_url:
          "https://sa7bi-ai-new.ahmedsab34.workers.dev/download",
        version:
          BACKEND_VERSION
      });
    }

    if (
      request.method === "GET" &&
      url.pathname === "/v1/news"
    ) {
      return handleNews(request);
    }

    if (
      request.method === "GET" &&
      url.pathname === "/v1/audio/search"
    ) {
      return handleAudioSearch(request);
    }

    if (!env.OPENAI_API_KEY) {
      return json(
        {
          ok: false,
          error:
            "AI service is not configured"
        },
        503
      );
    }

    if (
      request.method === "POST" &&
      url.pathname === "/v1/chat"
    ) {
      return handleChat(
        request,
        env
      );
    }

    if (
      request.method === "POST" &&
      url.pathname === "/v1/image"
    ) {
      return handleImageGeneration(
        request,
        env
      );
    }

    return json(
      {
        ok: false,
        error: "Not found"
      },
      404
    );
  }
};
