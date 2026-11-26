const DEFAULT_LIMIT_BYTES = 8 * 1024 * 1024 * 1024;
const DEFAULT_WARNING_BYTES = 7 * 1024 * 1024 * 1024;

function sqlFor(actor) {
  const sql = actor?.ctx?.storage?.sql;
  if (!sql || typeof sql.exec !== "function") throw new Error("STORAGE_SQL_UNAVAILABLE");
  return sql;
}

export function ensureQuotaTables(actor) {
  const sql = sqlFor(actor);
  sql.exec(`
    CREATE TABLE IF NOT EXISTS sa7bi_storage_objects (
      object_key TEXT PRIMARY KEY,
      provider TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      state TEXT NOT NULL,
      reservation_id TEXT NOT NULL UNIQUE,
      version_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  `);
  sql.exec(`
    CREATE INDEX IF NOT EXISTS sa7bi_storage_objects_state_idx
    ON sa7bi_storage_objects(state, provider)
  `);
}

function readUsage(actor) {
  const row = sqlFor(actor).exec(
    `SELECT COALESCE(SUM(size_bytes), 0) AS used_bytes,
            COUNT(*) AS object_count
     FROM sa7bi_storage_objects
     WHERE provider = 'b2' AND state IN ('reserved', 'stored')`,
  ).toArray()[0] || {};
  return {
    usedBytes: Number(row.used_bytes) || 0,
    objectCount: Number(row.object_count) || 0,
  };
}

function getLimits(env = {}) {
  const configuredLimit = Number(env.SA7BI_B2_MAX_BYTES);
  const configuredWarning = Number(env.SA7BI_B2_WARNING_BYTES);
  const limitBytes = Number.isSafeInteger(configuredLimit) && configuredLimit > 0
    ? configuredLimit
    : DEFAULT_LIMIT_BYTES;
  const warningBytes = Number.isSafeInteger(configuredWarning) &&
      configuredWarning > 0 && configuredWarning < limitBytes
    ? configuredWarning
    : Math.min(DEFAULT_WARNING_BYTES, limitBytes);
  return { limitBytes, warningBytes };
}

function makeStatus(actor, limits = getLimits(actor.env)) {
  const usage = readUsage(actor);
  return {
    provider: "b2",
    usedBytes: usage.usedBytes,
    objectCount: usage.objectCount,
    limitBytes: limits.limitBytes,
    warningBytes: limits.warningBytes,
    remainingBytes: Math.max(0, limits.limitBytes - usage.usedBytes),
    warning: usage.usedBytes >= limits.warningBytes,
    full: usage.usedBytes >= limits.limitBytes,
  };
}

function runTransaction(actor, callback) {
  const storage = actor?.ctx?.storage;
  if (!storage || typeof storage.transactionSync !== "function") {
    throw new Error("STORAGE_TRANSACTION_UNAVAILABLE");
  }
  return storage.transactionSync(callback);
}

export function getStorageStatus(actor) {
  ensureQuotaTables(actor);
  return makeStatus(actor);
}

export function getStorageObjectRecord(actor, objectKey) {
  ensureQuotaTables(actor);
  return sqlFor(actor).exec(
    `SELECT object_key, provider, size_bytes, state,
            reservation_id, version_id, created_at, updated_at
     FROM sa7bi_storage_objects WHERE object_key = ? LIMIT 1`,
    objectKey,
  ).toArray()[0] || null;
}

export function reserveStorage(actor, { objectKey, sizeBytes }) {
  ensureQuotaTables(actor);
  if (typeof objectKey !== "string" || !objectKey.trim() || objectKey.length > 1024) {
    throw new Error("INVALID_STORAGE_OBJECT_KEY");
  }
  if (!Number.isSafeInteger(sizeBytes) || sizeBytes <= 0) {
    throw new Error("INVALID_STORAGE_SIZE");
  }

  const reservationId = crypto.randomUUID();
  const now = Date.now();
  const limits = getLimits(actor.env);

  return runTransaction(actor, () => {
    const sql = sqlFor(actor);
    const existing = sql.exec(
      "SELECT object_key FROM sa7bi_storage_objects WHERE object_key = ?",
      objectKey,
    ).toArray()[0];
    if (existing) throw new Error("STORAGE_OBJECT_ALREADY_REGISTERED");

    const usage = readUsage(actor);
    if (usage.usedBytes + sizeBytes > limits.limitBytes) {
      throw new Error("STORAGE_CAPACITY_EXCEEDED");
    }

    sql.exec(
      `INSERT INTO sa7bi_storage_objects
       (object_key, provider, size_bytes, state, reservation_id,
        version_id, created_at, updated_at)
       VALUES (?, 'b2', ?, 'reserved', ?, NULL, ?, ?)`,
      objectKey,
      sizeBytes,
      reservationId,
      now,
      now,
    );
    return {
      reservationId,
      objectKey,
      sizeBytes,
      usedBytes: usage.usedBytes + sizeBytes,
      limitBytes: limits.limitBytes,
      warning: usage.usedBytes + sizeBytes >= limits.warningBytes,
    };
  });
}

export function commitStorageReservation(actor, { reservationId, objectKey, versionId }) {
  ensureQuotaTables(actor);
  if (
    typeof reservationId !== "string" || !reservationId ||
    typeof objectKey !== "string" || !objectKey ||
    typeof versionId !== "string" || !versionId
  ) {
    throw new Error("INVALID_STORAGE_COMMIT");
  }

  return runTransaction(actor, () => {
    const result = sqlFor(actor).exec(
      `UPDATE sa7bi_storage_objects
       SET state = 'stored', version_id = ?, updated_at = ?
       WHERE reservation_id = ? AND object_key = ?
         AND provider = 'b2' AND state = 'reserved'`,
      versionId,
      Date.now(),
      reservationId,
      objectKey,
    );
    if (result.rowsWritten !== 1) throw new Error("STORAGE_RESERVATION_NOT_FOUND");
    return makeStatus(actor);
  });
}

export function releaseStorageReservation(actor, { reservationId, objectKey }) {
  ensureQuotaTables(actor);
  return runTransaction(actor, () => {
    const result = sqlFor(actor).exec(
      `DELETE FROM sa7bi_storage_objects
       WHERE reservation_id = ? AND object_key = ?
         AND provider = 'b2' AND state = 'reserved' AND version_id IS NULL`,
      reservationId,
      objectKey,
    );
    return { released: result.rowsWritten === 1, status: makeStatus(actor) };
  });
}

export function releaseDeletedStorageObject(actor, { objectKey, versionId }) {
  ensureQuotaTables(actor);
  if (typeof objectKey !== "string" || !objectKey || typeof versionId !== "string" || !versionId) {
    throw new Error("EXACT_VERSION_REQUIRED");
  }
  return runTransaction(actor, () => {
    const result = sqlFor(actor).exec(
      `DELETE FROM sa7bi_storage_objects
       WHERE object_key = ? AND provider = 'b2'
         AND state = 'stored' AND version_id = ?`,
      objectKey,
      versionId,
    );
    return { released: result.rowsWritten === 1, status: makeStatus(actor) };
  });
}
