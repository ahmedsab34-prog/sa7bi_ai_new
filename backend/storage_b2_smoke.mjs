import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { webcrypto } from "node:crypto";
import { createStorageBucketAdapter } from "./src/storage/storage_bucket.js";
import { getStorageStatus } from "./src/storage/storage_quota.js";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const db = new DatabaseSync(":memory:");
const sql = {
  exec(query, ...params) {
    const statement = db.prepare(query);
    const normalized = query.trim().toUpperCase();
    if (normalized.startsWith("SELECT") || normalized.startsWith("PRAGMA")) {
      const rows = statement.all(...params);
      return { toArray: () => rows, rowsWritten: 0 };
    }
    const result = statement.run(...params);
    return { toArray: () => [], rowsWritten: Number(result.changes || 0) };
  },
};

const storage = {
  sql,
  transactionSync(callback) {
    db.exec("BEGIN IMMEDIATE");
    try {
      const result = callback();
      db.exec("COMMIT");
      return result;
    } catch (error) {
      db.exec("ROLLBACK");
      throw error;
    }
  },
};

const r2Objects = new Map();
const r2Bucket = {
  async put(key, value) {
    r2Objects.set(key, Buffer.from(await new Response(value).arrayBuffer()));
  },
  async get(key, options = {}) {
    const bytes = r2Objects.get(key);
    if (!bytes) return null;
    const start = options.range?.offset ?? 0;
    const end = options.range ? start + options.range.length : bytes.length;
    const selected = bytes.subarray(start, end);
    return {
      body: new Response(selected).body,
      size: bytes.length,
      httpEtag: '"r2-etag"',
      writeHttpMetadata(headers) {
        headers.set("Content-Type", "application/octet-stream");
      },
    };
  },
  async delete(key) {
    r2Objects.delete(key);
  },
};

const env = {
  SA7BI_STORAGE_PROVIDER: "b2",
  SA7BI_B2_ENDPOINT: "https://s3.eu-central-003.backblazeb2.com",
  SA7BI_B2_BUCKET: "sa7bi-ai-storage",
  SA7BI_B2_REGION: "eu-central-003",
  SA7BI_B2_ACCESS_KEY_ID: "test-access-key",
  SA7BI_B2_SECRET_ACCESS_KEY: "test-secret-key",
  SA7BI_B2_MAX_BYTES: "16",
  SA7BI_B2_WARNING_BYTES: "12",
  SA7BI_REELS: r2Bucket,
};

const actor = { ctx: { storage }, env };
const b2Versions = new Map();
let currentVersion = 0;
let rejectNextPutStatus = null;
let throwNextPutNetwork = false;
let lastRequest = null;
const originalFetch = globalThis.fetch;

globalThis.fetch = async (input, init = {}) => {
  const url = new URL(input);
  const method = init.method || "GET";
  const headers = new Headers(init.headers || {});
  lastRequest = { url, method, headers };
  const key = decodeURIComponent(url.pathname.replace(/^\/sa7bi-ai-storage\//, ""));

  if (method === "PUT") {
    if (throwNextPutNetwork) {
      throwNextPutNetwork = false;
      throw new Error("simulated network break after request dispatch");
    }
    if (rejectNextPutStatus) {
      const status = rejectNextPutStatus;
      rejectNextPutStatus = null;
      return new Response("not exposed", { status });
    }
    const bytes = Buffer.from(await new Response(init.body).arrayBuffer());
    const versionId = `b2-version-${++currentVersion}`;
    b2Versions.set(`${key}:${versionId}`, bytes);
    return new Response(null, {
      status: 200,
      headers: { "x-amz-version-id": versionId, etag: '"mock-etag"' },
    });
  }

  if (method === "GET") {
    const versionId = url.searchParams.get("versionId");
    const bytes = b2Versions.get(`${key}:${versionId}`);
    if (!bytes) return new Response(null, { status: 404 });
    const range = headers.get("range");
    let output = bytes;
    if (range) {
      const match = /^bytes=(\d+)-(\d+)$/.exec(range);
      assert.ok(match, "range header must be explicit and valid");
      output = bytes.subarray(Number(match[1]), Number(match[2]) + 1);
    }
    return new Response(output, {
      status: 200,
      headers: {
        "content-type": "video/mp4",
        "cache-control": "private, no-store",
        "content-length": String(output.length),
        etag: '"mock-etag"',
      },
    });
  }

  if (method === "DELETE") {
    const versionId = url.searchParams.get("versionId");
    assert.ok(versionId, "B2 DELETE must specify versionId");
    b2Versions.delete(`${key}:${versionId}`);
    return new Response(null, { status: 204 });
  }

  return new Response(null, { status: 405 });
};

try {
  const bucket = createStorageBucketAdapter(actor, env);

  const payload = Buffer.from("0123456789");
  await bucket.put("reels/test.mp4", payload, {
    httpMetadata: {
      contentType: "video/mp4",
      cacheControl: "private, no-store",
    },
    customMetadata: { reelId: "test-reel", ownerId: "test-owner" },
  });

  assert.equal(lastRequest.method, "PUT");
  assert.match(lastRequest.headers.get("authorization"), /^AWS4-HMAC-SHA256 /);
  assert.match(lastRequest.headers.get("authorization"), /Credential=test-access-key\//);
  assert.match(lastRequest.headers.get("authorization"), /SignedHeaders=.*host/);
  assert.equal(getStorageStatus(actor).usedBytes, payload.length);
  assert.equal(getStorageStatus(actor).objectCount, 1);

  const ranged = await bucket.get("reels/test.mp4", {
    range: { offset: 2, length: 4 },
  });
  assert.ok(ranged);
  assert.equal(lastRequest.method, "GET");
  assert.equal(new URL(lastRequest.url).searchParams.get("versionId"), "b2-version-1");
  assert.equal(lastRequest.headers.get("range"), "bytes=2-5");
  assert.equal(Buffer.from(await new Response(ranged.body).arrayBuffer()).toString(), "2345");
  assert.equal(ranged.size, payload.length);

  const beforeBlockedPut = lastRequest.url.toString();
  await assert.rejects(
    bucket.put("reels/too-large.mp4", Buffer.alloc(7)),
    /STORAGE_CAPACITY_EXCEEDED/,
  );
  assert.equal(lastRequest.url.toString(), beforeBlockedPut);

  await bucket.delete("reels/test.mp4");
  assert.equal(lastRequest.method, "DELETE");
  assert.equal(new URL(lastRequest.url).searchParams.get("versionId"), "b2-version-1");
  assert.equal(getStorageStatus(actor).usedBytes, 0);
  assert.equal(getStorageStatus(actor).objectCount, 0);

  rejectNextPutStatus = 403;
  await assert.rejects(bucket.put("reels/denied.mp4", Buffer.from("1234")), /B2_HTTP_403/);
  assert.equal(getStorageStatus(actor).usedBytes, 0);

  throwNextPutNetwork = true;
  await assert.rejects(bucket.put("reels/uncertain.mp4", Buffer.from("12345")), /B2_NETWORK_OUTCOME_UNKNOWN/);
  assert.equal(getStorageStatus(actor).usedBytes, 5);
  assert.equal(getStorageStatus(actor).objectCount, 1);

  r2Objects.set("reels/old-r2.mp4", Buffer.from("legacy"));
  const oldR2 = await bucket.get("reels/old-r2.mp4");
  assert.ok(oldR2);
  assert.equal(Buffer.from(await new Response(oldR2.body).arrayBuffer()).toString(), "legacy");
  await bucket.delete("reels/old-r2.mp4");
  assert.equal(r2Objects.has("reels/old-r2.mp4"), false);

  console.log("B2 hybrid storage smoke test: PASS");
} finally {
  globalThis.fetch = originalFetch;
  db.close();
}
