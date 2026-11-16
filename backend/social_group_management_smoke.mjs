
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { handleSocialGroupManagement } from './src/social_group_management.js';

const db = new DatabaseSync(':memory:');

const sql = {
  exec(query, ...params) {
    const statement = db.prepare(query);
    const normalized = query.trim().toUpperCase();

    if (normalized.startsWith('SELECT') || normalized.startsWith('PRAGMA')) {
      const result = statement.all(...params);
      return { toArray: () => result, rowsWritten: 0 };
    }

    const result = statement.run(...params);
    return { toArray: () => [], rowsWritten: Number(result.changes || 0) };
  },
};

db.exec(`
  CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );
`);

const users = [
  { id: '11111111-1111-4111-8111-111111111111', username: 'Owner' },
  { id: '22222222-2222-4222-8222-222222222222', username: 'Member' },
  { id: '33333333-3333-4333-8333-333333333333', username: 'Outsider' },
  { id: '44444444-4444-4444-8444-444444444444', username: 'RateLimitTester' },
];

for (const user of users) {
  db.prepare('INSERT INTO users(id, username, created_at) VALUES (?, ?, ?)')
    .run(user.id, user.username, Date.now());
}

const tokens = new Map([
  ['owner-token', users[0]],
  ['member-token', users[1]],
  ['outsider-token', users[2]],
  ['rate-limit-token', users[3]],
]);

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
    try {
      return await request.json();
    } catch {
      return { error: 'INVALID_JSON' };
    }
  },
};

async function call(
  path,
  {
    method = 'GET',
    token = 'owner-token',
    body,
  } = {},
) {
  const request = new Request(`https://worker.test${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });

  const response = await handleSocialGroupManagement(request, actor);

  assert.ok(
    response instanceof Response,
    `No management response for ${method} ${path}`,
  );

  return {
    status: response.status,
    data: await response.json(),
  };
}

const created = await call('/v1/social/groups/private', {
  method: 'POST',
  body: {
    name: 'Family Circle',
    description: 'Private group smoke test',
  },
});

assert.equal(created.status, 201);
assert.equal(created.data.group.isPublic, false);
assert.equal(created.data.group.myRole, 'owner');

const groupId = created.data.group.id;

const outsiderMembers = await call(
  `/v1/social/groups/${groupId}/members`,
  { token: 'outsider-token' },
);

assert.equal(outsiderMembers.status, 403);
assert.equal(outsiderMembers.data.error, 'GROUP_MEMBERSHIP_REQUIRED');

const invite = await call(`/v1/social/groups/${groupId}/invites`, {
  method: 'POST',
  body: {},
});

assert.equal(invite.status, 201);
assert.match(invite.data.invite.code, /^[A-HJ-NP-Z2-9]{10}$/);
assert.equal(invite.data.invite.maxUses, 25);

const badCode = await call('/v1/social/groups/join-invite', {
  method: 'POST',
  token: 'member-token',
  body: { code: 'BAD' },
});

assert.equal(badCode.status, 400);

const joined = await call('/v1/social/groups/join-invite', {
  method: 'POST',
  token: 'member-token',
  body: { code: invite.data.invite.code },
});

assert.equal(joined.status, 200);
assert.equal(joined.data.group.isMember, true);
assert.equal(joined.data.group.myRole, 'member');

const ownerMembers = await call(`/v1/social/groups/${groupId}/members`);

assert.equal(ownerMembers.status, 200);
assert.equal(ownerMembers.data.members.length, 2);

const promoted = await call(
  `/v1/social/groups/${groupId}/members/${users[1].id}/admin`,
  {
    method: 'POST',
    body: { isAdmin: true },
  },
);

assert.equal(promoted.status, 200);
assert.equal(promoted.data.role, 'admin');

const adminCannotPromote = await call(
  `/v1/social/groups/${groupId}/members/${users[2].id}/admin`,
  {
    method: 'POST',
    token: 'member-token',
    body: { isAdmin: true },
  },
);

assert.equal(adminCannotPromote.status, 403);
assert.equal(adminCannotPromote.data.error, 'GROUP_OWNER_REQUIRED');

const secondInvite = await call(`/v1/social/groups/${groupId}/invites`, {
  method: 'POST',
  body: {},
});

const outsiderJoined = await call('/v1/social/groups/join-invite', {
  method: 'POST',
  token: 'outsider-token',
  body: { code: secondInvite.data.invite.code },
});

assert.equal(outsiderJoined.status, 200);

const removed = await call(
  `/v1/social/groups/${groupId}/members/${users[2].id}`,
  {
    method: 'DELETE',
    token: 'member-token',
  },
);

assert.equal(removed.status, 200);

const adminCannotRemoveOwner = await call(
  `/v1/social/groups/${groupId}/members/${users[0].id}`,
  {
    method: 'DELETE',
    token: 'member-token',
  },
);

assert.equal(adminCannotRemoveOwner.status, 409);
assert.equal(
  adminCannotRemoveOwner.data.error,
  'GROUP_CANNOT_REMOVE_OWNER',
);

const left = await call(`/v1/social/groups/${groupId}/leave`, {
  method: 'POST',
  token: 'member-token',
  body: {},
});

assert.equal(left.status, 200);

const ownerCannotLeave = await call(`/v1/social/groups/${groupId}/leave`, {
  method: 'POST',
  token: 'owner-token',
  body: {},
});

assert.equal(ownerCannotLeave.status, 409);
assert.equal(ownerCannotLeave.data.error, 'GROUP_OWNER_MUST_DELETE');

const deleted = await call(`/v1/social/groups/${groupId}`, {
  method: 'DELETE',
  token: 'owner-token',
});

assert.equal(deleted.status, 200);
assert.equal(deleted.data.deleted, true);

const afterDelete = await call(
  `/v1/social/groups/${groupId}/members`,
  { token: 'owner-token' },
);

assert.equal(afterDelete.status, 404);

// Use a fresh account so earlier successful invite joins do not consume
// the attempts reserved for this isolated rate-limit test.
for (let attempt = 0; attempt < 10; attempt++) {
  const invalidInvite = await call('/v1/social/groups/join-invite', {
    method: 'POST',
    token: 'rate-limit-token',
    body: { code: 'AAAAAAAAAA' },
  });

  assert.equal(invalidInvite.status, 404);
}

const rateLimited = await call('/v1/social/groups/join-invite', {
  method: 'POST',
  token: 'rate-limit-token',
  body: { code: 'AAAAAAAAAA' },
});

assert.equal(rateLimited.status, 429);
assert.equal(rateLimited.data.error, 'GROUP_INVITE_RATE_LIMIT');

console.log(
  'PASS: private group creation, invite codes, membership, role management, removal, leave, delete and invite rate limiting.',
);
