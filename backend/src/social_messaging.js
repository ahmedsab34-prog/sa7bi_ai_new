
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

  const recipientId = safeString(body.recipientUserId, 80);
  const game = safeString(body.game, 40);

  if (!isUuid(recipientId)) {
    return json({ ok: false, error: "INVALID_RECIPIENT" }, 400);
  }

  if (!SUPPORTED_INVITATION_GAMES.has(game)) {
    return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
  }

  if (recipientId === user.id) {
    return json({ ok: false, error: "CANNOT_INVITE_SELF" }, 409);
  }

  const recipient = actor.ctx.storage.sql.exec(
    "SELECT id FROM users WHERE id = ?",
    recipientId,
  ).toArray()[0];

  if (!recipient) {
    return json({ ok: false, error: "RECIPIENT_NOT_FOUND" }, 404);
  }

  const now = Date.now();
  const duplicate = actor.ctx.storage.sql.exec(
    `SELECT id
     FROM social_invitations
     WHERE sender_id = ?
       AND recipient_id = ?
       AND status = 'pending'
       AND expires_at > ?
     LIMIT 1`,
    user.id,
    recipientId,
    now,
  ).toArray()[0];

  if (duplicate) {
    return json({ ok: false, error: "INVITATION_ALREADY_PENDING" }, 409);
  }

  let code = "";
  let uniqueCode = false;
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  for (let attempt = 0; attempt < 12; attempt++) {
    const bytes = crypto.getRandomValues(new Uint8Array(6));
    code = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");

    const exists = actor.ctx.storage.sql.exec(
      "SELECT id FROM game_rooms WHERE code = ?",
      code,
    ).toArray()[0];

    if (!exists) {
      uniqueCode = true;
      break;
    }
  }

  if (!uniqueCode) {
    return json({ ok: false, error: "INVITE_CODE_GENERATION_FAILED" }, 503);
  }

  const roomId = crypto.randomUUID();
  const invitationId = crypto.randomUUID();
  const expiresAt = now + INVITATION_TTL_MS;

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

  try {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_invitations
       (id, sender_id, recipient_id, game, room_id, status, created_at, expires_at, responded_at)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, NULL)`,
      invitationId,
      user.id,
      recipientId,
      game,
      roomId,
      now,
      expiresAt,
    );
  } catch (_) {
    actor.ctx.storage.sql.exec(
      "DELETE FROM game_rooms WHERE id = ? AND host_id = ? AND guest_id IS NULL",
      roomId,
      user.id,
    );
    return json({ ok: false, error: "INVITATION_CREATE_FAILED" }, 500);
  }

  return json(
    {
      ok: true,
      invitation: invitationPayload(
        getInvitationRow(actor, invitationId),
        user.id,
      ),
    },
    201,
  );
}

async function respondToInvitation(actor, invitationId, request, user, action) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const invitation = getInvitationRow(actor, invitationId);

  if (!invitation) {
    return json({ ok: false, error: "INVITATION_NOT_FOUND" }, 404);
  }

  if (invitation.recipient_id !== user.id) {
    return json({ ok: false, error: "INVITATION_ACCESS_DENIED" }, 403);
  }

  const now = Date.now();

  if (invitation.status === "accepted" && action === "accept") {
    const room = actor.ctx.storage.sql.exec(
      "SELECT guest_id FROM game_rooms WHERE id = ?",
      invitation.room_id,
    ).toArray()[0];

    if (room && room.guest_id === user.id) {
      return json({
        ok: true,
        invitation: invitationPayload(getInvitationRow(actor, invitationId), user.id),
        room: await actor.roomPayload(invitation.room_id, user.id),
      });
    }
  }

  if (invitation.status !== "pending") {
    return json({ ok: false, error: "INVITATION_NOT_PENDING" }, 409);
  }

  if (invitation.expires_at <= now) {
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
       WHERE id = ? AND recipient_id = ? AND status = 'pending'`,
      now,
      invitationId,
      user.id,
    );

    return json({
      ok: true,
      invitation: invitationPayload(getInvitationRow(actor, invitationId), user.id),
    });
  }

  const room = actor.ctx.storage.sql.exec(
    "SELECT id, host_id, guest_id, status FROM game_rooms WHERE id = ?",
    invitation.room_id,
  ).toArray()[0];

  if (!room) {
    return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
  }

  if (room.guest_id && room.guest_id !== user.id) {
    return json({ ok: false, error: "ROOM_FULL" }, 409);
  }

  if (room.status !== "waiting" && room.guest_id !== user.id) {
    return json({ ok: false, error: "ROOM_NOT_AVAILABLE" }, 409);
  }

  if (!room.guest_id) {
    const update = actor.ctx.storage.sql.exec(
      `UPDATE game_rooms
       SET guest_id = ?, status = 'playing', updated_at = ?
       WHERE id = ? AND guest_id IS NULL AND status = 'waiting'`,
      user.id,
      now,
      invitation.room_id,
    );

    if (update.rowsWritten === 0) {
      return json({ ok: false, error: "ROOM_FULL" }, 409);
    }
  }

  const inviteUpdate = actor.ctx.storage.sql.exec(
    `UPDATE social_invitations
     SET status = 'accepted', responded_at = ?
     WHERE id = ? AND recipient_id = ? AND status = 'pending'`,
    now,
    invitationId,
    user.id,
  );

  if (inviteUpdate.rowsWritten === 0) {
    const currentRoom = actor.ctx.storage.sql.exec(
      "SELECT guest_id FROM game_rooms WHERE id = ?",
      invitation.room_id,
    ).toArray()[0];

    if (!currentRoom || currentRoom.guest_id !== user.id) {
      return json({ ok: false, error: "INVITATION_NOT_PENDING" }, 409);
    }
  }

  return json({
    ok: true,
    invitation: invitationPayload(getInvitationRow(actor, invitationId), user.id),
    room: await actor.roomPayload(invitation.room_id, user.id),
  });
}

async function getOrCreateConversation(actor, firstUserId, secondUserId) {
  const userA = firstUserId < secondUserId ? firstUserId : secondUserId;
  const userB = firstUserId < secondUserId ? secondUserId : firstUserId;

  let conversation = actor.ctx.storage.sql.exec(
    `SELECT id, user_a, user_b, created_at, updated_at
     FROM social_conversations
     WHERE user_a = ? AND user_b = ?`,
    userA,
    userB,
  ).toArray()[0];

  if (conversation) return conversation;

  const now = Date.now();
  const id = crypto.randomUUID();

  try {
    actor.ctx.storage.sql.exec(
      `INSERT INTO social_conversations (id, user_a, user_b, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)`,
      id,
      userA,
      userB,
      now,
      now,
    );
  } catch (_) {
    // If another request created the same pair first, read that conversation.
  }

  conversation = actor.ctx.storage.sql.exec(
    `SELECT id, user_a, user_b, created_at, updated_at
     FROM social_conversations
     WHERE user_a = ? AND user_b = ?`,
    userA,
    userB,
  ).toArray()[0];

  return conversation || null;
}

async function createConversation(actor, request, user) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const targetId = safeString(body.userId, 80);

  if (!isUuid(targetId)) {
    return json({ ok: false, error: "INVALID_USER_ID" }, 400);
  }

  if (targetId === user.id) {
    return json({ ok: false, error: "CANNOT_MESSAGE_SELF" }, 409);
  }

  const target = actor.ctx.storage.sql.exec(
    "SELECT id FROM users WHERE id = ?",
    targetId,
  ).toArray()[0];

  if (!target) {
    return json({ ok: false, error: "USER_NOT_FOUND" }, 404);
  }

  const conversation = await getOrCreateConversation(actor, user.id, targetId);

  if (!conversation) {
    return json({ ok: false, error: "CONVERSATION_CREATE_FAILED" }, 500);
  }

  return json({
    ok: true,
    conversation: await conversationPayload(actor, conversation, user.id),
  }, 201);
}

async function conversationPayload(actor, conversation, currentUserId) {
  const peerId = otherUserId(conversation, currentUserId);
  const peer = actor.ctx.storage.sql.exec(
    "SELECT id, username FROM users WHERE id = ?",
    peerId,
  ).toArray()[0];

  const lastMessage = actor.ctx.storage.sql.exec(
    `SELECT id, sender_id, body, created_at
     FROM social_messages
     WHERE conversation_id = ?
     ORDER BY created_at DESC
     LIMIT 1`,
    conversation.id,
  ).toArray()[0] || null;

  const unreadRow = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS unread_count
     FROM social_messages
     WHERE conversation_id = ?
       AND sender_id <> ?
       AND read_at IS NULL`,
    conversation.id,
    currentUserId,
  ).toArray()[0];

  return {
    id: conversation.id,
    otherUser: userSummary(peer?.id, peer?.username),
    lastMessage: lastMessage
      ? {
          id: lastMessage.id,
          senderId: lastMessage.sender_id,
          text: lastMessage.body,
          createdAt: lastMessage.created_at,
        }
      : null,
    unreadCount: Number(unreadRow?.unread_count || 0),
    createdAt: conversation.created_at,
    updatedAt: conversation.updated_at,
  };
}

async function listConversations(actor, user) {
  const rows = actor.ctx.storage.sql.exec(
    `SELECT id, user_a, user_b, created_at, updated_at
     FROM social_conversations
     WHERE user_a = ? OR user_b = ?
     ORDER BY updated_at DESC
     LIMIT 50`,
    user.id,
    user.id,
  ).toArray();

  const conversations = [];

  for (const row of rows) {
    conversations.push(await conversationPayload(actor, row, user.id));
  }

  return json({ ok: true, conversations });
}

async function getMessages(actor, request, user) {
  const url = new URL(request.url);
  const conversationId = url.searchParams.get("conversationId") || "";

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

  const requestedLimit = Number(url.searchParams.get("limit") || 50);
  const limit = Number.isFinite(requestedLimit)
    ? Math.max(1, Math.min(100, Math.floor(requestedLimit)))
    : 50;

  const rows = actor.ctx.storage.sql.exec(
    `SELECT id, conversation_id, sender_id, body, created_at, read_at
     FROM (
       SELECT id, conversation_id, sender_id, body, created_at, read_at
       FROM social_messages
       WHERE conversation_id = ?
       ORDER BY created_at DESC
       LIMIT ?
     )
     ORDER BY created_at ASC`,
    conversationId,
    limit,
  ).toArray();

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

  const conversationId = safeString(body.conversationId, 80);
  const messageText = typeof body.text === "string" ? body.text.trim() : "";

  if (!isUuid(conversationId)) {
    return json({ ok: false, error: "INVALID_CONVERSATION_ID" }, 400);
  }

  if (!messageText || messageText.length > MESSAGE_MAX_LENGTH) {
    return json({
      ok: false,
      error: "INVALID_MESSAGE",
      message: `الرسالة يجب أن تكون من حرف واحد إلى ${MESSAGE_MAX_LENGTH} حرف.`,
    }, 400);
  }

  const conversation = getConversationRow(actor, conversationId);

  if (!conversation) {
    return json({ ok: false, error: "CONVERSATION_NOT_FOUND" }, 404);
  }

  if (!conversationMember(conversation, user.id)) {
    return json({ ok: false, error: "CONVERSATION_ACCESS_DENIED" }, 403);
  }

  const now = Date.now();
  const recentRow = actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS message_count
     FROM social_messages
     WHERE sender_id = ? AND created_at >= ?`,
    user.id,
    now - MESSAGE_RATE_WINDOW_MS,
  ).toArray()[0];

  if (Number(recentRow?.message_count || 0) >= MESSAGE_RATE_LIMIT) {
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
    messageText,
    now,
  );

  actor.ctx.storage.sql.exec(
    "UPDATE social_conversations SET updated_at = ? WHERE id = ?",
    now,
    conversationId,
  );

  return json({
    ok: true,
    message: {
      id: messageId,
      conversationId,
      senderId: user.id,
      text: messageText,
      createdAt: now,
      readAt: null,
      isMine: true,
    },
  }, 201);
}

async function markMessagesRead(actor, request, user) {
  const body = await actor.readBody(request);
  const bodyError = bodyErrorResponse(body);
  if (bodyError) return bodyError;

  const conversationId = safeString(body.conversationId, 80);

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

/**
 * Returns a Response for the new messaging routes, or null for existing routes.
 * The actor is the existing Sa7biSocial Durable Object instance.
 */
export async function handleSocialMessaging(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  const isInvitationRoute = path === "/v1/social/invitations" ||
    /^\/v1\/social\/invitations\/[a-f0-9-]{36}\/(accept|decline)$/i.test(path);
  const isConversationRoute = path === "/v1/social/conversations";
  const isMessageRoute = path === "/v1/social/messages" ||
    path === "/v1/social/messages/read";

  if (!isInvitationRoute && !isConversationRoute && !isMessageRoute) {
    return null;
  }

  try {
    ensureMessagingTables(actor);

    const user = await actor.requireUser(request);
    if (user instanceof Response) return user;

    if (path === "/v1/social/invitations" && method === "GET") {
      return await listInvitations(actor, request, user);
    }

    if (path === "/v1/social/invitations" && method === "POST") {
      return await createInvitation(actor, request, user);
    }

    const invitationMatch = path.match(
      /^\/v1\/social\/invitations\/([a-f0-9-]{36})\/(accept|decline)$/i,
    );

    if (invitationMatch && method === "POST") {
      return await respondToInvitation(
        actor,
        invitationMatch[1],
        request,
        user,
        invitationMatch[2].toLowerCase(),
      );
    }

    if (path === "/v1/social/conversations" && method === "GET") {
      return await listConversations(actor, user);
    }

    if (path === "/v1/social/conversations" && method === "POST") {
      return await createConversation(actor, request, user);
    }

    if (path === "/v1/social/messages" && method === "GET") {
      return await getMessages(actor, request, user);
    }

    if (path === "/v1/social/messages" && method === "POST") {
      return await sendMessage(actor, request, user);
    }

    if (path === "/v1/social/messages/read" && method === "POST") {
      return await markMessagesRead(actor, request, user);
    }

    return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  } catch (_) {
    return json(
      {
        ok: false,
        error: "SOCIAL_MESSAGING_INTERNAL_ERROR",
        message: "تعذر إكمال طلب الدعوات أو الرسائل. حاول مرة أخرى.",
      },
      500,
    );
  }
}
