// Sa7bi AI private group management.
// Reuses the existing social_groups and social_group_members tables.
// Invite codes are stored as SHA-256 hashes and are never returned again
// after the create-invite response.

const MAX_GROUP_NAME = 40;
const MAX_GROUP_DESCRIPTION = 160;
const MAX_GROUP_MEMBERS = 200;
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const INVITE_MAX_USES = 25;
const INVITE_ATTEMPT_WINDOW_MS = 15 * 60 * 1000;
const INVITE_ATTEMPT_LIMIT = 10;
const INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function rows(cursor) {
  return cursor && typeof cursor.toArray === "function"
    ? cursor.toArray()
    : [];
}

function safeString(value, max = 200) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function ensureTables(actor) {
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
    CREATE TABLE IF NOT EXISTS social_group_messages (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_group_invites (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      token_hash TEXT NOT NULL UNIQUE,
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      max_uses INTEGER NOT NULL,
      uses INTEGER NOT NULL DEFAULT 0,
      revoked_at INTEGER
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_group_invites_group_idx
    ON social_group_invites(group_id, created_at DESC)
  `);

  sql.exec(`
    CREATE TABLE IF NOT EXISTS social_group_invite_attempts (
      user_id TEXT NOT NULL,
      attempted_at INTEGER NOT NULL
    )
  `);

  sql.exec(`
    CREATE INDEX IF NOT EXISTS social_group_invite_attempts_user_idx
    ON social_group_invite_attempts(user_id, attempted_at DESC)
  `);
}

async function requireUser(actor, request) {
  return actor.requireUser(request);
}

async function readBody(actor, request) {
  const body = await actor.readBody(request);
  if (!body || typeof body !== "object" || body.error) {
    return { error: body?.error || "INVALID_JSON" };
  }
  return body;
}

function membership(actor, groupId, userId) {
  return rows(actor.ctx.storage.sql.exec(
    `SELECT role, joined_at FROM social_group_members
     WHERE group_id = ? AND user_id = ? LIMIT 1`,
    groupId,
    userId,
  ))[0] || null;
}

function groupRow(actor, groupId, userId) {
  return rows(actor.ctx.storage.sql.exec(
    `SELECT g.id, g.name, g.description, g.created_by, g.is_public,
            g.created_at, g.updated_at,
            (SELECT COUNT(*) FROM social_group_members m
             WHERE m.group_id = g.id) AS member_count,
            EXISTS(SELECT 1 FROM social_group_members mine
                   WHERE mine.group_id = g.id AND mine.user_id = ?) AS is_member,
            (SELECT mine.role FROM social_group_members mine
             WHERE mine.group_id = g.id AND mine.user_id = ? LIMIT 1) AS my_role,
            (SELECT body FROM social_group_messages msg
             WHERE msg.group_id = g.id
             ORDER BY msg.created_at DESC LIMIT 1) AS last_message
     FROM social_groups g WHERE g.id = ? LIMIT 1`,
    userId,
    userId,
    groupId,
  ))[0] || null;
}

function groupPayload(row) {
  return {
    id: row.id,
    name: row.name,
    description: row.description || "",
    ownerId: row.created_by,
    memberCount: Number(row.member_count || 0),
    isMember: Number(row.is_member || 0) === 1,
    isPublic: Number(row.is_public || 0) === 1,
    myRole: row.my_role || "",
    lastMessage: row.last_message || "",
    createdAt: Number(row.created_at || 0),
    updatedAt: Number(row.updated_at || 0),
  };
}

function inviteCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(10));
  return Array.from(
    bytes,
    (byte) => INVITE_ALPHABET[byte % INVITE_ALPHABET.length],
  ).join("");
}

async function hashCode(code) {
  const bytes = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

async function listMyGroups(actor, user) {
  const found = rows(actor.ctx.storage.sql.exec(
    `SELECT g.id
     FROM social_groups g
     INNER JOIN social_group_members m ON m.group_id = g.id
     WHERE m.user_id = ?
     ORDER BY g.updated_at DESC, g.created_at DESC
     LIMIT 100`,
    user.id,
  ));

  const groups = found
    .map((item) => groupRow(actor, item.id, user.id))
    .filter(Boolean)
    .map(groupPayload);

  return json({ ok: true, groups });
}

async function createPrivateGroup(actor, request, user) {
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
  const sql = actor.ctx.storage.sql;

  sql.exec(
    `INSERT INTO social_groups
     (id, name, description, created_by, is_public, created_at, updated_at)
     VALUES (?, ?, ?, ?, 0, ?, ?)`,
    groupId,
    name,
    description,
    user.id,
    now,
    now,
  );

  sql.exec(
    `INSERT INTO social_group_members
     (group_id, user_id, role, joined_at, last_read_at)
     VALUES (?, ?, 'owner', ?, ?)`,
    groupId,
    user.id,
    now,
    now,
  );

  return json({
    ok: true,
    group: groupPayload(groupRow(actor, groupId, user.id)),
  }, 201);
}

async function createInvite(actor, request, groupId, user) {
  const group = groupRow(actor, groupId, user.id);

  if (!group || Number(group.is_public) !== 0) {
    return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);
  }

  if (!["owner", "admin"].includes(group.my_role)) {
    return json({ ok: false, error: "GROUP_ADMIN_REQUIRED" }, 403);
  }

  const now = Date.now();
  let code = "";
  let tokenHash = "";
  let saved = false;

  for (let attempt = 0; attempt < 5; attempt++) {
    code = inviteCode();
    tokenHash = await hashCode(code);
    const id = crypto.randomUUID();

    try {
      actor.ctx.storage.sql.exec(
        `INSERT INTO social_group_invites
         (id, group_id, token_hash, created_by, created_at,
          expires_at, max_uses, uses, revoked_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0, NULL)`,
        id,
        groupId,
        tokenHash,
        user.id,
        now,
        now + INVITE_TTL_MS,
        INVITE_MAX_USES,
      );

      saved = true;
      break;
    } catch (_) {
      // Retry only in the extremely unlikely event of a token collision.
    }
  }

  if (!saved) {
    return json({ ok: false, error: "GROUP_INVITE_CREATE_FAILED" }, 503);
  }

  return json({
    ok: true,
    invite: {
      code,
      expiresAt: now + INVITE_TTL_MS,
      maxUses: INVITE_MAX_USES,
    },
  }, 201);
}

async function joinByInvite(actor, request, user) {
  const body = await readBody(actor, request);
  if (body.error) return json({ ok: false, error: body.error }, 400);

  const code = safeString(body.code, 20).toUpperCase();
  const now = Date.now();

  const recentAttempts = rows(actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS total FROM social_group_invite_attempts
     WHERE user_id = ? AND attempted_at >= ?`,
    user.id,
    now - INVITE_ATTEMPT_WINDOW_MS,
  ))[0];

  if (Number(recentAttempts?.total || 0) >= INVITE_ATTEMPT_LIMIT) {
    return json({
      ok: false,
      error: "GROUP_INVITE_RATE_LIMIT",
      retryAfterSeconds: Math.ceil(INVITE_ATTEMPT_WINDOW_MS / 1000),
    }, 429);
  }

  actor.ctx.storage.sql.exec(
    `INSERT INTO social_group_invite_attempts(user_id, attempted_at)
     VALUES (?, ?)`,
    user.id,
    now,
  );

  if (!/^[A-HJ-NP-Z2-9]{10}$/.test(code)) {
    return json({ ok: false, error: "GROUP_INVITE_INVALID" }, 400);
  }

  const tokenHash = await hashCode(code);

  const invite = rows(actor.ctx.storage.sql.exec(
    `SELECT id, group_id, expires_at, max_uses, uses, revoked_at
     FROM social_group_invites WHERE token_hash = ? LIMIT 1`,
    tokenHash,
  ))[0];

  if (!invite || invite.revoked_at != null) {
    return json({ ok: false, error: "GROUP_INVITE_INVALID" }, 404);
  }

  if (Number(invite.expires_at) <= now) {
    return json({ ok: false, error: "GROUP_INVITE_EXPIRED" }, 410);
  }

  if (Number(invite.uses) >= Number(invite.max_uses)) {
    return json({ ok: false, error: "GROUP_INVITE_MAX_USES" }, 409);
  }

  const group = rows(actor.ctx.storage.sql.exec(
    `SELECT id, is_public FROM social_groups WHERE id = ? LIMIT 1`,
    invite.group_id,
  ))[0];

  if (!group || Number(group.is_public) !== 0) {
    return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);
  }

  const alreadyMember = membership(actor, invite.group_id, user.id);

  if (alreadyMember) {
    return json({
      ok: true,
      alreadyMember: true,
      group: groupPayload(groupRow(actor, invite.group_id, user.id)),
    });
  }

  const count = rows(actor.ctx.storage.sql.exec(
    `SELECT COUNT(*) AS total
     FROM social_group_members WHERE group_id = ?`,
    invite.group_id,
  ))[0];

  if (Number(count?.total || 0) >= MAX_GROUP_MEMBERS) {
    return json({ ok: false, error: "GROUP_FULL" }, 409);
  }

  const updated = actor.ctx.storage.sql.exec(
    `UPDATE social_group_invites SET uses = uses + 1
     WHERE id = ? AND revoked_at IS NULL
       AND expires_at > ? AND uses < max_uses`,
    invite.id,
    now,
  );

  if (Number(updated?.rowsWritten || 0) === 0) {
    return json({ ok: false, error: "GROUP_INVITE_MAX_USES" }, 409);
  }

  try {
    actor.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO social_group_members
       (group_id, user_id, role, joined_at, last_read_at)
       VALUES (?, ?, 'member', ?, ?)`,
      invite.group_id,
      user.id,
      now,
      now,
    );
  } catch (_) {
    actor.ctx.storage.sql.exec(
      `UPDATE social_group_invites
       SET uses = CASE WHEN uses > 0 THEN uses - 1 ELSE 0 END
       WHERE id = ?`,
      invite.id,
    );

    return json({ ok: false, error: "GROUP_JOIN_FAILED" }, 500);
  }

  return json({
    ok: true,
    alreadyMember: false,
    group: groupPayload(groupRow(actor, invite.group_id, user.id)),
  });
}

async function listMembers(actor, groupId, user) {
  const group = groupRow(actor, groupId, user.id);

  if (!group) return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);

  if (!group.is_member) {
    return json({ ok: false, error: "GROUP_MEMBERSHIP_REQUIRED" }, 403);
  }

  const members = rows(actor.ctx.storage.sql.exec(
    `SELECT m.user_id, m.role, m.joined_at, u.username
     FROM social_group_members m
     LEFT JOIN users u ON u.id = m.user_id
     WHERE m.group_id = ?
     ORDER BY CASE m.role
       WHEN 'owner' THEN 0
       WHEN 'admin' THEN 1
       ELSE 2
     END, m.joined_at ASC`,
    groupId,
  )).map((row) => ({
    userId: row.user_id,
    username: row.username || "لاعب",
    role: row.role || "member",
    joinedAt: Number(row.joined_at || 0),
  }));

  return json({ ok: true, members });
}

async function setMemberAdmin(actor, request, groupId, targetId, user) {
  const group = groupRow(actor, groupId, user.id);

  if (!group) return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);

  if (group.my_role !== "owner") {
    return json({ ok: false, error: "GROUP_OWNER_REQUIRED" }, 403);
  }

  if (targetId === user.id) {
    return json({ ok: false, error: "GROUP_CANNOT_CHANGE_OWNER" }, 409);
  }

  const target = membership(actor, groupId, targetId);

  if (!target) {
    return json({ ok: false, error: "GROUP_MEMBER_NOT_FOUND" }, 404);
  }

  if (target.role === "owner") {
    return json({ ok: false, error: "GROUP_CANNOT_CHANGE_OWNER" }, 409);
  }

  const body = await readBody(actor, request);

  if (body.error || typeof body.isAdmin !== "boolean") {
    return json({ ok: false, error: "INVALID_GROUP_ROLE" }, 400);
  }

  const role = body.isAdmin ? "admin" : "member";

  actor.ctx.storage.sql.exec(
    `UPDATE social_group_members
     SET role = ? WHERE group_id = ? AND user_id = ?`,
    role,
    groupId,
    targetId,
  );

  return json({ ok: true, userId: targetId, role });
}

async function removeMember(actor, groupId, targetId, user) {
  const group = groupRow(actor, groupId, user.id);

  if (!group) return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);

  if (!["owner", "admin"].includes(group.my_role)) {
    return json({ ok: false, error: "GROUP_ADMIN_REQUIRED" }, 403);
  }

  if (targetId === user.id) {
    return json({ ok: false, error: "GROUP_USE_LEAVE_ROUTE" }, 409);
  }

  const target = membership(actor, groupId, targetId);

  if (!target) {
    return json({ ok: false, error: "GROUP_MEMBER_NOT_FOUND" }, 404);
  }

  if (target.role === "owner") {
    return json({ ok: false, error: "GROUP_CANNOT_REMOVE_OWNER" }, 409);
  }

  if (group.my_role === "admin" && target.role !== "member") {
    return json({ ok: false, error: "GROUP_ADMIN_CANNOT_REMOVE_ADMIN" }, 403);
  }

  actor.ctx.storage.sql.exec(
    `DELETE FROM social_group_members
     WHERE group_id = ? AND user_id = ?`,
    groupId,
    targetId,
  );

  return json({ ok: true, removed: true, userId: targetId });
}

async function leaveGroup(actor, groupId, user) {
  const member = membership(actor, groupId, user.id);

  if (!member) {
    return json({ ok: false, error: "GROUP_MEMBERSHIP_REQUIRED" }, 403);
  }

  if (member.role === "owner") {
    return json({ ok: false, error: "GROUP_OWNER_MUST_DELETE" }, 409);
  }

  actor.ctx.storage.sql.exec(
    `DELETE FROM social_group_members
     WHERE group_id = ? AND user_id = ?`,
    groupId,
    user.id,
  );

  return json({ ok: true, left: true });
}

async function deleteGroup(actor, groupId, user) {
  const group = groupRow(actor, groupId, user.id);

  if (!group) return json({ ok: false, error: "GROUP_NOT_FOUND" }, 404);

  if (group.my_role !== "owner") {
    return json({ ok: false, error: "GROUP_OWNER_REQUIRED" }, 403);
  }

  const sql = actor.ctx.storage.sql;

  sql.exec(`DELETE FROM social_group_invites WHERE group_id = ?`, groupId);
  sql.exec(`DELETE FROM social_group_messages WHERE group_id = ?`, groupId);
  sql.exec(`DELETE FROM social_group_members WHERE group_id = ?`, groupId);
  sql.exec(`DELETE FROM social_groups WHERE id = ?`, groupId);

  return json({ ok: true, deleted: true });
}

/** Private group and membership-management routes for Sa7bi Connect. */
export async function handleSocialGroupManagement(request, actor) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  const mine = path === "/v1/social/groups/mine";
  const privateCreate = path === "/v1/social/groups/private";
  const joinInvite = path === "/v1/social/groups/join-invite";

  const inviteMatch = path.match(
    /^\/v1\/social\/groups\/([a-f0-9-]{36})\/invites$/i,
  );

  const membersMatch = path.match(
    /^\/v1\/social\/groups\/([a-f0-9-]{36})\/members$/i,
  );

  const adminMatch = path.match(
    /^\/v1\/social\/groups\/([a-f0-9-]{36})\/members\/([a-f0-9-]{36})\/admin$/i,
  );

  const removeMatch = path.match(
    /^\/v1\/social\/groups\/([a-f0-9-]{36})\/members\/([a-f0-9-]{36})$/i,
  );

  const leaveMatch = path.match(
    /^\/v1\/social\/groups\/([a-f0-9-]{36})\/leave$/i,
  );

  const deleteMatch = path.match(
    /^\/v1\/social\/groups\/([a-f0-9-]{36})$/i,
  );

  const known = mine || privateCreate || joinInvite || inviteMatch ||
    membersMatch || adminMatch || removeMatch || leaveMatch || deleteMatch;

  if (!known) return null;

  try {
    ensureTables(actor);

    const user = await requireUser(actor, request);

    if (user instanceof Response) return user;

    if (mine && method === "GET") {
      return await listMyGroups(actor, user);
    }

    if (privateCreate && method === "POST") {
      return await createPrivateGroup(actor, request, user);
    }

    if (joinInvite && method === "POST") {
      return await joinByInvite(actor, request, user);
    }

    if (inviteMatch && method === "POST") {
      return await createInvite(actor, request, inviteMatch[1], user);
    }

    if (membersMatch && method === "GET") {
      return await listMembers(actor, membersMatch[1], user);
    }

    if (adminMatch && method === "POST") {
      return await setMemberAdmin(
        actor,
        request,
        adminMatch[1],
        adminMatch[2],
        user,
      );
    }

    if (removeMatch && method === "DELETE") {
      return await removeMember(
        actor,
        removeMatch[1],
        removeMatch[2],
        user,
      );
    }

    if (leaveMatch && method === "POST") {
      return await leaveGroup(actor, leaveMatch[1], user);
    }

    if (deleteMatch && method === "DELETE") {
      return await deleteGroup(actor, deleteMatch[1], user);
    }

    return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  } catch (_) {
    return json({
      ok: false,
      error: "SOCIAL_GROUP_MANAGEMENT_INTERNAL_ERROR",
      message: "تعذر إكمال إدارة المجموعة. حاول مرة أخرى.",
    }, 500);
  }
}
