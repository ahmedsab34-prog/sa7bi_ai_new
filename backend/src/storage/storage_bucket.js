import { createB2S3Client } from "./b2_s3.js";
import {
  commitStorageReservation,
  getStorageObjectRecord,
  releaseDeletedStorageObject,
  releaseStorageReservation,
  reserveStorage,
} from "./storage_quota.js";

function selectedProvider(env) {
  const provider = String(env?.SA7BI_STORAGE_PROVIDER || "r2").trim().toLowerCase();
  if (provider !== "r2" && provider !== "b2") throw new Error("STORAGE_PROVIDER_INVALID");
  return provider;
}

async function toBytes(value) {
  if (value instanceof Uint8Array) return value;
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  }
  return new Uint8Array(await new Response(value).arrayBuffer());
}

export function createStorageBucketAdapter(actor, env) {
  const r2Bucket = env?.SA7BI_REELS || null;
  let b2Client = null;

  function getB2Client() {
    if (!b2Client) b2Client = createB2S3Client(env);
    return b2Client;
  }

  function requireR2() {
    if (!r2Bucket) throw new Error("R2_STORAGE_NOT_CONFIGURED");
    return r2Bucket;
  }

  return {
    async put(objectKey, value, options = {}) {
      if (selectedProvider(env) === "r2") {
        return requireR2().put(objectKey, value, options);
      }

      const bytes = await toBytes(value);
      // Validate B2 credentials/endpoint before reserving quota. A local
      // configuration mistake must not leave a false pending reservation.
      const b2 = getB2Client();
      const reservation = reserveStorage(actor, {
        objectKey,
        sizeBytes: bytes.byteLength,
      });

      let stored;
      try {
        stored = await b2.putObject(objectKey, bytes, options);
      } catch (error) {
        if (error?.definiteFailure === true) {
          releaseStorageReservation(actor, {
            reservationId: reservation.reservationId,
            objectKey,
          });
        }
        // Ambiguous network/5xx outcomes remain reserved so accounting cannot undercount.
        throw error;
      }

      if (!stored.versionId) {
        // Keep the reservation: a successful PUT without its version ID cannot be
        // safely deleted and must never be reported as freed capacity.
        throw new Error("B2_VERSION_ID_MISSING");
      }

      commitStorageReservation(actor, {
        reservationId: reservation.reservationId,
        objectKey,
        versionId: stored.versionId,
      });
      return { versionId: stored.versionId, etag: stored.etag || undefined };
    },

    async get(objectKey, options = {}) {
      const record = getStorageObjectRecord(actor, objectKey);
      if (record?.provider === "b2") {
        if (record.state !== "stored" || !record.version_id) return null;
        return getB2Client().getObject(objectKey, {
          versionId: record.version_id,
          range: options.range,
          sizeBytes: Number(record.size_bytes) || 0,
        });
      }
      return requireR2().get(objectKey, options);
    },

    async delete(objectKey) {
      const record = getStorageObjectRecord(actor, objectKey);
      if (record?.provider === "b2") {
        if (record.state !== "stored" || !record.version_id) {
          throw new Error("B2_EXACT_VERSION_REQUIRED");
        }
        await getB2Client().deleteObject(objectKey, record.version_id);
        // Quota is released only after exact-version deletion is confirmed.
        releaseDeletedStorageObject(actor, {
          objectKey,
          versionId: record.version_id,
        });
        return;
      }
      return requireR2().delete(objectKey);
    },
  };
}
