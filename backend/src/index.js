const MAX_BODY_BYTES = 32 * 1024;
const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 24000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store"
};

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders,
      ...extraHeaders
    }
  });
}

function cleanMessages(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_MESSAGES) {
    return null;
  }

  let total = 0;
  const messages = [];

  for (const item of value) {
    if (!item || typeof item !== "object") {
      return null;
    }

    if (item.role !== "user" && item.role !== "assistant") {
      return null;
    }

    if (typeof item.content !== "string") {
      return null;
    }

    const content = item.content.trim();

    if (!content || content.length > MAX_MESSAGE_CHARS) {
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

  if (messages[messages.length - 1]?.role !== "user") {
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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders
      });
    }

    if (request.method === "GET" && url.pathname === "/") {
      return json({
        ok: true,
        service: "Sa7bi AI Backend",
        status: "online",
        version: "1.0.0"
      });
    }

    if (
      request.method !== "POST" ||
      url.pathname !== "/v1/chat"
    ) {
      return json(
        {
          ok: false,
          error: "Not found"
        },
        404
      );
    }

    if (!env.OPENAI_API_KEY) {
      return json(
        {
          ok: false,
          error: "AI service is not configured"
        },
        503
      );
    }

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

    const contentLength = Number(
      request.headers.get("content-length") || 0
    );

    if (contentLength > MAX_BODY_BYTES) {
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
      const raw = await request.text();

      if (
        new TextEncoder().encode(raw).byteLength >
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

      body = JSON.parse(raw);
    } catch {
      return json(
        {
          ok: false,
          error: "Invalid JSON"
        },
        400
      );
    }

    const messages = cleanMessages(body?.messages);

    if (!messages) {
      return json(
        {
          ok: false,
          error:
            "Invalid messages. Send 1-20 user/assistant messages and end with a user message."
        },
        400
      );
    }

    const model =
      env.OPENAI_MODEL || "gpt-5.6-luna";

    const openaiResponse = await fetch(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",
        headers: {
          "Authorization":
            `Bearer ${env.OPENAI_API_KEY}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model,
          store: false,
          instructions:
            "You are Sa7bi AI, a helpful Arabic-first assistant. " +
            "Be clear, practical, respectful, and concise. " +
            "Do not claim to have performed actions you did not perform. " +
            "Protect user privacy and do not request secrets or API keys.",
          input: messages
        })
      }
    );

    if (!openaiResponse.ok) {
      let details = null;

      try {
        details = await openaiResponse.json();
      } catch {}

      console.error("OpenAI request failed", {
        status: openaiResponse.status,
        type: details?.error?.type || null,
        code: details?.error?.code || null
      });

      if (openaiResponse.status === 429) {
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
      data = await openaiResponse.json();
    } catch {
      return json(
        {
          ok: false,
          error: "Invalid AI response"
        },
        502
      );
    }

    const reply = extractOutputText(data);

    if (!reply) {
      return json(
        {
          ok: false,
          error: "AI returned an empty response"
        },
        502
      );
    }

    return json({
      ok: true,
      reply,
      model
    });
  }
};
