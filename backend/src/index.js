const MAX_BODY_BYTES = 8 * 1024 * 1024;

const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 24000;

const MAX_IMAGE_CHARS = 6 * 1024 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store"
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders
    }
  });
}

function cleanMessages(value) {
  if (
    !Array.isArray(value) ||
    value.length === 0 ||
    value.length > MAX_MESSAGES
  ) {
    return null;
  }

  let total = 0;
  const messages = [];

  for (const item of value) {
    if (!item || typeof item !== "object") {
      return null;
    }

    if (
      item.role !== "user" &&
      item.role !== "assistant"
    ) {
      return null;
    }

    if (typeof item.content !== "string") {
      return null;
    }

    const content = item.content.trim();

    if (
      !content ||
      content.length > MAX_MESSAGE_CHARS
    ) {
      return null;
    }

    total += content.length;

    if (total > MAX_TOTAL_CHARS) {
      return null;
    }

    messages.push({
      role: item.role,
      content
    });
  }

  if (
    messages[messages.length - 1]?.role !== "user"
  ) {
    return null;
  }

  return messages;
}

function extractOutputText(data) {
  if (
    typeof data?.output_text === "string" &&
    data.output_text.trim()
  ) {
    return data.output_text.trim();
  }

  const parts = [];

  for (const item of data?.output ?? []) {
    for (const content of item?.content ?? []) {
      if (
        content?.type === "output_text" &&
        typeof content?.text === "string"
      ) {
        parts.push(content.text);
      }
    }
  }

  return parts.join("").trim();
}

function isValidImageDataUrl(value) {
  if (typeof value !== "string") {
    return false;
  }

  if (value.length > MAX_IMAGE_CHARS) {
    return false;
  }

  return /^data:image\/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=]+$/i.test(
    value
  );
}

function decodeXml(value) {
  return String(value)
    .replace(
      /<!\[CDATA\[([\s\S]*?)\]\]>/g,
      "$1"
    )
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/gi, "'");
}

function stripHtml(value) {
  return String(value)
    .replace(/<[^>]*>/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

async function callOpenAI(
  env,
  payload,
  model
) {
  return fetch(
    "https://api.openai.com/v1/responses",
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
        store: false,
        ...payload
      })
    }
  );
}

async function handleChat(
  request,
  env
) {
  const contentType =
    request.headers.get("content-type") || "";

  if (
    !contentType
      .toLowerCase()
      .includes("application/json")
  ) {
    return json(
      {
        ok: false,
        error: "JSON request required"
      },
      415
    );
  }

  const contentLength =
    Number(
      request.headers.get(
        "content-length"
      ) || 0
    );

  if (
    contentLength >
    MAX_BODY_BYTES
  ) {
    return json(
      {
        ok: false,
        error: "Request is too large"
      },
      413
    );
  }

  let body;

  try {
    const raw =
      await request.text();

    if (
      new TextEncoder()
        .encode(raw)
        .byteLength >
      MAX_BODY_BYTES
    ) {
      return json(
        {
          ok: false,
          error: "Request is too large"
        },
        413
      );
    }

    body =
      JSON.parse(raw);
  } catch {
    return json(
      {
        ok: false,
        error: "Invalid JSON"
      },
      400
    );
  }

  const messages =
    cleanMessages(
      body?.messages
    );

  if (!messages) {
    return json(
      {
        ok: false,
        error: "Invalid messages."
      },
      400
    );
  }

  const image =
    body?.image;

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
    image
      ? (
          env.OPENAI_VISION_MODEL ||
          env.OPENAI_MODEL ||
          "gpt-5.6-luna"
        )
      : (
          env.OPENAI_MODEL ||
          "gpt-5.6-luna"
        );

  let input;

  if (image) {
    const lastMessage =
      messages[
        messages.length - 1
      ];

    const previousMessages =
      messages.slice(
        0,
        messages.length - 1
      );

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
  } else {
    input = messages;
  }

  let openaiResponse;

  try {
    openaiResponse =
      await callOpenAI(
        env,
        {
          instructions:
            [
              "أنت صَحبي AI.",
              "",
              "أنت مساعد عربي ودود وذكي وقريب من المستخدم.",
              "افهم نبرة المستخدم ورد بطريقة إنسانية وطبيعية.",
              "",
              "اجعل الردود:",
              "- واضحة ومباشرة.",
              "- مفيدة وليست طويلة بلا داعٍ.",
              "- دافئة وقريبة من الكلام الطبيعي.",
              "- فيها لمسة emotion مناسبة للسياق.",
              "- استخدم الإيموجي باعتدال عندما يضيف إحساسًا للرد.",
              "- لا تستخدم نفس الإيموجي في كل رد.",
              "- لا تبدأ كل رد بعبارات محفوظة مثل: بالتأكيد يا عزيزي.",
              "",
              "إذا كان المستخدم حزينًا أو قلقًا، كن هادئًا ومتعاونًا.",
              "إذا كان متحمسًا أو يطلب فكرة إبداعية، شاركه الحماس.",
              "إذا كان يسأل سؤالًا تقنيًا، كن عمليًا ودقيقًا.",
              "إذا كان يريد إجابة قصيرة، لا تطل الرد.",
              "",
              "لا تدّعي أنك نفذت شيئًا لم تنفذه.",
              "لا تخترع معلومات.",
              "إذا كانت المعلومة غير مؤكدة، وضح ذلك.",
              "عند تحليل صورة، صف فقط ما يظهر بشكل معقول.",
              "",
              "استخدم العربية افتراضيًا، إلا إذا طلب المستخدم لغة أخرى."
            ].join(" "),

          reasoning: {
            effort: "none"
          },

          max_output_tokens: 700,

          input
        },
        model
      );
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

  if (!openaiResponse.ok) {
    let details = null;

    try {
      details =
        await openaiResponse.json();
    } catch {}

    console.error(
      "OpenAI request failed",
      {
        status:
          openaiResponse.status,
        type:
          details?.error?.type ||
          null,
        code:
          details?.error?.code ||
          null
      }
    );

    if (
      openaiResponse.status ===
      429
    ) {
      return json(
        {
          ok: false,
          error:
            "AI service is busy. Please try again shortly."
        },
        429
      );
    }

    return json(
      {
        ok: false,
        error:
          "AI service temporarily unavailable"
      },
      502
    );
  }

  let data;

  try {
    data =
      await openaiResponse.json();
  } catch {
    return json(
      {
        ok: false,
        error:
          "Invalid AI response"
      },
      502
    );
  }

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
}

async function handleImageGeneration(
  request,
  env
) {
  let body;

  try {
    body =
      await request.json();
  } catch {
    return json(
      {
        ok: false,
        error:
          "Invalid JSON"
      },
      400
    );
  }

  const prompt =
    body?.prompt
      ?.toString()
      .trim();

  if (!prompt) {
    return json(
      {
        ok: false,
        error:
          "Image prompt is required"
      },
      400
    );
  }

  if (prompt.length > 8000) {
    return json(
      {
        ok: false,
        error:
          "Image prompt is too long"
      },
      400
    );
  }

  const model =
    env.OPENAI_IMAGE_MODEL ||
    "gpt-image-2.5-flare";

  let response;

  try {
    response =
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

  if (!response.ok) {
    let details = null;

    try {
      details =
        await response.json();
    } catch {}

    console.error(
      "Image generation failed",
      {
        status:
          response.status,
        type:
          details?.error?.type ||
          null,
        code:
          details?.error?.code ||
          null,
        message:
          details?.error?.message ||
          null
      }
    );

    if (
      response.status ===
      429
    ) {
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
      response.status ===
      403
    ) {
      return json(
        {
          ok: false,
          error:
            "خدمة الصور تحتاج تفعيل صلاحية إنشاء الصور في حساب الـAPI."
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

  let data;

  try {
    data =
      await response.json();
  } catch {
    return json(
      {
        ok: false,
        error:
          "Invalid image response"
      },
      502
    );
  }

  const imageBase64 =
    data?.data?.[0]?.b64_json;

  if (
    typeof imageBase64 !==
      "string" ||
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
    image_base64:
      imageBase64,
    model
  });
}

async function handleNews(
  request
) {
  if (
    request.method !==
    "GET"
  ) {
    return json(
      {
        ok: false,
        error:
          "GET required"
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
              "Sa7biAI/1.0 News Reader"
          },
          cf: {
            cacheTtl: 300,
            cacheEverything: true
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
      const block of blocks.slice(
        0,
        12
      )
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
          (
            linkMatch?.[1] ||
            ""
          ).trim()
        );

      const source =
        stripHtml(
          decodeXml(
            sourceMatch?.[1] ||
            "Google News"
          )
        );

      if (
        title &&
        link
      ) {
        items.push({
          title,
          source:
            source ||
            "Google News",
          link
        });
      }
    }

    return json({
      ok: true,
      source:
        "Google News",
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
  async fetch(
    request,
    env
  ) {
    const url =
      new URL(request.url);

    if (
      request.method ===
      "OPTIONS"
    ) {
      return new Response(
        null,
        {
          status: 204,
          headers:
            corsHeaders
        }
      );
    }

    if (
      request.method ===
        "GET" &&
      url.pathname === "/"
    ) {
      return json({
        ok: true,
        service:
          "Sa7bi AI Backend",
        status:
          "online",
        version:
          "2.2.0"
      });
    }

    if (
      request.method ===
        "GET" &&
      url.pathname ===
        "/v1/news"
    ) {
      return handleNews(
        request
      );
    }

    if (
      !env.OPENAI_API_KEY
    ) {
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
      request.method ===
        "POST" &&
      url.pathname ===
        "/v1/chat"
    ) {
      return handleChat(
        request,
        env
      );
    }

    if (
      request.method ===
        "POST" &&
      url.pathname ===
        "/v1/image"
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
          "Not found"
      },
      404
    );
  }
};
