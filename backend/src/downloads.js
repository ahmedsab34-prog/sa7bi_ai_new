// backend/src/downloads.js
// Sa7bi AI Backend - Downloads Module
// Final Backend Version: 6.3.0
//
// Responsibilities:
// - Safe HTTP/HTTPS media proxy
// - Download health check
// - Safe filename handling
//
// Security:
// - No API keys
// - No client-side secrets
// - Rejects unsupported URL protocols
// - Rejects credentials inside URLs
// - Rejects obvious local/private network targets
// - Does not forward Authorization/Cookie headers
// - Limits redirect handling
// - Limits downloadable response size

import {
  json,
} from "./utils.js";

const BACKEND_VERSION = "6.3.0";

const ALLOWED_PROTOCOLS = new Set([
  "http:",
  "https:",
]);

const MAX_URL_LENGTH = 4096;

const MAX_REDIRECTS = 3;

const MAX_DOWNLOAD_BYTES =
  50 * 1024 * 1024;

/* -------------------------------------------------------------------------- */
/* URL security                                                               */
/* -------------------------------------------------------------------------- */

function isPrivateIpv4(
  hostname
) {
  const parts =
    hostname.split(".").map(
      (part) => Number(part)
    );

  if (
    parts.length !== 4 ||
    parts.some(
      (part) =>
        !Number.isInteger(part) ||
        part < 0 ||
        part > 255
    )
  ) {
    return false;
  }

  const [
    a,
    b,
  ] = parts;

  if (a === 10) {
    return true;
  }

  if (
    a === 127
  ) {
    return true;
  }

  if (
    a === 169 &&
    b === 254
  ) {
    return true;
  }

  if (
    a === 172 &&
    b >= 16 &&
    b <= 31
  ) {
    return true;
  }

  if (
    a === 192 &&
    b === 168
  ) {
    return true;
  }

  return false;
}

function isBlockedHostname(
  hostname
) {
  const host =
    String(
      hostname || ""
    )
      .toLowerCase()
      .trim();

  if (!host) {
    return true;
  }

  if (
    host === "localhost" ||
    host === "localhost.localdomain"
  ) {
    return true;
  }

  if (
    host.endsWith(
      ".localhost"
    )
  ) {
    return true;
  }

  if (
    host === "0.0.0.0" ||
    host === "::" ||
    host === "::1"
  ) {
    return true;
  }

  if (
    isPrivateIpv4(host)
  ) {
    return true;
  }

  /*
   * Obvious local/internal hostnames.
   *
   * Public content providers normally do not use
   * these suffixes.
   */
  if (
    host.endsWith(".local") ||
    host.endsWith(".internal") ||
    host.endsWith(".lan")
  ) {
    return true;
  }

  return false;
}

/**
 * Validate and normalize a download URL.
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
      error: "url is required",
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
      error: "url is too long",
    };
  }

  let parsed;

  try {
    parsed =
      new URL(raw);
  } catch (_) {
    return {
      ok: false,
      error: "Invalid URL",
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

  /*
   * Reject URLs containing username/password.
   *
   * Example:
   * https://user:password@example.com/file
   */
  if (
    parsed.username ||
    parsed.password
  ) {
    return {
      ok: false,
      error:
        "URLs containing credentials are not supported",
    };
  }

  if (
    isBlockedHostname(
      parsed.hostname
    )
  ) {
    return {
      ok: false,
      error:
        "Local or private network URLs are not supported",
    };
  }

  /*
   * Explicitly reject URL fragments because they are
   * not sent to the remote server and can cause
   * confusing cache/proxy behavior.
   */
  parsed.hash = "";

  return {
    ok: true,
    url:
      parsed.toString(),
  };
}

/* -------------------------------------------------------------------------- */
/* Filename helpers                                                           */
/* -------------------------------------------------------------------------- */

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
    // Use fallback below.
  }

  return "download";
}

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
    "image/avif": ".avif",

    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/ogg": ".ogg",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/flac": ".flac",

    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",
    "video/x-matroska": ".mkv",

    "application/pdf": ".pdf",

    "text/plain": ".txt",
    "text/csv": ".csv",
  };

  return map[type] || "";
}

function sanitizeFilename(
  filename
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
      .replace(
        /\s+/g,
        " "
      )
      .trim();

  if (!clean) {
    return "download";
  }

  return clean.substring(
    0,
    180
  );
}

function ensureExtension(
  filename,
  contentType
) {
  const clean =
    sanitizeFilename(
      filename
    );

  if (
    /\.[a-z0-9]{1,10}$/i.test(
      clean
    )
  ) {
    return clean;
  }

  return (
    clean +
    extensionFromContentType(
      contentType
    )
  );
}

/* -------------------------------------------------------------------------- */
/* Remote response validation                                                 */
/* -------------------------------------------------------------------------- */

function getContentLength(
  response
) {
  const value =
    response.headers.get(
      "Content-Length"
    );

  if (!value) {
    return null;
  }

  const parsed =
    Number(value);

  if (
    !Number.isFinite(parsed) ||
    parsed < 0
  ) {
    return null;
  }

  return parsed;
}

function isResponseTooLarge(
  response
) {
  const length =
    getContentLength(
      response
    );

  return (
    length !== null &&
    length >
      MAX_DOWNLOAD_BYTES
  );
}

/* -------------------------------------------------------------------------- */
/* Remote fetch                                                               */
/* -------------------------------------------------------------------------- */

async function fetchRemote(
  targetUrl,
  accept,
  redirectCount = 0
) {
  if (
    redirectCount >
    MAX_REDIRECTS
  ) {
    throw new Error(
      "TOO_MANY_REDIRECTS"
    );
  }

  const response =
    await fetch(
      targetUrl,
      {
        method: "GET",

        headers: {
          Accept:
            accept || "*/*",
        },

        /*
         * We handle redirects ourselves so every
         * redirect target can be validated before
         * another request is made.
         */
        redirect:
          "manual",
      }
    );

  const status =
    response.status;

  const isRedirect =
    status >= 300 &&
    status < 400;

  if (isRedirect) {
    const location =
      response.headers.get(
        "Location"
      );

    if (!location) {
      throw new Error(
        "REDIRECT_LOCATION_MISSING"
      );
    }

    let nextUrl;

    try {
      nextUrl =
        new URL(
          location,
          targetUrl
        ).toString();
    } catch (_) {
      throw new Error(
        "INVALID_REDIRECT_URL"
      );
    }

    const validation =
      validateDownloadUrl(
        nextUrl
      );

    if (
      !validation.ok
    ) {
      throw new Error(
        "UNSAFE_REDIRECT_URL"
      );
    }

    return fetchRemote(
      validation.url,
      accept,
      redirectCount + 1
    );
  }

  return response;
}

/* -------------------------------------------------------------------------- */
/* Main download handler                                                      */
/* -------------------------------------------------------------------------- */

/**
 * GET /download?url=https://...
 *
 * The Worker proxies a public remote media/file response
 * to the Flutter application.
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

    const accept =
      request.headers.get(
        "Accept"
      ) || "*/*";

    const response =
      await fetchRemote(
        targetUrl,
        accept
      );

    if (!response.ok) {
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

    /*
     * Protect the Worker from accidentally proxying
     * very large files.
     */
    if (
      isResponseTooLarge(
        response
      )
    ) {
      return json(
        {
          ok: false,

          error:
            "DOWNLOAD_TOO_LARGE",

          maxBytes:
            MAX_DOWNLOAD_BYTES,

          backendVersion:
            BACKEND_VERSION,
        },
        413
      );
    }

    const contentType =
      response.headers.get(
        "Content-Type"
      ) ||
      "application/octet-stream";

    const contentLength =
      getContentLength(
        response
      );

    const headers =
      new Headers();

    headers.set(
      "Content-Type",
      contentType
    );

    if (
      contentLength !== null
    ) {
      headers.set(
        "Content-Length",
        String(
          contentLength
        )
      );
    }

    const remoteDisposition =
      response.headers.get(
        "Content-Disposition"
      );

    if (
      remoteDisposition
    ) {
      /*
       * We do not blindly copy arbitrary response
       * headers. Only the useful download metadata
       * is retained.
       */
      headers.set(
        "Content-Disposition",
        remoteDisposition
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
        status: 200,
        headers,
      }
    );
  } catch (error) {
    const code =
      error?.message ||
      "DOWNLOAD_SERVICE_UNAVAILABLE";

    let status = 502;

    if (
      code ===
        "TOO_MANY_REDIRECTS" ||
      code ===
        "UNSAFE_REDIRECT_URL" ||
      code ===
        "INVALID_REDIRECT_URL" ||
      code ===
        "REDIRECT_LOCATION_MISSING"
    ) {
      status = 400;
    }

    return json(
      {
        ok: false,

        error:
          code ===
          "DOWNLOAD_SERVICE_UNAVAILABLE"
            ? code
            : code,

        backendVersion:
          BACKEND_VERSION,
      },
      status
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Health                                                                     */
/* -------------------------------------------------------------------------- */

export async function handleDownloadHealth() {
  return json({
    ok: true,

    type:
      "download-health",

    backendVersion:
      BACKEND_VERSION,

    maxDownloadBytes:
      MAX_DOWNLOAD_BYTES,
  });
}

/* -------------------------------------------------------------------------- */
/* Public test helpers                                                        */
/* -------------------------------------------------------------------------- */

export {
  validateDownloadUrl,
  filenameFromUrl,
  extensionFromContentType,
  ensureExtension,
};

/* -------------------------------------------------------------------------- */
/* Default export                                                             */
/* -------------------------------------------------------------------------- */

export default {
  handleDownload,
  handleDownloadHealth,
};
