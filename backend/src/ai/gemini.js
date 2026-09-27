// backend/src/ai/gemini.js
// Sa7bi AI - Gemini Provider
//
// Gemini is the primary AI provider.
//
// Supported:
// - Text generation
// - Conversation history
// - Image analysis
// - Multiple image inputs
// - Image generation
// - Image editing using reference images
//
// Security:
// - GEMINI_API_KEY is read only from Cloudflare Worker secrets.
// - The API key is never returned to the Flutter application.
// - No API key is stored in source code.

const DEFAULT_GEMINI_TEXT_MODEL =
  "gemini-3.8-flash";

const DEFAULT_GEMINI_IMAGE_MODEL =
  "gemini-3.1-flash-image";

const GEMINI_API_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";

const DEFAULT_IMAGE_PROMPT =
  "حلل الصور المرفقة بدقة، واقرأ النصوص الواضحة فيها، واشرح الأشياء المهمة الظاهرة فقط دون تخمين.";

const MAX_INPUT_IMAGES = 14;

const MAX_IMAGE_DATA_URL_LENGTH =
  8 * 1024 * 1024;

const MAX_OUTPUT_TOKENS =
  4096;

const ALLOWED_ASPECT_RATIOS =
  new Set([
    "1:1",
    "1:4",
    "4:1",
    "1:8",
    "8:1",
    "2:3",
    "3:2",
    "3:4",
    "4:3",
    "4:5",
    "5:4",
    "9:16",
    "16:9",
    "21:9",
  ]);

const ALLOWED_IMAGE_SIZES =
  new Set([
    "512",
    "1K",
    "2K",
    "4K",
  ]);

/* -------------------------------------------------------------------------- */
/* Configuration                                                              */
/* -------------------------------------------------------------------------- */

function getGeminiApiKey(env) {
  const key =
    typeof env?.GEMINI_API_KEY ===
      "string"
      ? env.GEMINI_API_KEY.trim()
      : "";

  if (!key) {
    const error =
      new Error(
        "GEMINI_API_KEY_MISSING"
      );

    error.code =
      "GEMINI_API_KEY_MISSING";

    throw error;
  }

  return key;
}

function getTextModel(env) {
  const model =
    typeof env?.GEMINI_TEXT_MODEL ===
      "string"
      ? env.GEMINI_TEXT_MODEL.trim()
      : "";

  return (
    model ||
    DEFAULT_GEMINI_TEXT_MODEL
  );
}

function getImageModel(env) {
  const model =
    typeof env?.GEMINI_IMAGE_MODEL ===
      "string"
      ? env.GEMINI_IMAGE_MODEL.trim()
      : "";

  return (
    model ||
    DEFAULT_GEMINI_IMAGE_MODEL
  );
}

/* -------------------------------------------------------------------------- */
/* Request errors                                                             */
/* -------------------------------------------------------------------------- */

function getErrorMessage(
  data,
  status
) {
  return (
    data?.error?.message ||
    data?.message ||
    `Gemini HTTP ${status}`
  );
}

/* -------------------------------------------------------------------------- */
/* Gemini HTTP request                                                        */
/* -------------------------------------------------------------------------- */

async function geminiRequest(
  env,
  model,
  body
) {
  const apiKey =
    getGeminiApiKey(env);

  const url =
    `${GEMINI_API_BASE}/${encodeURIComponent(
      model
    )}:generateContent`;

  let response;

  try {
    response =
      await fetch(url, {
        method: "POST",

        headers: {
          "Content-Type":
            "application/json",

          "x-goog-api-key":
            apiKey,
        },

        body:
          JSON.stringify(body),
      });
  } catch (cause) {
    const error =
      new Error(
        "GEMINI_NETWORK_ERROR"
      );

    error.code =
      "GEMINI_NETWORK_ERROR";

    error.cause =
      cause?.message ||
      cause?.name ||
      "network_error";

    throw error;
  }

  const raw =
    await response.text();

  let data;

  try {
    data =
      raw.trim()
        ? JSON.parse(raw)
        : {};
  } catch {
    data = {
      raw,
    };
  }

  if (!response.ok) {
    const error =
      new Error(
        getErrorMessage(
          data,
          response.status
        )
      );

    error.code =
      "GEMINI_HTTP_ERROR";

    error.status =
      response.status;

    error.data =
      data;

    throw error;
  }

  return data;
}

/* -------------------------------------------------------------------------- */
/* Response extraction                                                        */
/* -------------------------------------------------------------------------- */

function extractGeminiParts(
  data
) {
  const parts = [];

  const candidates =
    Array.isArray(
      data?.candidates
    )
      ? data.candidates
      : [];

  for (
    const candidate of
      candidates
  ) {
    const candidateParts =
      Array.isArray(
        candidate?.content?.parts
      )
        ? candidate.content.parts
        : [];

    for (
      const part of
        candidateParts
    ) {
      if (part) {
        parts.push(part);
      }
    }
  }

  return parts;
}

function extractGeminiText(
  data
) {
  const parts =
    extractGeminiParts(data);

  const texts = [];

  for (
    const part of parts
  ) {
    if (
      typeof part?.text ===
        "string" &&
      part.text.trim()
    ) {
      texts.push(
        part.text.trim()
      );
    }
  }

  return texts
    .join("\n")
    .trim();
}

function extractGeminiImage(
  data
) {
  const parts =
    extractGeminiParts(data);

  for (
    const part of parts
  ) {
    const inline =
      part?.inlineData ||
      part?.inline_data;

    if (
      inline &&
      typeof inline.data ===
        "string" &&
      inline.data.trim()
    ) {
      const mimeType =
        typeof inline.mimeType ===
          "string" &&
        inline.mimeType.trim()
          ? inline.mimeType.trim()
          : "image/png";

      return {
        mimeType,
        base64:
          inline.data.trim(),
      };
    }
  }

  return null;
}

/* -------------------------------------------------------------------------- */
/* Image input helpers                                                        */
/* -------------------------------------------------------------------------- */

function dataUrlParts(
  dataUrl
) {
  if (
    typeof dataUrl !==
      "string" ||
    !dataUrl.trim()
  ) {
    return null;
  }

  const image =
    dataUrl.trim();

  if (
    image.length >
    MAX_IMAGE_DATA_URL_LENGTH
  ) {
    const error =
      new Error(
        "GEMINI_IMAGE_TOO_LARGE"
      );

    error.code =
      "GEMINI_IMAGE_TOO_LARGE";

    throw error;
  }

  const match =
    image.match(
      /^data:(image\/[a-z0-9.+-]+);base64,([A-Za-z0-9+/=\s]+)$/i
    );

  if (!match) {
    return null;
  }

  return {
    mimeType:
      match[1].trim(),

    data:
      match[2].trim(),
  };
}

function normalizeImageDataUrls(
  imageDataUrls
) {
  if (
    !Array.isArray(
      imageDataUrls
    )
  ) {
    return [];
  }

  const images = [];

  for (
    const imageDataUrl of
      imageDataUrls
  ) {
    if (
      images.length >=
      MAX_INPUT_IMAGES
    ) {
      break;
    }

    const parsed =
      dataUrlParts(
        imageDataUrl
      );

    if (parsed) {
      images.push(
        parsed
      );
    }
  }

  return images;
}

function buildGeminiParts(
  text,
  imageDataUrls = []
) {
  const parts = [];

  if (
    typeof text ===
      "string" &&
    text.trim()
  ) {
    parts.push({
      text:
        text.trim(),
    });
  }

  const images =
    normalizeImageDataUrls(
      imageDataUrls
    );

  for (
    const image of images
  ) {
    parts.push({
      inlineData: {
        mimeType:
          image.mimeType,

        data:
          image.data,
      },
    });
  }

  return parts;
}

/* -------------------------------------------------------------------------- */
/* Conversation construction                                                 */
/* -------------------------------------------------------------------------- */

function buildContents(
  messages,
  imageDataUrls = [],
  imagePrompt = ""
) {
  const contents = [];

  const normalizedMessages =
    Array.isArray(messages)
      ? messages
      : [];

  for (
    const message of
      normalizedMessages
  ) {
    if (
      !message ||
      typeof message !==
        "object"
    ) {
      continue;
    }

    const text =
      typeof message.content ===
        "string"
        ? message.content.trim()
        : "";

    if (!text) {
      continue;
    }

    const role =
      message.role ===
      "assistant"
        ? "model"
        : "user";

    contents.push({
      role,

      parts: [
        {
          text,
        },
      ],
    });
  }

  const images =
    normalizeImageDataUrls(
      imageDataUrls
    );

  if (images.length) {
    const parts =
      buildGeminiParts(
        imagePrompt ||
          DEFAULT_IMAGE_PROMPT,
        imageDataUrls
      );

    if (parts.length) {
      contents.push({
        role: "user",
        parts,
      });
    }
  }

  return contents;
}

function normalizeSystemInstruction(
  instructions
) {
  if (
    typeof instructions !==
      "string" ||
    !instructions.trim()
  ) {
    return undefined;
  }

  return {
    parts: [
      {
        text:
          instructions.trim(),
      },
    ],
  };
}

/* -------------------------------------------------------------------------- */
/* Generation configuration                                                  */
/* -------------------------------------------------------------------------- */

function normalizeMaxOutputTokens(
  value
) {
  const parsed =
    Number(value);

  if (
    !Number.isFinite(
      parsed
    )
  ) {
    return 1200;
  }

  return Math.max(
    64,
    Math.min(
      MAX_OUTPUT_TOKENS,
      Math.floor(parsed)
    )
  );
}

function normalizeAspectRatio(
  value
) {
  const ratio =
    typeof value ===
      "string"
      ? value.trim()
      : "";

  if (
    ALLOWED_ASPECT_RATIOS.has(
      ratio
    )
  ) {
    return ratio;
  }

  return "1:1";
}

function normalizeImageSize(
  value
) {
  const size =
    typeof value ===
      "string"
      ? value.trim()
      : "";

  if (
    ALLOWED_IMAGE_SIZES.has(
      size
    )
  ) {
    return size;
  }

  return "1K";
}

/* -------------------------------------------------------------------------- */
/* Text + vision generation                                                   */
/* -------------------------------------------------------------------------- */

export async function generateGeminiText({
  env,
  messages,
  instructions,
  imageDataUrls = [],
  imagePrompt = "",
  maxOutputTokens = 1200,
} = {}) {
  const model =
    getTextModel(env);

  const contents =
    buildContents(
      messages,
      imageDataUrls,
      imagePrompt
    );

  if (!contents.length) {
    const error =
      new Error(
        "GEMINI_EMPTY_CONTENT"
      );

    error.code =
      "GEMINI_EMPTY_CONTENT";

    throw error;
  }

  const body = {
    contents,

    generationConfig: {
      maxOutputTokens:
        normalizeMaxOutputTokens(
          maxOutputTokens
        ),
    },
  };

  const systemInstruction =
    normalizeSystemInstruction(
      instructions
    );

  if (systemInstruction) {
    body.systemInstruction =
      systemInstruction;
  }

  const data =
    await geminiRequest(
      env,
      model,
      body
    );

  const answer =
    extractGeminiText(
      data
    );

  if (!answer) {
    const error =
      new Error(
        "GEMINI_EMPTY_RESPONSE"
      );

    error.code =
      "GEMINI_EMPTY_RESPONSE";

    error.data =
      data;

    throw error;
  }

  return {
    answer,

    model,

    raw:
      data,
  };
}

/* -------------------------------------------------------------------------- */
/* Image generation / editing                                                */
/* -------------------------------------------------------------------------- */

export async function generateGeminiImage({
  env,
  prompt,
  imageDataUrls = [],
  aspectRatio = "1:1",
  imageSize = "1K",
} = {}) {
  const model =
    getImageModel(env);

  const normalizedPrompt =
    typeof prompt ===
      "string"
      ? prompt.trim()
      : "";

  if (!normalizedPrompt) {
    const error =
      new Error(
        "GEMINI_EMPTY_IMAGE_PROMPT"
      );

    error.code =
      "GEMINI_EMPTY_IMAGE_PROMPT";

    throw error;
  }

  const images =
    normalizeImageDataUrls(
      imageDataUrls
    );

  const parts =
    buildGeminiParts(
      normalizedPrompt,
      imageDataUrls
    );

  if (!parts.length) {
    const error =
      new Error(
        "GEMINI_EMPTY_IMAGE_PROMPT"
      );

    error.code =
      "GEMINI_EMPTY_IMAGE_PROMPT";

    throw error;
  }

  const normalizedRatio =
    normalizeAspectRatio(
      aspectRatio
    );

  const normalizedSize =
    normalizeImageSize(
      imageSize
    );

  /*
   * Gemini's image generation API supports:
   * - text prompt
   * - reference images
   * - TEXT + IMAGE response
   * - aspect ratio
   * - output image size
   *
   * Reference images are therefore passed directly
   * as inlineData parts.
   */
  const body = {
    contents: [
      {
        role: "user",

        parts,
      },
    ],

    generationConfig: {
      responseModalities: [
        "TEXT",
        "IMAGE",
      ],

      responseFormat: {
        image: {
          aspectRatio:
            normalizedRatio,

          imageSize:
            normalizedSize,
        },
      },
    },
  };

  /*
   * Keep the number of images visible in diagnostics,
   * without ever returning their raw data in a status field.
   */
  const data =
    await geminiRequest(
      env,
      model,
      body
    );

  const image =
    extractGeminiImage(
      data
    );

  if (!image) {
    const error =
      new Error(
        "GEMINI_NO_IMAGE_RESULT"
      );

    error.code =
      "GEMINI_NO_IMAGE_RESULT";

    error.data =
      data;

    error.imageCount =
      images.length;

    throw error;
  }

  return {
    imageDataUrl:
      `data:${image.mimeType};base64,${image.base64}`,

    mimeType:
      image.mimeType,

    model,

    text:
      extractGeminiText(
        data
      ),

    imageCount:
      images.length,

    aspectRatio:
      normalizedRatio,

    imageSize:
      normalizedSize,

    raw:
      data,
  };
}

/* -------------------------------------------------------------------------- */
/* Provider status                                                            */
/* -------------------------------------------------------------------------- */

export function isGeminiConfigured(
  env
) {
  return Boolean(
    typeof env?.GEMINI_API_KEY ===
      "string" &&
      env.GEMINI_API_KEY.trim()
  );
}

export function getGeminiModels(
  env
) {
  return {
    text:
      getTextModel(env),

    image:
      getImageModel(env),
  };
}
