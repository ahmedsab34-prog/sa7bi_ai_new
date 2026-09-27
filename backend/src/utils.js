const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, X-Sa7bi-Force-Fallback",
  "Cache-Control": "no-store",
};

const MAX_BODY_BYTES = 10 * 1024 * 1024;

const MAX_MESSAGES = 20;

const MAX_MESSAGE_CHARS = 8000;

const MAX_TOTAL_CHARS = 24000;

const MAX_IMAGE_CHARS = 8 * 1024 * 1024;

const MAX_IMAGES = 4;

/**
 * Build common response headers.
 */
export function headers(extra = {}) {
  return {
    ...CORS_HEADERS,
    ...extra,
  };
}

/**
 * JSON response helper.
 */
export function json(data, status = 200, extra = {}) {
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

/**
 * Normalize Arabic text for searching/comparison.
 */
export function normalizeArabic(value) {
  return String(value || "")
    .replace(/\u0640/g, "")
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Remove HTML tags/scripts/styles.
 */
export function stripHtml(value) {
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

/**
 * Decode common XML entities.
 */
export function decodeXml(value) {
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

/**
 * Return the first matching capture group.
 */
export function firstMatch(
  block,
  patterns
) {
  for (const pattern of patterns) {
    const match =
      String(block || "").match(
        pattern
      );

    if (match?.[1]) {
      return decodeXml(
        match[1].trim()
      );
    }
  }

  return "";
}

/**
 * Extract an image URL from an RSS item.
 */
export function extractNewsImage(block) {
  return firstMatch(block, [
    /<media:content[^>]+url=["']([^"']+)["']/i,
    /<media:thumbnail[^>]+url=["']([^"']+)["']/i,
    /<enclosure[^>]+url=["']([^"']+)["']/i,
    /<img[^>]+src=["']([^"']+)["']/i,
  ]);
}

/**
 * Clean and limit chat messages before sending
 * them to an AI provider.
 */
export function cleanMessages(messages) {
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

    content =
      content.substring(
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

/**
 * Validate a base64 image data URL.
 */
export function isValidImageDataUrl(
  value
) {
  return (
    typeof value === "string" &&
    /^data:image\/[a-z0-9.+-]+;base64,/i.test(
      value
    ) &&
    value.length <=
      MAX_IMAGE_CHARS
  );
}

/**
 * Read and validate a JSON request body.
 */
export async function readJsonBody(
  request
) {
  const contentLength =
    Number(
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
      typeof data !==
        "object" ||
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

/**
 * Fetch JSON from an external service.
 */
export async function fetchJson(
  url,
  options = {}
) {
  const response =
    await fetch(url, {
      ...options,
      headers: {
        "User-Agent":
          "Sa7bi-AI/6.0.0",
        ...(options.headers || {}),
      },
    });

  if (!response.ok) {
    throw new Error(
      `HTTP_${response.status}`
    );
  }

  return response.json();
}

/**
 * Get the maximum number of images
 * accepted by the backend.
 */
export function getMaxImages() {
  return MAX_IMAGES;
}

/**
 * Get backend request limits.
 */
export function getRequestLimits() {
  return {
    maxBodyBytes:
      MAX_BODY_BYTES,
    maxMessages:
      MAX_MESSAGES,
    maxMessageChars:
      MAX_MESSAGE_CHARS,
    maxTotalChars:
      MAX_TOTAL_CHARS,
    maxImageChars:
      MAX_IMAGE_CHARS,
    maxImages:
      MAX_IMAGES,
  };
}
