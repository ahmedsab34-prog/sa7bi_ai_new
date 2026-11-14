
import assert from 'node:assert/strict';
import {
  handlePrivateRealtimeRequest,
  broadcastConversationEvent,
} from './src/social_realtime.js';

const conversationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const userA = '11111111-1111-4111-8111-111111111111';
const userB = '22222222-2222-4222-8222-222222222222';

function makeSocket(userId, id = conversationId) {
  const sent = [];
  return {
    readyState: 1,
    sent,
    deserializeAttachment() {
      return { userId, conversationId: id, tokenHash: 'a'.repeat(64) };
    },
    send(value) {
      sent.push(JSON.parse(value));
    },
  };
}

const socketA = makeSocket(userA);
const socketB = makeSocket(userB);
const otherConversationSocket = makeSocket(
  userB,
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
);

const actor = {
  ctx: {
    storage: {
      sql: {
        exec(query) {
          if (query.includes('FROM sessions')) {
            return { toArray: () => [{ user_id: userB }] };
          }
          if (query.includes('FROM social_conversations')) {
            return {
              toArray: () => [{
                id: conversationId,
                user_a: userA,
                user_b: userB,
              }],
            };
          }
          return { toArray: () => [] };
        },
      },
    },
    getWebSockets(tag) {
      assert.equal(
        tag,
        `sa7bi-private-conversation:${conversationId}`,
      );
      return [socketA, socketB, otherConversationSocket];
    },
  },
  async requireUser(request) {
    const auth = request.headers.get('Authorization') || '';
    if (auth === `Bearer ${'1'.repeat(64)}`) {
      return { id: userA, username: 'Sender' };
    }
    return new Response(
      JSON.stringify({ ok: false, error: 'AUTH_REQUIRED' }),
      { status: 401 },
    );
  },
};

const noUpgrade = await handlePrivateRealtimeRequest(
  new Request(
    `https://worker.test/v1/social/realtime?conversationId=${conversationId}`,
  ),
  actor,
);
assert.equal(noUpgrade.status, 426);

const invalidId = await handlePrivateRealtimeRequest(
  new Request('https://worker.test/v1/social/realtime?conversationId=bad', {
    headers: { Upgrade: 'websocket' },
  }),
  actor,
);
assert.equal(invalidId.status, 400);

const unauthorized = await handlePrivateRealtimeRequest(
  new Request(
    `https://worker.test/v1/social/realtime?conversationId=${conversationId}`,
    {
      headers: {
        Upgrade: 'websocket',
        Authorization: 'Bearer invalid',
      },
    },
  ),
  actor,
);
assert.equal(unauthorized.status, 401);

const delivered = await broadcastConversationEvent(
  actor,
  conversationId,
  { type: 'message.created', message: { id: 'message-1' } },
  { excludeUserId: userA },
);
assert.equal(delivered, 1);
assert.equal(socketA.sent.length, 0);
assert.equal(socketB.sent.length, 1);
assert.equal(socketB.sent[0].type, 'message.created');
assert.equal(otherConversationSocket.sent.length, 0);

console.log('social realtime smoke test: PASS');
