
// Sa7bi AI - authenticated in-app game invitations and private conversations.
// This module is attached to the existing Sa7biSocial Durable Object by index-v2.js.
// All data is stored in the same SQLite Durable Object as the social accounts.
// Messages are access-controlled, but are NOT end-to-end encrypted in this version.

const INVITATION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MESSAGE_MAX_LENGTH = 3000;
const MESSAGE_RATE_WINDOW_MS = 60 * 1000;
const MESSAGE_RATE_LIMIT = 30;
const SUPPORTED_INVITATION_GAMES = new Set([
  "tic_tac_toe",
  "rock_paper_scissors",
  "chess",
]);

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function isUuid(value) {
  return typeof value === "string" &&
    /^[a-f0-9-]{36}$/i.test(value);
}

function safeString(value, maxLength = 200) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function createGameState(game) {
  if (game === "tic_tac_toe") {
    return {
      board: Array(9).fill(""),
      next: "X",
      winner: null,
      winnerUserId: null,
      moves: 0,
      history: [],
    };
  }

  if (game === "rock_paper_scissors") {
    return {
      choices: {},
      round: 1,
      result: null,
      lastResult: null,
      lastWinner: null,
      scores: { host: 0, guest: 0, draws: 0 },
      history: [],
    };
  }

  return {
    fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    pgn: "",
    history: [],
    turn: "w",
    check: false,
    checkmate: false,
    draw: false,
    winnerUserId: null,
    lastMove: null,
  };
}

function ensureMessagingTables(actor) {
  const sql = actor.ctx.storage.sql;

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_invitations (
      id TEXT PRIMARY KEY,
      sender_id TEXT NOT NULL,
      recipient_id TEXT NOT NULL,
      game TEXT NOT NULL,
      room_id TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      responded_at INTEGER
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_invitations_recipient_idx
    ON social_invitations(recipient_id, status, created_at DESC)
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_invitations_sender_idx
    ON social_invitations(sender_id, status, created_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_conversations (
      id TEXT PRIMARY KEY,
      user_a TEXT NOT NULL,
      user_b TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_a, user_b)
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_conversations_user_a_idx
    ON social_conversations(user_a, updated_at DESC)
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_conversations_user_b_idx
    ON social_conversations(user_b, updated_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_messages (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      read_at INTEGER
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_messages_conversation_idx
    ON social_messages(conversation_id, created_at DESC)
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_messages_sender_idx
    ON social_messages(sender_id, created_at DESC)
  `);
}

function bodyErrorResponse(body) {
  if (!body || !body.error) return null;
  const status = body.error === "BODY_TOO_LARGE" ? 413 : 400;
  return json({ ok: false, error: body.error }, status);
}

function userSummary(id, username) {
  return id ? { id, username: username || "لاعب" } : null;
}

function invitationPayload(row, currentUserId) {
  if (!row) return null;

  return {
    id: row.id,
    sender: userSummary(row.sender_id, row.sender_username),
    recipient: userSummary(row.recipient_id, row.recipient_username),
    game: row.game,
    status: row.status,
    roomId: row.room_id,
    inviteCode: row.invite_code || "",
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    respondedAt: row.responded_at,
    direction: row.sender_id === currentUserId ? "outgoing" : "incoming",
  };
}

function getInvitationRow(actor, invitationId) {
  return actor.ctx.storage.sql.exec(
    `SELECT
       i.id,
       i.sender_id,
       i.recipient_id,
       i.game,
       i.room_id,
       i.status,
       i.created_at,
       i.expires_at,
       i.responded_at,
       sender.username AS sender_username,
       recipient.username AS recipient_username,
       game_rooms.code AS invite_code
     FROM social_invitations i
     JOIN users sender ON sender.id = i.sender_id
     JOIN users recipient ON recipient.id = i.recipient_id
     LEFT JOIN game_rooms ON game_rooms.id = i.room_id
     WHERE i.id = ?`,
    invitationId,
  ).toArray()[0] || null;
}

function getConversationRow(actor, conversationId) {
  return actor.ctx.storage.sql.exec(
    `SELECT id, user_a, user_b, created_at, updated_at
     FROM social_conversations
     WHERE id = ?`,
    conversationId,
  ).toArray()[0] || null;
}

function conversationMember(conversation, userId) {
  return Boolean(conversation &&
    (conversation.user_a === userId || conversation.user_b === userId));
}

function otherUserId(conversation, userId) {
  return conversation.user_a === userId
    ? conversation.user_b
    : conversation.user_a;
}

async function listInvitations(actor, request, user) {
  const url = new URL(request.url);
  const box = url.searchParams.get("box") === "outbox" ? "outbox" : "inbox";
  const now = Date.now();

  actor.ctx.storage.sql.exec(
    `UPDATE social_invitations
     SET status = 'expired', responded_at = ?
     WHERE status = 'pending' AND expires_at <= ?`,
    now,
    now,
  );

  const rows = box === "outbox"
    ? actor.ctx.storage.sql.exec(
        `SELECT i.id
         FROM social_invitations i
         WHERE i.sender_id = ?
         ORDER BY i.created_at DESC
         LIMIT 50`,
        user.id,
      ).toArray()
    : actor.ctx.storage.sql.exec(
        `SELECT i.id
         FROM social_invitations i
         WHERE i.recipient_id = ?
         ORDER BY i.created_at DESC
         LIMIT 50`,
        user.id,
      ).toArray();

  const invitations = [];

  for (const item of rows) {
    invitations.push(
      invitationPayload(getInvitationRow(actor, item.id), user.id),
    );
  }

  return json({ ok: true, box, invitations });
}

async function createInvitation(actor, request, user) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const recipientUserId = safeString(body.recipientUserId, 64);
  const game = safeString(body.game, 40);

  if (!isUuid(recipientUserId) || !SUPPORTED_INVITATION_GAMES.has(game)) {
    return json({ ok: false, error: "INVALID_INVITATION_DATA" }, 400);
  }

  if (recipientUserId === user.id) {
    return json({ ok: false, error: "CANNOT_INVITE_SELF" }, 409);
  }

  const recipient = actor.ctx.storage.sql.exec(
    "SELECT id FROM users WHERE id = ?",
    recipientUserId,
  ).toArray()[0];

  if (!recipient) {
    return json({ ok: false, error: "USER_NOT_FOUND" }, 404);
  }

  const now = Date.now();

  actor.ctx.storage.sql.exec(
    `UPDATE social_invitations
     SET status = 'expired', responded_at = ?
     WHERE status = 'pending' AND expires_at <= ?`,
    now,
    now,
  );

  const existing = actor.ctx.storage.sql.exec(
    `SELECT id
     FROM social_invitations
     WHERE sender_id = ?
       AND recipient_id = ?
       AND status = 'pending'
       AND expires_at > ?
     LIMIT 1`,
    user.id,
    recipientUserId,
    now,
  ).toArray()[0];

  if (existing) {
    return json({ ok: false, error: "INVITATION_ALREADY_PENDING" }, 409);
  }

  let code = "";
  let unique = false;

  for (let attempt = 0; attempt < 12; attempt++) {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const bytes = crypto.getRandomValues(new Uint8Array(6));
    code = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");

    const found = actor.ctx.storage.sql.exec(
      "SELECT id FROM game_rooms WHERE code = ?",
      code,
    ).toArray()[0];

    if (!found) {
      unique = true;
      break;
    }
  }

  if (!unique) {
    return json({ ok: false, error: "INVITE_CODE_GENERATION_FAILED" }, 503);
  }

  const roomId = crypto.randomUUID();
  const invitationId = crypto.randomUUID();

  actor.ctx.storage.sql.exec(
    `INSERT INTO game_rooms
     (id, code, game, host_id, guest_id, state_json, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, NULL, ?, 'waiting', ?, ?)`,
    roomId,
    code,
    game,
    user.id,
    JSON.stringify(createGameState(game)),
    now,
    now,
  );

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_invitations
     (id, sender_id, recipient_id, game, room_id, status, created_at, expires_at, responded_at)
     VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, NULL)`,
    invitationId,
    user.id,
    recipientUserId,
    game,
    roomId,
    now,
    now + INVITATION_TTL_MS,
  );

  const row = getInvitationRow(actor, invitationId);

  return json(
    {
      ok: true,
      invitation: invitationPayload(row, user.id),
    },
    201,
  );
}

async function respondToInvitation(actor, request, user, invitationId, action) {
  if (!isUuid(invitationId)) {
    return json({ ok: false, error: "INVALID_INVITATION_ID" }, 400);
  }

  const row = getInvitationRow(actor, invitationId);

  if (!row) {
    return json({ ok: false, error: "INVITATION_NOT_FOUND" }, 404);
  }

  if (row.recipient_id !== user.id) {
    return json({ ok: false, error: "INVITATION_ACCESS_DENIED" }, 403);
  }

  if (row.status !== "pending") {
    return json({ ok: false, error: "INVITATION_ALREADY_RESPONDED" }, 409);
  }

  const now = Date.now();

  if (row.expires_at <= now) {
    actor.ctx.storage.sql.exec(
      `UPDATE social_invitations
       SET status = 'expired', responded_at = ?
       WHERE id = ? AND status = 'pending'`,
      now,
      invitationId,
    );

    return json({ ok: false, error: "INVITATION_EXPIRED" }, 410);
  }

  if (action === "decline") {
    actor.ctx.storage.sql.exec(
      `UPDATE social_invitations
       SET status = 'declined', responded_at = ?
       WHERE id = ? AND status = 'pending'`,
      now,
      invitationId,
    );

    return json({
      ok: true,
      invitation: invitationPayload(getInvitationRow(actor, invitationId), user.id),
    });
  }

  const room = actor.ctx.storage.sql.exec(
    "SELECT * FROM game_rooms WHERE id = ?",
    row.room_id,
  ).toArray()[0];

  if (!room) {
    return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
  }

  if (room.status !== "waiting" || room.guest_id) {
    actor.ctx.storage.sql.exec(
      `UPDATE social_invitations
       SET status = 'unavailable', responded_at = ?
       WHERE id = ? AND status = 'pending'`,
      now,
      invitationId,
    );

    return json({ ok: false, error: "ROOM_UNAVAILABLE" }, 409);
  }

  const updated = actor.ctx.storage.sql.exec(
    `UPDATE game_rooms
     SET guest_id = ?, status = 'playing', updated_at = ?
     WHERE id = ? AND guest_id IS NULL AND status = 'waiting'`,
    user.id,
    now,
    room.id,
  );

  if (updated.rowsWritten === 0) {
    return json({ ok: false, error: "ROOM_UNAVAILABLE" }, 409);
  }

  actor.ctx.storage.sql.exec(
    `UPDATE social_invitations
     SET status = 'accepted', responded_at = ?
     WHERE id = ? AND status = 'pending'`,
    now,
    invitationId,
  );

  const invitation = invitationPayload(
    getInvitationRow(actor, invitationId),
    user.id,
  );

  return json({
    ok: true,
    invitation,
    room: await actor.roomPayload(room.id, user.id),
  });
}

async function createConversation(actor, request, user) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const otherId = safeString(body.userId, 64);

  if (!isUuid(otherId) || otherId === user.id) {
    return json({ ok: false, error: "INVALID_USER_ID" }, 400);
  }

  const other = actor.ctx.storage.sql.exec(
    "SELECT id, username FROM users WHERE id = ?",
    otherId,
  ).toArray()[0];

  if (!other) {
    return json({ ok: false, error: "USER_NOT_FOUND" }, 404);
  }

  const userA = user.id < otherId ? user.id : otherId;
  const userB = user.id < otherId ? otherId : user.id;
  const now = Date.now();

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_conversations
     (id, user_a, user_b, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(user_a, user_b) DO NOTHING`,
    crypto.randomUUID(),
    userA,
    userB,
    now,
    now,
  );

  const conversation = actor.ctx.storage.sql.exec(
    `SELECT id, user_a, user_b, created_at, updated_at
     FROM social_conversations
     WHERE user_a = ? AND user_b = ?`,
    userA,
    userB,
  ).toArray()[0];

  return json({
    ok: true,
    conversation: {
      id: conversation.id,
      otherUser: userSummary(other.id, other.username),
      createdAt: conversation.created_at,
      updatedAt: conversation.updated_at,
    },
  });
}

async function listConversations(actor, user) {
  const rows = actor.ctx.storage.sql.exec(
    `SELECT
       c.id,
       c.user_a,
       c.user_b,
       c.created_at,
       c.updated_at,
       other.id AS other_id,
       other.username AS other_username,
       (SELECT body
        FROM social_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC
        LIMIT 1) AS last_message,
       (SELECT created_at
        FROM social_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC
        LIMIT 1) AS last_message_at,
       (SELECT COUNT(*)
        FROM social_messages m
        WHERE m.conversation_id = c.id
          AND m.sender_id <> ?
          AND m.read_at IS NULL) AS unread_count
     FROM social_conversations c
     JOIN users other
       ON other.id = CASE
         WHEN c.user_a = ? THEN c.user_b
         ELSE c.user_a
       END
     WHERE c.user_a = ? OR c.user_b = ?
     ORDER BY COALESCE(last_message_at, c.updated_at) DESC
     LIMIT 100`,
    user.id,
    user.id,
    user.id,
    user.id,
  ).toArray();

  return json({
    ok: true,
    conversations: rows.map((row) => ({
      id: row.id,
      otherUser: userSummary(row.other_id, row.other_username),
      lastMessage: row.last_message || "",
      updatedAt: row.last_message_at || row.updated_at,
      unreadCount: Number(row.unread_count || 0),
    })),
  });
}

async function listMessages(actor, request, user) {
  const url = new URL(request.url);
  const conversationId = safeString(url.searchParams.get("conversationId"), 64);

  if (!isUuid(conversationId)) {
    return json({ ok: false, error: "INVALID_CONVERSATION_ID" }, 400);
  }

  const conversation = getConversationRow(actor, conversationId);

  if (!conversation) {
    return json({ ok: false, error: "CONVERSATION_NOT_FOUND" }, 404);
  }

  if (!conversationMember(conversation, user.id)) {
    return json({ ok: false, error: "CONVERSATION_ACCESS_DENIED" }, 403);
  }

  const limitValue = Number(url.searchParams.get("limit") || 50);
  const limit = Number.isFinite(limitValue)
    ? Math.min(100, Math.max(1, Math.trunc(limitValue)))
    : 50;

  const rows = actor.ctx.storage.sql.exec(
    `SELECT id, conversation_id, sender_id, body, created_at, read_at
     FROM social_messages
     WHERE conversation_id = ?
     ORDER BY created_at DESC
     LIMIT ?`,
    conversationId,
    limit,
  ).toArray().reverse();

  return json({
    ok: true,
    messages: rows.map((row) => ({
      id: row.id,
      conversationId: row.conversation_id,
      senderId: row.sender_id,
      text: row.body,
      createdAt: row.created_at,
      readAt: row.read_at,
      isMine: row.sender_id === user.id,
    })),
  });
}

async function sendMessage(actor, request, user) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const conversationId = safeString(body.conversationId, 64);
  const message = typeof body.text === "string" ? body.text.trim() : "";

  if (!isUuid(conversationId) || !message || message.length > MESSAGE_MAX_LENGTH) {
    return json({ ok: false, error: "INVALID_MESSAGE" }, 400);
  }

  const conversation = getConversationRow(actor, conversationId);

  if (!conversation) {
    return json({ ok: false, error: "CONVERSATION_NOT_FOUND" }, 404);
  }

  if (!conversationMember(conversation, user.id)) {
    return json({ ok: false, error: "CONVERSATION_ACCESS_DENIED" }, 403);
  }

  const now = Date.now();
  const recent = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS total
     FROM social_messages
     WHERE sender_id = ? AND created_at > ?`,
    user.id,
    now - MESSAGE_RATE_WINDOW_MS,
  ).toArray()[0];

  if (Number(recent?.total || 0) >= MESSAGE_RATE_LIMIT) {
    return json({ ok: false, error: "MESSAGE_RATE_LIMIT" }, 429);
  }

  const messageId = crypto.randomUUID();

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_messages
     (id, conversation_id, sender_id, body, created_at, read_at)
     VALUES (?, ?, ?, ?, ?, NULL)`,
    messageId,
    conversationId,
    user.id,
    message,
    now,
  );

  actor.ctx.storage.sql.exec(
    "UPDATE social_conversations SET updated_at = ? WHERE id = ?",
    now,
    conversationId,
  );

  return json(
    {
      ok: true,
      message: {
        id: messageId,
        conversationId,
        senderId: user.id,
        text: message,
        createdAt: now,
        readAt: null,
        isMine: true,
      },
    },
    201,
  );
}

async function markMessagesRead(actor, request, user) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const conversationId = safeString(body.conversationId, 64);

  if (!isUuid(conversationId)) {
    return json({ ok: false, error: "INVALID_CONVERSATION_ID" }, 400);
  }

  const conversation = getConversationRow(actor, conversationId);

  if (!conversation) {
    return json({ ok: false, error: "CONVERSATION_NOT_FOUND" }, 404);
  }

  if (!conversationMember(conversation, user.id)) {
    return json({ ok: false, error: "CONVERSATION_ACCESS_DENIED" }, 403);
  }

  const now = Date.now();

  actor.ctx.storage.sql.exec(
    `UPDATE social_messages
     SET read_at = ?
     WHERE conversation_id = ?
       AND sender_id <> ?
       AND read_at IS NULL`,
    now,
    conversationId,
    user.id,
  );

  return json({ ok: true, readAt: now });
}

export async function handleSocialMessaging(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  const routes = [
    ["GET", "/v1/social/invitations"],
    ["POST", "/v1/social/invitations"],
    ["POST", "/v1/social/conversations"],
    ["GET", "/v1/social/conversations"],
    ["GET", "/v1/social/messages"],
    ["POST", "/v1/social/messages"],
    ["POST", "/v1/social/messages/read"],
  ];

  const invitationAction = path.match(
    /^\/v1\/social\/invitations\/([a-f0-9-]{36})\/(accept|decline)$/i,
  );

  const isMessagingRoute =
    routes.some(([method, route]) => request.method === method && path === route) ||
    (request.method === "POST" && invitationAction);

  if (!isMessagingRoute) return null;

  ensureMessagingTables(actor);

  const user = await actor.requireUser(request);

  if (user instanceof Response) return user;

  if (request.method === "GET" && path === "/v1/social/invitations") {
    return listInvitations(actor, request, user);
  }

  if (request.method === "POST" && path === "/v1/social/invitations") {
    return createInvitation(actor, request, user);
  }

  if (request.method === "POST" && invitationAction) {
    return respondToInvitation(
      actor,
      request,
      user,
      invitationAction[1],
      invitationAction[2].toLowerCase(),
    );
  }

  if (request.method === "POST" && path === "/v1/social/conversations") {
    return createConversation(actor, request, user);
  }

  if (request.method === "GET" && path === "/v1/social/conversations") {
    return listConversations(actor, user);
  }

  if (request.method === "GET" && path === "/v1/social/messages") {
    return listMessages(actor, request, user);
  }

  if (request.method === "POST" && path === "/v1/social/messages") {
    return sendMessage(actor, request, user);
  }

  if (request.method === "POST" && path === "/v1/social/messages/read") {
    return markMessagesRead(actor, request, user);
  }

  return null;
}
