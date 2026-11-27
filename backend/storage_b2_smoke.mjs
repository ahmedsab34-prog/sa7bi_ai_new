
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

const env = {
  // This deliberately present legacy binding must never be used by the adapter.
  SA7BI_STORAGE_PROVIDER: "r2",
  SA7BI_REELS: {
    async put() { throw new Error("LEGACY_STORAGE_MUST_NOT_BE_USED"); },
    async get() { throw new Error("LEGACY_STORAGE_MUST_NOT_BE_USED"); },
    async delete() { throw new Error("LEGACY_STORAGE_MUST_NOT_BE_USED"); },
  },
  SA7BI_B2_ENDPOINT: "https://s3.eu-central-003.backblazeb2.com",
  SA7BI_B2_BUCKET: "sa7bi-ai-storage",
  SA7BI_B2_REGION: "eu-central-003",
  SA7BI_B2_ACCESS_KEY_ID: "test-access-key",
  SA7BI_B2_SECRET_ACCESS_KEY: "test-secret-key-never-send",
  SA7BI_B2_MAX_BYTES: "64",
  SA7BI_B2_WARNING_BYTES: "48",
};

const actor = { ctx: { storage }, env };
const b2Versions = new Map();
let currentVersion = 0;
let rejectNextPutStatus = null;
let throwNextPutNetwork = false;
let omitNextVersionId = false;
let rejectNextDeleteStatus = null;
let lastRequest = null;
const originalFetch = globalThis.fetch;

globalThis.fetch = async (input, init = {}) => {
  const url = new URL(input);
  const method = init.method || "GET";
  const headers = new Headers(init.headers || {});
  lastRequest = { url, method, headers };
  const key = decodeURIComponent(url.pathname.replace(/^\/sa7bi-ai-storage\//, ""));

  if (method === "PUT") {
    const bytes = Buffer.from(await new Response(init.body).arrayBuffer());
    const versionId = `b2-version-${++currentVersion}`;

    // Simulate the ambiguous case where B2 stored the object but the response
    // was lost before the Worker could receive the version ID.
    b2Versions.set(`${key}:${versionId}`, bytes);

    if (throwNextPutNetwork) {
      throwNextPutNetwork = false;
      throw new Error("simulated network break after B2 stored the object");
    }

    if (rejectNextPutStatus) {
      const status = rejectNextPutStatus;
      rejectNextPutStatus = null;
      return new Response("not exposed", { status });
    }

    const responseHeaders = { etag: '"mock-etag"' };
    if (!omitNextVersionId) responseHeaders["x-amz-version-id"] = versionId;
    omitNextVersionId = false;

    return new Response(null, { status: 200, headers: responseHeaders });
  }

  if (method === "GET") {
    const versionId = url.searchParams.get("versionId");
    const bytes = b2Versions.get(`${key}:${versionId}`);
    if (!bytes) return new Response(null, { status: 404 });

    const range = headers.get("range");
    let output = bytes;
    let status = 200;
    const responseHeaders = {
      "content-type": "video/mp4",
      "cache-control": "private, no-store",
      "content-length": String(bytes.length),
      etag: '"mock-etag"',
    };

    if (range) {
      const match = /^bytes=(\d+)-(\d+)$/.exec(range);
      assert.ok(match, "range header must be explicit and valid");
      const start = Number(match[1]);
      const end = Number(match[2]);
      output = bytes.subarray(start, end + 1);
      status = 206;
      responseHeaders["content-length"] = String(output.length);
      responseHeaders["content-range"] = `bytes ${start}-${end}/${bytes.length}`;
    }

    return new Response(output, { status, headers: responseHeaders });
  }

  if (method === "DELETE") {
    const versionId = url.searchParams.get("versionId");
    assert.ok(versionId, "B2 DELETE must specify versionId");
    if (rejectNextDeleteStatus) {
      const status = rejectNextDeleteStatus;
      rejectNextDeleteStatus = null;
      return new Response("delete not confirmed", { status });
    }
    b2Versions.delete(`${key}:${versionId}`);
    return new Response(null, { status: 204 });
  }

  return new Response(null, { status: 405 });
};

try {
  const bucket = createStorageBucketAdapter(actor, env);

  // New upload, signature shape, metadata and quota reservation/commit.
  const payload = Buffer.from("0123456789");
  const put = await bucket.put("reels/test.mp4", payload, {
    httpMetadata: {
      contentType: "video/mp4",
      cacheControl: "private, no-store",
    },
    customMetadata: { reelId: "test-reel", ownerId: "test-owner" },
  });

  assert.equal(put.versionId, "b2-version-1");
  assert.equal(lastRequest.method, "PUT");
  assert.match(lastRequest.headers.get("authorization"), /^AWS4-HMAC-SHA256 /);
  assert.match(lastRequest.headers.get("authorization"), /Credential=test-access-key\//);
  assert.match(lastRequest.headers.get("authorization"), /SignedHeaders=.*host/);
  assert.equal(lastRequest.headers.get("content-type"), "video/mp4");
  assert.equal(lastRequest.headers.get("x-amz-meta-reelid"), "test-reel");
  assert.ok(![...lastRequest.headers.values()].join("\n").includes(env.SA7BI_B2_SECRET_ACCESS_KEY));
  assert.equal(getStorageStatus(actor).usedBytes, payload.length);
  assert.equal(getStorageStatus(actor).objectCount, 1);

  // Exact-version GET and byte-range forwarding.
  const ranged = await bucket.get("reels/test.mp4", {
    range: { offset: 2, length: 4 },
  });
  assert.ok(ranged);
  assert.equal(lastRequest.method, "GET");
  assert.equal(new URL(lastRequest.url).searchParams.get("versionId"), "b2-version-1");
  assert.equal(lastRequest.headers.get("range"), "bytes=2-5");
  assert.equal(Buffer.from(await new Response(ranged.body).arrayBuffer()).toString(), "2345");
  assert.equal(ranged.size, payload.length);

  // A missing ledger record must fail closed; no R2/legacy fallback is allowed.
  assert.equal(await bucket.get("reels/untracked.mp4"), null);
  await assert.rejects(bucket.delete("reels/untracked.mp4"), /STORAGE_OBJECT_NOT_FOUND/);

  // Quota is checked before a new network request.
  const beforeBlockedPut = lastRequest.url.toString();
  await assert.rejects(
    bucket.put("reels/too-large.mp4", Buffer.alloc(65)),
    /STORAGE_CAPACITY_EXCEEDED/,
  );
  assert.equal(lastRequest.url.toString(), beforeBlockedPut);

  // Exact-version delete frees quota only after B2 confirms the DELETE.
  await bucket.delete("reels/test.mp4");
  assert.equal(lastRequest.method, "DELETE");
  assert.equal(new URL(lastRequest.url).searchParams.get("versionId"), "b2-version-1");
  assert.equal(getStorageStatus(actor).usedBytes, 0);
  assert.equal(getStorageStatus(actor).objectCount, 0);

  // Concurrent uploads cannot both reserve more capacity than the limit.
  const concurrent = await Promise.allSettled([
    bucket.put("reels/concurrent-a.mp4", Buffer.alloc(40)),
    bucket.put("reels/concurrent-b.mp4", Buffer.alloc(40)),
  ]);
  assert.equal(concurrent.filter((item) => item.status === "fulfilled").length, 1);
  assert.equal(concurrent.filter((item) => item.status === "rejected").length, 1);
  assert.equal(getStorageStatus(actor).usedBytes, 40);
  const concurrentWinner = concurrent[0].status === "fulfilled"
    ? "reels/concurrent-a.mp4"
    : "reels/concurrent-b.mp4";
  await bucket.delete(concurrentWinner);
  assert.equal(getStorageStatus(actor).usedBytes, 0);

  // A failed DELETE must not release quota; a confirmed retry may release it.
  await bucket.put("reels/delete-retry.mp4", Buffer.from("delete-me"));
  rejectNextDeleteStatus = 500;
  await assert.rejects(bucket.delete("reels/delete-retry.mp4"), /B2_HTTP_500/);
  assert.equal(getStorageStatus(actor).usedBytes, 9);
  await bucket.delete("reels/delete-retry.mp4");
  assert.equal(getStorageStatus(actor).usedBytes, 0);

  // A definite client rejection releases the reservation.
  rejectNextPutStatus = 403;
  await assert.rejects(bucket.put("reels/denied.mp4", Buffer.from("1234")), /B2_HTTP_403/);
  assert.equal(getStorageStatus(actor).usedBytes, 0);

  // Ambiguous network outcome keeps the reservation even if B2 may have stored it.
  throwNextPutNetwork = true;
  await assert.rejects(
    bucket.put("reels/uncertain.mp4", Buffer.from("12345")),
    /B2_NETWORK_OUTCOME_UNKNOWN/,
  );
  assert.equal(getStorageStatus(actor).usedBytes, 5);
  assert.equal(getStorageStatus(actor).objectCount, 1);

  // A successful PUT without a version ID also keeps its reservation.
  omitNextVersionId = true;
  await assert.rejects(
    bucket.put("reels/no-version.mp4", Buffer.from("123456")),
    /B2_VERSION_ID_MISSING/,
  );
  assert.equal(getStorageStatus(actor).usedBytes, 11);
  assert.equal(getStorageStatus(actor).objectCount, 2);

  // No R2 calls occurred; R2 provider configuration is ignored by design.
  console.log("B2-only storage smoke test: PASS");
} finally {
  globalThis.fetch = originalFetch;
  db.close();
}
