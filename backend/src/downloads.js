// backend/src/downloads.js
// Sa7bi AI Backend - Downloads Module
// Version: 6.0.0

import {
  json,
} from "./utils.js";

const BACKEND_VERSION = "6.0.0";

/**
 * Allowed media URL protocols.
 *
 * We intentionally allow only HTTP/HTTPS URLs.
 */
const ALLOWED_PROTOCOLS = new Set([
  "http:",
  "https:",
]);

/**
 * Maximum URL length accepted by the download helper.
 */
const MAX_URL_LENGTH = 4096;

/**
 * Check whether a URL is valid and safe enough
 * for the backend's download/proxy route.
 */
function validateDownloadUrl(
  value
) {
  if (
    typeof value !== "string" ||
    !value.trim()
  ) {
    return {
      ok: false,
      error:
        "url is required",
    };
  }

  const raw =
    value.trim();

  if (
    raw.length >
    MAX_URL_LENGTH
  ) {
    return {
      ok: false,
      error:
        "url is too long",
    };
  }

  let parsed;

  try {
    parsed =
      new URL(raw);
  } catch (_) {
    return {
      ok: false,
      error:
        "Invalid URL",
    };
  }

  if (
    !ALLOWED_PROTOCOLS.has(
      parsed.protocol
    )
  ) {
    return {
      ok: false,
      error:
        "Only HTTP and HTTPS URLs are supported",
    };
  }

  return {
    ok: true,
    url:
      parsed.toString(),
  };
}

/**
 * Extract a filename from a URL.
 */
function filenameFromUrl(
  value
) {
  try {
    const parsed =
      new URL(value);

    const pathname =
      parsed.pathname || "";

    const last =
      pathname
        .split("/")
        .filter(Boolean)
        .pop();

    if (
      last &&
      last.length <= 180
    ) {
      try {
        return decodeURIComponent(
          last
        );
      } catch (_) {
        return last;
      }
    }
  } catch (_) {
    // Ignore and use fallback below.
  }

  return "download";
}

/**
 * Guess an extension from content type.
 */
function extensionFromContentType(
  contentType
) {
  const type =
    String(
      contentType || ""
    )
      .toLowerCase()
      .split(";")[0]
      .trim();

  const map = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",

    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/ogg": ".ogg",
    "audio/mp4": ".m4a",

    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",

    "application/pdf": ".pdf",

    "text/plain": ".txt",
  };

  return (
    map[type] || ""
  );
}

/**
 * Add a safe extension if the original filename
 * does not contain one.
 */
function ensureExtension(
  filename,
  contentType
) {
  const clean =
    String(
      filename ||
        "download"
    )
      .replace(
        /[<>:"/\\|?*\x00-\x1F]/g,
        "_"
      )
      .trim();

  if (
    /\.[a-z0-9]{1,8}$/i.test(
      clean
    )
  ) {
    return clean;
  }

  const extension =
    extensionFromContentType(
      contentType
    );

  return (
    clean +
    extension
  );
}

/**
 * Main download/proxy handler.
 *
 * Supported:
 *
 * GET /download?url=https://...
 *
 * The route streams the remote response back to
 * the Flutter application without exposing any
 * backend secret.
 */
export async function handleDownload(
  request
) {
  try {
    const requestUrl =
      new URL(
        request.url
      );

    const rawUrl =
      requestUrl.searchParams.get(
        "url"
      );

    const validation =
      validateDownloadUrl(
        rawUrl
      );

    if (
      !validation.ok
    ) {
      return json(
        {
          ok: false,
          error:
            validation.error,
          backendVersion:
            BACKEND_VERSION,
        },
        400
      );
    }

    const targetUrl =
      validation.url;

    const response =
      await fetch(
        targetUrl,
        {
          method: "GET",

          headers: {
            Accept:
              request.headers.get(
                "Accept"
              ) ||
              "*/*",
          },

          redirect:
            "follow",
        }
      );

    if (
      !response.ok
    ) {
      return json(
        {
          ok: false,

          error:
            "Remote download failed",

          status:
            response.status,

          backendVersion:
            BACKEND_VERSION,
        },
        502
      );
    }

    const headers =
      new Headers();

    const contentType =
      response.headers.get(
        "Content-Type"
      ) ||
      "application/octet-stream";

    headers.set(
      "Content-Type",
      contentType
    );

    const contentLength =
      response.headers.get(
        "Content-Length"
      );

    if (
      contentLength
    ) {
      headers.set(
        "Content-Length",
        contentLength
      );
    }

    const contentDisposition =
      response.headers.get(
        "Content-Disposition"
      );

    if (
      contentDisposition
    ) {
      headers.set(
        "Content-Disposition",
        contentDisposition
      );
    } else {
      const filename =
        ensureExtension(
          filenameFromUrl(
            targetUrl
          ),
          contentType
        );

      headers.set(
        "Content-Disposition",
        `inline; filename="${filename}"`
      );
    }

    headers.set(
      "Cache-Control",
      "public, max-age=3600"
    );

    headers.set(
      "Access-Control-Allow-Origin",
      "*"
    );

    return new Response(
      response.body,
      {
        status:
          response.status,

        headers,
      }
    );
  } catch (error) {
    return json(
      {
        ok: false,

        error:
          "Download service unavailable",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Lightweight endpoint for checking whether the
 * download module is available.
 */
export async function handleDownloadHealth() {
  return json({
    ok: true,

    type:
      "download-health",

    backendVersion:
      BACKEND_VERSION,
  });
}

/**
 * Export helpers for later tests.
 */
export {
  validateDownloadUrl,
  filenameFromUrl,
  extensionFromContentType,
  ensureExtension,
};

export default {
  handleDownload,
  handleDownloadHealth,
};
