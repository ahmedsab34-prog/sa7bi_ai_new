
 // backend/src/social_games.js
// Sa7bi AI social accounts + cross-device multiplayer rooms.
// Persistent data is stored in a SQLite-backed Durable Object.
// Player names are always read from authenticated server accounts.

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const PASSWORD_ITERATIONS = 120000;
const MAX_BODY_BYTES = 16 * 1024;

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
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function randomCode(length = 6) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

async function sha256(value) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}

async function hashPassword(password, saltHex) {
  const salt = Uint8Array.from(
    saltHex.match(/.{2}/g),
    (x) => parseInt(x, 16),
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

  return Array.from(new Uint8Array(bits), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
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

export async function handleSocialGames(request, env) {
  if (!env.SA7BI_SOCIAL) {
    return json(
      {
        ok: false,
        error: "SOCIAL_SERVICE_NOT_CONFIGURED",
        message:
          "خدمة الحسابات والألعاب لم تُفعّل في إعدادات الخادم بعد.",
      },
      503,
    );
  }

  const id = env.SA7BI_SOCIAL.idFromName(
    "sa7bi-social-global-v1",
  );

  return env.SA7BI_SOCIAL.get(id).fetch(request);
}

export class Sa7biSocial {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;

    // Keep each CREATE statement separate for SQLite compatibility.
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
  }

  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    try {
      if (
        request.method === "POST" &&
        path === "/v1/social/register"
      ) {
        return await this.register(request);
      }

      if (
        request.method === "POST" &&
        path === "/v1/social/login"
      ) {
        return await this.login(request);
      }

      if (
        request.method === "GET" &&
        path === "/v1/social/me"
      ) {
        const user = await this.requireUser(request);
        return user instanceof Response
          ? user
          : json({ ok: true, user: safeUser(user) });
      }

      if (
        request.method === "GET" &&
        path === "/v1/social/users/search"
      ) {
        return await this.searchUsers(request);
      }

      if (
        request.method === "POST" &&
        path === "/v1/games/rooms"
      ) {
        return await this.createRoom(request);
      }

      if (
        request.method === "POST" &&
        path === "/v1/games/rooms/join"
      ) {
        return await this.joinRoom(request);
      }

      const moveMatch = path.match(
        /^\/v1\/games\/rooms\/([a-f0-9-]+)\/move$/i,
      );

      if (request.method === "POST" && moveMatch) {
        return await this.makeMove(request, moveMatch[1]);
      }

      const roomMatch = path.match(
        /^\/v1\/games\/rooms\/([a-f0-9-]+)$/i,
      );

      if (request.method === "GET" && roomMatch) {
        return await this.getRoom(request, roomMatch[1]);
      }

      return json({ ok: false, error: "NOT_FOUND" }, 404);
    } catch (_) {
      // Never expose SQL errors, password hashes, tokens, or stack traces.
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
    const raw = await request.text();

    if (raw.length > MAX_BODY_BYTES) {
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
    if (body.error) return json({ ok: false, error: body.error }, 400);

    const username =
      typeof body.username === "string" ? body.username.trim() : "";

    const password =
      typeof body.password === "string" ? body.password : "";

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

    const exists = this.ctx.storage.sql
      .exec(
        "SELECT id FROM users WHERE username = ? COLLATE NOCASE",
        username,
      )
      .toArray()[0];

    if (exists) {
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

    return json(
      { ok: true, token, user: safeUser(user) },
      201,
    );
  }

  async login(request) {
    const body = await this.readBody(request);
    if (body.error) return json({ ok: false, error: body.error }, 400);

    const username =
      typeof body.username === "string" ? body.username.trim() : "";

    const password =
      typeof body.password === "string" ? body.password : "";

    if (!username || !password) {
      return json(
        { ok: false, error: "USERNAME_AND_PASSWORD_REQUIRED" },
        400,
      );
    }

    const row = this.ctx.storage.sql
      .exec(
        `SELECT id, username, password_salt, password_hash, created_at
         FROM users WHERE username = ? COLLATE NOCASE`,
        username,
      )
      .toArray()[0];

    if (!row) {
      return json({ ok: false, error: "INVALID_CREDENTIALS" }, 401);
    }

    const supplied = await hashPassword(password, row.password_salt);

    if (supplied !== row.password_hash) {
      return json({ ok: false, error: "INVALID_CREDENTIALS" }, 401);
    }

    const token = await this.createSession(row.id);

    return json({ ok: true, token, user: safeUser(row) });
  }

  async createSession(userId) {
    const token = randomHex(32);
    const tokenHash = await sha256(token);
    const now = Date.now();

    this.ctx.storage.sql.exec(
      "DELETE FROM sessions WHERE expires_at <= ?",
      now,
    );

    this.ctx.storage.sql.exec(
      `INSERT INTO sessions (token_hash, user_id, expires_at)
       VALUES (?, ?, ?)`,
      tokenHash,
      userId,
      now + SESSION_TTL_MS,
    );

    // Only the token hash is stored in the database.
    return token;
  }

  async requireUser(request) {
    const auth = request.headers.get("Authorization") || "";
    const match = auth.match(/^Bearer ([a-f0-9]{64})$/i);

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

    return (
      row ||
      json({ ok: false, error: "SESSION_EXPIRED" }, 401)
    );
  }

  async searchUsers(request) {
    const user = await this.requireUser(request);
    if (user instanceof Response) return user;

    const q = new URL(request.url).searchParams.get("q")?.trim() || "";

    if (q.length < 2) {
      return json({ ok: true, users: [] });
    }

    const escaped = q.replace(/[\\%_]/g, "\\$&");

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
    if (body.error) return json({ ok: false, error: body.error }, 400);

    const game = typeof body.game === "string" ? body.game : "";

    if (!["tic_tac_toe", "rock_paper_scissors"].includes(game)) {
      return json({ ok: false, error: "UNSUPPORTED_GAME" }, 400);
    }

    let code = randomCode();

    for (
      let attempt = 0;
      attempt < 5 &&
      this.ctx.storage.sql.exec(
        "SELECT id FROM game_rooms WHERE code = ?",
        code,
      ).toArray().length;
      attempt++
    ) {
      code = randomCode();
    }

    const id = crypto.randomUUID();
    const now = Date.now();

    const state =
      game === "tic_tac_toe"
        ? {
            board: Array(9).fill(""),
            next: "X",
            winner: null,
            moves: 0,
          }
        : {
            choices: {},
            round: 1,
            result: null,
          };

    this.ctx.storage.sql.exec(
      `INSERT INTO game_rooms
       (id, code, game, host_id, guest_id, state_json, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, NULL, ?, 'waiting', ?, ?)`,
      id,
      code,
      game,
      user.id,
      JSON.stringify(state),
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
    if (body.error) return json({ ok: false, error: body.error }, 400);

    const code =
      typeof body.code === "string" ? body.code.trim().toUpperCase() : "";

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

    if (room.guest_id && room.guest_id !== user.id) {
      return json({ ok: false, error: "ROOM_FULL" }, 409);
    }

    if (room.status === "finished") {
      return json({ ok: false, error: "ROOM_FINISHED" }, 409);
    }

    this.ctx.storage.sql.exec(
      `UPDATE game_rooms
       SET guest_id = ?, status = 'playing', updated_at = ?
       WHERE id = ?`,
      user.id,
      Date.now(),
      room.id,
    );

    return json({
      ok: true,
      room: await this.roomPayload(room.id, user.id),
    });
  }

  async getRoom(request, roomId) {
    const user = await this.requireUser(request);
    if (user instanceof Response) return user;

    const room = this.ctx.storage.sql
      .exec(
        "SELECT id, host_id, guest_id FROM game_rooms WHERE id = ?",
        roomId,
      )
      .toArray()[0];

    if (!room) {
      return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
    }

    if (room.host_id !== user.id && room.guest_id !== user.id) {
      return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
    }

    return json({
      ok: true,
      room: await this.roomPayload(roomId, user.id),
    });
  }

  async makeMove(request, roomId) {
    const user = await this.requireUser(request);
    if (user instanceof Response) return user;

    const body = await this.readBody(request);
    if (body.error) return json({ ok: false, error: body.error }, 400);

    const room = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    if (!room) {
      return json({ ok: false, error: "ROOM_NOT_FOUND" }, 404);
    }

    if (room.host_id !== user.id && room.guest_id !== user.id) {
      return json({ ok: false, error: "ROOM_ACCESS_DENIED" }, 403);
    }

    if (!room.guest_id || room.status !== "playing") {
      return json({ ok: false, error: "WAITING_FOR_PLAYER" }, 409);
    }

    const state = parseJson(room.state_json);

    if (!state) {
      return json({ ok: false, error: "INVALID_ROOM_STATE" }, 500);
    }

    if (room.game === "tic_tac_toe") {
      if (state.winner || state.moves >= 9) {
        return json({ ok: false, error: "ROUND_FINISHED" }, 409);
      }

      const expectedUser =
        state.next === "X" ? room.host_id : room.guest_id;

      if (user.id !== expectedUser) {
        return json({ ok: false, error: "NOT_YOUR_TURN" }, 409);
      }

      const index = Number(body.index);

      if (
        !Number.isInteger(index) ||
        index < 0 ||
        index > 8 ||
        state.board[index] !== ""
      ) {
        return json({ ok: false, error: "INVALID_MOVE" }, 400);
      }

      state.board[index] = state.next;
      state.moves += 1;

      const lines = [
        [0, 1, 2],
        [3, 4, 5],
        [6, 7, 8],
        [0, 4, 6],
        [1, 4, 7],
        [2, 5, 8],
        [0, 4, 8],
        [2, 4, 6],
      ];

      const win = lines.some(([a, b, c]) =>
        state.board[a] &&
        state.board[a] === state.board[b] &&
        state.board[a] === state.board[c],
      );

      if (win) {
        state.winner = state.next;
      } else if (state.moves === 9) {
        state.winner = "draw";
      } else {
        state.next = state.next === "X" ? "O" : "X";
      }

      const finished = Boolean(state.winner);

      this.ctx.storage.sql.exec(
        `UPDATE game_rooms
         SET state_json = ?, status = ?, updated_at = ?
         WHERE id = ?`,
        JSON.stringify(state),
        finished ? "finished" : "playing",
        Date.now(),
        roomId,
      );
    } else if (room.game === "rock_paper_scissors") {
      const choice =
        typeof body.choice === "string" ? body.choice : "";

      if (!["rock", "paper", "scissors"].includes(choice)) {
        return json({ ok: false, error: "INVALID_MOVE" }, 400);
      }

      if (state.result) {
        state.round += 1;
        state.choices = {};
        state.result = null;
      }

      if (state.choices[user.id]) {
        return json(
          { ok: false, error: "MOVE_ALREADY_SUBMITTED" },
          409,
        );
      }

      state.choices[user.id] = choice;

      if (
        state.choices[room.host_id] &&
        state.choices[room.guest_id]
      ) {
        const a = state.choices[room.host_id];
        const b = state.choices[room.guest_id];

        state.result =
          a === b
            ? "draw"
            : (
                (a === "rock" && b === "scissors") ||
                (a === "paper" && b === "rock") ||
                (a === "scissors" && b === "paper")
              )
              ? room.host_id
              : room.guest_id;
      }

      this.ctx.storage.sql.exec(
        `UPDATE game_rooms
         SET state_json = ?, updated_at = ?
         WHERE id = ?`,
        JSON.stringify(state),
        Date.now(),
        roomId,
      );
    }

    return json({
      ok: true,
      room: await this.roomPayload(roomId, user.id),
    });
  }

  async roomPayload(roomId, viewerId) {
    const row = this.ctx.storage.sql
      .exec("SELECT * FROM game_rooms WHERE id = ?", roomId)
      .toArray()[0];

    const host = this.ctx.storage.sql
      .exec(
        "SELECT id, username FROM users WHERE id = ?",
        row.host_id,
      )
      .toArray()[0];

    const guest = row.guest_id
      ? this.ctx.storage.sql
          .exec(
            "SELECT id, username FROM users WHERE id = ?",
            row.guest_id,
          )
          .toArray()[0]
      : null;

    return {
      id: row.id,
      inviteCode: row.code,
      game: row.game,
      status: row.status,
      host: host
        ? { id: host.id, username: host.username, mark: "X" }
        : null,
      guest: guest
        ? { id: guest.id, username: guest.username, mark: "O" }
        : null,
      myRole: viewerId === row.host_id ? "host" : "guest",
      state: parseJson(row.state_json),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
