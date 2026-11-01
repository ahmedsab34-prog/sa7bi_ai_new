import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { handleSocialMatchmaking } from './src/social_matchmaking.js';

const db = new DatabaseSync(':memory:');
db.exec(`
  CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );
  CREATE TABLE game_rooms (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    game TEXT NOT NULL,
    host_id TEXT NOT NULL,
    guest_id TEXT,
    state_json TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );
`);

const sql = {
  exec(query, ...params) {
    const statement = db.prepare(query);
    const normalized = query.trim().toUpperCase();
    if (normalized.startsWith('SELECT') || normalized.startsWith('PRAGMA')) {
      const rows = statement.all(...params);
      return { toArray: () => rows, rowsWritten: 0 };
    }
    const result = statement.run(...params);
    return { toArray: () => [], rowsWritten: Number(result.changes || 0) };
  },
};

const users = [
  { id: '11111111-1111-4111-8111-111111111111', username: 'Owner' },
  { id: '22222222-2222-4222-8222-222222222222', username: 'Member' },
  { id: '33333333-3333-4333-8333-333333333333', username: 'Outsider' },
];
for (const user of users) {
  sql.exec(
    'INSERT INTO users(id, username, created_at) VALUES (?, ?, ?)',
    user.id,
    user.username,
    Date.now(),
  );
}

const tokens = new Map([
  ['owner-token', users[0]],
  ['member-token', users[1]],
  ['outsider-token', users[2]],
]);

function readRows(cursor) {
  return cursor?.toArray?.() ?? [];
}

function initialState(game) {
  if (game === 'tic_tac_toe') {
    return {
      board: Array(9).fill(''),
      next: 'X',
      winner: null,
      winnerUserId: null,
      moves: 0,
      history: [],
    };
  }
  if (game === 'rock_paper_scissors') {
    return {
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
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    pgn: '',
    history: [],
    turn: 'w',
    check: false,
    checkmate: false,
    draw: false,
    winnerUserId: null,
    lastMove: null,
  };
}

const actor = {
  ctx: { storage: { sql } },
  async requireUser(request) {
    const token = (request.headers.get('Authorization') || '').replace('Bearer ', '');
    return tokens.get(token) || new Response(
      JSON.stringify({ ok: false, error: 'AUTH_REQUIRED' }),
      { status: 401 },
    );
  },
  async readBody(request) {
    try { return await request.json(); } catch { return { error: 'INVALID_JSON' }; }
  },
  async createRoom(request) {
    const user = await this.requireUser(request);
    if (user instanceof Response) return user;
    const body = await this.readBody(request);
    if (!['tic_tac_toe', 'rock_paper_scissors', 'chess'].includes(body.game)) {
      return new Response(JSON.stringify({ ok: false, error: 'UNSUPPORTED_GAME' }), { status: 400 });
    }
    const id = crypto.randomUUID();
    const code = Math.random().toString(36).slice(2, 8).toUpperCase();
    const now = Date.now();
    sql.exec(
      `INSERT INTO game_rooms
       (id, code, game, host_id, guest_id, state_json, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, NULL, ?, 'waiting', ?, ?)`,
      id, code, body.game, user.id, JSON.stringify(initialState(body.game)), now, now,
    );
    return new Response(JSON.stringify({ ok: true, room: await this.roomPayload(id, user.id) }), { status: 201 });
  },
  async roomPayload(roomId, userId) {
    const room = readRows(sql.exec('SELECT * FROM game_rooms WHERE id = ?', roomId))[0];
    if (!room) return null;
    const state = JSON.parse(room.state_json);
    const host = readRows(sql.exec('SELECT id, username FROM users WHERE id = ?', room.host_id))[0] || null;
    const guest = room.guest_id
      ? readRows(sql.exec('SELECT id, username FROM users WHERE id = ?', room.guest_id))[0] || null
      : state.aiOpponent === true
          ? { id: 'sa7bi-ai', username: 'صاحبي AI' }
          : null;
    return {
      id: room.id,
      inviteCode: room.code,
      game: room.game,
      status: room.status,
      myRole: room.host_id === userId ? 'host' : room.guest_id === userId ? 'guest' : null,
      state,
      host,
      guest,
    };
  },
};

async function call(path, { method = 'GET', token = 'owner-token', body } = {}) {
  const request = new Request(`https://worker.test${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const response = await handleSocialMatchmaking(request, actor);
  assert.ok(response instanceof Response, `No response for ${method} ${path}`);
  return { status: response.status, data: await response.json() };
}

// First player creates a server-side queue room.
const first = await call('/v1/games/matchmaking', {
  method: 'POST',
  body: { game: 'tic_tac_toe' },
});
assert.equal(first.status, 200);
assert.equal(first.data.matched, false);
assert.equal(first.data.room.status, 'waiting');
assert.equal(first.data.room.state.matchmakingStatus, 'searching');
assert.equal(first.data.waitSeconds, 25);
const queuedRoomId = first.data.room.id;

// Repeated taps from the same account reuse the same waiting room.
const repeated = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'owner-token',
  body: { game: 'tic_tac_toe' },
});
assert.equal(repeated.data.room.id, queuedRoomId);
assert.equal(repeated.data.reused, true);

// A second account finds and joins the human queue instead of getting an AI room.
const second = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'member-token',
  body: { game: 'tic_tac_toe' },
});
assert.equal(second.status, 200);
assert.equal(second.data.matched, true);
assert.equal(second.data.aiFallback, false);
assert.equal(second.data.room.status, 'playing');
assert.equal(second.data.room.myRole, 'guest');
assert.equal(second.data.room.guest.username, 'Member');
assert.equal(second.data.room.state.matchmakingStatus, 'matched');
const hostMatchedRead = await handleSocialMatchmaking(
  new Request(`https://worker.test/v1/games/rooms/${queuedRoomId}`, {
    headers: { Authorization: 'Bearer owner-token' },
  }),
  actor,
);
assert.equal(hostMatchedRead, null, 'matched human rooms must fall through to the existing room handler');
const cannotCancelMatched = await call(`/v1/games/rooms/${queuedRoomId}/cancel-matchmaking`, {
  method: 'POST',
  token: 'owner-token',
  body: {},
});
assert.equal(cannotCancelMatched.status, 409);
assert.equal(cannotCancelMatched.data.error, 'MATCH_SEARCH_ALREADY_FINISHED');

// A lone player is promoted to a persisted AI room after the server deadline.
const waitingAi = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'member-token',
  body: { game: 'rock_paper_scissors' },
});
assert.equal(waitingAi.data.matched, false);
const aiRoomId = waitingAi.data.room.id;
const aiRow = readRows(sql.exec('SELECT * FROM game_rooms WHERE id = ?', aiRoomId))[0];
const expiredState = JSON.parse(aiRow.state_json);
expiredState.matchmakingExpiresAt = Date.now() - 1000;
sql.exec(
  'UPDATE game_rooms SET state_json = ? WHERE id = ?',
  JSON.stringify(expiredState),
  aiRoomId,
);

const autoFallback = await call(`/v1/games/rooms/${aiRoomId}`, {
  token: 'member-token',
});
assert.equal(autoFallback.status, 200);
assert.equal(autoFallback.data.matched, true);
assert.equal(autoFallback.data.aiFallback, true);
assert.equal(autoFallback.data.room.status, 'playing');
assert.equal(autoFallback.data.room.state.aiOpponent, true);
assert.equal(autoFallback.data.room.state.matchmakingStatus, 'ai_fallback');
assert.equal(autoFallback.data.room.guest.username, 'صاحبي AI');

const waitingChess = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'member-token',
  body: { game: 'chess' },
});
const chessQueueRow = readRows(sql.exec(
  'SELECT * FROM game_rooms WHERE id = ?',
  waitingChess.data.room.id,
))[0];
const expiredChessState = JSON.parse(chessQueueRow.state_json);
expiredChessState.matchmakingExpiresAt = Date.now() - 1000;
sql.exec(
  'UPDATE game_rooms SET state_json = ? WHERE id = ?',
  JSON.stringify(expiredChessState),
  waitingChess.data.room.id,
);
const chessFallback = await call(`/v1/games/rooms/${waitingChess.data.room.id}`, {
  token: 'member-token',
});
assert.equal(chessFallback.data.room.state.aiOpponent, true);
assert.equal(
  chessFallback.data.room.state.fen,
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
);

// Expired queue entries are not offered to another player as human matches.
const nextPlayer = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'outsider-token',
  body: { game: 'rock_paper_scissors' },
});
assert.equal(nextPlayer.data.matched, false);
assert.notEqual(nextPlayer.data.room.id, aiRoomId);

// A player can safely cancel an open search; the cancelled room is not reusable.
const cancelQueue = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'outsider-token',
  body: { game: 'chess' },
});
assert.equal(cancelQueue.data.room.status, 'waiting');
const cancelled = await call(`/v1/games/rooms/${cancelQueue.data.room.id}/cancel-matchmaking`, {
  method: 'POST',
  token: 'outsider-token',
  body: {},
});
assert.equal(cancelled.status, 200);
assert.equal(cancelled.data.cancelled, true);
assert.equal(cancelled.data.room.status, 'finished');
assert.equal(cancelled.data.room.state.matchmakingStatus, 'cancelled');
const afterCancel = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'owner-token',
  body: { game: 'chess' },
});
assert.equal(afterCancel.data.matched, false);
assert.notEqual(afterCancel.data.room.id, cancelQueue.data.room.id);

const invalid = await call('/v1/games/matchmaking', {
  method: 'POST',
  body: { game: 'unsupported' },
});
assert.equal(invalid.status, 400);
assert.equal(invalid.data.error, 'UNSUPPORTED_GAME');

const unauthenticated = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'missing-token',
  body: { game: 'chess' },
});
assert.equal(unauthenticated.status, 401);

console.log('social matchmaking and automatic AI fallback smoke test: PASS');
