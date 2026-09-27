// backend/src/credits.js
// Sa7bi AI - Server Authoritative Credits
// Persistent per-device credit ledger using Cloudflare Durable Objects.

import { DurableObject } from "cloudflare:workers";

/* =========================================================
   CREDIT POLICY
   ========================================================= */

export const CREDIT_COSTS = Object.freeze({
  text: 1,
  image_analysis: 3,
  video_analysis: 5,
  image_generation: 10,
  image_edit: 10,
});

export const INITIAL_CREDITS = 100;

export const REWARDED_AD_CREDITS = 10;

export const REWARDED_AD_DAILY_LIMIT = 5;

const RESERVATION_TTL_MS = 10 * 60 * 1000;

/* =========================================================
   HELPERS
   ========================================================= */

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function todayKey() {
  const now = new Date();

  const year = now.getUTCFullYear();

  const month = String(
    now.getUTCMonth() + 1,
  ).padStart(2, "0");

  const day = String(
    now.getUTCDate(),
  ).padStart(2, "0");

  return `${year}-${month}-${day}`;
}

function normalizeDeviceId(value) {
  if (typeof value !== "string") {
    return "";
  }

  const clean = value.trim();

  if (!clean) {
    return "";
  }

  return clean.substring(0, 128);
}

function normalizeRequestId(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().substring(0, 128);
}

function normalizeTransactionId(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().substring(0, 256);
}

function normalizeOperation(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().toLowerCase();
}

function getCreditCost(operation) {
  const normalized = normalizeOperation(operation);

  return CREDIT_COSTS[normalized] ?? null;
}

function clampCredits(value) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return 0;
  }

  if (number < 0) {
    return 0;
  }

  if (number > 1000000) {
    return 1000000;
  }

  return Math.floor(number);
}

/* =========================================================
   DURABLE OBJECT
   ========================================================= */

export class Sa7biCredits extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);

    this.ctx = ctx;
    this.env = env;

    /* -------------------------------------------------------
       ACCOUNT
       ------------------------------------------------------- */

    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS account (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        credits INTEGER NOT NULL,
        rewarded_date TEXT NOT NULL,
        rewarded_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `);

    /* -------------------------------------------------------
       AI RESERVATIONS
       ------------------------------------------------------- */

    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS reservations (
        request_id TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        cost INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        state TEXT NOT NULL
      )
    `);

    /* -------------------------------------------------------
       VERIFIED REWARDED AD TRANSACTIONS

       transaction_id is the idempotency key.

       A verified AdMob reward can therefore only
       be credited once for this device.
       ------------------------------------------------------- */

    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS rewarded_transactions (
        transaction_id TEXT PRIMARY KEY,
        reward_amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        source TEXT NOT NULL
      )
    `);
  }

  /* =======================================================
     ACCOUNT INITIALIZATION
     ======================================================= */

  ensureAccount() {
    const row = this.ctx.storage.sql
      .exec(
        `
        SELECT
          id,
          credits,
          rewarded_date,
          rewarded_count,
          created_at,
          updated_at
        FROM account
        WHERE id = 1
        LIMIT 1
        `,
      )
      .one();

    if (row) {
      return row;
    }

    const now = Date.now();

    this.ctx.storage.sql.exec(
      `
      INSERT INTO account (
        id,
        credits,
        rewarded_date,
        rewarded_count,
        created_at,
        updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?)
      `,
      1,
      INITIAL_CREDITS,
      todayKey(),
      0,
      now,
      now,
    );

    return this.ctx.storage.sql
      .exec(
        `
        SELECT
          id,
          credits,
          rewarded_date,
          rewarded_count,
          created_at,
          updated_at
        FROM account
        WHERE id = 1
        LIMIT 1
        `,
      )
      .one();
  }

  /* =======================================================
     DAILY REWARDED RESET
     ======================================================= */

  resetRewardedCounterIfNeeded() {
    const account = this.ensureAccount();

    const today = todayKey();

    if (account.rewarded_date === today) {
      return account;
    }

    const now = Date.now();

    this.ctx.storage.sql.exec(
      `
      UPDATE account
      SET
        rewarded_date = ?,
        rewarded_count = 0,
        updated_at = ?
      WHERE id = 1
      `,
      today,
      now,
    );

    return this.ensureAccount();
  }

  /* =======================================================
     CLEAN EXPIRED RESERVATIONS
     ======================================================= */

  cleanupExpiredReservations() {
    const now = Date.now();

    this.ctx.storage.sql.exec(
      `
      DELETE FROM reservations
      WHERE state = 'reserved'
        AND expires_at <= ?
      `,
      now,
    );
  }

  /* =======================================================
     RESERVED TOTAL
     ======================================================= */

  getReservedTotal() {
    const row = this.ctx.storage.sql
      .exec(
        `
        SELECT
          COALESCE(SUM(cost), 0) AS total
        FROM reservations
        WHERE state = 'reserved'
        `,
      )
      .one();

    return clampCredits(row?.total ?? 0);
  }

  /* =======================================================
     ACCOUNT STATE
     ======================================================= */

  getState() {
    this.cleanupExpiredReservations();

    const account =
      this.resetRewardedCounterIfNeeded();

    const reserved = this.getReservedTotal();

    const credits = clampCredits(account.credits);

    const available = Math.max(
      0,
      credits - reserved,
    );

    const rewardedAdsToday = Math.max(
      0,
      Number(account.rewarded_count || 0),
    );

    const remainingRewardedAds = Math.max(
      0,
      REWARDED_AD_DAILY_LIMIT -
        rewardedAdsToday,
    );

    return {
      credits,

      availableCredits: available,

      reservedCredits: reserved,

      rewardedAdsToday,

      rewardedAdDailyLimit:
        REWARDED_AD_DAILY_LIMIT,

      remainingRewardedAds,

      rewardedAdCredits:
        REWARDED_AD_CREDITS,
    };
  }

  /* =======================================================
     RESERVE AI CREDITS
     ======================================================= */

  reserve({
    operation,
    requestId,
  }) {
    this.cleanupExpiredReservations();

    const normalizedOperation =
      normalizeOperation(operation);

    const normalizedRequestId =
      normalizeRequestId(requestId);

    if (!normalizedRequestId) {
      return {
        ok: false,
        error: "REQUEST_ID_REQUIRED",
      };
    }

    const cost = getCreditCost(
      normalizedOperation,
    );

    if (cost === null) {
      return {
        ok: false,
        error: "UNKNOWN_CREDIT_OPERATION",
      };
    }

    /* -------------------------------------------------------
       REQUEST IDEMPOTENCY
       ------------------------------------------------------- */

    const existing =
      this.ctx.storage.sql
        .exec(
          `
          SELECT
            request_id,
            operation,
            cost,
            created_at,
            expires_at,
            state
          FROM reservations
          WHERE request_id = ?
          LIMIT 1
          `,
          normalizedRequestId,
        )
        .one();

    if (existing) {
      if (existing.state === "reserved") {
        return {
          ok: true,

          alreadyReserved: true,

          operation: existing.operation,

          cost: Number(existing.cost),

          requestId: existing.request_id,

          state: existing.state,

          expiresAt: Number(
            existing.expires_at,
          ),

          balance: this.getState(),
        };
      }

      return {
        ok: false,
        error: "REQUEST_ALREADY_FINALIZED",
      };
    }

    const account = this.ensureAccount();

    const reserved = this.getReservedTotal();

    const available = Math.max(
      0,
      clampCredits(account.credits) -
        reserved,
    );

    if (available < cost) {
      return {
        ok: false,

        error: "INSUFFICIENT_CREDITS",

        required: cost,

        available,

        balance: this.getState(),
      };
    }

    const now = Date.now();

    const expiresAt =
      now + RESERVATION_TTL_MS;

    this.ctx.storage.sql.exec(
      `
      INSERT INTO reservations (
        request_id,
        operation,
        cost,
        created_at,
        expires_at,
        state
      )
      VALUES (?, ?, ?, ?, ?, 'reserved')
      `,
      normalizedRequestId,
      normalizedOperation,
      cost,
      now,
      expiresAt,
    );

    return {
      ok: true,

      alreadyReserved: false,

      operation: normalizedOperation,

      cost,

      requestId: normalizedRequestId,

      state: "reserved",

      expiresAt,

      balance: this.getState(),
    };
  }

  /* =======================================================
     COMMIT AI CREDITS
     ======================================================= */

  commit(requestId) {
    this.cleanupExpiredReservations();

    const normalizedRequestId =
      normalizeRequestId(requestId);

    if (!normalizedRequestId) {
      return {
        ok: false,
        error: "REQUEST_ID_REQUIRED",
      };
    }

    const reservation =
      this.ctx.storage.sql
        .exec(
          `
          SELECT
            request_id,
            operation,
            cost,
            state,
            expires_at
          FROM reservations
          WHERE request_id = ?
          LIMIT 1
          `,
          normalizedRequestId,
        )
        .one();

    if (!reservation) {
      return {
        ok: false,
        error: "RESERVATION_NOT_FOUND",
      };
    }

    if (reservation.state === "committed") {
      return {
        ok: true,

        alreadyCommitted: true,

        cost: Number(
          reservation.cost,
        ),

        balance: this.getState(),
      };
    }

    if (reservation.state !== "reserved") {
      return {
        ok: false,
        error: "RESERVATION_NOT_ACTIVE",
      };
    }

    if (
      Number(reservation.expires_at) <=
      Date.now()
    ) {
      this.ctx.storage.sql.exec(
        `
        UPDATE reservations
        SET state = 'released'
        WHERE request_id = ?
        `,
        normalizedRequestId,
      );

      return {
        ok: false,
        error: "RESERVATION_EXPIRED",
      };
    }

    const cost = clampCredits(
      reservation.cost,
    );

    const account = this.ensureAccount();

    const currentCredits =
      clampCredits(account.credits);

    if (currentCredits < cost) {
      this.ctx.storage.sql.exec(
        `
        UPDATE reservations
        SET state = 'released'
        WHERE request_id = ?
        `,
        normalizedRequestId,
      );

      return {
        ok: false,

        error: "INSUFFICIENT_CREDITS",

        balance: this.getState(),
      };
    }

    const now = Date.now();

    this.ctx.storage.sql.exec(
      `
      UPDATE account
      SET
        credits = credits - ?,
        updated_at = ?
      WHERE id = 1
      `,
      cost,
      now,
    );

    this.ctx.storage.sql.exec(
      `
      UPDATE reservations
      SET state = 'committed'
      WHERE request_id = ?
      `,
      normalizedRequestId,
    );

    return {
      ok: true,

      committed: true,

      cost,

      balance: this.getState(),
    };
  }

  /* =======================================================
     RELEASE AI CREDITS
     ======================================================= */

  release(requestId) {
    const normalizedRequestId =
      normalizeRequestId(requestId);

    if (!normalizedRequestId) {
      return {
        ok: false,
        error: "REQUEST_ID_REQUIRED",
      };
    }

    const reservation =
      this.ctx.storage.sql
        .exec(
          `
          SELECT
            request_id,
            operation,
            cost,
            state
          FROM reservations
          WHERE request_id = ?
          LIMIT 1
          `,
          normalizedRequestId,
        )
        .one();

    if (!reservation) {
      return {
        ok: false,
        error: "RESERVATION_NOT_FOUND",
      };
    }

    if (reservation.state === "released") {
      return {
        ok: true,

        alreadyReleased: true,

        balance: this.getState(),
      };
    }

    if (reservation.state === "committed") {
      return {
        ok: false,
        error: "REQUEST_ALREADY_COMMITTED",
      };
    }

    this.ctx.storage.sql.exec(
      `
      UPDATE reservations
      SET state = 'released'
      WHERE request_id = ?
      `,
      normalizedRequestId,
    );

    return {
      ok: true,

      released: true,

      cost: Number(
        reservation.cost,
      ),

      balance: this.getState(),
    };
  }

  /* =======================================================
     VERIFIED ADMOB REWARDED AD
     ======================================================= */

  /*
   * IMPORTANT:
   *
   * This function must ONLY be called after the Worker
   * verifies the AdMob SSV signature and callback data.
   *
   * Flutter NEVER calls this function directly.
   *
   * The server determines the reward amount from:
   *
   * REWARDED_AD_CREDITS = 10
   *
   * The client cannot choose the reward amount.
   */

  rewardVerifiedAd({
    transactionId,
    source = "admob_ssv",
  }) {
    const normalizedTransactionId =
      normalizeTransactionId(
        transactionId,
      );

    if (!normalizedTransactionId) {
      return {
        ok: false,

        error:
          "REWARD_TRANSACTION_ID_REQUIRED",
      };
    }

    /* -------------------------------------------------------
       IDEMPOTENCY CHECK
       ------------------------------------------------------- */

    const existing =
      this.ctx.storage.sql
        .exec(
          `
          SELECT
            transaction_id,
            reward_amount,
            created_at,
            source
          FROM rewarded_transactions
          WHERE transaction_id = ?
          LIMIT 1
          `,
          normalizedTransactionId,
        )
        .one();

    if (existing) {
      return {
        ok: true,

        alreadyRewarded: true,

        transactionId:
          existing.transaction_id,

        added: Number(
          existing.reward_amount,
        ),

        balance: this.getState(),
      };
    }

    /* -------------------------------------------------------
       DAILY LIMIT
       ------------------------------------------------------- */

    const account =
      this.resetRewardedCounterIfNeeded();

    const rewardedCount = Math.max(
      0,
      Number(account.rewarded_count || 0),
    );

    if (
      rewardedCount >=
      REWARDED_AD_DAILY_LIMIT
    ) {
      return {
        ok: false,

        error:
          "REWARDED_AD_DAILY_LIMIT",

        balance: this.getState(),
      };
    }

    /* -------------------------------------------------------
       APPLY VERIFIED REWARD
       ------------------------------------------------------- */

    const now = Date.now();

    /*
     * Store the transaction BEFORE updating the balance.
     *
     * Cloudflare Durable Objects execute this request
     * serially, so the transaction ID remains the
     * idempotency barrier for repeated callbacks.
     */

    this.ctx.storage.sql.exec(
      `
      INSERT INTO rewarded_transactions (
        transaction_id,
        reward_amount,
        created_at,
        source
      )
      VALUES (?, ?, ?, ?)
      `,
      normalizedTransactionId,
      REWARDED_AD_CREDITS,
      now,
      typeof source === "string" &&
        source.trim()
        ? source.trim().substring(0, 128)
        : "admob_ssv",
    );

    this.ctx.storage.sql.exec(
      `
      UPDATE account
      SET
        credits = credits + ?,
        rewarded_count = rewarded_count + 1,
        rewarded_date = ?,
        updated_at = ?
      WHERE id = 1
      `,
      REWARDED_AD_CREDITS,
      todayKey(),
      now,
    );

    return {
      ok: true,

      rewarded: true,

      alreadyRewarded: false,

      transactionId:
        normalizedTransactionId,

      added:
        REWARDED_AD_CREDITS,

      balance: this.getState(),
    };
  }

  /* =======================================================
     LEGACY REWARD METHOD
     ======================================================= */

  /*
   * Old direct reward path intentionally disabled.
   *
   * This prevents Flutter or an unauthenticated request
   * from creating credits.
   */

  rewardAd() {
    return {
      ok: false,

      error:
        "REWARD_VERIFICATION_REQUIRED",
    };
  }

  /* =======================================================
     DURABLE OBJECT HTTP API
     ======================================================= */

  async fetch(request) {
    try {
      const url = new URL(request.url);

      const action =
        url.searchParams.get("action") ||
        "balance";

      /* -----------------------------------------------------
         GET
         ----------------------------------------------------- */

      if (request.method === "GET") {
        if (action === "balance") {
          return json({
            ok: true,
            ...this.getState(),
          });
        }

        return json(
          {
            ok: false,
            error: "UNKNOWN_ACTION",
          },
          400,
        );
      }

      /* -----------------------------------------------------
         METHOD
         ----------------------------------------------------- */

      if (request.method !== "POST") {
        return json(
          {
            ok: false,
            error: "METHOD_NOT_ALLOWED",
          },
          405,
        );
      }

      let body = {};

      try {
        body = await request.json();
      } catch (_) {
        body = {};
      }

      /* -----------------------------------------------------
         RESERVE
         ----------------------------------------------------- */

      if (action === "reserve") {
        return json(
          this.reserve({
            operation: body.operation,
            requestId: body.requestId,
          }),
          200,
        );
      }

      /* -----------------------------------------------------
         COMMIT
         ----------------------------------------------------- */

      if (action === "commit") {
        return json(
          this.commit(
            body.requestId,
          ),
          200,
        );
      }

      /* -----------------------------------------------------
         RELEASE
         ----------------------------------------------------- */

      if (action === "release") {
        return json(
          this.release(
            body.requestId,
          ),
          200,
        );
      }

      /* -----------------------------------------------------
         VERIFIED REWARD

         This action is intentionally NOT publicly
         authorized by the main Worker route.

         The module-level rewardVerifiedAd() helper
         calls it only after SSV verification.
         ----------------------------------------------------- */

      if (
        action === "verified-reward"
      ) {
        return json(
          this.rewardVerifiedAd({
            transactionId:
              body.transactionId,

            source:
              body.source ||
              "admob_ssv",
          }),
          200,
        );
      }

      /* -----------------------------------------------------
         LEGACY REWARD-AD ROUTE
         ----------------------------------------------------- */

      if (action === "reward-ad") {
        return json(
          {
            ok: false,

            error:
              "REWARD_VERIFICATION_REQUIRED",
          },
          403,
        );
      }

      return json(
        {
          ok: false,
          error: "UNKNOWN_ACTION",
        },
        400,
      );
    } catch (error) {
      return json(
        {
          ok: false,

          error:
            error?.message ||
            "CREDITS_INTERNAL_ERROR",
        },
        500,
      );
    }
  }
}

/* =========================================================
   DEVICE ID → DURABLE OBJECT
   ========================================================= */

export async function getCreditsObject(
  env,
  deviceId,
) {
  if (!env.SA7BI_CREDITS) {
    throw new Error(
      "SA7BI_CREDITS_BINDING_MISSING",
    );
  }

  const normalized =
    normalizeDeviceId(deviceId);

  if (!normalized) {
    throw new Error(
      "DEVICE_ID_REQUIRED",
    );
  }

  /*
   * SHA-256 prevents the raw installation identifier
   * from becoming the Durable Object name.
   */

  const bytes =
    new TextEncoder().encode(
      normalized,
    );

  const digest =
    await crypto.subtle.digest(
      "SHA-256",
      bytes,
    );

  const digestBytes =
    new Uint8Array(digest);

  let hex = "";

  for (const byte of digestBytes) {
    hex += byte
      .toString(16)
      .padStart(2, "0");
  }

  const id =
    env.SA7BI_CREDITS.idFromName(
      hex,
    );

  return env.SA7BI_CREDITS.get(id);
}

/* =========================================================
   PUBLIC CREDIT HELPERS
   ========================================================= */

export async function getServerCredits(
  env,
  deviceId,
) {
  const object =
    await getCreditsObject(
      env,
      deviceId,
    );

  const response =
    await object.fetch(
      "https://credits.local/?action=balance",
    );

  return response.json();
}

export async function reserveCredits(
  env,
  {
    deviceId,
    operation,
    requestId,
  },
) {
  const object =
    await getCreditsObject(
      env,
      deviceId,
    );

  const response =
    await object.fetch(
      new Request(
        "https://credits.local/?action=reserve",
        {
          method: "POST",

          headers: {
            "Content-Type":
              "application/json",
          },

          body: JSON.stringify({
            operation,
            requestId,
          }),
        },
      ),
    );

  return response.json();
}

export async function commitCredits(
  env,
  {
    deviceId,
    requestId,
  },
) {
  const object =
    await getCreditsObject(
      env,
      deviceId,
    );

  const response =
    await object.fetch(
      new Request(
        "https://credits.local/?action=commit",
        {
          method: "POST",

          headers: {
            "Content-Type":
              "application/json",
          },

          body: JSON.stringify({
            requestId,
          }),
        },
      ),
    );

  return response.json();
}

export async function releaseCredits(
  env,
  {
    deviceId,
    requestId,
  },
) {
  const object =
    await getCreditsObject(
      env,
      deviceId,
    );

  const response =
    await object.fetch(
      new Request(
        "https://credits.local/?action=release",
        {
          method: "POST",

          headers: {
            "Content-Type":
              "application/json",
          },

          body: JSON.stringify({
            requestId,
          }),
        },
      ),
    );

  return response.json();
}

/* =========================================================
   VERIFIED REWARDED AD HELPER
   ========================================================= */

/*
 * ONLY the verified AdMob SSV handler should call this.
 *
 * The SSV handler must first verify:
 *
 * - Google signature
 * - timestamp
 * - transaction_id
 * - reward_amount
 * - reward_item
 * - custom_data / device ID
 * - optional ad unit
 *
 * After successful verification, this function:
 *
 * - finds the device Durable Object
 * - checks transaction idempotency
 * - checks daily reward limit
 * - adds exactly REWARDED_AD_CREDITS
 * - stores the transaction
 */

export async function rewardVerifiedAd(
  env,
  {
    deviceId,
    transactionId,
    source = "admob_ssv",
  },
) {
  const object =
    await getCreditsObject(
      env,
      deviceId,
    );

  const normalizedTransactionId =
    normalizeTransactionId(
      transactionId,
    );

  if (!normalizedTransactionId) {
    return {
      ok: false,

      error:
        "REWARD_TRANSACTION_ID_REQUIRED",
    };
  }

  const response =
    await object.fetch(
      new Request(
        "https://credits.local/?action=verified-reward",
        {
          method: "POST",

          headers: {
            "Content-Type":
              "application/json",
          },

          body: JSON.stringify({
            transactionId:
              normalizedTransactionId,

            source,
          }),
        },
      ),
    );

  return response.json();
}
