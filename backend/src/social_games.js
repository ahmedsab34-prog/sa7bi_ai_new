
// backend/src/social_games.js
// Sa7bi AI social accounts and persistent cross-device multiplayer games.
// Room state and accounts are stored in a SQLite-backed Durable Object.
// Every move is validated on the server before it is saved.

import { Chess } from "chess.js";

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const PASSWORD_ITERATIONS = 120000;
const MAX_BODY_BYTES = 16 * 1024;
const MAX_ROOM_HISTORY = 100;
const MAX_SAVED_ROOMS = 100;

const SUPPORTED_GAMES = new Set([
  "tic_tac_toe",
  "rock_paper_scissors",
  "chess",
]);

const TTT_WINS = [
  [0, 1, 2],
  [3, 4, 5],
  [6, 7, 8],
  [0, 3, 6],
  [1, 4, 7],
  [2, 5, 8],
  [0, 4, 8],
  [2, 4, 6],
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

function randomHex(byteLength = 32) {
  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function randomCode(length = 6) {
  // Excludes ambiguous characters such as I, O, 0 and 1.
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
}

async function sha256(value) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );

  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

async function hashPassword(password, saltHex) {
  const salt = Uint8Array.from(
    saltHex.match(/.{2}/g) || [],
    (part) => Number.parseInt(part, 16),
  );

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );

  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt,
      iterations: PASSWORD_ITERATIONS,
    },
    key,
    256,
  );

  return Array.from(new Uint8Array(bits), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

function constantTimeEqual(left, right) {
  if (typeof left !== "string" || typeof right !== "string") {
    return false;
  }

  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);

  for (let index = 0; index < length; index++) {
    difference |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }

  return difference === 0;
}

function safeUser(row) {
  return {
    id: row.id,
    username: row.username,
    createdAt: row.created_at,
  };
}

function parseJson(value) {
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}

function initialState(game) {
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

  const chess = new Chess();

  return {
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
  if (!Array.isArray(state.history)) {
    state.history = [];
  }

  state.history.push(item);

  if (state.history.length > MAX_ROOM_HISTORY) {
    state.history = state.history.slice(-MAX_ROOM_HISTORY);
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

function rpsWinner(hostChoice, guestChoice) {
  if (hostChoice === guestChoice) return "draw";

  const hostWins =
    (hostChoice === "rock" && guestChoice === "scissors") ||
    (hostChoice === "paper" && guestChoice === "rock") ||
    (hostChoice === "scissors" && guestChoice === "paper");

  return hostWins ? "host" : "guest";
}

function roleForUser(room, userId) {
  if (room.host_id === userId) return "host";
  if (room.guest_id === userId) return "guest";
  return null;
}

function publicPlayer(row, role, game) {
  if (!row) return null;

  let mark = role === "host" ? "X" : "O";

  if (game === "chess") {
    mark = role === "host" ? "white" : "black";
  } else if (game === "rock_paper_scissors") {
    mark = role === "host" ? "player_1" : "player_2";
  }

  return {
    id: row.id,
    username: row.username,
    mark,
  };
}

export async function handleSocialGames(request, env) {
  if (!env.SA7BI_SOCIAL) {
    return json(
      {
        ok: false,
        error: "SOCIAL_SERVICE_NOT_CONFIGURED",
        message: "خدمة الحسابات والألعاب لم تُفعّل في إعدادات الخادم بعد.",
      },
      503,
    );
  }

  const id = env.SA7BI_SOCIAL.idFromName("sa7bi-social-global-v1");
  return env.SA7BI_SOCIAL.get(id).fetch(request);
}

export class Sa7biSocial {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;

    ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    `);

    ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS sessions (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expires_at INTEGER NOT NULL
      )
    `);

    ctx.storage.sql.exec(`
      CREATE INDEX IF NOT EXISTS sessions_expiry_idx
      ON sessions(expires_at)
    `);

    ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS game_rooms (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL COLLATE NOCASE UNIQUE,
        game TEXT NOT NULL,
        host_id TEXT NOT NULL,
        guest_id TEXT,
        state_json TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `);

    ctx.storage.sql.exec(`
      CREATE INDEX IF NOT EXISTS game_rooms_host_idx
      ON game_rooms(host_id, updated_at DESC)
    `);

    ctx.storage.sql.exec(`
      CREATE INDEX IF NOT EXISTS game_rooms_guest_idx
      ON game_rooms(guest_id, updated_at DESC)
    `);
  }

  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    try {
      if (request.method === "POST" && path === "/v1/social/register") {
        return await this.register(request);
      }

      if (request.method === "POST" && path === "/v1/social/login") {
        return await this.login(request);
      }

      if (request.method === "GET" && path === "/v1/social/me") {
        const user = await this.requireUser(request);
        return user instanceof Response
          ? user
          : json({ ok: true, user: safeUser(user) });
      }

      if (request.method === "GET" && path === "/v1/social/users/search") {
        return await this.searchUsers(request);
      }

      if (request.method === "POST" && path === "/v1/games/rooms") {
        return await this.createRoom(request);
      }

      if (request.method === "POST" && path === "/v1/games/rooms/join") {
        return await this.joinRoom(request);
      }

      if (request.method === "GET" && path === "/v1/games/rooms/mine") {
        return await this.listMyRooms(request);
      }

      const actionMatch = path.match(
        /^\/v1\/games\/rooms\/([a-f0-9-]{36})\/(move|pause|resume)$/i,
      );

      if (request.method === "POST" && actionMatch) {
        const [, roomId, action] = actionMatch;

        if (action === "move") return await this.makeMove(request, roomId);
        if (action === "pause") {
          return await this.changeRoomStatus(request, roomId, "paused");
        }

        return await this.changeRoomStatus(request, roomId, "playing");
      }

      const roomMatch = path.match(/^\/v1\/games\/rooms\/([a-f0-9-]{36})$/i);

      if (request.method === "GET" && roomMatch) {
        return await this.getRoom(request, roomMatch[1]);
      }

      return json({ ok: false, error: "NOT_FOUND" }, 404);
    } catch (_) {
      // Never expose SQL errors, hashes, session tokens, or stack traces.
      return json(
        {
          ok: false,
          error: "SOCIAL_GAME_INTERNAL_ERROR",
          message: "حدث خطأ بالخدمة. حاول مرة أخرى.",
        },
        500,
      );
    }
  }

  async readBody(request) {
    const contentLength = Number(request.headers.get("Content-Length") || 0);

    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      return { error: "BODY_TOO_LARGE" };
    }

    const raw = await request.text();

    if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
      return { error: "BODY_TOO_LARGE" };
    }

    const body = parseJson(raw);

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return { error: "INVALID_JSON" };
    }

    return body;
  }

  async register(request) {
    const body = await this.readBody(request);

    if (body.error) {
      return json({ ok: false, error: body.error }, 400);
    }

    const username = typeof body.username === "string" ? body.username.trim() : "";
    const password = typeof body.password === "string" ? body.password : "";

    if (!/^[\p{L}\p{N}_.-]{3,24}$/u.test(username)) {
      return json(
        {
          ok: false,
          error: "INVALID_USERNAME",
          message: "اسم المستخدم يجب أن يكون من 3 إلى 24 حرفًا أو رقمًا.",
        },
        400,
      );
    }

    if (password.length < 10 || password.length > 128) {
      return json(
        {
          ok: false,
          error: "INVALID_PASSWORD",
          message: "كلمة المرور يجب أن تكون من 10 إلى 128 حرفًا.",
        },
        400,
      );
    }

    const existing = this.ctx.storage.sql
      .exec("SELECT id FROM users WHERE username = ? COLLATE NOCASE", username)
      .toArray()[0];

    if (existing) {
      return json({ ok: false, error: "USERNAME_TAKEN" }, 409);
    }

    const user = {
      id: crypto.randomUUID(),
      username,
      created_at: Date.now(),
    };
    const salt = randomHex(16);
    const passwordHash = await hashPassword(password, salt);

    try {
      this.ctx.storage.sql.exec(
        `INSERT INTO users
         (id, username, password_salt, password_hash, created_at)
         VALUES (?, ?, ?, ?, ?)`,
        user.id,
        user.username,
        salt,
        passwordHash,
        user.created_at,
      );
    } catch (_) {
      return json({ ok: false, error: "USERNAME_TAKEN" }, 409);
    }

    const token = await this.createSession(user.id);
    return json({ ok: true, token, user: safeUser(user) }, 201);
  }

  async login(request) {
    const body = await this.readBody(request);

    if (body.error) {
      return json({ ok: false, error: body.error }, 400);
    }

    const username = typeof body.username === "string" ? body.username.trim() : "";
    const password = typeof body.password === "string" ? body.password : "";

    if (!username || !password || password.length > 128) {
      return json({ ok: false, error: "USERNAME_AND_PASSWORD_REQUIRED" }, 400);
    }

    const row = this.ctx.storage.sql
      .exec(
        `SELECT id, username, password_salt, password_hash, created_at
         FROM users
         WHERE username = ? COLLATE NOCASE`,
        username,
      )
      .toArray()[0];

    if (!row) {
      return json({ ok: false, error: "INVALID_CREDENTIALS" }, 401);
    }

    const supplied = await hashPassword(password, row.password_salt);

    if (!constantTimeEqual(supplied, row.password_hash)) {
      return json({ ok: false, error: "INVALID_CREDENTIALS" }, 401);
    }

    const token = await this.createSession(row.id);
    return json({ ok: true, token, user: safeUser(row) });
  }

  async createSession(userId) {
    const token = randomHex(32);
    const tokenHash = await sha256(token);
    const now = Date.now();

    this.ctx.storage.sql.exec("DELETE FROM sessions WHERE expires_at <= ?", now);
    this.ctx.storage.sql.exec(
      `INSERT INTO sessions (token_hash, user_id, expires_at)
       VALUES (?, ?, ?)`,
      tokenHash,
      userId,
      now + SESSION_TTL_MS,
    );

    return token;
  }

  async requireUser(request) {
    const authorization = request.headers.get("Authorization") || "";
    const match = authorization.match(/^Bearer ([a-f0-9]{64})$/i);

    if (!match) {
      return json({ ok: false, error: "AUTH_REQUIRED" }, 401);
    }

    const tokenHash = await sha256(match[1]);
    const row = this.ctx.storage.sql
      .exec(
        `SELECT u.id, u.username, u.created_at
         FROM sessions s
         JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = ? AND s.expires_at > ?`,
        tokenHash,
        Date.now(),
      )
      .toArray()[0];

    return row || json({ ok: false, error: "SESSION_EXPIRED" }, 401);
  }

  async searchUsers(request) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const query = new URL(request.url).searchParams.get("q")?.trim() || "";

    if (query.length < 2) {
      return json({ ok: true, users: [] });
    }

    const escaped = query.replace(/[\\%_]/g, "\\$&");
    const rows = this.ctx.storage.sql
      .exec(
        `SELECT id, username, created_at
         FROM users
         WHERE username LIKE ? ESCAPE '\\'
           AND id <> ?
         ORDER BY username
         LIMIT 20`,
        `%${escaped}%`,
        user.id,
      )
      .toArray();

    return json({ ok: true, users: rows.map(safeUser) });
  }

  async createRoom(request) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const body = await this.readBody(request);

    if (body.error) {
      return json({ ok: false, error: body.error }, 400);
    }

    const game = typeof body.game === "string" ? body.game : "";

    if (!SUPPORTED_GAMES.has(game)) {
      return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
    }

    let code = "";
    let unique = false;

    for (let attempt = 0; attempt < 12; attempt++) {
      code = randomCode();
      const exists = this.ctx.storage.sql
        .exec("SELECT id FROM game_rooms WHERE code = ?", code)
        .toArray()[0];

      if (!exists) {
        unique = true;
        break;
      }
    }

    if (!unique) {
      return json({ ok: false, error: "INVITE_CODE_GENERATION_FAILED" }, 503);
    }

    const id = crypto.randomUUID();
    const now = Date.now();

    this.ctx.storage.sql.exec(
      `INSERT INTO game_rooms
       (id, code, game, host_id, guest_id, state_json, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, NULL, ?, 'waiting', ?, ?)`,
      id,
      code,
      game,
      user.id,
      JSON.stringify(initialState(game)),
      now,
      now,
    );

    return json(
      {
        ok: true,
        room: await this.roomPayload(id, user.id),
        inviteCode: code,
      },
      201,
    );
  }

  async joinRoom(request) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const body = await this.readBody(request);

    if (body.error) {
      return json({ ok: false, error: body.error }, 400);
    }

    const code = typeof body.code === "string" ? body.code.trim().toUpperCase() : "";

    if (!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) {
      return json({ ok: false, error: "INVALID_INVITE_CODE" }, 400);
    }

    const room = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE code = ?", code)
      .toArray()[0];

    if (!room) {
      return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
    }

    if (room.host_id === user.id) {
      return json({ ok: false, error: "CANNOT_JOIN_OWN_ROOM" }, 409);
    }

    if (room.guest_id === user.id) {
      return json({ ok: true, room: await this.roomPayload(room.id, user.id) });
    }

    if (room.status !== "waiting" || room.guest_id) {
      return json({ ok: false, error: "ROOM_FULL" }, 409);
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE game_rooms
       SET guest_id = ?, status = 'playing', updated_at = ?
       WHERE id = ? AND guest_id IS NULL AND status = 'waiting'`,
      user.id,
      now,
      room.id,
    );

    const updated = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", room.id)
      .toArray()[0];

    if (!updated || updated.guest_id !== user.id) {
      return json({ ok: false, error: "ROOM_FULL" }, 409);
    }

    return json({ ok: true, room: await this.roomPayload(room.id, user.id) });
  }

  async listMyRooms(request) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const rows = this.ctx.storage.sql
      .exec(
        `SELECT id
         FROM game_rooms
         WHERE host_id = ? OR guest_id = ?
         ORDER BY updated_at DESC
         LIMIT ?`,
        user.id,
        user.id,
        MAX_SAVED_ROOMS,
      )
      .toArray();

    const rooms = [];

    for (const row of rows) {
      const payload = await this.roomPayload(row.id, user.id);
      if (payload) rooms.push(payload);
    }

    return json({ ok: true, rooms });
  }

  async getRoom(request, roomId) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const room = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    if (!room) {
      return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
    }

    if (!roleForUser(room, user.id)) {
      return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
    }

    return json({ ok: true, room: await this.roomPayload(roomId, user.id) });
  }

  async changeRoomStatus(request, roomId, nextStatus) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const room = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    if (!room) {
      return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
    }

    if (!roleForUser(room, user.id)) {
      return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
    }

    if (room.status === "finished") {
      return json({ ok: false, error: "ROOM_FINISHED" }, 409);
    }

    if (nextStatus === "paused" && room.status !== "playing") {
      return json({ ok: false, error: "ROOM_NOT_PLAYING" }, 409);
    }

    if (nextStatus === "playing" && room.status !== "paused") {
      return json({ ok: false, error: "ROOM_NOT_PAUSED" }, 409);
    }

    this.ctx.storage.sql.exec(
      "UPDATE game_rooms SET status = ?, updated_at = ? WHERE id = ?",
      nextStatus,
      Date.now(),
      roomId,
    );

    return json({ ok: true, room: await this.roomPayload(roomId, user.id) });
  }

  async makeMove(request, roomId) {
    const user = await this.requireUser(request);

    if (user instanceof Response) return user;

    const body = await this.readBody(request);

    if (body.error) {
      return json({ ok: false, error: body.error }, 400);
    }

    const room = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    if (!room) {
      return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
    }

    const role = roleForUser(room, user.id);

    if (!role) {
      return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
    }

    if (room.status === "waiting") {
      return json({ ok: false, error: "WAITING_FOR_PLAYER" }, 409);
    }

    if (room.status === "paused") {
      return json({ ok: false, error: "GAME_PAUSED" }, 409);
    }

    if (room.status === "finished") {
      return json({ ok: false, error: "ROOM_FINISHED" }, 409);
    }

    if (!room.guest_id) {
      return json({ ok: false, error: "WAITING_FOR_PLAYER" }, 409);
    }

    const state = parseJson(room.state_json);

    if (!state || typeof state !== "object" || Array.isArray(state)) {
      return json({ ok: false, error: "INVALID_ROOM_STATE" }, 500);
    }

    let nextStatus = room.status;

    if (room.game === "tic_tac_toe") {
      const result = this.applyTicTacToeMove(state, role, user, body);
      if (result.error) {
        return json({ ok: false, error: result.error, message: result.message }, result.status || 409);
      }
      if (result.finished) nextStatus = "finished";
    } else if (room.game === "rock_paper_scissors") {
      const result = this.applyRpsMove(state, role, body);
      if (result.error) {
        return json({ ok: false, error: result.error, message: result.message }, result.status || 409);
      }
    } else if (room.game === "chess") {
      const result = this.applyChessMove(state, role, user, body);
      if (result.error) {
        return json({ ok: false, error: result.error, message: result.message }, result.status || 409);
      }
      if (result.finished) nextStatus = "finished";
    } else {
      return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
    }

    // Monotonic timestamps make the optimistic concurrency check reliable,
    // including two moves that arrive within the same millisecond.
    const now = Math.max(Date.now(), Number(room.updated_at || 0) + 1);
    const serializedState = JSON.stringify(state);

    const updateCursor = this.ctx.storage.sql.exec(
      `UPDATE game_rooms
       SET state_json = ?, status = ?, updated_at = ?
       WHERE id = ? AND updated_at = ? AND status = 'playing'`,
      serializedState,
      nextStatus,
      now,
      roomId,
      room.updated_at,
    );

    // SqlStorageCursor.rowsWritten is zero when another request already
    // changed this room; do not report that stale move as successful.
    if (updateCursor.rowsWritten === 0) {
      return json({ ok: false, error: "MOVE_CONFLICT" }, 409);
    }

    const saved = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    if (!saved || saved.updated_at !== now || saved.state_json !== serializedState) {
      return json({ ok: false, error: "MOVE_CONFLICT" }, 409);
    }

    return json({ ok: true, room: await this.roomPayload(roomId, user.id) });
  }

  applyTicTacToeMove(state, role, user, body) {
    const index = body.index;

    if (!Number.isInteger(index) || index < 0 || index > 8) {
      return { error: "INVALID_MOVE", status: 400, message: "المربع المحدد غير صحيح." };
    }

    if (!Array.isArray(state.board) || state.board.length !== 9) {
      return { error: "INVALID_ROOM_STATE", status: 500 };
    }

    if (state.winner || state.board.every((cell) => cell !== "")) {
      return { error: "ROUND_FINISHED", status: 409 };
    }

    const mark = role === "host" ? "X" : "O";

    if (state.next !== mark) {
      return { error: "NOT_YOUR_TURN", status: 409 };
    }

    if (state.board[index] !== "") {
      return { error: "INVALID_MOVE", status: 409, message: "هذا المربع مستخدم بالفعل." };
    }

    state.board[index] = mark;
    state.moves = (Number(state.moves) || 0) + 1;

    const winner = tttWinner(state.board);
    const draw = !winner && state.board.every((cell) => cell !== "");

    state.winner = winner || (draw ? "draw" : null);
    state.winnerUserId = winner ? user.id : null;
    state.next = winner || draw ? null : mark === "X" ? "O" : "X";

    appendHistory(state, {
      index,
      mark,
      userId: user.id,
      at: Date.now(),
    });

    return { finished: Boolean(winner || draw) };
  }

  applyRpsMove(state, role, body) {
    const choice = typeof body.choice === "string" ? body.choice.toLowerCase() : "";

    if (!["rock", "paper", "scissors"].includes(choice)) {
      return { error: "INVALID_MOVE", status: 400, message: "الاختيار غير صحيح." };
    }

    if (!state.choices || typeof state.choices !== "object" || Array.isArray(state.choices)) {
      state.choices = {};
    }

    if (!state.scores || typeof state.scores !== "object" || Array.isArray(state.scores)) {
      state.scores = { host: 0, guest: 0, draws: 0 };
    }

    if (state.choices[role]) {
      return { error: "MOVE_ALREADY_SUBMITTED", status: 409 };
    }

    state.choices[role] = choice;
    state.result = null;

    if (state.choices.host && state.choices.guest) {
      const winner = rpsWinner(state.choices.host, state.choices.guest);
      const round = Number(state.round) || 1;
      let resultText;

      if (winner === "draw") {
        resultText = "تعادل";
        state.scores.draws = (Number(state.scores.draws) || 0) + 1;
      } else if (winner === "host") {
        resultText = "فاز اللاعب الأول";
        state.scores.host = (Number(state.scores.host) || 0) + 1;
      } else {
        resultText = "فاز اللاعب الثاني";
        state.scores.guest = (Number(state.scores.guest) || 0) + 1;
      }

      state.lastResult = resultText;
      state.lastWinner = winner;
      appendHistory(state, {
        round,
        hostChoice: state.choices.host,
        guestChoice: state.choices.guest,
        winner,
        result: resultText,
        at: Date.now(),
      });

      // A completed round is archived, then choices are cleared for the next round.
      state.choices = {};
      state.round = round + 1;
    }

    return { finished: false };
  }

  applyChessMove(state, role, user, body) {
    const from = typeof body.from === "string" ? body.from.toLowerCase() : "";
    const to = typeof body.to === "string" ? body.to.toLowerCase() : "";
    const promotion = typeof body.promotion === "string" ? body.promotion.toLowerCase() : "q";

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

    const expectedColor = role === "host" ? "w" : "b";

    if (chess.turn() !== expectedColor) {
      return { error: "NOT_YOUR_TURN", status: 409 };
    }

    let move;

    try {
      move = chess.move({ from, to, promotion });
    } catch (_) {
      move = null;
    }

    if (!move) {
      return { error: "ILLEGAL_CHESS_MOVE", status: 409 };
    }

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

    if (state.checkmate) {
      state.winnerUserId = user.id;
    }

    return { finished: Boolean(state.checkmate || state.draw || chess.isGameOver()) };
  }

  async roomPayload(roomId, currentUserId) {
    const room = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    if (!room) return null;

    const host = this.ctx.storage.sql
      .exec("SELECT id, username, created_at FROM users WHERE id = ?", room.host_id)
      .toArray()[0];

    const guest = room.guest_id
      ? this.ctx.storage.sql
          .exec("SELECT id, username, created_at FROM users WHERE id = ?", room.guest_id)
          .toArray()[0]
      : null;

    const state = parseJson(room.state_json) || {};

    return {
      id: room.id,
      inviteCode: room.code,
      game: room.game,
      status: room.status,
      myRole: roleForUser(room, currentUserId),
      state,
      host: publicPlayer(host, "host", room.game),
      guest: publicPlayer(guest, "guest", room.game),
      createdAt: room.created_at,
      updatedAt: room.updated_at,
    };
  }
}
