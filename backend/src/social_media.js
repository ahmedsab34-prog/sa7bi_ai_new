
const MAX_REEL_BYTES = 50 * 1024 * 1024;
const MAX_CAPTION_LENGTH = 220;
const MAX_COMMENT_LENGTH = 1000;
const MAX_DAILY_UPLOADS = 10;

const VIDEO_TYPES = new Map([
  ["video/mp4", "mp4"],
  ["video/quicktime", "mov"],
  ["video/webm", "webm"],
  ["video/3gpp", "3gp"],
  ["video/x-m4v", "m4v"],
]);

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...extraHeaders,
    },
  });
}

function cleanString(value, max = 200) {
  return typeof value === "string"
    ? value.trim().slice(0, max)
    : "";
}

function isUuid(value) {
  return typeof value === "string" &&
    /^[a-f0-9-]{36}$/i.test(value);
}

function ensureSocialMediaTables(actor) {
  const sql = actor.ctx.storage.sql;

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_reels (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      caption TEXT NOT NULL DEFAULT '',
      object_key TEXT NOT NULL UNIQUE,
      content_type TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'ready',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_reels_feed_idx
    ON social_reels(status, created_at DESC)
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_reels_owner_idx
    ON social_reels(owner_id, created_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_reel_likes (
      reel_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(reel_id, user_id)
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_reel_likes_user_idx
    ON social_reel_likes(user_id, created_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_reel_comments (
      id TEXT PRIMARY KEY,
      reel_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_reel_comments_idx
    ON social_reel_comments(reel_id, created_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_follows (
      user_id TEXT NOT NULL,
      following_user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(user_id, following_user_id)
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_follows_target_idx
    ON social_follows(following_user_id, created_at DESC)
  `);
}

async function requireUser(request, actor) {
  const user = await actor.requireUser(request);

  if (user instanceof Response) {
    return { response: user, user: null };
  }

  return { response: null, user };
}

function getReelRow(actor, reelId, currentUserId) {
  return actor.ctx.storage.sql.exec(
    `SELECT
       r.id,
       r.owner_id,
       r.caption,
       r.object_key,
       r.content_type,
       r.size_bytes,
       r.created_at,
       u.username,
       (
         SELECT COUNT(*)
         FROM social_reel_likes l
         WHERE l.reel_id = r.id
       ) AS likes_count,
       (
         SELECT COUNT(*)
         FROM social_reel_comments c
         WHERE c.reel_id = r.id
       ) AS comments_count,
       EXISTS(
         SELECT 1
         FROM social_reel_likes l
         WHERE l.reel_id = r.id
           AND l.user_id = ?
       ) AS liked_by_me,
       EXISTS(
         SELECT 1
         FROM social_follows f
         WHERE f.user_id = ?
           AND f.following_user_id = r.owner_id
       ) AS followed_by_me
     FROM social_reels r
     JOIN users u ON u.id = r.owner_id
     WHERE r.id = ? AND r.status = 'ready'`,
    currentUserId,
    currentUserId,
    reelId,
  ).toArray()[0] || null;
}

function reelPayload(row, origin) {
  if (!row) return null;

  return {
    id: row.id,
    ownerId: row.owner_id,
    username: row.username || "صاحبي",
    caption: row.caption || "",
    videoUrl:
      `${origin}/v1/social/reels/${encodeURIComponent(row.id)}/media`,
    contentType: row.content_type,
    sizeBytes: Number(row.size_bytes) || 0,
    createdAt: Number(row.created_at) || 0,
    likesCount: Number(row.likes_count) || 0,
    commentsCount: Number(row.comments_count) || 0,
    likedByMe: Boolean(row.liked_by_me),
    followedByMe: Boolean(row.followed_by_me),
    isMine: false,
  };
}

async function readLimitedBody(request, maximumBytes) {
  if (!request.body) {
    return { bytes: null, error: "EMPTY_UPLOAD" };
  }

  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;

  try {
    while (true) {
      const result = await reader.read();

      if (result.done) break;

      const chunk = result.value;

      total += chunk.byteLength;

      if (total > maximumBytes) {
        try {
          await reader.cancel();
        } catch (_) {}

        return {
          bytes: null,
          error: "REEL_TOO_LARGE",
        };
      }

      chunks.push(chunk);
    }
  } finally {
    reader.releaseLock();
  }

  if (total === 0) {
    return { bytes: null, error: "EMPTY_UPLOAD" };
  }

  const output = new Uint8Array(total);
  let offset = 0;

  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return { bytes: output, error: null };
}

function reelBucket(actor) {
  return actor.env?.SA7BI_REELS || null;
}

async function uploadReel(request, actor, user, url) {
  const bucket = reelBucket(actor);

  if (!bucket) {
    return json({
      ok: false,
      error: "REELS_STORAGE_NOT_CONFIGURED",
      message: "تخزين الفيديوهات لم يتم ربطه بالخادم بعد.",
    }, 503);
  }

  const rawType = cleanString(
    request.headers.get("Content-Type") || "",
    100,
  ).split(";")[0].toLowerCase();

  const extension = VIDEO_TYPES.get(rawType);

  if (!extension) {
    return json({
      ok: false,
      error: "UNSUPPORTED_VIDEO_TYPE",
      message: "صيغة الفيديو غير مدعومة. استخدم MP4 أو MOV أو WEBM.",
    }, 415);
  }

  const declaredLength = Number(
    request.headers.get("Content-Length") || 0,
  );

  if (!Number.isSafeInteger(declaredLength) || declaredLength <= 0) {
    return json({
      ok: false,
      error: "CONTENT_LENGTH_REQUIRED",
    }, 411);
  }

  if (declaredLength > MAX_REEL_BYTES) {
    return json({
      ok: false,
      error: "REEL_TOO_LARGE",
      maxBytes: MAX_REEL_BYTES,
    }, 413);
  }

  const upload = await readLimitedBody(
    request,
    MAX_REEL_BYTES,
  );

  if (upload.error) {
    return json({
      ok: false,
      error: upload.error,
      maxBytes: MAX_REEL_BYTES,
    }, upload.error === "REEL_TOO_LARGE" ? 413 : 400);
  }

  const bytes = upload.bytes;

  if (bytes.byteLength !== declaredLength) {
    return json({
      ok: false,
      error: "UPLOAD_SIZE_MISMATCH",
    }, 400);
  }

  const now = Date.now();
  const dayStart = new Date(now);
  dayStart.setUTCHours(0, 0, 0, 0);

  const count = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS total
     FROM social_reels
     WHERE owner_id = ? AND created_at >= ?`,
    user.id,
    dayStart.getTime(),
  ).toArray()[0];

  if (Number(count?.total || 0) >= MAX_DAILY_UPLOADS) {
    return json({
      ok: false,
      error: "REEL_DAILY_LIMIT",
      limit: MAX_DAILY_UPLOADS,
    }, 429);
  }

  const caption = cleanString(
    url.searchParams.get("caption") || "",
    MAX_CAPTION_LENGTH,
  );

  const reelId = crypto.randomUUID();

  const objectKey =
    `reels/${user.id}/${reelId}.${extension}`;

  try {
    await bucket.put(
      objectKey,
      bytes,
      {
        httpMetadata: {
          contentType: rawType,
          cacheControl: "public, max-age=3600",
        },
        customMetadata: {
          reelId,
          ownerId: user.id,
          uploadedAt: String(now),
        },
      },
    );
  } catch (_) {
    return json({
      ok: false,
      error: "REEL_STORAGE_WRITE_FAILED",
      message: "تعذر حفظ الفيديو في التخزين. حاول مرة أخرى.",
    }, 503);
  }

  try {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_reels
       (id, owner_id, caption, object_key, content_type,
        size_bytes, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'ready', ?, ?)`,
      reelId,
      user.id,
      caption,
      objectKey,
      rawType,
      bytes.byteLength,
      now,
      now,
    );
  } catch (_) {
    try {
      await bucket.delete(objectKey);
    } catch (_) {}

    return json({
      ok: false,
      error: "REEL_METADATA_SAVE_FAILED",
      message: "تعذر حفظ بيانات الفيديو. لم يتم نشره.",
    }, 500);
  }

  return json({
    ok: true,
    reel: {
      id: reelId,
      ownerId: user.id,
      username: user.username || "صاحبي",
      caption,
      videoUrl:
        `${url.origin}/v1/social/reels/${encodeURIComponent(reelId)}/media`,
      contentType: rawType,
      sizeBytes: bytes.byteLength,
      createdAt: now,
      likesCount: 0,
      commentsCount: 0,
      likedByMe: false,
      followedByMe: false,
      isMine: true,
    },
  }, 201);
}

async function listReels(request, actor, user) {
  const url = new URL(request.url);
  const limitValue = Number(url.searchParams.get("limit") || 20);
  const limit = Number.isFinite(limitValue)
    ? Math.min(30, Math.max(1, Math.floor(limitValue)))
    : 20;

  const beforeValue = Number(url.searchParams.get("before") || 0);
  const before = Number.isFinite(beforeValue) && beforeValue > 0
    ? beforeValue
    : Date.now() + 1;

  const rows = actor.ctx.storage.sql.exec(
    `SELECT r.id
     FROM social_reels r
     WHERE r.status = 'ready' AND r.created_at < ?
     ORDER BY r.created_at DESC
     LIMIT ?`,
    before,
    limit,
  ).toArray();

  const reels = [];

  for (const item of rows) {
    const row = getReelRow(actor, item.id, user.id);

    if (!row) continue;

    const payload = reelPayload(row, url.origin);
    payload.isMine = row.owner_id === user.id;
    reels.push(payload);
  }

  return json({
    ok: true,
    reels,
    count: reels.length,
    nextBefore: reels.length
      ? reels[reels.length - 1].createdAt
      : null,
  });
}

async function changeLike(request, actor, user, reelId, liked) {
  const reel = actor.ctx.storage.sql.exec(
    "SELECT id FROM social_reels WHERE id = ? AND status = 'ready'",
    reelId,
  ).toArray()[0];

  if (!reel) {
    return json({ ok: false, error: "REEL_NOT_FOUND" }, 404);
  }

  if (liked) {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_reel_likes
       (reel_id, user_id, created_at)
       VALUES (?, ?, ?)
       ON CONFLICT(reel_id, user_id) DO NOTHING`,
      reelId,
      user.id,
      Date.now(),
    );
  } else {
    actor.ctx.storage.sql.exec(
      `DELETE FROM social_reel_likes
       WHERE reel_id = ? AND user_id = ?`,
      reelId,
      user.id,
    );
  }

  const row = getReelRow(actor, reelId, user.id);

  return json({
    ok: true,
    liked: Boolean(row?.liked_by_me),
    likesCount: Number(row?.likes_count || 0),
  });
}

async function listComments(actor, user, reelId) {
  const reel = actor.ctx.storage.sql.exec(
    "SELECT id FROM social_reels WHERE id = ? AND status = 'ready'",
    reelId,
  ).toArray()[0];

  if (!reel) {
    return json({ ok: false, error: "REEL_NOT_FOUND" }, 404);
  }

  const rows = actor.ctx.storage.sql.exec(
    `SELECT
       c.id,
       c.user_id,
       u.username,
       c.text,
       c.created_at
     FROM social_reel_comments c
     JOIN users u ON u.id = c.user_id
     WHERE c.reel_id = ?
     ORDER BY c.created_at ASC
     LIMIT 100`,
    reelId,
  ).toArray();

  return json({
    ok: true,
    comments: rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      username: row.username,
      text: row.text,
      createdAt: Number(row.created_at) || 0,
      isMine: row.user_id === user.id,
    })),
  });
}

async function addComment(request, actor, user, reelId) {
  const body = await actor.readBody(request);

  if (body.error) {
    return json({ ok: false, error: body.error }, 400);
  }

  const text = cleanString(
    body.text,
    MAX_COMMENT_LENGTH,
  );

  if (!text) {
    return json({ ok: false, error: "EMPTY_COMMENT" }, 400);
  }

  const reel = actor.ctx.storage.sql.exec(
    "SELECT id FROM social_reels WHERE id = ? AND status = 'ready'",
    reelId,
  ).toArray()[0];

  if (!reel) {
    return json({ ok: false, error: "REEL_NOT_FOUND" }, 404);
  }

  const id = crypto.randomUUID();
  const now = Date.now();

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_reel_comments
     (id, reel_id, user_id, text, created_at)
     VALUES (?, ?, ?, ?, ?)`,
    id,
    reelId,
    user.id,
    text,
    now,
  );

  return json({
    ok: true,
    comment: {
      id,
      userId: user.id,
      username: user.username || "صاحبي",
      text,
      createdAt: now,
      isMine: true,
    },
  }, 201);
}

async function changeFollow(actor, user, targetUserId, following) {
  if (!isUuid(targetUserId)) {
    return json({ ok: false, error: "INVALID_USER_ID" }, 400);
  }

  if (targetUserId === user.id) {
    return json({ ok: false, error: "CANNOT_FOLLOW_SELF" }, 409);
  }

  const target = actor.ctx.storage.sql.exec(
    "SELECT id FROM users WHERE id = ?",
    targetUserId,
  ).toArray()[0];

  if (!target) {
    return json({ ok: false, error: "USER_NOT_FOUND" }, 404);
  }

  if (following) {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_follows
       (user_id, following_user_id, created_at)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id, following_user_id) DO NOTHING`,
      user.id,
      targetUserId,
      Date.now(),
    );
  } else {
    actor.ctx.storage.sql.exec(
      `DELETE FROM social_follows
       WHERE user_id = ? AND following_user_id = ?`,
      user.id,
      targetUserId,
    );
  }

  const count = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS total
     FROM social_follows
     WHERE following_user_id = ?`,
    targetUserId,
  ).toArray()[0];

  return json({
    ok: true,
    following,
    followersCount: Number(count?.total || 0),
  });
}

async function deleteReel(actor, user, reelId) {
  const row = actor.ctx.storage.sql.exec(
    `SELECT id, owner_id, object_key
     FROM social_reels
     WHERE id = ? AND status = 'ready'`,
    reelId,
  ).toArray()[0];

  if (!row) {
    return json({ ok: false, error: "REEL_NOT_FOUND" }, 404);
  }

  if (row.owner_id !== user.id) {
    return json({ ok: false, error: "REEL_DELETE_FORBIDDEN" }, 403);
  }

  const bucket = reelBucket(actor);

  if (!bucket) {
    return json({
      ok: false,
      error: "REELS_STORAGE_NOT_CONFIGURED",
    }, 503);
  }

  try {
    await bucket.delete(row.object_key);
  } catch (_) {
    return json({
      ok: false,
      error: "REEL_STORAGE_DELETE_FAILED",
    }, 503);
  }

  actor.ctx.storage.sql.exec(
    "DELETE FROM social_reel_likes WHERE reel_id = ?",
    reelId,
  );

  actor.ctx.storage.sql.exec(
    "DELETE FROM social_reel_comments WHERE reel_id = ?",
    reelId,
  );

  actor.ctx.storage.sql.exec(
    "DELETE FROM social_reels WHERE id = ? AND owner_id = ?",
    reelId,
    user.id,
  );

  return json({ ok: true, deleted: true });
}

function parseByteRange(value, size) {
  if (!value) return null;

  const match = /^bytes=(\d*)-(\d*)$/i.exec(value.trim());

  if (!match || size <= 0) {
    return { invalid: true };
  }

  let start;
  let end;

  if (!match[1]) {
    const suffixLength = Number(match[2]);

    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) {
      return { invalid: true };
    }

    start = Math.max(0, size - suffixLength);
    end = size - 1;
  } else {
    start = Number(match[1]);
    end = match[2] ? Number(match[2]) : size - 1;
  }

  if (
    !Number.isSafeInteger(start) ||
    !Number.isSafeInteger(end) ||
    start < 0 ||
    end < start ||
    start >= size
  ) {
    return { invalid: true };
  }

  end = Math.min(end, size - 1);

  return {
    start,
    end,
    length: end - start + 1,
  };
}

async function serveReelMedia(request, actor, reelId) {
  const bucket = reelBucket(actor);

  if (!bucket) {
    return json({
      ok: false,
      error: "REELS_STORAGE_NOT_CONFIGURED",
    }, 503);
  }

  const row = actor.ctx.storage.sql.exec(
    `SELECT object_key, content_type, size_bytes
     FROM social_reels
     WHERE id = ? AND status = 'ready'`,
    reelId,
  ).toArray()[0];

  if (!row) {
    return json({ ok: false, error: "REEL_NOT_FOUND" }, 404);
  }

  const size = Number(row.size_bytes) || 0;

  if (size <= 0) {
    return json({ ok: false, error: "REEL_EMPTY" }, 410);
  }

  const rangeHeader = request.headers.get("Range");
  const range = parseByteRange(rangeHeader, size);

  if (range?.invalid) {
    return new Response(null, {
      status: 416,
      headers: {
        "Accept-Ranges": "bytes",
        "Content-Range": `bytes */${size}`,
        "Cache-Control": "no-store",
      },
    });
  }

  let object;

  try {
    object = range
      ? await bucket.get(row.object_key, {
          range: {
            offset: range.start,
            length: range.length,
          },
        })
      : await bucket.get(row.object_key);
  } catch (_) {
    return json({ ok: false, error: "REEL_STORAGE_READ_FAILED" }, 503);
  }

  if (!object) {
    return json({ ok: false, error: "REEL_FILE_MISSING" }, 404);
  }

  const headers = new Headers();

  if (typeof object.writeHttpMetadata === "function") {
    object.writeHttpMetadata(headers);
  }

  headers.set(
    "Content-Type",
    row.content_type || "application/octet-stream",
  );
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Accept-Ranges", "bytes");
  headers.set("Cache-Control", "public, max-age=3600");

  if (object.httpEtag) {
    headers.set("ETag", object.httpEtag);
  }

  if (range) {
    headers.set("Content-Length", String(range.length));
    headers.set(
      "Content-Range",
      `bytes ${range.start}-${range.end}/${size}`,
    );

    return new Response(object.body, {
      status: 206,
      headers,
    });
  }

  headers.set("Content-Length", String(size));

  return new Response(object.body, {
    status: 200,
    headers,
  });
}

export async function handleSocialMedia(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  const mediaMatch = path.match(
    /^\/v1\/social\/reels\/([a-f0-9-]{36})\/media$/i,
  );

  if (
    mediaMatch &&
    (request.method === "GET" || request.method === "HEAD")
  ) {
    ensureSocialMediaTables(actor);
    return serveReelMedia(request, actor, mediaMatch[1]);
  }

  const reelMatch = path.match(
    /^\/v1\/social\/reels\/([a-f0-9-]{36})$/i,
  );

  const likeMatch = path.match(
    /^\/v1\/social\/reels\/([a-f0-9-]{36})\/like$/i,
  );

  const commentsMatch = path.match(
    /^\/v1\/social\/reels\/([a-f0-9-]{36})\/comments$/i,
  );

  const followMatch = path.match(
    /^\/v1\/social\/users\/([a-f0-9-]{36})\/follow$/i,
  );

  const isKnownRoute =
    path === "/v1/social/reels" ||
    path === "/v1/social/reels/feed" ||
    Boolean(reelMatch) ||
    Boolean(likeMatch) ||
    Boolean(commentsMatch) ||
    Boolean(followMatch);

  if (!isKnownRoute) return null;

  ensureSocialMediaTables(actor);

  const auth = await requireUser(request, actor);

  if (auth.response) return auth.response;

  const user = auth.user;

  if (
    request.method === "POST" &&
    path === "/v1/social/reels"
  ) {
    return uploadReel(request, actor, user, url);
  }

  if (
    request.method === "GET" &&
    path === "/v1/social/reels/feed"
  ) {
    return listReels(request, actor, user);
  }

  if (
    request.method === "DELETE" &&
    reelMatch
  ) {
    return deleteReel(actor, user, reelMatch[1]);
  }

  if (likeMatch) {
    if (request.method === "POST") {
      return changeLike(
        request,
        actor,
        user,
        likeMatch[1],
        true,
      );
    }

    if (request.method === "DELETE") {
      return changeLike(
        request,
        actor,
        user,
        likeMatch[1],
        false,
      );
    }
  }

  if (commentsMatch) {
    if (request.method === "GET") {
      return listComments(actor, user, commentsMatch[1]);
    }

    if (request.method === "POST") {
      return addComment(
        request,
        actor,
        user,
        commentsMatch[1],
      );
    }
  }

  if (followMatch) {
    if (request.method === "POST") {
      return changeFollow(
        actor,
        user,
        followMatch[1],
        true,
      );
    }

    if (request.method === "DELETE") {
      return changeFollow(
        actor,
        user,
        followMatch[1],
        false,
      );
    }
  }

  return json({
    ok: false,
    error: "METHOD_NOT_ALLOWED",
  }, 405);
}
