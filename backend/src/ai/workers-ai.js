/**
 * Sa7bi AI
 * Cloudflare Workers AI provider
 *
 * Responsibilities:
 * - Text generation fallback
 * - Vision/image understanding fallback
 * - Image generation fallback
 *
 * Architecture:
 * - Gemini is the primary AI provider.
 * - Workers AI is the automatic fallback provider.
 * - No private API key is stored here.
 * - Workers AI is accessed only through env.AI.
 *
 * Compatible with:
 * - ai-router.js
 * - gemini.js
 * - index.js
 * - backend/wrangler.toml
 */

const DEFAULT_WORKERS_TEXT_MODEL =
  "@cf/meta/llama-3.3-70b-instruct-fp8-fast";

const DEFAULT_WORKERS_VISION_MODEL =
  "@cf/meta/llama-3.2-11b-vision-instruct";

const DEFAULT_WORKERS_IMAGE_MODEL =
  "@cf/black-forest-labs/flux-1-schnell";

const MAX_OUTPUT_TOKENS = 4096;
const DEFAULT_MAX_OUTPUT_TOKENS = 1024;

const MAX_IMAGE_DATA_URL_LENGTH = 20 * 1024 * 1024;
const MAX_IMAGE_PROMPT_LENGTH = 2048;

const IMAGE_GENERATION_ATTEMPTS = 2;
const IMAGE_RETRY_DELAY_MS = 1200;

/* -------------------------------------------------------------------------- */
/* Errors                                                                     */
/* -------------------------------------------------------------------------- */

function createError(
  code,
  message,
  details = null
) {
  const error = new Error(message);
  error.code = code;

  if (details !== null) {
    error.details = details;
  }

  return error;
}

/* -------------------------------------------------------------------------- */
/* Workers AI binding                                                         */
/* -------------------------------------------------------------------------- */

function requireWorkersAI(env) {
  if (
    !env ||
    !env.AI ||
    typeof env.AI.run !== "function"
  ) {
    throw createError(
      "WORKERS_AI_BINDING_MISSING",
      "Cloudflare Workers AI binding env.AI is not available."
    );
  }

  return env.AI;
}

/* -------------------------------------------------------------------------- */
/* Model selection                                                            */
/* -------------------------------------------------------------------------- */

function getTextModel(env) {
  return (
    env?.WORKERS_TEXT_MODEL ||
    DEFAULT_WORKERS_TEXT_MODEL
  );
}

function getVisionModel(env) {
  return (
    env?.WORKERS_VISION_MODEL ||
    DEFAULT_WORKERS_VISION_MODEL
  );
}

function getImageModel(env) {
  return (
    env?.WORKERS_IMAGE_MODEL ||
    DEFAULT_WORKERS_IMAGE_MODEL
  );
}

/* -------------------------------------------------------------------------- */
/* Message normalization                                                      */
/* -------------------------------------------------------------------------- */

function normalizeRole(role) {
  if (
    role === "assistant" ||
    role === "model"
  ) {
    return "assistant";
  }

  if (role === "system") {
    return "system";
  }

  return "user";
}

function normalizeContent(content) {
  if (
    content === null ||
    content === undefined
  ) {
    return "";
  }

  if (typeof content === "string") {
    return content.trim();
  }

  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (!part) {
          return "";
        }

        if (typeof part === "string") {
          return part;
        }

        if (typeof part.text === "string") {
          return part.text;
        }

        if (
          typeof part.content ===
          "string"
        ) {
          return part.content;
        }

        return "";
      })
      .filter(Boolean)
      .join("\n")
      .trim();
  }

  if (typeof content === "object") {
    if (
      typeof content.text ===
      "string"
    ) {
      return content.text.trim();
    }

    if (
      typeof content.content ===
      "string"
    ) {
      return content.content.trim();
    }
  }

  return String(content).trim();
}

function normalizeMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  return messages
    .map((message) => {
      if (
        !message ||
        typeof message !== "object"
      ) {
        return null;
      }

      const content =
        normalizeContent(
          message.content
        );

      if (!content) {
        return null;
      }

      return {
        role: normalizeRole(
          message.role
        ),
        content,
      };
    })
    .filter(Boolean);
}

function normalizePrompt(
  prompt,
  messages = []
) {
  const directPrompt =
    normalizeContent(prompt);

  if (directPrompt) {
    return directPrompt;
  }

  const normalized =
    normalizeMessages(messages);

  if (!normalized.length) {
    return "";
  }

  return normalized
    .map((message) => {
      if (
        message.role === "system"
      ) {
        return `System: ${message.content}`;
      }

      if (
        message.role === "assistant"
      ) {
        return `Assistant: ${message.content}`;
      }

      return `User: ${message.content}`;
    })
    .join("\n\n")
    .trim();
}

/* -------------------------------------------------------------------------- */
/* Image input normalization                                                  */
/* -------------------------------------------------------------------------- */

function normalizeImageDataUrl(value) {
  if (typeof value !== "string") {
    return null;
  }

  const image = value.trim();

  if (!image) {
    return null;
  }

  if (
    image.length >
    MAX_IMAGE_DATA_URL_LENGTH
  ) {
    throw createError(
      "WORKERS_IMAGE_TOO_LARGE",
      "The image data is too large for the Workers AI vision request."
    );
  }

  if (
    !/^data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=\s]+$/.test(
      image
    )
  ) {
    throw createError(
      "WORKERS_INVALID_IMAGE_DATA",
      "Vision fallback requires a valid base64 image data URL."
    );
  }

  return image;
}

function normalizeImageDataUrls(
  imageDataUrls
) {
  if (!imageDataUrls) {
    return [];
  }

  if (
    typeof imageDataUrls ===
    "string"
  ) {
    return [
      normalizeImageDataUrl(
        imageDataUrls
      ),
    ].filter(Boolean);
  }

  if (!Array.isArray(imageDataUrls)) {
    return [];
  }

  return imageDataUrls
    .map(normalizeImageDataUrl)
    .filter(Boolean);
}

/* -------------------------------------------------------------------------- */
/* Workers AI response normalization                                          */
/* -------------------------------------------------------------------------- */

function extractWorkersText(
  response
) {
  if (
    response === null ||
    response === undefined
  ) {
    return "";
  }

  if (typeof response === "string") {
    return response.trim();
  }

  if (
    typeof response.response ===
    "string"
  ) {
    return response.response.trim();
  }

  if (
    typeof response.result ===
    "string"
  ) {
    return response.result.trim();
  }

  if (
    typeof response.text ===
    "string"
  ) {
    return response.text.trim();
  }

  if (
    typeof response.description ===
    "string"
  ) {
    return response.description.trim();
  }

  if (
    response.result &&
    typeof response.result ===
      "object"
  ) {
    if (
      typeof response.result
        .response === "string"
    ) {
      return response.result
        .response.trim();
    }

    if (
      typeof response.result.text ===
      "string"
    ) {
      return response.result.text.trim();
    }

    if (
      typeof response.result
        .description === "string"
    ) {
      return response.result
        .description.trim();
    }
  }

  return "";
}

function extractWorkersImage(
  response
) {
  if (
    response === null ||
    response === undefined
  ) {
    return null;
  }

  if (typeof response === "string") {
    return response.trim() || null;
  }

  if (
    typeof response.image ===
    "string" &&
    response.image.trim()
  ) {
    return response.image.trim();
  }

  if (
    response.result &&
    typeof response.result ===
      "object"
  ) {
    if (
      typeof response.result
        .image === "string" &&
      response.result.image.trim()
    ) {
      return response.result.image.trim();
    }
  }

  return null;
}

function normalizeBase64Image(
  value
) {
  if (
    typeof value !== "string"
  ) {
    return null;
  }

  let image = value.trim();

  if (!image) {
    return null;
  }

  image = image.replace(
    /^data:image\/[^;]+;base64,/i,
    ""
  );

  image = image.replace(
    /\s+/g,
    ""
  );

  if (!image) {
    return null;
  }

  /*
   * Basic Base64 validation.
   * Do not decode the entire image here;
   * the payload may be several megabytes.
   */
  if (
    !/^[A-Za-z0-9+/]+={0,2}$/.test(
      image
    )
  ) {
    return null;
  }

  return image;
}

function imageBase64ToDataUrl(
  base64
) {
  const normalized =
    normalizeBase64Image(base64);

  if (!normalized) {
    return null;
  }

  return `data:image/jpeg;base64,${normalized}`;
}

/* -------------------------------------------------------------------------- */
/* Request options                                                             */
/* -------------------------------------------------------------------------- */

function normalizeMaxTokens(
  value
) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return DEFAULT_MAX_OUTPUT_TOKENS;
  }

  return Math.max(
    64,
    Math.min(
      MAX_OUTPUT_TOKENS,
      Math.floor(parsed)
    )
  );
}

function normalizeTemperature(
  value,
  fallback = 0.6
) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.max(
    0,
    Math.min(2, parsed)
  );
}

/* -------------------------------------------------------------------------- */
/* Text generation                                                             */
/* -------------------------------------------------------------------------- */

export async function generateWorkersText({
  env,
  messages = [],
  prompt = "",
  systemInstruction = "",
  maxOutputTokens =
    DEFAULT_MAX_OUTPUT_TOKENS,
  temperature = 0.6,
} = {}) {
  const AI =
    requireWorkersAI(env);

  const model =
    getTextModel(env);

  const normalizedMessages =
    normalizeMessages(messages);

  const finalMessages = [];

  if (
    typeof systemInstruction ===
      "string" &&
    systemInstruction.trim()
  ) {
    finalMessages.push({
      role: "system",
      content:
        systemInstruction.trim(),
    });
  }

  if (normalizedMessages.length) {
    finalMessages.push(
      ...normalizedMessages
    );
  } else {
    const normalizedPrompt =
      normalizePrompt(prompt);

    if (normalizedPrompt) {
      finalMessages.push({
        role: "user",
        content: normalizedPrompt,
      });
    }
  }

  if (!finalMessages.length) {
    throw createError(
      "WORKERS_TEXT_PROMPT_MISSING",
      "No text prompt or messages were supplied."
    );
  }

  let raw;

  try {
    raw = await AI.run(
      model,
      {
        messages: finalMessages,
        max_tokens:
          normalizeMaxTokens(
            maxOutputTokens
          ),
        temperature:
          normalizeTemperature(
            temperature
          ),
        stream: false,
      }
    );
  } catch (error) {
    throw createError(
      "WORKERS_TEXT_REQUEST_FAILED",
      error?.message ||
        "Workers AI text generation failed.",
      {
        model,
        cause:
          error?.code ||
          error?.name ||
          "unknown",
      }
    );
  }

  const answer =
    extractWorkersText(raw);

  if (!answer) {
    throw createError(
      "WORKERS_TEXT_EMPTY",
      "Workers AI returned an empty text response.",
      {
        model,
      }
    );
  }

  return {
    answer,
    model,
    provider:
      "cloudflare-workers-ai",
    raw,
  };
}

/* -------------------------------------------------------------------------- */
/* Vision generation                                                           */
/* -------------------------------------------------------------------------- */

export async function generateWorkersVision({
  env,
  messages = [],
  prompt = "",
  systemInstruction = "",
  imageDataUrls = [],
  maxOutputTokens =
    DEFAULT_MAX_OUTPUT_TOKENS,
  temperature = 0.4,
} = {}) {
  const AI =
    requireWorkersAI(env);

  const model =
    getVisionModel(env);

  const images =
    normalizeImageDataUrls(
      imageDataUrls
    );

  const image =
    images.length > 0
      ? images[0]
      : null;

  const normalizedMessages =
    normalizeMessages(messages);

  const finalMessages = [];

  if (
    typeof systemInstruction ===
      "string" &&
    systemInstruction.trim()
  ) {
    finalMessages.push({
      role: "system",
      content:
        systemInstruction.trim(),
    });
  }

  if (normalizedMessages.length) {
    finalMessages.push(
      ...normalizedMessages
    );
  }

  const normalizedPrompt =
    normalizePrompt(prompt);

  if (
    normalizedPrompt &&
    !normalizedMessages.some(
      (message) =>
        message.role === "user" &&
        message.content ===
          normalizedPrompt
    )
  ) {
    finalMessages.push({
      role: "user",
      content: normalizedPrompt,
    });
  }

  if (!finalMessages.length) {
    finalMessages.push({
      role: "user",
      content: image
        ? "Describe and analyze the provided image."
        : "Please answer the user's request.",
    });
  }

  const request = {
    messages: finalMessages,
    max_tokens:
      normalizeMaxTokens(
        maxOutputTokens
      ),
    temperature:
      normalizeTemperature(
        temperature,
        0.4
      ),
    stream: false,
  };

  if (image) {
    request.image = image;
  }

  let raw;

  try {
    raw = await AI.run(
      model,
      request
    );
  } catch (error) {
    throw createError(
      "WORKERS_VISION_REQUEST_FAILED",
      error?.message ||
        "Workers AI vision generation failed.",
      {
        model,
        hasImage: Boolean(image),
        imageCount: images.length,
        cause:
          error?.code ||
          error?.name ||
          "unknown",
      }
    );
  }

  const answer =
    extractWorkersText(raw);

  if (!answer) {
    throw createError(
      "WORKERS_VISION_EMPTY",
      "Workers AI returned an empty vision response.",
      {
        model,
        hasImage: Boolean(image),
        imageCount: images.length,
      }
    );
  }

  return {
    answer,
    model,
    provider:
      "cloudflare-workers-ai",
    hasImage: Boolean(image),
    imageCount: images.length,
    raw,
  };
}

/* -------------------------------------------------------------------------- */
/* Image generation                                                            */
/* -------------------------------------------------------------------------- */

function isRetryableImageError(
  error
) {
  const code =
    String(error?.code || "")
      .toUpperCase();

  const message =
    String(
      error?.message || ""
    ).toLowerCase();

  return (
    code.includes("1101") ||
    code.includes("TIMEOUT") ||
    code.includes("INTERNAL") ||
    code.includes("OVERLOAD") ||
    code.includes("SERVER") ||
    message.includes("high demand") ||
    message.includes("temporarily") ||
    message.includes("timeout") ||
    message.includes("internal") ||
    message.includes("overload") ||
    message.includes("service unavailable") ||
    message.includes("1101")
  );
}

function sleep(ms) {
  return new Promise(
    (resolve) =>
      setTimeout(resolve, ms)
  );
}

async function runWorkersImageOnce({
  AI,
  model,
  request,
} = {}) {
  try {
    return await AI.run(
      model,
      request
    );
  } catch (error) {
    throw createError(
      "WORKERS_IMAGE_REQUEST_FAILED",
      error?.message ||
        "Workers AI image generation failed.",
      {
        model,
        cause:
          error?.code ||
          error?.name ||
          "unknown",
      }
    );
  }
}

export async function generateWorkersImage({
  env,
  prompt = "",
  seed = null,
  steps = 4,
} = {}) {
  const AI =
    requireWorkersAI(env);

  const model =
    getImageModel(env);

  const normalizedPrompt =
    normalizeContent(prompt);

  if (!normalizedPrompt) {
    throw createError(
      "WORKERS_IMAGE_PROMPT_MISSING",
      "An image generation prompt is required."
    );
  }

  if (
    normalizedPrompt.length >
    MAX_IMAGE_PROMPT_LENGTH
  ) {
    throw createError(
      "WORKERS_IMAGE_PROMPT_TOO_LONG",
      "The image generation prompt is too long."
    );
  }

  const parsedSteps =
    Number(steps);

  const normalizedSteps =
    Number.isFinite(parsedSteps)
      ? Math.max(
          1,
          Math.min(
            8,
            Math.floor(parsedSteps)
          )
        )
      : 4;

  /*
   * FLUX.1 schnell officially accepts
   * prompt, steps and seed.
   */
  const request = {
    prompt: normalizedPrompt,
    steps: normalizedSteps,
  };

  const normalizedSeed =
    Number(seed);

  if (
    Number.isFinite(
      normalizedSeed
    ) &&
    normalizedSeed >= 1 &&
    normalizedSeed <= 9999999999
  ) {
    request.seed =
      Math.floor(
        normalizedSeed
      );
  }

  let raw = null;
  let lastError = null;

  for (
    let attempt = 1;
    attempt <=
      IMAGE_GENERATION_ATTEMPTS;
    attempt += 1
  ) {
    try {
      raw =
        await runWorkersImageOnce({
          AI,
          model,
          request,
        });

      const imageBase64 =
        extractWorkersImage(
          raw
        );

      const imageDataUrl =
        imageBase64ToDataUrl(
          imageBase64
        );

      if (imageDataUrl) {
        return {
          imageDataUrl,
          mimeType:
            "image/jpeg",
          model,
          provider:
            "cloudflare-workers-ai",
          raw,
          attempts: attempt,
        };
      }

      lastError =
        createError(
          "WORKERS_IMAGE_INVALID_RESPONSE",
          "Workers AI returned no valid Base64 image.",
          {
            model,
            attempt,
          }
        );
    } catch (error) {
      lastError = error;

      if (
        attempt <
          IMAGE_GENERATION_ATTEMPTS &&
        isRetryableImageError(
          error
        )
      ) {
        await sleep(
          IMAGE_RETRY_DELAY_MS
        );
        continue;
      }

      break;
    }

    if (
      attempt <
        IMAGE_GENERATION_ATTEMPTS
    ) {
      await sleep(
        IMAGE_RETRY_DELAY_MS
      );
    }
  }

  if (lastError) {
    throw createError(
      lastError.code ||
        "WORKERS_IMAGE_FAILED",
      lastError.message ||
        "Workers AI image generation failed.",
      {
        model,
        attempts:
          IMAGE_GENERATION_ATTEMPTS,
        cause:
          lastError.details ||
          null,
      }
    );
  }

  throw createError(
    "WORKERS_IMAGE_EMPTY",
    "Workers AI returned no generated image.",
    {
      model,
      attempts:
        IMAGE_GENERATION_ATTEMPTS,
    }
  );
}

/* -------------------------------------------------------------------------- */
/* Provider status                                                             */
/* -------------------------------------------------------------------------- */

export function isWorkersAIConfigured(
  env
) {
  return Boolean(
    env &&
      env.AI &&
      typeof env.AI.run ===
        "function"
  );
}

export function getWorkersAIModels(
  env
) {
  return {
    text: getTextModel(env),
    vision: getVisionModel(env),
    image: getImageModel(env),
  };
}

export function getWorkersAIStatus(
  env
) {
  const configured =
    isWorkersAIConfigured(env);

  return {
    configured,
    provider:
      "cloudflare-workers-ai",
    binding: "AI",
    models:
      getWorkersAIModels(env),
    capabilities: {
      text: configured,
      vision: configured,
      imageGeneration:
        configured,
    },
  };
}
