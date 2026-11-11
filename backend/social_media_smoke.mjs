
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { handleSocialMedia } from "./src/social_media.js";

const db = new DatabaseSync(":memory:");

const sql = {
  exec(query, ...params) {
    const statement = db.prepare(query);
    const normalized = query.trim().toUpperCase();

    if (
      normalized.startsWith("SELECT") ||
      normalized.startsWith("PRAGMA")
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
`);

const owner = {
  id: "11111111-1111-4111-8111-111111111111",
  username: "Owner",
};

const viewer = {
  id: "22222222-2222-4222-8222-222222222222",
  username: "Viewer",
};

for (const user of [owner, viewer]) {
  db.prepare(
    "INSERT INTO users(id, username, created_at) VALUES (?, ?, ?)",
  ).run(user.id, user.username, Date.now());
}

const sessions = new Map([
  ["owner-token", owner],
  ["viewer-token", viewer],
]);

const objects = new Map();

const bucket = {
  async put(key, value) {
    const bytes = await new Response(value).arrayBuffer();
    objects.set(key, Buffer.from(bytes));
  },

  async get(key, options = {}) {
    const data = objects.get(key);

    if (!data) return null;

    const start = options.range?.offset ?? 0;
    const end = options.range
      ? start + options.range.length
      : data.length;

    const bytes = data.subarray(start, end);

    return {
      size: data.length,
      httpEtag: '"social-media-smoke-etag"',
      body: new Response(bytes).body,
      writeHttpMetadata(headers) {
        headers.set("Content-Type", "video/mp4");
      },
    };
  },

  async delete(key) {
    objects.delete(key);
  },
};

const actor = {
  ctx: {
    storage: { sql },
  },

  env: {
    SA7BI_REELS: bucket,
  },

  async requireUser(request) {
    const authorization =
      request.headers.get("Authorization") || "";

    const token = authorization.replace(/^Bearer /, "");
    const user = sessions.get(token);

    if (user) return user;

    return new Response(
      JSON.stringify({
        ok: false,
        error: "AUTH_REQUIRED",
      }),
      { status: 401 },
    );
  },

  async readBody(request) {
    try {
      return await request.json();
    } catch (_) {
      return { error: "INVALID_JSON" };
    }
  },
};

async function call(path, {
  method = "GET",
  token = "owner-token",
  body,
  headers = {},
} = {}) {
  const requestHeaders = {
    ...(token
      ? { Authorization: `Bearer ${token}` }
      : {}),
    ...headers,
  };

  let requestBody;

  if (body instanceof Uint8Array || Buffer.isBuffer(body)) {
    requestBody = body;
  } else if (body !== undefined) {
    requestHeaders["Content-Type"] = "application/json";
    requestBody = JSON.stringify(body);
  }

  const request = new Request(
    `https://worker.test${path}`,
    {
      method,
      headers: requestHeaders,
      ...(requestBody !== undefined
        ? { body: requestBody }
        : {}),
    },
  );

  const response = await handleSocialMedia(request, actor);

  assert.ok(
    response instanceof Response,
    `No response for ${method} ${path}`,
  );

  const text = await response.text();

  let data = null;

  try {
    data = text ? JSON.parse(text) : null;
  } catch (_) {}

  return {
    status: response.status,
    data,
    text,
    headers: response.headers,
  };
}

// 1. Authentication is required for the feed.
const unauthorized = await call(
  "/v1/social/reels/feed",
  { token: null },
);

assert.equal(unauthorized.status, 401);

// 2. Upload a reel to the fake R2 bucket.
const videoBytes = Buffer.from(
  "fake-mp4-content-for-social-media-smoke-test",
);

const uploaded = await call(
  "/v1/social/reels?caption=First%20community%20reel",
  {
    method: "POST",
    token: "owner-token",
    body: videoBytes,
    headers: {
      "Content-Type": "video/mp4",
      "Content-Length": String(videoBytes.length),
    },
  },
);

assert.equal(uploaded.status, 201);
assert.equal(uploaded.data.ok, true);
assert.equal(
  uploaded.data.reel.caption,
  "First community reel",
);

const reelId = uploaded.data.reel.id;
assert.ok(reelId);
assert.equal(objects.size, 1);

// 3. Another signed-in user sees the published reel.
const feed = await call(
  "/v1/social/reels/feed",
  { token: "viewer-token" },
);

assert.equal(feed.status, 200);
assert.equal(feed.data.reels.length, 1);
assert.equal(feed.data.reels[0].id, reelId);
assert.equal(feed.data.reels[0].isMine, false);
assert.equal(feed.data.reels[0].likedByMe, false);

// 4. Like is idempotent.
const liked = await call(
  `/v1/social/reels/${reelId}/like`,
  {
    method: "POST",
    token: "viewer-token",
  },
);

assert.equal(liked.status, 200);
assert.equal(liked.data.liked, true);
assert.equal(liked.data.likesCount, 1);

const likedAgain = await call(
  `/v1/social/reels/${reelId}/like`,
  {
    method: "POST",
    token: "viewer-token",
  },
);

assert.equal(likedAgain.data.likesCount, 1);

// 5. Add and read a comment.
const comment = await call(
  `/v1/social/reels/${reelId}/comments`,
  {
    method: "POST",
    token: "viewer-token",
    body: { text: "جميل جدًا!" },
  },
);

assert.equal(comment.status, 201);
assert.equal(comment.data.comment.text, "جميل جدًا!");

const comments = await call(
  `/v1/social/reels/${reelId}/comments`,
  { token: "viewer-token" },
);

assert.equal(comments.status, 200);
assert.equal(comments.data.comments.length, 1);
assert.equal(comments.data.comments[0].username, "Viewer");

// 6. Follow the reel owner.
const followed = await call(
  `/v1/social/users/${owner.id}/follow`,
  {
    method: "POST",
    token: "viewer-token",
  },
);

assert.equal(followed.status, 200);
assert.equal(followed.data.following, true);
assert.equal(followed.data.followersCount, 1);

// 7. Feed reflects the updated interaction state.
const updatedFeed = await call(
  "/v1/social/reels/feed",
  { token: "viewer-token" },
);

assert.equal(updatedFeed.data.reels[0].likedByMe, true);
assert.equal(updatedFeed.data.reels[0].followedByMe, true);
assert.equal(updatedFeed.data.reels[0].commentsCount, 1);

// 8. A viewer cannot delete someone else's video.
const forbiddenDelete = await call(
  `/v1/social/reels/${reelId}`,
  {
    method: "DELETE",
    token: "viewer-token",
  },
);

assert.equal(forbiddenDelete.status, 403);
assert.equal(objects.size, 1);

// 9. Public video playback supports HTTP Range.
const media = await call(
  `/v1/social/reels/${reelId}/media`,
  {
    token: null,
    headers: {
      Range: "bytes=0-3",
    },
  },
);

assert.equal(media.status, 206);
assert.equal(
  media.headers.get("Content-Range"),
  `bytes 0-3/${videoBytes.length}`,
);
assert.equal(media.headers.get("Accept-Ranges"), "bytes");

// 10. Only the owner can delete the reel.
const deleted = await call(
  `/v1/social/reels/${reelId}`,
  {
    method: "DELETE",
    token: "owner-token",
  },
);

assert.equal(deleted.status, 200);
assert.equal(deleted.data.deleted, true);
assert.equal(objects.size, 0);

// 11. Deleted media must no longer be available.
const missingMedia = await call(
  `/v1/social/reels/${reelId}/media`,
  { token: null },
);

assert.equal(missingMedia.status, 404);

console.log("social media smoke test: PASS");

db.close();
