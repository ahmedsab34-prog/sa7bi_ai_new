
// Sa7bi AI - one shared public Connect room.
// Stored in the authenticated Sa7biSocial Durable Object SQLite database.
// REST is the source of truth. Clients can poll for new messages.
// Messages are not end-to-end encrypted.

const MAX_MESSAGE_LENGTH = 3000;
const MAX_HISTORY = 50;
const RATE_WINDOW_MS = 60 * 1000;
const RATE_LIMIT = 20;

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

function ensurePublicChatTables(actor) {
  const sql = actor.ctx.storage.sql;

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_public_messages (
      id TEXT PRIMARY KEY,
      sender_id TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_public_messages_created_idx
    ON social_public_messages(created_at DESC, id DESC)
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_public_messages_sender_idx
    ON social_public_messages(sender_id, created_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_public_message_reports (
      id TEXT PRIMARY KEY,
      message_id TEXT NOT NULL,
      reporter_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(message_id, reporter_id)
    )
  `);
}

function readRows(cursor) {
  return cursor && typeof cursor.toArray === "function"
    ? cursor.toArray()
    : [];
}

function messagePayload(row) {
  return {
    id: row.id,
    senderId: row.sender_id,
    username: row.username || "مستخدم صاحبي",
    text: row.body,
    createdAt: Number(row.created_at),
  };
}

async function requireUser(actor, request) {
  const user = await actor.requireUser(request);
  return user instanceof Response ? user : user;
}

async function listMessages(actor, request, user) {
  const url = new URL(request.url);
  const requestedLimit = Number(url.searchParams.get("limit") || MAX_HISTORY);
  const limit = Number.isFinite(requestedLimit)
    ? Math.max(1, Math.min(MAX_HISTORY, Math.floor(requestedLimit)))
    : MAX_HISTORY;

  const before = Number(url.searchParams.get("before") || 0);

  let rows;

  if (Number.isSafeInteger(before) && before > 0) {
    rows = readRows(actor.ctx.storage.sql.exec(
      `SELECT m.id, m.sender_id, m.body, m.created_at, u.username
       FROM social_public_messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.created_at < ?
       ORDER BY m.created_at DESC, m.id DESC
       LIMIT ?`,
      before,
      limit,
    ));
  } else {
    rows = readRows(actor.ctx.storage.sql.exec(
      `SELECT m.id, m.sender_id, m.body, m.created_at, u.username
       FROM social_public_messages m
       LEFT JOIN users u ON u.id = m.sender_id
       ORDER BY m.created_at DESC, m.id DESC
       LIMIT ?`,
      limit,
    ));
  }

  rows.reverse();

  return json({
    ok: true,
    room: "global",
    messages: rows.map(messagePayload),
    currentUserId: user.id,
    hasMore: rows.length === limit,
  });
}

async function sendMessage(actor, request, user) {
  const body = await actor.readBody(request);

  if (!body || body.error) {
    return json({
      ok: false,
      error: body?.error || "INVALID_JSON",
    }, 400);
  }

  const text = typeof body.text === "string"
    ? body.text.trim()
    : "";

  if (!text || text.length > MAX_MESSAGE_LENGTH) {
    return json({
      ok: false,
      error: "INVALID_MESSAGE",
      message: "اكتب رسالة من حرف واحد إلى 3000 حرف.",
    }, 400);
  }

  const now = Date.now();
  const recent = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS total
     FROM social_public_messages
     WHERE sender_id = ? AND created_at > ?`,
    user.id,
    now - RATE_WINDOW_MS,
  ).toArray()[0];

  if (Number(recent?.total || 0) >= RATE_LIMIT) {
    return json({
      ok: false,
      error: "MESSAGE_RATE_LIMIT",
      message: "أرسلت رسائل كثيرة بسرعة. انتظر قليلًا.",
    }, 429);
  }

  const id = crypto.randomUUID();

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_public_messages
       (id, sender_id, body, created_at)
     VALUES (?, ?, ?, ?)`,
    id,
    user.id,
    text,
    now,
  );

  const saved = actor.ctx.storage.sql.exec(
    `SELECT m.id, m.sender_id, m.body, m.created_at, u.username
     FROM social_public_messages m
     LEFT JOIN users u ON u.id = m.sender_id
     WHERE m.id = ?`,
    id,
  ).toArray()[0];

  if (!saved) {
    return json({
      ok: false,
      error: "MESSAGE_SAVE_FAILED",
    }, 500);
  }

  return json({
    ok: true,
    room: "global",
    message: messagePayload(saved),
  }, 201);
}

async function reportMessage(actor, request, user) {
  const body = await actor.readBody(request);

  if (!body || body.error) {
    return json({
      ok: false,
      error: body?.error || "INVALID_JSON",
    }, 400);
  }

  const messageId = typeof body.messageId === "string"
    ? body.messageId.trim()
    : "";

  const reason = typeof body.reason === "string"
    ? body.reason.trim().slice(0, 300)
    : "";

  if (!/^[a-f0-9-]{36}$/i.test(messageId) || !reason) {
    return json({
      ok: false,
      error: "INVALID_REPORT",
    }, 400);
  }

  const message = actor.ctx.storage.sql.exec(
    "SELECT id FROM social_public_messages WHERE id = ?",
    messageId,
  ).toArray()[0];

  if (!message) {
    return json({
      ok: false,
      error: "MESSAGE_NOT_FOUND",
    }, 404);
  }

  try {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_public_message_reports
         (id, message_id, reporter_id, reason, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      crypto.randomUUID(),
      messageId,
      user.id,
      reason,
      Date.now(),
    );
  } catch (_) {
    return json({
      ok: false,
      error: "ALREADY_REPORTED",
    }, 409);
  }

  return json({ ok: true });
}

/**
 * Routes:
 * GET  /v1/social/public/messages
 * POST /v1/social/public/messages
 * POST /v1/social/public/report
 */
export async function handleSocialPublicChat(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  const isMessages = path === "/v1/social/public/messages";
  const isReport = path === "/v1/social/public/report";

  if (!isMessages && !isReport) return null;

  try {
    ensurePublicChatTables(actor);

    const user = await requireUser(actor, request);
    if (user instanceof Response) return user;

    if (isMessages && method === "GET") {
      return await listMessages(actor, request, user);
    }

    if (isMessages && method === "POST") {
      return await sendMessage(actor, request, user);
    }

    if (isReport && method === "POST") {
      return await reportMessage(actor, request, user);
    }

    return json({
      ok: false,
      error: "METHOD_NOT_ALLOWED",
    }, 405);
  } catch (_) {
    return json({
      ok: false,
      error: "PUBLIC_CHAT_INTERNAL_ERROR",
      message: "تعذر تحميل الشات العام أو إرسال الرسالة.",
    }, 500);
  }
}
