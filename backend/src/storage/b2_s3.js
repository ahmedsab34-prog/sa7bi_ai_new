const EMPTY_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
const encoder = new TextEncoder();

function encodeRfc3986(value) {
  return encodeURIComponent(String(value)).replace(/[!'()*]/g, (character) =>
    `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function toHex(bytes) {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value) {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
  return toHex(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
}

async function hmacSha256(key, value) {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value)));
}

function canonicalQuery(parameters) {
  const entries = [];
  for (const [key, value] of parameters.entries()) {
    entries.push([encodeRfc3986(key), encodeRfc3986(value)]);
  }
  entries.sort((left, right) => {
    if (left[0] !== right[0]) return left[0].localeCompare(right[0]);
    return left[1].localeCompare(right[1]);
  });
  return entries.map(([key, value]) => `${key}=${value}`).join("&");
}

function canonicalObjectPath(bucket, objectKey) {
  const encodedBucket = encodeRfc3986(bucket);
  const encodedKey = String(objectKey)
    .split("/")
    .map((part) => encodeRfc3986(part))
    .join("/");
  return `/${encodedBucket}/${encodedKey}`;
}

function normalizeHeaderValue(value) {
  return String(value).trim().replace(/\s+/g, " ");
}

function validateConfiguration(env) {
  const endpointValue = String(env.SA7BI_B2_ENDPOINT || "").trim();
  const bucket = String(env.SA7BI_B2_BUCKET || "").trim();
  const accessKeyId = String(env.SA7BI_B2_ACCESS_KEY_ID || "").trim();
  const secretAccessKey = String(env.SA7BI_B2_SECRET_ACCESS_KEY || "");
  const region = String(env.SA7BI_B2_REGION || "eu-central-003").trim();

  if (!endpointValue || !bucket || !accessKeyId || !secretAccessKey) {
    throw new Error("B2_STORAGE_CONFIGURATION_INCOMPLETE");
  }

  let endpoint;
  try {
    endpoint = new URL(endpointValue);
  } catch (_) {
    throw new Error("B2_STORAGE_ENDPOINT_INVALID");
  }

  if (
    endpoint.protocol !== "https:" ||
    !endpoint.hostname.endsWith(".backblazeb2.com") ||
    endpoint.username ||
    endpoint.password ||
    endpoint.search ||
    endpoint.hash ||
    (endpoint.pathname !== "/" && endpoint.pathname !== "")
  ) {
    throw new Error("B2_STORAGE_ENDPOINT_INVALID");
  }

  if (!/^[a-z0-9][a-z0-9.-]{1,62}[a-z0-9]$/i.test(bucket)) {
    throw new Error("B2_STORAGE_BUCKET_INVALID");
  }
  if (!/^[a-z0-9-]{1,64}$/i.test(region)) {
    throw new Error("B2_STORAGE_REGION_INVALID");
  }

  return { endpoint, bucket, accessKeyId, secretAccessKey, region };
}

export function createB2S3Client(env) {
  const config = validateConfiguration(env || {});

  async function request(method, objectKey, {
    body,
    contentType,
    cacheControl,
    metadata,
    range,
    versionId,
  } = {}) {
    if (typeof objectKey !== "string" || !objectKey || objectKey.length > 1024) {
      throw new Error("B2_OBJECT_KEY_INVALID");
    }

    const url = new URL(config.endpoint.origin);
    url.pathname = canonicalObjectPath(config.bucket, objectKey);

    const query = new URLSearchParams();
    if (versionId) query.set("versionId", versionId);
    const queryString = canonicalQuery(query);
    url.search = queryString;

    const headers = new Headers();
    const payloadBytes = body === undefined || body === null
      ? new Uint8Array(0)
      : body instanceof Uint8Array
          ? body
          : new Uint8Array(body);
    const payloadHash = method === "GET" || method === "DELETE"
      ? EMPTY_SHA256
      : await sha256Hex(payloadBytes);
    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]/g, "").replace(/\.\d{3}Z$/, "Z");
    const dateStamp = amzDate.slice(0, 8);

    headers.set("x-amz-content-sha256", payloadHash);
    headers.set("x-amz-date", amzDate);
    if (contentType) headers.set("content-type", contentType);
    if (cacheControl) headers.set("cache-control", cacheControl);
    if (range) headers.set("range", range);

    if (metadata && typeof metadata === "object") {
      for (const [rawName, rawValue] of Object.entries(metadata)) {
        const name = String(rawName).toLowerCase().replace(/[^a-z0-9-]/g, "-").slice(0, 80);
        if (!name || rawValue === undefined || rawValue === null) continue;
        const value = String(rawValue).replace(/[\r\n\u0000]/g, " ").slice(0, 1024);
        headers.set(`x-amz-meta-${name}`, value);
      }
    }

    const headerEntries = [["host", url.host]];
    for (const [name, value] of headers.entries()) {
      headerEntries.push([name.toLowerCase(), normalizeHeaderValue(value)]);
    }
    headerEntries.sort((left, right) => left[0].localeCompare(right[0]));

    const canonicalHeaders = headerEntries
      .map(([name, value]) => `${name}:${value}\n`)
      .join("");
    const signedHeaders = headerEntries.map(([name]) => name).join(";");
    const canonicalRequest = [
      method,
      url.pathname,
      queryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join("\n");

    const scope = `${dateStamp}/${config.region}/s3/aws4_request`;
    const stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      scope,
      await sha256Hex(encoder.encode(canonicalRequest)),
    ].join("\n");

    const kDate = await hmacSha256(encoder.encode(`AWS4${config.secretAccessKey}`), dateStamp);
    const kRegion = await hmacSha256(kDate, config.region);
    const kService = await hmacSha256(kRegion, "s3");
    const kSigning = await hmacSha256(kService, "aws4_request");
    const signature = toHex(await hmacSha256(kSigning, stringToSign));

    headers.set(
      "authorization",
      `AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    );

    let response;
    try {
      response = await fetch(url.toString(), {
        method,
        headers,
        ...(method === "PUT" ? { body: payloadBytes } : {}),
      });
    } catch (_) {
      const error = new Error("B2_NETWORK_OUTCOME_UNKNOWN");
      error.definiteFailure = false;
      throw error;
    }

    if (!response.ok) {
      const error = new Error(`B2_HTTP_${response.status}`);
      error.status = response.status;
      error.definiteFailure = response.status >= 400 &&
        response.status < 500 &&
        response.status !== 408 &&
        response.status !== 429;
      throw error;
    }

    return response;
  }

  return {
    async putObject(objectKey, bytes, options = {}) {
      const response = await request("PUT", objectKey, {
        body: bytes,
        contentType: options.httpMetadata?.contentType,
        cacheControl: options.httpMetadata?.cacheControl,
        metadata: options.customMetadata,
      });
      return {
        versionId: response.headers.get("x-amz-version-id") || "",
        etag: response.headers.get("etag") || "",
      };
    },

    async getObject(objectKey, { versionId, range, sizeBytes } = {}) {
      const rangeHeader = range
        ? `bytes=${range.offset}-${range.offset + range.length - 1}`
        : undefined;
      let response;
      try {
        response = await request("GET", objectKey, {
          versionId,
          range: rangeHeader,
        });
      } catch (error) {
        if (error?.status === 404) return null;
        throw error;
      }

      const metadata = {
        contentType: response.headers.get("content-type"),
        cacheControl: response.headers.get("cache-control"),
        contentDisposition: response.headers.get("content-disposition"),
        contentEncoding: response.headers.get("content-encoding"),
        contentLanguage: response.headers.get("content-language"),
        expires: response.headers.get("expires"),
      };

      return {
        body: response.body,
        size: Number(sizeBytes) || Number(response.headers.get("content-length")) || 0,
        httpEtag: response.headers.get("etag") || "",
        writeHttpMetadata(targetHeaders) {
          if (metadata.contentType) targetHeaders.set("Content-Type", metadata.contentType);
          if (metadata.cacheControl) targetHeaders.set("Cache-Control", metadata.cacheControl);
          if (metadata.contentDisposition) targetHeaders.set("Content-Disposition", metadata.contentDisposition);
          if (metadata.contentEncoding) targetHeaders.set("Content-Encoding", metadata.contentEncoding);
          if (metadata.contentLanguage) targetHeaders.set("Content-Language", metadata.contentLanguage);
          if (metadata.expires) targetHeaders.set("Expires", metadata.expires);
        },
      };
    },

    async deleteObject(objectKey, versionId) {
      if (typeof versionId !== "string" || !versionId) {
        throw new Error("B2_EXACT_VERSION_REQUIRED");
      }
      await request("DELETE", objectKey, { versionId });
      return { deleted: true, versionId };
    },
  };
}
