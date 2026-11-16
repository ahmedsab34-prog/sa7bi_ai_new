// Sa7bi Connect private attachments.
// Files are stored in the existing SA7BI_REELS R2 bucket under a private
// prefix. No public URL is returned; every download is authenticated and
// re-checks conversation/group membership in the Sa7biSocial Durable Object.

const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
const UUID_PATTERN = /^[a-f0-9-]{36}$/i;
const ALLOWED_TYPES = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
  ["image/gif", "gif"],
  ["audio/mp4", "m4a"],
  ["audio/aac", "aac"],
  ["audio/mpeg", "mp3"],
  ["audio/ogg", "ogg"],
  ["audio/webm", "webm"],
  ["application/pdf", "pdf"],
  ["text/plain", "txt"],
]);

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function ensureAttachmentTables(actor) {
  // These CREATE TABLE IF NOT EXISTS statements make the attachment route
  // safe on older Durable Object instances before their first chat request.
  actor.ctx.storage.sql.exec(`
    CREATE TABLE IF NOT EXISTS social_conversations (
      id TEXT PRIMARY KEY,
      user_a TEXT NOT NULL,
      user_b TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_a, user_b)
    )
  `);

  actor.ctx.storage.sql.exec(`
    CREATE TABLE IF NOT EXISTS social_group_members (
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'member',
      joined_at INTEGER NOT NULL,
      last_read_at INTEGER,
      PRIMARY KEY(group_id, user_id)
    )
  `);

  actor.ctx.storage.sql.exec(`
    CREATE TABLE IF NOT EXISTS social_attachments (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      scope_type TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      object_key TEXT NOT NULL UNIQUE,
      file_name TEXT NOT NULL,
      content_type TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  `);

  actor.ctx.storage.sql.exec(`
    CREATE INDEX IF NOT EXISTS social_attachments_scope_idx
    ON social_attachments(scope_type, scope_id, created_at DESC)
  `);

  actor.ctx.storage.sql.exec(`
    CREATE INDEX IF NOT EXISTS social_attachments_owner_idx
    ON social_attachments(owner_id, created_at DESC)
  `);
}

function attachmentBucket(actor) {
  return actor.env?.SA7BI_REELS || null;
}

function decodeBase64UrlText(value) {
  if (typeof value !== "string" || value.length > 1024) return "";

  try {
    const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch (_) {
    return "";
  }
}

function cleanFileName(value) {
  if (typeof value !== "string") return "attachment";

  const cleaned = value
    .normalize("NFC")
    .replace(/[\\/\u0000-\u001f\u007f<>:"|?*]/g, "_")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120);

  return cleaned || "attachment";
}

function isScopeAccessible(actor, userId, scopeType, scopeId) {
  if (!UUID_PATTERN.test(scopeId || "")) return false;

  if (scopeType === "conversation") {
    const conversation = actor.ctx.storage.sql.exec(
      `SELECT id, user_a, user_b
       FROM social_conversations
       WHERE id = ?
       LIMIT 1`,
      scopeId,
    ).toArray()[0];

    return Boolean(
      conversation &&
      (conversation.user_a === userId || conversation.user_b === userId),
    );
  }

  if (scopeType === "group") {
    const membership = actor.ctx.storage.sql.exec(
      `SELECT group_id
       FROM social_group_members
       WHERE group_id = ? AND user_id = ?
       LIMIT 1`,
      scopeId,
      userId,
    ).toArray()[0];

    return Boolean(membership);
  }

  return false;
}

function hasExpectedSignature(contentType, bytes) {
  const startsWith = (signature) =>
    bytes.length >= signature.length &&
    signature.every((value, index) => bytes[index] === value);

  switch (contentType) {
    case "image/jpeg":
      return startsWith([0xff, 0xd8, 0xff]);
    case "image/png":
      return startsWith([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    case "image/gif":
      return startsWith([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
        startsWith([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
    case "image/webp":
      return bytes.length >= 12 &&
        startsWith([0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] === 0x57 && bytes[9] === 0x45 &&
        bytes[10] === 0x42 && bytes[11] === 0x50;
    case "audio/mp4":
      return bytes.length >= 12 &&
        bytes[4] === 0x66 && bytes[5] === 0x74 &&
        bytes[6] === 0x79 && bytes[7] === 0x70;
    case "audio/ogg":
      return startsWith([0x4f, 0x67, 0x67, 0x53]);
    case "audio/webm":
      return startsWith([0x1a, 0x45, 0xdf, 0xa3]);
    case "audio/mpeg":
      return startsWith([0x49, 0x44, 0x33]) ||
        (bytes.length >= 2 && bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0);
    case "audio/aac":
      return bytes.length >= 2 && bytes[0] === 0xff &&
        ((bytes[1] & 0xf6) === 0xf0);
    case "application/pdf":
      return startsWith([0x25, 0x50, 0x44, 0x46, 0x2d]);
    case "text/plain":
      return !bytes.slice(0, Math.min(bytes.length, 4096)).includes(0);
    default:
      return false;
  }
}

async function readLimitedBody(request, maximumBytes) {
  if (!request.body) return { bytes: null, error: "EMPTY_UPLOAD" };

  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;

  try {
    while (true) {
      const result = await reader.read();
      if (result.done) break;

      total += result.value.byteLength;
      if (total > maximumBytes) {
        try { await reader.cancel(); } catch (_) {}
        return { bytes: null, error: "ATTACHMENT_TOO_LARGE" };
      }

      chunks.push(result.value);
    }
  } finally {
    reader.releaseLock();
  }

  if (total === 0) return { bytes: null, error: "EMPTY_UPLOAD" };

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return { bytes, error: null };
}

function attachmentPayload(row) {
  return {
    id: row.id,
    fileName: row.file_name,
    contentType: row.content_type,
    sizeBytes: Number(row.size_bytes) || 0,
    createdAt: Number(row.created_at) || 0,
  };
}

async function uploadAttachment(request, actor, user) {
  const bucket = attachmentBucket(actor);
  if (!bucket) {
    return json({ ok: false, error: "ATTACHMENT_STORAGE_NOT_CONFIGURED" }, 503);
  }

  const scopeType = (request.headers.get("X-Sa7bi-Attachment-Scope") || "")
    .trim()
    .toLowerCase();
  const scopeId = (request.headers.get("X-Sa7bi-Attachment-Scope-Id") || "")
    .trim()
    .toLowerCase();
  const fileName = cleanFileName(
    decodeBase64UrlText(request.headers.get("X-Sa7bi-Attachment-Filename") || ""),
  );
  const contentType = (request.headers.get("Content-Type") || "")
    .split(";")[0]
    .trim()
    .toLowerCase();

  if (!ALLOWED_TYPES.has(contentType)) {
    return json({ ok: false, error: "UNSUPPORTED_ATTACHMENT_TYPE" }, 415);
  }

  if (scopeType !== "conversation" && scopeType !== "group") {
    return json({ ok: false, error: "INVALID_ATTACHMENT_SCOPE" }, 400);
  }

  if (!UUID_PATTERN.test(scopeId)) {
    return json({ ok: false, error: "INVALID_ATTACHMENT_SCOPE_ID" }, 400);
  }

  if (!isScopeAccessible(actor, user.id, scopeType, scopeId)) {
    return json({ ok: false, error: "ATTACHMENT_SCOPE_ACCESS_DENIED" }, 403);
  }

  const declaredLength = Number(request.headers.get("Content-Length") || 0);
  if (!Number.isSafeInteger(declaredLength) || declaredLength <= 0) {
    return json({ ok: false, error: "CONTENT_LENGTH_REQUIRED" }, 411);
  }

  if (declaredLength > MAX_ATTACHMENT_BYTES) {
    return json({
      ok: false,
      error: "ATTACHMENT_TOO_LARGE",
      maxBytes: MAX_ATTACHMENT_BYTES,
    }, 413);
  }

  const usage = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS file_count, COALESCE(SUM(size_bytes), 0) AS total_bytes
     FROM social_attachments
     WHERE owner_id = ? AND created_at >= ?`,
    user.id,
    Date.now() - 24 * 60 * 60 * 1000,
  ).toArray()[0] || {};

  if (Number(usage.file_count || 0) >= 50 ||
      Number(usage.total_bytes || 0) + declaredLength > 100 * 1024 * 1024) {
    return json({
      ok: false,
      error: "ATTACHMENT_DAILY_LIMIT",
      maxFilesPerDay: 50,
      maxBytesPerDay: 100 * 1024 * 1024,
    }, 429);
  }

  const upload = await readLimitedBody(request, MAX_ATTACHMENT_BYTES);
  if (upload.error) {
    return json({
      ok: false,
      error: upload.error,
      maxBytes: MAX_ATTACHMENT_BYTES,
    }, upload.error === "ATTACHMENT_TOO_LARGE" ? 413 : 400);
  }

  const bytes = upload.bytes;
  if (bytes.byteLength !== declaredLength) {
    return json({ ok: false, error: "UPLOAD_SIZE_MISMATCH" }, 400);
  }

  if (!hasExpectedSignature(contentType, bytes)) {
    return json({ ok: false, error: "ATTACHMENT_CONTENT_MISMATCH" }, 415);
  }

  const id = crypto.randomUUID();
  const now = Date.now();
  const extension = ALLOWED_TYPES.get(contentType);
  const objectKey = `private-attachments/${scopeType}/${scopeId}/${user.id}/${id}.${extension}`;

  try {
    await bucket.put(objectKey, bytes, {
      httpMetadata: {
        contentType,
        cacheControl: "private, no-store, max-age=0",
      },
      customMetadata: {
        attachmentId: id,
        ownerId: user.id,
        scopeType,
        scopeId,
        uploadedAt: String(now),
      },
    });
  } catch (_) {
    return json({ ok: false, error: "ATTACHMENT_STORAGE_WRITE_FAILED" }, 503);
  }

  try {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_attachments
       (id, owner_id, scope_type, scope_id, object_key,
        file_name, content_type, size_bytes, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      id,
      user.id,
      scopeType,
      scopeId,
      objectKey,
      fileName,
      contentType,
      bytes.byteLength,
      now,
    );
  } catch (_) {
    try { await bucket.delete(objectKey); } catch (_) {}
    return json({ ok: false, error: "ATTACHMENT_METADATA_SAVE_FAILED" }, 500);
  }

  return json({
    ok: true,
    attachment: {
      id,
      fileName,
      contentType,
      sizeBytes: bytes.byteLength,
      createdAt: now,
    },
  }, 201);
}

function contentDisposition(fileName) {
  const asciiName = fileName.replace(/[^\x20-\x7e]/g, "_").replace(/["\\;]/g, "_");
  const encodedName = encodeURIComponent(fileName)
    .replace(/[!'()*]/g, (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`);

  return `attachment; filename="${asciiName}"; filename*=UTF-8''${encodedName}`;
}

async function downloadAttachment(request, actor, user, attachmentId) {
  const bucket = attachmentBucket(actor);
  if (!bucket) return json({ ok: false, error: "ATTACHMENT_STORAGE_NOT_CONFIGURED" }, 503);

  const row = actor.ctx.storage.sql.exec(
    `SELECT id, owner_id, scope_type, scope_id, object_key,
            file_name, content_type, size_bytes, created_at
     FROM social_attachments
     WHERE id = ?
     LIMIT 1`,
    attachmentId,
  ).toArray()[0];

  if (!row) return json({ ok: false, error: "ATTACHMENT_NOT_FOUND" }, 404);

  if (!isScopeAccessible(actor, user.id, row.scope_type, row.scope_id)) {
    return json({ ok: false, error: "ATTACHMENT_ACCESS_DENIED" }, 403);
  }

  let object;
  try {
    object = await bucket.get(row.object_key);
  } catch (_) {
    return json({ ok: false, error: "ATTACHMENT_STORAGE_READ_FAILED" }, 503);
  }

  if (!object) return json({ ok: false, error: "ATTACHMENT_NOT_FOUND" }, 404);

  return new Response(object.body, {
    status: 200,
    headers: {
      "Content-Type": row.content_type,
      "Content-Length": String(Number(row.size_bytes) || object.size || 0),
      "Content-Disposition": contentDisposition(row.file_name),
      "Cache-Control": "private, no-store, max-age=0",
      "X-Content-Type-Options": "nosniff",
      "Cross-Origin-Resource-Policy": "same-site",
    },
  });
}

async function deleteAttachment(actor, user, attachmentId) {
  const bucket = attachmentBucket(actor);
  if (!bucket) return json({ ok: false, error: "ATTACHMENT_STORAGE_NOT_CONFIGURED" }, 503);

  const row = actor.ctx.storage.sql.exec(
    `SELECT id, owner_id, scope_type, scope_id, object_key
     FROM social_attachments
     WHERE id = ?
     LIMIT 1`,
    attachmentId,
  ).toArray()[0];

  if (!row) return json({ ok: true, deleted: false });
  if (row.owner_id !== user.id) {
    return json({ ok: false, error: "ATTACHMENT_DELETE_ACCESS_DENIED" }, 403);
  }

  try {
    await bucket.delete(row.object_key);
  } catch (_) {
    return json({ ok: false, error: "ATTACHMENT_STORAGE_DELETE_FAILED" }, 503);
  }

  actor.ctx.storage.sql.exec(
    "DELETE FROM social_attachments WHERE id = ? AND owner_id = ?",
    attachmentId,
    user.id,
  );

  return json({ ok: true, deleted: true });
}

/**
 * Handles authenticated upload/download/delete routes for private Connect
 * attachments. Returns null for every route not owned by this module.
 */
export async function handleSocialAttachments(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();
  const isUpload = path === "/v1/social/attachments";
  const attachmentMatch = path.match(
    /^\/v1\/social\/attachments\/([a-f0-9-]{36})$/i,
  );

  if (!isUpload && !attachmentMatch) return null;
  if (isUpload && method !== "POST") {
    return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  }
  if (attachmentMatch && !["GET", "DELETE"].includes(method)) {
    return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    ensureAttachmentTables(actor);
    const user = await actor.requireUser(request);
    if (user instanceof Response) return user;

    if (isUpload) return await uploadAttachment(request, actor, user);
    if (method === "GET") {
      return await downloadAttachment(request, actor, user, attachmentMatch[1]);
    }
    return await deleteAttachment(actor, user, attachmentMatch[1]);
  } catch (_) {
    return json({
      ok: false,
      error: "SOCIAL_ATTACHMENT_INTERNAL_ERROR",
      message: "تعذر إكمال طلب المرفق. حاول مرة أخرى.",
    }, 500);
  }
}
