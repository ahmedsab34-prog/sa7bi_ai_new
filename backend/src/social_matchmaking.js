// Sa7bi AI - server-authoritative quick matchmaking with automatic AI fallback.
// Reuses the existing Sa7biSocial Durable Object and game_rooms table.

const QUEUE_WAIT_MS = 25 * 1000;
const MAX_QUEUE_SCAN = 100;
const SUPPORTED_GAMES = new Set([
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

function readRows(cursor) {
  if (!cursor) return [];
  if (typeof cursor.toArray === "function") return cursor.toArray();
  return Array.isArray(cursor) ? cursor : [];
}

function parseState(room) {
  try {
    const value = JSON.parse(room?.state_json || "{}");
    return value && typeof value === "object" && !Array.isArray(value)
      ? value
      : {};
  } catch (_) {
    return {};
  }
}


function initialGameState(game) {
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

function initialAiState(game) {
  if (game === "tic_tac_toe") {
    return {
      aiOpponent: true,
      botName: "صاحبي AI",
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
      aiOpponent: true,
      botName: "صاحبي AI",
      choices: {},
      round: 1,
      result: null,
      lastResult: null,
      lastWinner: null,
      lastHumanChoice: null,
      lastBotChoice: null,
      scores: { host: 0, guest: 0, draws: 0 },
      history: [],
    };
  }

  return {
    aiOpponent: true,
    botName: "صاحبي AI",
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

function queueState(room) {
  const state = parseState(room);
  return state.matchmaking === true &&
    state.matchmakingStatus === "searching";
}

function getRoom(sql, roomId) {
  return readRows(sql.exec(
    "SELECT * FROM game_rooms WHERE id = ? LIMIT 1",
    roomId,
  ))[0] || null;
}

function isWriteSuccessful(cursor) {
  return Number(cursor?.rowsWritten || 0) > 0;
}

function nextTimestamp(room) {
  return Math.max(Date.now(), Number(room.updated_at || 0) + 1);
}

async function roomResult(actor, roomId, userId, extra = {}) {
  return json({
    ok: true,
    ...extra,
    room: await actor.roomPayload(roomId, userId),
  });
}

function promoteRoomToAi(actor, room) {
  if (!room || room.status !== "waiting" || room.guest_id) return false;

  const state = parseState(room);
  if (state.matchmaking !== true ||
      state.matchmakingStatus !== "searching") return false;

  const deadline = Number(state.matchmakingExpiresAt || 0);
  if (!Number.isFinite(deadline) || deadline > Date.now()) return false;

  const now = nextTimestamp(room);
  const aiState = {
    ...initialAiState(room.game),
    matchmaking: true,
    matchmakingStatus: "ai_fallback",
    matchmakingStartedAt: Number(state.matchmakingStartedAt || room.created_at || now),
    matchmakingExpiresAt: deadline,
    aiFallbackAt: now,
  };

  const cursor = actor.ctx.storage.sql.exec(
    `UPDATE game_rooms
     SET state_json = ?, status = 'playing', updated_at = ?
     WHERE id = ? AND status = 'waiting' AND guest_id IS NULL AND updated_at = ?`,
    JSON.stringify(aiState),
    now,
    room.id,
    room.updated_at,
  );

  return isWriteSuccessful(cursor);
}

function setMatchedRoom(actor, room, guestId) {
  if (!room || room.status !== "waiting" || room.guest_id) return false;

  const state = parseState(room);
  if (state.matchmaking !== true ||
      state.matchmakingStatus !== "searching") return false;

  const now = nextTimestamp(room);
  const matchedState = {
    ...state,
    matchmakingStatus: "matched",
    matchedAt: now,
  };

  const cursor = actor.ctx.storage.sql.exec(
    `UPDATE game_rooms
     SET guest_id = ?, state_json = ?, status = 'playing', updated_at = ?
     WHERE id = ? AND status = 'waiting' AND guest_id IS NULL AND updated_at = ?`,
    guestId,
    JSON.stringify(matchedState),
    now,
    room.id,
    room.updated_at,
  );

  return isWriteSuccessful(cursor);
}

async function createQueueRoom(actor, user, game) {
  const sql = actor.ctx.storage.sql;
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  let unique = false;

  for (let attempt = 0; attempt < 12; attempt++) {
    const bytes = crypto.getRandomValues(new Uint8Array(6));
    code = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
    if (readRows(sql.exec(
      "SELECT id FROM game_rooms WHERE code = ? LIMIT 1",
      code,
    )).length === 0) {
      unique = true;
      break;
    }
  }

  if (!unique) return json({ ok: false, error: "INVITE_CODE_GENERATION_FAILED" }, 503);

  const roomId = crypto.randomUUID();
  const now = Date.now();
  const deadline = now + QUEUE_WAIT_MS;
  const state = {
    ...initialGameState(game),
    matchmaking: true,
    matchmakingStatus: "searching",
    matchmakingStartedAt: now,
    matchmakingExpiresAt: deadline,
  };

  sql.exec(
    `INSERT INTO game_rooms
     (id, code, game, host_id, guest_id, state_json, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, NULL, ?, 'waiting', ?, ?)`,
    roomId,
    code,
    game,
    user.id,
    JSON.stringify(state),
    now,
    now,
  );

  return roomResult(actor, roomId, user.id, {
    matched: false,
    aiFallback: false,
    waitSeconds: Math.ceil(QUEUE_WAIT_MS / 1000),
  });
}

async function startQuickMatch(request, actor) {
  const user = await actor.requireUser(request);
  if (user instanceof Response) return user;

  const body = await actor.readBody(request);
  if (body?.error) {
    return json({ ok: false, error: body.error }, 400);
  }

  const game = typeof body?.game === "string" ? body.game : "";
  if (!SUPPORTED_GAMES.has(game)) {
    return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
  }

  const sql = actor.ctx.storage.sql;
  const ownRooms = readRows(sql.exec(
    `SELECT * FROM game_rooms
     WHERE host_id = ? AND game = ? AND status = 'waiting' AND guest_id IS NULL
     ORDER BY created_at DESC LIMIT 20`,
    user.id,
    game,
  ));

  // Reuse an existing search started by this player; never create duplicate
  // queue entries when the user taps twice or the mobile request is retried.
  for (const ownRoom of ownRooms) {
    if (!queueState(ownRoom)) continue;
    const deadline = Number(parseState(ownRoom).matchmakingExpiresAt || 0);
    if (deadline > Date.now()) {
      return roomResult(actor, ownRoom.id, user.id, {
        matched: false,
        aiFallback: false,
        waitSeconds: Math.max(1, Math.ceil((deadline - Date.now()) / 1000)),
        reused: true,
      });
    }

    promoteRoomToAi(actor, ownRoom);
    const latest = getRoom(sql, ownRoom.id);
    if (latest?.status === "playing") {
      const latestState = parseState(latest);
      return roomResult(actor, latest.id, user.id, {
        matched: true,
        aiFallback: latestState.aiOpponent === true,
        reused: true,
      });
    }
  }

  const candidates = readRows(sql.exec(
    `SELECT * FROM game_rooms
     WHERE game = ? AND status = 'waiting' AND guest_id IS NULL AND host_id <> ?
     ORDER BY created_at ASC LIMIT ?`,
    game,
    user.id,
    MAX_QUEUE_SCAN,
  ));

  for (const candidate of candidates) {
    if (!queueState(candidate)) continue;
    const state = parseState(candidate);
    const deadline = Number(state.matchmakingExpiresAt || 0);

    if (!Number.isFinite(deadline) || deadline <= Date.now()) {
      promoteRoomToAi(actor, candidate);
      continue;
    }

    if (setMatchedRoom(actor, candidate, user.id)) {
      return roomResult(actor, candidate.id, user.id, {
        matched: true,
        aiFallback: false,
      });
    }
  }

  return createQueueRoom(actor, user, game);
}

async function maybeResolveExpiredRoom(request, actor, roomId) {
  const room = getRoom(actor.ctx.storage.sql, roomId);
  if (!room) return null;

  const state = parseState(room);
  if (state.matchmaking !== true) return null;
  if (state.matchmakingStatus !== "searching") return null;

  const user = await actor.requireUser(request);
  if (user instanceof Response) return user;
  if (room.host_id !== user.id && room.guest_id !== user.id) {
    return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
  }

  if (room.status === "waiting" && !room.guest_id) {
    const deadline = Number(state.matchmakingExpiresAt || 0);
    if (Number.isFinite(deadline) && deadline <= Date.now()) {
      promoteRoomToAi(actor, room);
      const latest = getRoom(actor.ctx.storage.sql, roomId);
      if (latest?.status === "playing" &&
          parseState(latest).aiOpponent === true) {
        return roomResult(actor, roomId, user.id, {
          matched: true,
          aiFallback: true,
        });
      }
    }
  }

  // Let the original room handler return non-expired or already matched rooms.
  return null;
}


async function cancelQuickMatch(request, actor, roomId) {
  const user = await actor.requireUser(request);
  if (user instanceof Response) return user;

  const room = getRoom(actor.ctx.storage.sql, roomId);
  if (!room) return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
  if (room.host_id !== user.id) {
    return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
  }
  if (room.status !== "waiting" || room.guest_id || !queueState(room)) {
    return json({ ok: false, error: "MATCH_SEARCH_ALREADY_FINISHED" }, 409);
  }

  const state = {
    ...parseState(room),
    matchmakingStatus: "cancelled",
    matchmakingCancelledAt: Date.now(),
  };
  const updatedAt = nextTimestamp(room);
  const cursor = actor.ctx.storage.sql.exec(
    `UPDATE game_rooms
     SET state_json = ?, status = 'finished', updated_at = ?
     WHERE id = ? AND host_id = ? AND status = 'waiting'
       AND guest_id IS NULL AND updated_at = ?`,
    JSON.stringify(state),
    updatedAt,
    roomId,
    user.id,
    room.updated_at,
  );
  if (!isWriteSuccessful(cursor)) {
    return json({ ok: false, error: "MATCH_SEARCH_ALREADY_FINISHED" }, 409);
  }
  return roomResult(actor, roomId, user.id, { cancelled: true });
}

/**
 * Routes quick matchmaking and resolves expired queue rooms to AI on the server.
 * Return null for all paths owned by the existing social-games handler.
 */
export async function handleSocialMatchmaking(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  if (method === "POST" && path === "/v1/games/matchmaking") {
    try {
      return await startQuickMatch(request, actor);
    } catch (_) {
      return json({
        ok: false,
        error: "MATCHMAKING_INTERNAL_ERROR",
        message: "تعذر البحث عن لاعب الآن. حاول مرة أخرى.",
      }, 500);
    }
  }

  const cancelMatch = path.match(/^\/v1\/games\/rooms\/([a-f0-9-]{36})\/cancel-matchmaking$/i);
  if (method === "POST" && cancelMatch) {
    try {
      return await cancelQuickMatch(request, actor, cancelMatch[1]);
    } catch (_) {
      return json({ ok: false, error: "MATCHMAKING_INTERNAL_ERROR" }, 500);
    }
  }

  const roomMatch = path.match(/^\/v1\/games\/rooms\/([a-f0-9-]{36})$/i);
  if (method === "GET" && roomMatch) {
    try {
      return await maybeResolveExpiredRoom(request, actor, roomMatch[1]);
    } catch (_) {
      return json({
        ok: false,
        error: "MATCHMAKING_INTERNAL_ERROR",
        message: "تعذر تحديث حالة البحث عن لاعب.",
      }, 500);
    }
  }

  return null;
}

export const SOCIAL_MATCHMAKING_WAIT_SECONDS = Math.ceil(QUEUE_WAIT_MS / 1000);
