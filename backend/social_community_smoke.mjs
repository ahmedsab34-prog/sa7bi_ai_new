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

  async roomPayload(roomId, userId) {
    const room = sql.exec(
      'SELECT * FROM game_rooms WHERE id = ?',
      roomId,
    ).toArray()[0];

    if (!room) return null;

    const state = JSON.parse(room.state_json);
    const ai = state.aiOpponent === true;

    const host = sql.exec(
      'SELECT id, username FROM users WHERE id = ?',
      room.host_id,
    ).toArray()[0];

    return {
      id: room.id,
      inviteCode: room.code,
      game: room.game,
      status: room.status,
      myRole: room.host_id === userId ? 'host' : null,
      state,
      host: host
        ? {
            id: host.id,
            username: host.username,
            mark: 'X',
          }
        : null,
      guest: ai
        ? {
            id: 'sa7bi-ai',
            username: 'صاحبي AI',
            mark:
              room.game === 'chess'
                ? 'black'
                : room.game === 'rock_paper_scissors'
                    ? 'player_2'
                    : 'O',
          }
        : null,
    };
  },
};

// Use the real Durable Object prototype so this test exercises the
// same fetch() dispatcher that receives production requests.
Object.setPrototypeOf(actor, Sa7biSocial.prototype);

async function call(
  path,
  {
    method = 'GET',
    token = 'owner-token',
    body,
  } = {},
) {
  const request = new Request(
    `https://worker.test${path}`,
    {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
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
