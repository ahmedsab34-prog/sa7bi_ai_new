// Sa7bi AI community groups and AI game opponents.
// This module extends the existing Sa7biSocial Durable Object and reuses
// its authenticated users, sessions, game_rooms table and SQLite storage.

import { Chess } from "chess.js";

const MAX_GROUP_NAME = 40;
const MAX_GROUP_DESCRIPTION = 160;
const MAX_GROUP_MEMBERS = 200;
const MAX_MESSAGE_LENGTH = 3000;
const MESSAGE_RATE_WINDOW_MS = 60 * 1000;
const MESSAGE_RATE_LIMIT = 30;
const MAX_HISTORY = 100;
const SUPPORTED_GAMES = new Set([
  "tic_tac_toe",
  "rock_paper_scissors",
  "chess",
]);
const TTT_WINS = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];

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

function readRows(cursor) {
  return cursor && typeof cursor.toArray === "function"
    ? cursor.toArray()
    : [];
}

function ensureCommunityTables(actor) {
  const sql = actor.ctx.storage.sql;

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_groups (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      created_by TEXT NOT NULL,
      is_public INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_groups_public_updated_idx
    ON social_groups(is_public, updated_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_group_members (
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'member',
      joined_at INTEGER NOT NULL,
      last_read_at INTEGER,
      PRIMARY KEY(group_id, user_id)
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_group_members_user_idx
    ON social_group_members(user_id, joined_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_group_messages (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_group_messages_group_idx
    ON social_group_messages(group_id, created_at DESC)
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_group_messages_sender_idx
    ON social_group_messages(sender_id, created_at DESC)
  `);
}

async function requireUser(actor, request) {
  const user = await actor.requireUser(request);
  return user instanceof Response ? user : user;
}

async function readBody(actor, request) {
  const body = await actor.readBody(request);
  if (!body || typeof body !== "object" || body.error) {
    return { error: body?.error || "INVALID_JSON" };
  }
  return body;
}

function isGroupMember(actor, groupId, userId) {
  return readRows(actor.ctx.storage.sql.exec(
    `SELECT group_id FROM social_group_members
     WHERE group_id = ? AND user_id = ? LIMIT 1`,
    groupId,
    userId,
  )).length > 0;
}

function groupPayload(row) {
  return {
    id: row.id,
    name: row.name,
    description: row.description || "",
    ownerId: row.created_by,
    memberCount: Number(row.member_count || 0),
    isMember: Number(row.is_member || 0) === 1,
    lastMessage: row.last_message || "",
    createdAt: Number(row.created_at || 0),
    updatedAt: Number(row.updated_at || 0),
  };
}

async function listGroups(actor, user) {
  const rows = readRows(actor.ctx.storage.sql.exec(
    `SELECT g.id, g.name, g.description, g.created_by,
            g.created_at, g.updated_at,
            (SELECT COUNT(*) FROM social_group_members m
             WHERE m.group_id = g.id) AS member_count,
            EXISTS(SELECT 1 FROM social_group_members mine
                   WHERE mine.group_id = g.id AND mine.user_id = ?) AS is_member,
            (SELECT body FROM social_group_messages msg
             WHERE msg.group_id = g.id
             ORDER BY msg.created_at DESC LIMIT 1) AS last_message
     FROM social_groups g
     WHERE g.is_public = 1
     ORDER BY g.updated_at DESC, g.created_at DESC
     LIMIT 100`,
    user.id,
  ));

  return json({ ok: true, groups: rows.map(groupPayload) });
}

async function createGroup(actor, request, user) {
  const body = await readBody(actor, request);
  if (body.error) return json({ ok: false, error: body.error }, 400);

  const name = safeString(body.name, MAX_GROUP_NAME);
  const description = safeString(body.description, MAX_GROUP_DESCRIPTION);

  if (name.length < 3) {
    return json({
      ok: false,
      error: "INVALID_GROUP_NAME",
      message: "اسم المجموعة يجب أن يكون من 3 إلى 40 حرفًا.",
    }, 400);
  }

  const now = Date.now();
  const groupId = crypto.randomUUID();

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_groups
     (id, name, description, created_by, is_public, created_at, updated_at)
     VALUES (?, ?, ?, ?, 1, ?, ?)`,
    groupId,
    name,
    description,
    user.id,
    now,
    now,
  );

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_group_members
     (group_id, user_id, role, joined_at, last_read_at)
     VALUES (?, ?, 'owner', ?, ?)`,
    groupId,
    user.id,
    now,
    now,
  );

  const row = readRows(actor.ctx.storage.sql.exec(
    `SELECT g.id, g.name, g.description, g.created_by,
            g.created_at, g.updated_at,
            1 AS member_count, 1 AS is_member, '' AS last_message
     FROM social_groups g WHERE g.id = ?`,
    groupId,
  ))[0];

  return json({ ok: true, group: groupPayload(row) }, 201);
}

async function joinGroup(actor, groupId, user) {
  const group = readRows(actor.ctx.storage.sql.exec(
    `SELECT id, is_public FROM social_groups WHERE id = ?`,
    groupId,
  ))[0];

  if (!group || Number(group.is_public) !== 1) {
    return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);
  }

  if (!isGroupMember(actor, groupId, user.id)) {
    const countRow = readRows(actor.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS member_count FROM social_group_members
       WHERE group_id = ?`,
      groupId,
    ))[0];

    if (Number(countRow?.member_count || 0) >= MAX_GROUP_MEMBERS) {
      return json({ ok: false, error: "GROUP_FULL" }, 409);
    }

    actor.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO social_group_members
       (group_id, user_id, role, joined_at, last_read_at)
       VALUES (?, ?, 'member', ?, ?)`,
      groupId,
      user.id,
      Date.now(),
      Date.now(),
    );
  }

  const row = readRows(actor.ctx.storage.sql.exec(
    `SELECT g.id, g.name, g.description, g.created_by,
            g.created_at, g.updated_at,
            (SELECT COUNT(*) FROM social_group_members m
             WHERE m.group_id = g.id) AS member_count,
            1 AS is_member,
            (SELECT body FROM social_group_messages msg
             WHERE msg.group_id = g.id
             ORDER BY msg.created_at DESC LIMIT 1) AS last_message
     FROM social_groups g WHERE g.id = ?`,
    groupId,
  ))[0];

  return json({ ok: true, group: groupPayload(row) });
}

async function getGroupMessages(actor, request, groupId, user) {
  if (!isGroupMember(actor, groupId, user.id)) {
    return json({ ok: false, error: "GROUP_MEMBERSHIP_REQUIRED" }, 403);
  }

  const url = new URL(request.url);
  const requestedLimit = Number(url.searchParams.get("limit") || 50);
  const limit = Number.isFinite(requestedLimit)
    ? Math.max(1, Math.min(100, Math.floor(requestedLimit)))
    : 50;

  const exists = readRows(actor.ctx.storage.sql.exec(
    `SELECT id FROM social_groups WHERE id = ?`,
    groupId,
  ))[0];
  if (!exists) return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);

  const rows = readRows(actor.ctx.storage.sql.exec(
    `SELECT msg.id, msg.group_id, msg.sender_id, msg.body,
            msg.created_at, users.username
     FROM (
       SELECT id, group_id, sender_id, body, created_at
       FROM social_group_messages
       WHERE group_id = ?
       ORDER BY created_at DESC
       LIMIT ?
     ) msg
     LEFT JOIN users ON users.id = msg.sender_id
     ORDER BY msg.created_at ASC`,
    groupId,
    limit,
  ));

  return json({
    ok: true,
    messages: rows.map((row) => ({
      id: row.id,
      groupId: row.group_id,
      senderId: row.sender_id,
      username: row.username || "لاعب",
      text: row.body,
      createdAt: Number(row.created_at || 0),
      isMine: row.sender_id === user.id,
    })),
  });
}

async function sendGroupMessage(actor, request, groupId, user) {
  if (!isGroupMember(actor, groupId, user.id)) {
    return json({ ok: false, error: "GROUP_MEMBERSHIP_REQUIRED" }, 403);
  }

  const body = await readBody(actor, request);
  if (body.error) return json({ ok: false, error: body.error }, 400);

  const messageText = typeof body.text === "string" ? body.text.trim() : "";
  if (!messageText || messageText.length > MAX_MESSAGE_LENGTH) {
    return json({
      ok: false,
      error: "INVALID_MESSAGE",
      message: `الرسالة يجب أن تكون من حرف واحد إلى ${MAX_MESSAGE_LENGTH} حرف.`,
    }, 400);
  }

  const now = Date.now();
  const recent = readRows(actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS message_count
     FROM social_group_messages
     WHERE sender_id = ? AND created_at >= ?`,
    user.id,
    now - MESSAGE_RATE_WINDOW_MS,
  ))[0];

  if (Number(recent?.message_count || 0) >= MESSAGE_RATE_LIMIT) {
    return json({ ok: false, error: "MESSAGE_RATE_LIMIT" }, 429);
  }

  const messageId = crypto.randomUUID();
  actor.ctx.storage.sql.exec(
    `INSERT INTO social_group_messages
     (id, group_id, sender_id, body, created_at)
     VALUES (?, ?, ?, ?, ?)`,
    messageId,
    groupId,
    user.id,
    messageText,
    now,
  );
  actor.ctx.storage.sql.exec(
    `UPDATE social_groups SET updated_at = ? WHERE id = ?`,
    now,
    groupId,
  );

  return json({
    ok: true,
    message: {
      id: messageId,
      groupId,
      senderId: user.id,
      username: user.username || "لاعب",
      text: messageText,
      createdAt: now,
      isMine: true,
    },
  }, 201);
}

function randomCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
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

  const chess = new Chess();
  return {
    aiOpponent: true,
    botName: "صاحبي AI",
    fen: chess.fen(),
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

function appendHistory(state, item) {
  if (!Array.isArray(state.history)) state.history = [];
  state.history.push(item);
  if (state.history.length > MAX_HISTORY) {
    state.history = state.history.slice(-MAX_HISTORY);
  }
}

function tttWinner(board) {
  for (const [a, b, c] of TTT_WINS) {
    if (board[a] && board[a] === board[b] && board[a] === board[c]) {
      return board[a];
    }
  }
  return null;
}

function chooseTttMove(board) {
  const available = board
    .map((cell, index) => cell === "" ? index : -1)
    .filter((index) => index >= 0);

  if (!available.length) return -1;

  const findWinningMove = (mark) => {
    for (const index of available) {
      const copy = [...board];
      copy[index] = mark;
      if (tttWinner(copy) === mark) return index;
    }
    return -1;
  };

  const winning = findWinningMove("O");
  if (winning >= 0) return winning;

  const block = findWinningMove("X");
  if (block >= 0) return block;

  if (board[4] === "") return 4;
  for (const index of [0, 2, 6, 8]) {
    if (board[index] === "") return index;
  }
  return available[0];
}

function chooseRpsMove() {
  const options = ["rock", "paper", "scissors"];
  const bytes = crypto.getRandomValues(new Uint8Array(1));
  return options[bytes[0] % options.length];
}

function rpsWinner(hostChoice, guestChoice) {
  if (hostChoice === guestChoice) return "draw";
  const hostWins =
    (hostChoice === "rock" && guestChoice === "scissors") ||
    (hostChoice === "paper" && guestChoice === "rock") ||
    (hostChoice === "scissors" && guestChoice === "paper");
  return hostWins ? "host" : "guest";
}

function applyChessMoveToState(state, chess, move, winnerId = null) {
  state.fen = chess.fen();
  state.pgn = chess.pgn();
  state.turn = chess.turn();
  state.check = chess.isCheck();
  state.checkmate = chess.isCheckmate();
  state.draw = chess.isDraw();
  state.lastMove = {
    color: move.color,
    from: move.from,
    to: move.to,
    san: move.san,
    captured: move.captured || null,
    promotion: move.promotion || null,
  };
  appendHistory(state, state.lastMove);
  if (state.checkmate) state.winnerUserId = winnerId;
  return Boolean(state.checkmate || state.draw || chess.isGameOver());
}

function makeHumanChessMove(state, user, body) {
  const from = typeof body.from === "string" ? body.from.toLowerCase() : "";
  const to = typeof body.to === "string" ? body.to.toLowerCase() : "";
  const promotion = typeof body.promotion === "string"
    ? body.promotion.toLowerCase()
    : "q";

  if (!/^[a-h][1-8]$/.test(from) || !/^[a-h][1-8]$/.test(to)) {
    return { error: "INVALID_MOVE", status: 400, message: "مربع البداية أو الوصول غير صحيح." };
  }
  if (!["q", "r", "b", "n"].includes(promotion)) {
    return { error: "INVALID_MOVE", status: 400, message: "اختيار ترقية البيدق غير صحيح." };
  }

  let chess;
  try {
    chess = new Chess(typeof state.fen === "string" ? state.fen : undefined);
  } catch (_) {
    return { error: "INVALID_ROOM_STATE", status: 500 };
  }
  if (chess.turn() !== "w") return { error: "NOT_YOUR_TURN", status: 409 };

  let move = null;
  try {
    move = chess.move({ from, to, promotion });
  } catch (_) {
    move = null;
  }
  if (!move) return { error: "ILLEGAL_CHESS_MOVE", status: 409 };

  const finished = applyChessMoveToState(state, chess, move, user.id);
  if (finished) return { finished: true };

  const legalMoves = chess.moves({ verbose: true });
  if (legalMoves.length === 0) return { finished: true };

  // Prefer checkmates, promotions, captures and checks; choose among the
  // strongest legal moves so the AI is varied without making illegal moves.
  const scored = legalMoves.map((candidate) => {
    let score = 0;
    if (candidate.san.includes("#")) score += 1000;
    if (candidate.promotion) score += 80;
    if (candidate.captured) score += 12;
    if (candidate.san.includes("+")) score += 6;
    return { candidate, score };
  }).sort((a, b) => b.score - a.score);

  const bestScore = scored[0].score;
  const best = scored.filter((item) => item.score === bestScore);
  const pickBytes = crypto.getRandomValues(new Uint8Array(1));
  const choice = best[pickBytes[0] % best.length].candidate;
  const botMove = chess.move({
    from: choice.from,
    to: choice.to,
    promotion: choice.promotion || "q",
  });
  if (!botMove) return { error: "AI_MOVE_FAILED", status: 500 };

  const botFinished = applyChessMoveToState(state, chess, botMove, "sa7bi-ai");
  return { finished: botFinished };
}

async function createAiRoom(actor, request) {
  const user = await requireUser(actor, request);
  if (user instanceof Response) return user;

  const body = await readBody(actor, request);
  if (body.error) return json({ ok: false, error: body.error }, 400);
  const game = safeString(body.game, 40);
  if (!SUPPORTED_GAMES.has(game)) {
    return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
  }

  let code = "";
  let unique = false;
  for (let attempt = 0; attempt < 12; attempt++) {
    code = randomCode();
    if (readRows(actor.ctx.storage.sql.exec(
      "SELECT id FROM game_rooms WHERE code = ?", code,
    )).length === 0) {
      unique = true;
      break;
    }
  }
  if (!unique) return json({ ok: false, error: "ROOM_CREATE_FAILED" }, 503);

  const roomId = crypto.randomUUID();
  const now = Date.now();
  actor.ctx.storage.sql.exec(
    `INSERT INTO game_rooms
     (id, code, game, host_id, guest_id, state_json, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, NULL, ?, 'playing', ?, ?)`,
    roomId,
    code,
    game,
    user.id,
    JSON.stringify(initialAiState(game)),
    now,
    now,
  );

  return json({
    ok: true,
    room: await actor.roomPayload(roomId, user.id),
  }, 201);
}

async function playAiRoomMove(actor, request, roomId) {
  const room = readRows(actor.ctx.storage.sql.exec(
    "SELECT * FROM game_rooms WHERE id = ?", roomId,
  ))[0];
  if (!room) return null;

  const state = (() => {
    try { return JSON.parse(room.state_json); } catch (_) { return null; }
  })();
  if (!state || state.aiOpponent !== true) return null;

  const user = await requireUser(actor, request);
  if (user instanceof Response) return user;
  if (room.host_id !== user.id) {
    return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
  }
  if (room.status === "finished") {
    return json({ ok: false, error: "ROOM_FINISHED" }, 409);
  }
  if (room.status === "paused") {
    return json({ ok: false, error: "GAME_PAUSED" }, 409);
  }
  if (room.status !== "playing") {
    return json({ ok: false, error: "ROOM_NOT_PLAYING" }, 409);
  }

  const body = await readBody(actor, request);
  if (body.error) return json({ ok: false, error: body.error }, 400);
  let finished = false;

  if (room.game === "tic_tac_toe") {
    const index = body.index;
    if (!Number.isInteger(index) || index < 0 || index > 8) {
      return json({ ok: false, error: "INVALID_MOVE" }, 400);
    }
    if (!Array.isArray(state.board) || state.board.length !== 9 ||
        state.board.some((cell) => !["", "X", "O"].includes(cell))) {
      return json({ ok: false, error: "INVALID_ROOM_STATE" }, 500);
    }
    if (state.winner || state.next !== "X" || state.board[index] !== "") {
      return json({ ok: false, error: "INVALID_MOVE" }, 409);
    }

    state.board[index] = "X";
    state.moves = (Number(state.moves) || 0) + 1;
    appendHistory(state, { index, mark: "X", userId: user.id, at: Date.now() });
    let winner = tttWinner(state.board);
    let draw = !winner && state.board.every((cell) => cell !== "");

    if (!winner && !draw) {
      const botIndex = chooseTttMove(state.board);
      if (botIndex < 0) {
        draw = true;
      } else {
        state.board[botIndex] = "O";
        state.moves += 1;
        appendHistory(state, {
          index: botIndex,
          mark: "O",
          userId: "sa7bi-ai",
          at: Date.now(),
        });
        winner = tttWinner(state.board);
        draw = !winner && state.board.every((cell) => cell !== "");
      }
    }

    state.winner = winner || (draw ? "draw" : null);
    state.winnerUserId = winner === "X"
      ? user.id
      : winner === "O"
          ? "sa7bi-ai"
          : null;
    state.next = winner || draw ? null : "X";
    finished = Boolean(winner || draw);
  } else if (room.game === "rock_paper_scissors") {
    const humanChoice = typeof body.choice === "string"
      ? body.choice.toLowerCase()
      : "";
    if (!["rock", "paper", "scissors"].includes(humanChoice)) {
      return json({ ok: false, error: "INVALID_MOVE" }, 400);
    }

    const botChoice = chooseRpsMove();
    const winner = rpsWinner(humanChoice, botChoice);
    if (!state.scores || typeof state.scores !== "object") {
      state.scores = { host: 0, guest: 0, draws: 0 };
    }
    if (winner === "host") state.scores.host = Number(state.scores.host || 0) + 1;
    else if (winner === "guest") state.scores.guest = Number(state.scores.guest || 0) + 1;
    else state.scores.draws = Number(state.scores.draws || 0) + 1;

    const round = Number(state.round) || 1;
    const resultText = winner === "draw"
      ? "تعادل"
      : winner === "host"
          ? "فزت بالجولة"
          : "فاز صاحبي AI بالجولة";
    state.lastResult = resultText;
    state.result = resultText;
    state.lastWinner = winner;
    state.lastHumanChoice = humanChoice;
    state.lastBotChoice = botChoice;
    state.choices = {};
    appendHistory(state, {
      round,
      hostChoice: humanChoice,
      guestChoice: botChoice,
      winner,
      result: resultText,
      at: Date.now(),
    });
    state.round = round + 1;
  } else if (room.game === "chess") {
    const result = makeHumanChessMove(state, user, body);
    if (result.error) {
      return json({ ok: false, error: result.error, message: result.message }, result.status || 409);
    }
    finished = Boolean(result.finished);
  } else {
    return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
  }

  const nextStatus = finished ? "finished" : "playing";
  const updatedAt = Math.max(Date.now(), Number(room.updated_at || 0) + 1);
  const serializedState = JSON.stringify(state);
  const cursor = actor.ctx.storage.sql.exec(
    `UPDATE game_rooms
     SET state_json = ?, status = ?, updated_at = ?
     WHERE id = ? AND updated_at = ? AND status = 'playing'`,
    serializedState,
    nextStatus,
    updatedAt,
    roomId,
    room.updated_at,
  );

  if (Number(cursor?.rowsWritten || 0) === 0) {
    return json({ ok: false, error: "MOVE_CONFLICT" }, 409);
  }

  const saved = readRows(actor.ctx.storage.sql.exec(
    "SELECT * FROM game_rooms WHERE id = ?", roomId,
  ))[0];
  if (!saved || Number(saved.updated_at) !== updatedAt ||
      saved.state_json !== serializedState) {
    return json({ ok: false, error: "MOVE_CONFLICT" }, 409);
  }

  return json({ ok: true, room: await actor.roomPayload(roomId, user.id) });
}

/** Handles public group routes and AI game creation/moves; returns null otherwise. */
export async function handleSocialCommunity(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  const isGroupRoot = path === "/v1/social/groups";
  const groupMessages = path.match(/^\/v1\/social\/groups\/([a-f0-9-]{36})\/messages$/i);
  const groupJoin = path.match(/^\/v1\/social\/groups\/([a-f0-9-]{36})\/join$/i);
  const isAiCreate = path === "/v1/games/ai";
  const aiMove = path.match(/^\/v1\/games\/rooms\/([a-f0-9-]{36})\/move$/i);

  if (!isGroupRoot && !groupMessages && !groupJoin && !isAiCreate && !aiMove) {
    return null;
  }

  try {
    if (isGroupRoot || groupMessages || groupJoin) {
      ensureCommunityTables(actor);
      const user = await requireUser(actor, request);
      if (user instanceof Response) return user;

      if (isGroupRoot && method === "GET") return await listGroups(actor, user);
      if (isGroupRoot && method === "POST") return await createGroup(actor, request, user);
      if (groupJoin && method === "POST") {
        return await joinGroup(actor, groupJoin[1], user);
      }
      if (groupMessages && method === "GET") {
        return await getGroupMessages(actor, request, groupMessages[1], user);
      }
      if (groupMessages && method === "POST") {
        return await sendGroupMessage(actor, request, groupMessages[1], user);
      }
      return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
    }

    if (isAiCreate && method === "POST") {
      return await createAiRoom(actor, request);
    }
    if (aiMove && method === "POST") {
      return await playAiRoomMove(actor, request, aiMove[1]);
    }
    return null;
  } catch (_) {
    return json({
      ok: false,
      error: "SOCIAL_COMMUNITY_INTERNAL_ERROR",
      message: "تعذر إكمال طلب المجتمع أو مباراة الذكاء الاصطناعي. حاول مرة أخرى.",
    }, 500);
  }
}
