/**
 * Sa7bi AI - Moondream 3.1 vision adapter for Cloudflare Workers AI.
 * Uses Cloudflare's `env.AI` binding; no API key or Worker setting is added.
 */

export const MOONDREAM_VISION_MODEL =
  "@cf/moondream/moondream3.1-9B-A2B";

function createVisionError(code, details = null) {
  const error = new Error(code);
  error.code = code;
  if (details !== null) error.details = details;
  return error;
}

function normalizeImageDataUrl(value) {
  if (typeof value !== "string") {
    throw createVisionError("MOONDREAM_IMAGE_MISSING");
  }

  const image = value.trim();
  if (!image) throw createVisionError("MOONDREAM_IMAGE_MISSING");

  if (!/^data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=\s]+$/.test(image)) {
    throw createVisionError("MOONDREAM_INVALID_IMAGE_DATA");
  }

  return image;
}

function extractAnswer(result) {
  const candidates = [
    result?.answer,
    result?.response,
    result?.text,
    result?.description,
    result?.result?.answer,
    result?.result?.response,
    result?.result?.text,
  ];

  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim()) {
      return candidate.trim();
    }
  }

  return "";
}

export async function generateMoondreamVision({
  env,
  imageDataUrl,
  question,
} = {}) {
  if (!env?.AI || typeof env.AI.run !== "function") {
    throw createVisionError("WORKERS_AI_BINDING_MISSING");
  }

  const image = normalizeImageDataUrl(imageDataUrl);
  const cleanQuestion =
    typeof question === "string" && question.trim()
      ? question.trim().slice(0, 12000)
      : "حلل الصورة المرفقة واشرح الأشياء والنصوص الظاهرة بوضوح، ولا تخمن ما لا يظهر.";

  let raw;
  try {
    raw = await env.AI.run(MOONDREAM_VISION_MODEL, {
      task: "query",
      image,
      question: cleanQuestion,
    });
  } catch (cause) {
    throw createVisionError("MOONDREAM_VISION_REQUEST_FAILED", {
      cause: cause?.code || cause?.name || "provider_error",
    });
  }

  const answer = extractAnswer(raw);
  if (!answer) {
    throw createVisionError("MOONDREAM_VISION_EMPTY_RESPONSE");
  }

  return {
    answer,
    model: MOONDREAM_VISION_MODEL,
    provider: "cloudflare-workers-ai",
    raw,
  };
}
