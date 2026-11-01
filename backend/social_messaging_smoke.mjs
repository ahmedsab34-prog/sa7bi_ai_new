import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { handleSocialMessaging } from './src/social_messaging.js';

const db = new DatabaseSync(':memory:');
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

db.exec(`
  CREATE TABLE users (id TEXT PRIMARY KEY, username TEXT NOT NULL, created_at INTEGER NOT NULL);
  CREATE TABLE game_rooms (
    id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE, game TEXT NOT NULL,
    host_id TEXT NOT NULL, guest_id TEXT, state_json TEXT NOT NULL,
    status TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
  );
`);
const users = [
  { id: '11111111-1111-4111-8111-111111111111', username: 'Sender' },
  { id: '22222222-2222-4222-8222-222222222222', username: 'Receiver' },
  { id: '33333333-3333-4333-8333-333333333333', username: 'Outsider' },
];
for (const user of users) {
  db.prepare('INSERT INTO users(id, username, created_at) VALUES (?, ?, ?)')
    .run(user.id, user.username, Date.now());
}

const actor = {
  ctx: { storage: { sql } },
  async requireUser(request) {
    const token = request.headers.get('Authorization') || '';
    if (token.endsWith('sender')) return { id: users[0].id, username: 'Sender' };
    if (token.endsWith('receiver')) return { id: users[1].id, username: 'Receiver' };
    if (token.endsWith('outsider')) return { id: users[2].id, username: 'Outsider' };
    return new Response(JSON.stringify({ ok: false, error: 'AUTH_REQUIRED' }), { status: 401 });
  },
  async readBody(request) {
    try { return await request.json(); } catch { return { error: 'INVALID_JSON' }; }
  },
  async roomPayload(roomId, userId) {
    const room = sql.exec('SELECT * FROM game_rooms WHERE id = ?', roomId).toArray()[0];
    return room ? { id: room.id, status: room.status, myRole: room.host_id === userId ? 'host' : 'guest' } : null;
  },
};

async function call(path, { method = 'GET', token = 'sender', body } = {}) {
  const request = new Request(`https://worker.test${path}`, {
    method,
    headers: {
      Authorization: `Bearer test-${token}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const response = await handleSocialMessaging(request, actor);
  assert.ok(response instanceof Response, `No response for ${method} ${path}`);
  return { status: response.status, data: await response.json() };
}

const created = await call('/v1/social/invitations', {
  method: 'POST', token: 'sender',
  body: { recipientUserId: users[1].id, game: 'chess' },
});
assert.equal(created.status, 201);
assert.equal(created.data.invitation.status, 'pending');
assert.equal(created.data.invitation.sender.username, 'Sender');
const invitationId = created.data.invitation.id;
const inbox = await call('/v1/social/invitations?box=inbox', { token: 'receiver' });
assert.equal(inbox.data.invitations.length, 1);
const accepted = await call(`/v1/social/invitations/${invitationId}/accept`, {
  method: 'POST', token: 'receiver', body: {},
});
assert.equal(accepted.status, 200);
assert.equal(accepted.data.invitation.status, 'accepted');
assert.equal(accepted.data.room.myRole, 'guest');
const savedRoom = sql.exec('SELECT * FROM game_rooms').toArray()[0];
assert.equal(savedRoom.status, 'playing');
assert.equal(savedRoom.guest_id, users[1].id);

const createdConversation = await call('/v1/social/conversations', {
  method: 'POST', token: 'sender', body: { userId: users[1].id },
});
assert.equal(createdConversation.status, 201);
const conversationId = createdConversation.data.conversation.id;
const sent = await call('/v1/social/messages', {
  method: 'POST', token: 'sender', body: { conversationId, text: 'Private hello' },
});
assert.equal(sent.status, 201);
const recipientMessages = await call(`/v1/social/messages?conversationId=${conversationId}`, { token: 'receiver' });
assert.equal(recipientMessages.data.messages.length, 1);
assert.equal(recipientMessages.data.messages[0].isMine, false);
const outsiderMessages = await call(`/v1/social/messages?conversationId=${conversationId}`, { token: 'outsider' });
assert.equal(outsiderMessages.status, 403);
const read = await call('/v1/social/messages/read', {
  method: 'POST', token: 'receiver', body: { conversationId },
});
assert.equal(read.status, 200);
const conversations = await call('/v1/social/conversations', { token: 'receiver' });
assert.equal(conversations.data.conversations[0].unreadCount, 0);

console.log('social messaging smoke test: PASS');
