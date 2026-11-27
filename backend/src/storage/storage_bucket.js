
import { createB2S3Client } from "./b2_s3.js";
import {
  commitStorageReservation,
  getStorageObjectRecord,
  releaseDeletedStorageObject,
  releaseStorageReservation,
  reserveStorage,
} from "./storage_quota.js";

async function toBytes(value) {
  if (value instanceof Uint8Array) return value;
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  }
  return new Uint8Array(await new Response(value).arrayBuffer());
}

/**
 * B2-only storage adapter for the Sa7biSocial Durable Object.
 *
 * The adapter deliberately has no R2 fallback. Every readable or deletable
 * object must have a matching B2 record in the Durable Object quota ledger.
 */
export function createStorageBucketAdapter(actor, env) {
  let b2Client = null;

  function getB2Client() {
    if (!b2Client) b2Client = createB2S3Client(env || {});
    return b2Client;
  }

  return {
    async put(objectKey, value, options = {}) {
      const bytes = await toBytes(value);

      // Validate configuration before creating a quota reservation. A local
      // configuration error must not leave a false pending reservation.
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
        // Network/5xx outcomes remain reserved because the PUT may have
        // reached B2 even when the response did not reach this Worker.
        throw error;
      }

      if (typeof stored?.versionId !== "string" || !stored.versionId) {
        // Never report capacity as freed when the PUT may have stored data.
        // Keep the reservation until a safe reconciliation can identify it.
        throw new Error("B2_VERSION_ID_MISSING");
      }

      commitStorageReservation(actor, {
        reservationId: reservation.reservationId,
        objectKey,
        versionId: stored.versionId,
      });

      return {
        versionId: stored.versionId,
        etag: stored.etag || undefined,
      };
    },

    async get(objectKey, options = {}) {
      const record = getStorageObjectRecord(actor, objectKey);
      if (!record) return null;
      if (record.provider !== "b2") {
        throw new Error("STORAGE_PROVIDER_UNSUPPORTED");
      }
      if (record.state !== "stored" || !record.version_id) return null;

      return getB2Client().getObject(objectKey, {
        versionId: record.version_id,
        range: options.range,
        sizeBytes: Number(record.size_bytes) || 0,
      });
    },

    async delete(objectKey) {
      const record = getStorageObjectRecord(actor, objectKey);
      if (!record) throw new Error("STORAGE_OBJECT_NOT_FOUND");
      if (record.provider !== "b2") {
        throw new Error("STORAGE_PROVIDER_UNSUPPORTED");
      }
      if (record.state !== "stored" || !record.version_id) {
        throw new Error("B2_EXACT_VERSION_REQUIRED");
      }

      await getB2Client().deleteObject(objectKey, record.version_id);

      // Quota is released only after B2 confirms deletion of this exact version.
      releaseDeletedStorageObject(actor, {
        objectKey,
        versionId: record.version_id,
      });
    },
  };
}
