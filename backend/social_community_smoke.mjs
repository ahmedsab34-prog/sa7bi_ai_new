import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { Sa7biSocial } from './src/social_games.js';

const db = new DatabaseSync(':memory:');

const sql = {
  exec(query, ...params) {
    const statement = db.prepare(query);
    const normalized = query.trim().toUpperCase();

    if (
      normalized.startsWith('SELECT') ||
      normalized.startsWith('PRAGMA')
    ) {
      const rows = statement.all(...params);
      return {
        toArray: () => rows,
        rowsWritten: 0,
      };
    }

    const result = statement.run(...params);

    return {
      toArray: () => [],
      rowsWritten: Number(result.changes || 0),
    };
  },
};

db.exec(`
  CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    password_salt TEXT,
    password_hash TEXT,
    created_at INTEGER NOT NULL
  );

  CREATE TABLE sessions (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL
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

const users = [
  {
    id: '11111111-1111-4111-8111-111111111111',
    username: 'Owner',
  },
  {
    id: '22222222-2222-4222-8222-222222222222',
    username: 'Member',
  },
  {
    id: '33333333-3333-4333-8333-333333333333',
    username: 'Outsider',
  },
];

for (const user of users) {
  db.prepare(
    'INSERT INTO users(id, username, created_at) VALUES (?, ?, ?)',
  ).run(user.id, user.username, Date.now());
}

const tokens = new Map([
  ['owner-token', users[0]],
  ['member-token', users[1]],
  ['outsider-token', users[2]],
]);

const actor = {
  ctx: {
    storage: {
      sql,
    },
  },

  async requireUser(request) {
    const token = (
      request.headers.get('Authorization') || ''
    ).replace('Bearer ', '');

    return tokens.get(token) || new Response(
      JSON.stringify({
        ok: false,
        error: 'AUTH_REQUIRED',
      }),
      {
        status: 401,
      },
    );
  },

  async readBody(request) {
    try {
      return await request.json();
    } catch {
      return {
        error: 'INVALID_JSON',
      };
    }
  },
};

// Inherit the real roomPayload() and fetch() methods from Sa7biSocial.
// This ensures the tests exercise the production dispatcher and response
// filtering rather than a test-only implementation.
Object.setPrototypeOf(actor, Sa7biSocial.prototype);

async function call(
  path,
  {
    method = 'GET',
    token = 'owner-token',
    body,
    ip = '192.0.2.1',
  } = {},
) {
  const request = new Request(
    `https://worker.test${path}`,
    {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        'CF-Connecting-IP': ip,
        ...(body !== undefined
          ? {
              'Content-Type': 'application/json',
            }
          : {}),
      },
      ...(body !== undefined
        ? {
            body: JSON.stringify(body),
          }
        : {}),
    },
  );

  const response = await Sa7biSocial.prototype.fetch.call(
    actor,
    request,
  );

  assert.ok(
    response instanceof Response,
    `No response for ${method} ${path}`,
  );

  return {
    status: response.status,
    data: await response.json(),
  };
}

// ------------------------------------------------------------
// Guest registration and registration abuse protection.
// A normal first-time install can create a guest account;
// the 61st registration attempt from one IP in ten minutes
// is rejected before password hashing.
// ------------------------------------------------------------

const registeredGuest = await call('/v1/social/register', {
  method: 'POST',
  ip: '198.51.100.10',
  body: {
    username: 'guest_smoke_2026',
    password: 'SmokePassword2026!',
  },
});

assert.equal(registeredGuest.status, 201);
assert.equal(registeredGuest.data.ok, true);
assert.equal(registeredGuest.data.user.username, 'guest_smoke_2026');
assert.equal(registeredGuest.data.token.length, 64);

for (let attempt = 0; attempt < 60; attempt++) {
  const invalidRegistration = await call('/v1/social/register', {
    method: 'POST',
    ip: '198.51.100.60',
    body: {
      username: 'x',
      password: 'short',
    },
  });

  assert.equal(invalidRegistration.status, 400);
}

const rateLimitedRegistration = await call('/v1/social/register', {
  method: 'POST',
  ip: '198.51.100.60',
  body: {
    username: 'guest_rate_limited',
    password: 'SmokePassword2026!',
  },
});

assert.equal(rateLimitedRegistration.status, 429);
assert.equal(
  rateLimitedRegistration.data.error,
  'REGISTRATION_RATE_LIMITED',
);
assert.ok(rateLimitedRegistration.data.retryAfterSeconds > 0);

// ------------------------------------------------------------
// Public groups: creation, discovery, joining, messages,
// and access control through the actual fetch dispatcher.
// ------------------------------------------------------------

const createdGroup = await call('/v1/social/groups', {
  method: 'POST',
  body: {
    name: 'Chess Friends',
    description: 'A public chess community',
  },
});

assert.equal(createdGroup.status, 201);
assert.equal(createdGroup.data.group.isMember, true);

const groupId = createdGroup.data.group.id;

const directory = await call('/v1/social/groups', {
  token: 'outsider-token',
});

assert.equal(directory.data.groups.length, 1);
assert.equal(directory.data.groups[0].isMember, false);

const deniedMessages = await call(
  `/v1/social/groups/${groupId}/messages`,
  {
    token: 'outsider-token',
  },
);

assert.equal(deniedMessages.status, 403);
assert.equal(
  deniedMessages.data.error,
  'GROUP_MEMBERSHIP_REQUIRED',
);

const joined = await call(
  `/v1/social/groups/${groupId}/join`,
  {
    method: 'POST',
    token: 'member-token',
    body: {},
  },
);

assert.equal(joined.status, 200);
assert.equal(joined.data.group.isMember, true);

const sentGroupMessage = await call(
  `/v1/social/groups/${groupId}/messages`,
  {
    method: 'POST',
    token: 'owner-token',
    body: {
      text: 'Welcome to the group',
    },
  },
);

assert.equal(sentGroupMessage.status, 201);

const groupMessages = await call(
  `/v1/social/groups/${groupId}/messages`,
  {
    token: 'member-token',
  },
);

assert.equal(groupMessages.data.messages.length, 1);
assert.equal(
  groupMessages.data.messages[0].username,
  'Owner',
);
assert.equal(
  groupMessages.data.messages[0].isMine,
  false,
);

// ------------------------------------------------------------
// Quick matchmaking must be routed by the actual Durable Object
// dispatcher, not only by its standalone helper test.
// ------------------------------------------------------------

const quickQueue = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'owner-token',
  body: { game: 'chess' },
});

assert.equal(quickQueue.status, 200);
assert.equal(quickQueue.data.matched, false);
assert.equal(quickQueue.data.room.status, 'waiting');
assert.equal(quickQueue.data.room.state.matchmakingStatus, 'searching');

const quickMatched = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'member-token',
  body: { game: 'chess' },
});

assert.equal(quickMatched.status, 200);
assert.equal(quickMatched.data.matched, true);
assert.equal(quickMatched.data.aiFallback, false);
assert.equal(quickMatched.data.room.status, 'playing');
assert.equal(quickMatched.data.room.myRole, 'guest');
assert.equal(quickMatched.data.room.host.username, 'Owner');
assert.equal(quickMatched.data.room.guest.username, 'Member');

// ------------------------------------------------------------
// Human multiplayer chess: the server enforces both player roles
// and rejects a second white move before black has replied.
// ------------------------------------------------------------

const humanChessRoom = await call('/v1/games/rooms', {
  method: 'POST',
  token: 'owner-token',
  body: { game: 'chess' },
});

assert.equal(humanChessRoom.status, 201);

const humanChessJoined = await call('/v1/games/rooms/join', {
  method: 'POST',
  token: 'member-token',
  body: { code: humanChessRoom.data.room.inviteCode },
});

assert.equal(humanChessJoined.status, 200);

const whiteMove = await call(
  `/v1/games/rooms/${humanChessRoom.data.room.id}/move`,
  {
    method: 'POST',
    token: 'owner-token',
    body: {
      from: 'e2',
      to: 'e4',
    },
  },
);

assert.equal(whiteMove.status, 200);
assert.equal(whiteMove.data.room.state.turn, 'b');

const rejectedOutOfTurnMove = await call(
  `/v1/games/rooms/${humanChessRoom.data.room.id}/move`,
  {
    method: 'POST',
    token: 'owner-token',
    body: {
      from: 'd2',
      to: 'd4',
    },
  },
);

assert.equal(rejectedOutOfTurnMove.status, 409);
assert.equal(rejectedOutOfTurnMove.data.error, 'NOT_YOUR_TURN');

const blackMove = await call(
  `/v1/games/rooms/${humanChessRoom.data.room.id}/move`,
  {
    method: 'POST',
    token: 'member-token',
    body: {
      from: 'e7',
      to: 'e5',
    },
  },
);

assert.equal(blackMove.status, 200);
assert.equal(blackMove.data.room.state.turn, 'w');

// ------------------------------------------------------------
// Human RPS: a pending choice must never be sent to the opponent.
// The round reveals both choices only after both players submit.
// ------------------------------------------------------------

const humanRpsRoom = await call('/v1/games/rooms', {
  method: 'POST',
  token: 'owner-token',
  body: { game: 'rock_paper_scissors' },
});

assert.equal(humanRpsRoom.status, 201);

const humanRpsJoined = await call('/v1/games/rooms/join', {
  method: 'POST',
  token: 'member-token',
  body: { code: humanRpsRoom.data.room.inviteCode },
});

assert.equal(humanRpsJoined.status, 200);

const hostRpsChoice = await call(
  `/v1/games/rooms/${humanRpsRoom.data.room.id}/move`,
  {
    method: 'POST',
    token: 'owner-token',
    body: { choice: 'rock' },
  },
);

assert.equal(hostRpsChoice.status, 200);
assert.equal(hostRpsChoice.data.room.state.choices.host, 'rock');
assert.equal(
  Object.prototype.hasOwnProperty.call(
    hostRpsChoice.data.room.state.choices,
    'guest',
  ),
  false,
);

const guestBeforeChoosing = await call(
  `/v1/games/rooms/${humanRpsRoom.data.room.id}`,
  {
    token: 'member-token',
  },
);

assert.equal(guestBeforeChoosing.status, 200);
assert.deepEqual(guestBeforeChoosing.data.room.state.choices, {});

const guestRpsChoice = await call(
  `/v1/games/rooms/${humanRpsRoom.data.room.id}/move`,
  {
    method: 'POST',
    token: 'member-token',
    body: { choice: 'scissors' },
  },
);

assert.equal(guestRpsChoice.status, 200);
assert.equal(
  Object.keys(guestRpsChoice.data.room.state.choices).length,
  0,
);
assert.equal(guestRpsChoice.data.room.state.history.length, 1);
assert.equal(
  guestRpsChoice.data.room.state.history[0].hostChoice,
  'rock',
);
assert.equal(
  guestRpsChoice.data.room.state.history[0].guestChoice,
  'scissors',
);

// ------------------------------------------------------------
// AI matchmaking fallback: expire the server-side deadline and
// verify the regular room read resolves to an actual AI opponent.
// ------------------------------------------------------------

const waitingAi = await call('/v1/games/matchmaking', {
  method: 'POST',
  token: 'outsider-token',
  body: { game: 'tic_tac_toe' },
});

assert.equal(waitingAi.status, 200);
assert.equal(waitingAi.data.matched, false);

const waitingAiId = waitingAi.data.room.id;
const waitingAiRow = db.prepare(
  'SELECT state_json FROM game_rooms WHERE id = ?',
).get(waitingAiId);

assert.ok(waitingAiRow, 'The AI fallback queue room must be persisted.');

const waitingAiState = JSON.parse(waitingAiRow.state_json);
waitingAiState.matchmakingExpiresAt = Date.now() - 1000;

db.prepare(
  'UPDATE game_rooms SET state_json = ? WHERE id = ?',
).run(JSON.stringify(waitingAiState), waitingAiId);

const resolvedAi = await call(`/v1/games/rooms/${waitingAiId}`, {
  token: 'outsider-token',
});

assert.equal(resolvedAi.status, 200);
assert.equal(resolvedAi.data.room.status, 'playing');
assert.equal(resolvedAi.data.room.state.aiOpponent, true);
assert.equal(resolvedAi.data.room.guest.username, 'صاحبي AI');

// ------------------------------------------------------------
// AI tic-tac-toe: bot responds in the same server transaction
// and blocks a winning human move.
// ------------------------------------------------------------

const tttRoom = await call('/v1/games/ai', {
  method: 'POST',
  body: {
    game: 'tic_tac_toe',
  },
});

assert.equal(tttRoom.status, 201);
assert.equal(tttRoom.data.room.state.aiOpponent, true);
assert.equal(tttRoom.data.room.guest.username, 'صاحبي AI');

const tttId = tttRoom.data.room.id;

const firstTttMove = await call(
  `/v1/games/rooms/${tttId}/move`,
  {
    method: 'POST',
    body: {
      index: 0,
    },
  },
);

assert.equal(firstTttMove.status, 200);
assert.equal(firstTttMove.data.room.state.board[0], 'X');
assert.equal(firstTttMove.data.room.state.board[4], 'O');
assert.equal(firstTttMove.data.room.state.next, 'X');

const secondTttMove = await call(
  `/v1/games/rooms/${tttId}/move`,
  {
    method: 'POST',
    body: {
      index: 1,
    },
  },
);

assert.equal(secondTttMove.status, 200);
assert.equal(secondTttMove.data.room.state.board[2], 'O');

// AI rooms must remain retrievable through the normal room endpoint.
const savedTttRoom = await call(
  `/v1/games/rooms/${tttId}`,
);

assert.equal(savedTttRoom.status, 200);
assert.equal(savedTttRoom.data.room.state.aiOpponent, true);

// The normal saved-room list must include AI rooms too.
const savedRooms = await call('/v1/games/rooms/mine');

assert.ok(
  savedRooms.data.rooms.some(
    (room) => room.id === tttId,
  ),
);

// ------------------------------------------------------------
// AI rock-paper-scissors: one API call resolves both choices.
// ------------------------------------------------------------

const rpsRoom = await call('/v1/games/ai', {
  method: 'POST',
  body: {
    game: 'rock_paper_scissors',
  },
});

assert.equal(rpsRoom.status, 201);

const rpsMove = await call(
  `/v1/games/rooms/${rpsRoom.data.room.id}/move`,
  {
    method: 'POST',
    body: {
      choice: 'rock',
    },
  },
);

assert.equal(rpsMove.status, 200);

assert.ok(
  ['rock', 'paper', 'scissors'].includes(
    rpsMove.data.room.state.lastBotChoice,
  ),
);

assert.ok(rpsMove.data.room.state.lastResult);
assert.equal(rpsMove.data.room.state.round, 2);

// ------------------------------------------------------------
// AI chess: server validates the human move and makes
// a legal black move before returning the updated board.
// ------------------------------------------------------------

const chessRoom = await call('/v1/games/ai', {
  method: 'POST',
  body: {
    game: 'chess',
  },
});

assert.equal(chessRoom.status, 201);

const chessMove = await call(
  `/v1/games/rooms/${chessRoom.data.room.id}/move`,
  {
    method: 'POST',
    body: {
      from: 'e2',
      to: 'e4',
    },
  },
);

assert.equal(chessMove.status, 200);
assert.equal(chessMove.data.room.state.turn, 'w');
assert.equal(chessMove.data.room.state.history.length, 2);

console.log(
  'social community and AI games dispatcher smoke test: PASS',
);

db.close();
