
// Sa7bi Connect - private conversation realtime transport.
// Uses the existing SQLite-backed Sa7biSocial Durable Object.
// REST remains the source of truth; WebSocket is an optional live event channel.

const UUID_PATTERN = /^[a-f0-9-]{36}$/i;
const SOCKET_TAG_PREFIX = "sa7bi-private-conversation:";
const MAX_FRAME_LENGTH = 4096;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function socketTag(conversationId) {
  return `${SOCKET_TAG_PREFIX}${conversationId}`;
}

function sendSocketEvent(socket, event) {
  if (!socket || socket.readyState !== 1) return false;

  try {
    socket.send(JSON.stringify({
      version: 1,
      sentAt: Date.now(),
      ...event,
    }));
    return true;
  } catch (_) {
    return false;
  }
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );

  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

function readSocketAttachment(socket) {
  try {
    const value = socket.deserializeAttachment();
    if (!value || typeof value !== "object") return null;
    if (typeof value.userId !== "string") return null;
    if (typeof value.conversationId !== "string") return null;
    if (typeof value.tokenHash !== "string") return null;
    return value;
  } catch (_) {
    return null;
  }
}

async function isSessionActive(actor, attachment) {
  const row = actor.ctx.storage.sql.exec(
    `SELECT user_id
     FROM sessions
     WHERE token_hash = ? AND expires_at > ?`,
    attachment.tokenHash,
    Date.now(),
  ).toArray()[0];

  return Boolean(row && row.user_id === attachment.userId);
}

function getConversation(actor, conversationId) {
  return actor.ctx.storage.sql.exec(
    `SELECT id, user_a, user_b
     FROM social_conversations
     WHERE id = ?`,
    conversationId,
  ).toArray()[0] || null;
}

function isConversationMember(conversation, userId) {
  return Boolean(conversation && (
    conversation.user_a === userId ||
    conversation.user_b === userId
  ));
}

/**
 * Handles GET /v1/social/realtime?conversationId=<uuid>.
 * Returns null for paths owned by other handlers.
 */
export async function handlePrivateRealtimeRequest(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (path !== "/v1/social/realtime") return null;

  if (request.method.toUpperCase() !== "GET") {
    return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  }

  if ((request.headers.get("Upgrade") || "").toLowerCase() !== "websocket") {
    return json({ ok: false, error: "WEBSOCKET_UPGRADE_REQUIRED" }, 426);
  }

  const conversationId = url.searchParams.get("conversationId") || "";
  if (!UUID_PATTERN.test(conversationId)) {
    return json({ ok: false, error: "INVALID_CONVERSATION_ID" }, 400);
  }

  const user = await actor.requireUser(request);
  if (user instanceof Response) return user;

  const authorization = request.headers.get("Authorization") || "";
  const tokenMatch = authorization.match(/^Bearer ([a-f0-9]{64})$/i);
  if (!tokenMatch) {
    return json({ ok: false, error: "AUTH_REQUIRED" }, 401);
  }

  // Safe for old Durable Object instances: ensure only the table needed here exists.
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

  const conversation = getConversation(actor, conversationId);
  if (!conversation) {
    return json({ ok: false, error: "CONVERSATION_NOT_FOUND" }, 404);
  }

  if (!isConversationMember(conversation, user.id)) {
    return json({ ok: false, error: "CONVERSATION_ACCESS_DENIED" }, 403);
  }

  if (typeof WebSocketPair !== "function") {
    return json({ ok: false, error: "WEBSOCKET_RUNTIME_UNAVAILABLE" }, 503);
  }

  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);
  const tokenHash = await hashToken(tokenMatch[1]);
  const tag = socketTag(conversationId);

  actor.ctx.acceptWebSocket(server, [tag]);
  server.serializeAttachment({
    version: 1,
    userId: user.id,
    conversationId,
    tokenHash,
    connectedAt: Date.now(),
    lastTypingAt: 0,
  });

  sendSocketEvent(server, {
    type: "connection.ready",
    conversationId,
  });

  await broadcastConversationEvent(actor, conversationId, {
    type: "presence.changed",
    conversationId,
    userId: user.id,
    online: true,
  }, { excludeUserId: user.id });

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
}

/** Broadcasts an event only to sockets subscribed to this conversation. */
export async function broadcastConversationEvent(
  actor,
  conversationId,
  event,
  { excludeUserId = null } = {},
) {
  if (!UUID_PATTERN.test(conversationId || "")) return 0;
  if (typeof actor.ctx.getWebSockets !== "function") return 0;

  let sockets;
  try {
    sockets = actor.ctx.getWebSockets(socketTag(conversationId));
  } catch (_) {
    return 0;
  }

  let delivered = 0;
  for (const socket of sockets || []) {
    const attachment = readSocketAttachment(socket);
    if (!attachment || attachment.conversationId !== conversationId) continue;
    if (excludeUserId && attachment.userId === excludeUserId) continue;

    if (!(await isSessionActive(actor, attachment))) {
      try { socket.close(4001, "Session expired"); } catch (_) {}
      continue;
    }

    const currentConversation = getConversation(actor, conversationId);
    if (!isConversationMember(currentConversation, attachment.userId)) {
      try { socket.close(1008, "Conversation access revoked"); } catch (_) {}
      continue;
    }

    if (sendSocketEvent(socket, event)) delivered++;
  }

  return delivered;
}

/** Handles small client control frames. Message writes still use authenticated REST. */
export async function handlePrivateRealtimeMessage(actor, socket, rawMessage) {
  const attachment = readSocketAttachment(socket);
  if (!attachment) {
    try { socket.close(1008, "Invalid connection state"); } catch (_) {}
    return;
  }

  if (!(await isSessionActive(actor, attachment))) {
    try { socket.close(4001, "Session expired"); } catch (_) {}
    return;
  }

  const conversation = getConversation(actor, attachment.conversationId);
  if (!isConversationMember(conversation, attachment.userId)) {
    try { socket.close(1008, "Conversation access revoked"); } catch (_) {}
    return;
  }

  if (typeof rawMessage !== "string" || rawMessage.length > MAX_FRAME_LENGTH) {
    sendSocketEvent(socket, { type: "error", code: "INVALID_FRAME" });
    return;
  }

  let payload;
  try {
    payload = JSON.parse(rawMessage);
  } catch (_) {
    sendSocketEvent(socket, { type: "error", code: "INVALID_JSON" });
    return;
  }

  const type = typeof payload?.type === "string" ? payload.type : "";

  if (type === "ping") {
    sendSocketEvent(socket, { type: "pong" });
    return;
  }

  if (type !== "typing.start" && type !== "typing.stop") {
    sendSocketEvent(socket, { type: "error", code: "UNSUPPORTED_EVENT" });
    return;
  }

  const now = Date.now();
  const lastTypingAt = Number(attachment.lastTypingAt || 0);
  if (type === "typing.start" && now - lastTypingAt < 800) return;

  if (type === "typing.start") {
    attachment.lastTypingAt = now;
    try { socket.serializeAttachment(attachment); } catch (_) {}
  }

  await broadcastConversationEvent(actor, attachment.conversationId, {
    type: "typing.changed",
    conversationId: attachment.conversationId,
    userId: attachment.userId,
    isTyping: type === "typing.start",
  }, { excludeUserId: attachment.userId });
}

export async function handlePrivateRealtimeClose(actor, socket) {
  const attachment = readSocketAttachment(socket);
  if (!attachment) return;

  let sockets = [];
  try {
    sockets = actor.ctx.getWebSockets(socketTag(attachment.conversationId));
  } catch (_) {
    return;
  }

  const anotherSessionIsOpen = (sockets || []).some((candidate) => {
    if (candidate === socket || candidate.readyState !== 1) return false;
    const other = readSocketAttachment(candidate);
    return other?.userId === attachment.userId;
  });

  if (!anotherSessionIsOpen) {
    await broadcastConversationEvent(actor, attachment.conversationId, {
      type: "presence.changed",
      conversationId: attachment.conversationId,
      userId: attachment.userId,
      online: false,
    }, { excludeUserId: attachment.userId });
  }
}

export async function handlePrivateRealtimeError(actor, socket) {
  await handlePrivateRealtimeClose(actor, socket);
  try {
    if (socket.readyState === 1) socket.close(1011, "Realtime transport error");
  } catch (_) {}
}
