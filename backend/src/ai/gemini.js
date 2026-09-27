const DEFAULT_GEMINI_TEXT_MODEL =
  "gemini-3.8-flash";

const DEFAULT_GEMINI_IMAGE_MODEL =
  "gemini-3.1-flash-image";

const GEMINI_API_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";

function getGeminiApiKey(env) {
  const key =
    typeof env?.GEMINI_API_KEY === "string"
      ? env.GEMINI_API_KEY.trim()
      : "";

  if (!key) {
    throw new Error("GEMINI_API_KEY_MISSING");
  }

  return key;
}

function getTextModel(env) {
  return (
    env?.GEMINI_TEXT_MODEL ||
    DEFAULT_GEMINI_TEXT_MODEL
  );
}

function getImageModel(env) {
  return (
    env?.GEMINI_IMAGE_MODEL ||
    DEFAULT_GEMINI_IMAGE_MODEL
  );
}

function getErrorMessage(data, status) {
  return (
    data?.error?.message ||
    data?.message ||
    `Gemini HTTP ${status}`
  );
}

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

  const response =
    await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type":
          "application/json",
        "x-goog-api-key":
          apiKey,
      },
      body: JSON.stringify(body),
    });

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

    error.data = data;

    throw error;
  }

  return data;
}

function extractGeminiParts(data) {
  const parts = [];

  const candidates =
    Array.isArray(
      data?.candidates
    )
      ? data.candidates
      : [];

  for (
    const candidate of candidates
  ) {
    const candidateParts =
      Array.isArray(
        candidate?.content?.parts
      )
        ? candidate.content.parts
        : [];

    for (
      const part of candidateParts
    ) {
      if (part) {
        parts.push(part);
      }
    }
  }

  return parts;
}

function extractGeminiText(data) {
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

function extractGeminiImage(data) {
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

  const match =
    dataUrl.match(
      /^data:([^;,]+);base64,(.+)$/s
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
      text: text.trim(),
    });
  }

  for (
    const imageDataUrl of
      imageDataUrls
  ) {
    const parsed =
      dataUrlParts(
        imageDataUrl
      );

    if (!parsed) {
      continue;
    }

    parts.push({
      inlineData: {
        mimeType:
          parsed.mimeType,
        data:
          parsed.data,
      },
    });
  }

  return parts;
}

function buildContents(
  messages,
  imageDataUrls = [],
  imagePrompt = ""
) {
  const contents = [];

  for (
    const message of
      Array.isArray(messages)
        ? messages
        : []
  ) {
    const role =
      message?.role ===
      "assistant"
        ? "model"
        : "user";

    const text =
      typeof message?.content ===
        "string"
        ? message.content.trim()
        : "";

    if (!text) {
      continue;
    }

    contents.push({
      role,
      parts: [
        {
          text,
        },
      ],
    });
  }

  if (
    imageDataUrls.length
  ) {
    const parts =
      buildGeminiParts(
        imagePrompt ||
          "حلل الصور المرفقة بدقة، واقرأ النصوص الواضحة فيها، واشرح الأشياء المهمة الظاهرة فقط دون تخمين."
        ,
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

export async function generateGeminiText({
  env,
  messages,
  instructions,
  imageDataUrls = [],
  imagePrompt = "",
  maxOutputTokens = 1200,
}) {
  const model =
    getTextModel(env);

  const contents =
    buildContents(
      messages,
      imageDataUrls,
      imagePrompt
    );

  if (!contents.length) {
    throw new Error(
      "GEMINI_EMPTY_CONTENT"
    );
  }

  const body = {
    contents,
    generationConfig: {
      maxOutputTokens:
        Math.max(
          64,
          Math.min(
            Number(
              maxOutputTokens
            ) || 1200,
            4096
          )
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
    extractGeminiText(data);

  if (!answer) {
    const error =
      new Error(
        "GEMINI_EMPTY_RESPONSE"
      );

    error.code =
      "GEMINI_EMPTY_RESPONSE";

    error.data = data;

    throw error;
  }

  return {
    answer,
    model,
    raw: data,
  };
}

export async function generateGeminiImage({
  env,
  prompt,
  imageDataUrls = [],
  aspectRatio = "1:1",
  imageSize = "1K",
}) {
  const model =
    getImageModel(env);

  const parts =
    buildGeminiParts(
      prompt,
      imageDataUrls
    );

  if (!parts.length) {
    throw new Error(
      "GEMINI_EMPTY_IMAGE_PROMPT"
    );
  }

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
          aspectRatio,
          imageSize,
        },
      },
    },
  };

  const data =
    await geminiRequest(
      env,
      model,
      body
    );

  const image =
    extractGeminiImage(data);

  if (!image) {
    const error =
      new Error(
        "GEMINI_NO_IMAGE_RESULT"
      );

    error.code =
      "GEMINI_NO_IMAGE_RESULT";

    error.data = data;

    throw error;
  }

  return {
    imageDataUrl:
      `data:${image.mimeType};base64,${image.base64}`,
    mimeType:
      image.mimeType,
    model,
    text:
      extractGeminiText(data),
    raw: data,
  };
}

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
