import { createClient } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./auth.ts";
import { createLifecycleUserClient } from "./account_lifecycle_client.ts";
import { readBoundedBytes } from "./http.ts";
import { enforceRateLimit } from "./rate_limit.ts";
import { getSupabaseSecretKey, getSupabaseUrl } from "./supabase.ts";

export const mediaBucket = "africlub-product-images";
export const mediaMaximumBytes = 5 * 1024 * 1024;
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const mimeExtensions: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/webp": "webp",
};
const kinds = new Set([
  "shop_product",
  "news_article",
  "home_banner",
  "fan_club",
  "match",
  "squad_player",
  "notification",
]);
const statuses = new Set([
  "pending",
  "uploading",
  "unknown",
  "staged",
  "completed",
  "failed",
]);

export interface MediaUploadCommand {
  operationId: string;
  actorId: string;
  clubId: number;
  kind: string;
  mimeType: string;
  byteLength: number;
  contentSha256: string;
}
export interface MediaUploadReceipt {
  operation_id: string;
  actor_id: string;
  club_id: number;
  kind: string;
  mime_type: string;
  byte_length: number;
  content_sha256: string;
  bucket: string;
  storage_path: string;
  status:
    | "pending"
    | "uploading"
    | "unknown"
    | "staged"
    | "completed"
    | "failed";
  object_id: string | null;
}
export interface MediaReleaseReceipt {
  operation_id: string;
  actor_id: string;
  club_id: number;
  released: true;
}
type RpcResult = {
  data: unknown;
  error: { code?: string; message?: string } | null;
};
export interface MediaUserClient {
  rpc(
    name: string,
    arguments_: Record<string, unknown>,
  ): PromiseLike<RpcResult>;
}
export interface MediaAdminClient extends MediaUserClient {
  storage: {
    from(bucket: string): {
      upload(
        path: string,
        bytes: Uint8Array,
        options: {
          cacheControl: string;
          contentType: string;
          upsert: false;
          metadata: Record<string, string>;
        },
      ): PromiseLike<{ error: unknown }>;
      download(
        path: string,
      ): PromiseLike<
        {
          data: Blob | null;
          error: { status?: number; statusCode?: string | number } | null;
        }
      >;
      info(
        path: string,
      ): PromiseLike<{ data: { id?: string } | null; error: unknown }>;
      getPublicUrl(path: string): { data: { publicUrl: string } };
    };
  };
}

/** Bounds actual RPC, upload acknowledgements and binary object reconciliation. */
export function createMediaUploadAdminClient(): MediaAdminClient {
  const deadline = AbortSignal.timeout(45_000);
  const boundedFetch: typeof fetch = async (input, init = {}) => {
    const signal = AbortSignal.any([
      deadline,
      AbortSignal.timeout(15_000),
      ...(init.signal ? [init.signal] : []),
    ]);
    const response = await fetch(input, { ...init, signal });
    if (!response.body) return response;
    const contentType = response.headers.get("content-type")?.split(";")[0]
      .trim().toLowerCase();
    const bytes = await readBoundedBytes(response, {
      maxBytes: contentType && mimeExtensions[contentType]
        ? mediaMaximumBytes
        : 64 * 1024,
      timeoutMs: 15_000,
      signal,
    });
    const headers = new Headers(response.headers);
    headers.delete("content-length");
    headers.delete("content-encoding");
    return new Response(new Uint8Array(bytes), {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  };
  return createClient(getSupabaseUrl(), getSupabaseSecretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: boundedFetch },
  }) as unknown as MediaAdminClient;
}

export function mediaStoragePath(
  command: Pick<
    MediaUploadCommand,
    "operationId" | "clubId" | "kind" | "mimeType"
  >,
) {
  return `club-${command.clubId}/admin/${command.kind}/${command.operationId}.${
    mimeExtensions[command.mimeType]
  }`;
}
export async function mediaSha256(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return Array.from(
    new Uint8Array(hash),
    (n) => n.toString(16).padStart(2, "0"),
  ).join("");
}

export function validateMediaUploadReceipt(
  value: unknown,
  expected:
    & { operationId: string; actorId: string }
    & Partial<MediaUploadCommand>,
): MediaUploadReceipt {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(502, "Image operation was not confirmed.");
  }
  const r = value as Record<string, unknown>;
  if (
    r.operation_id !== expected.operationId ||
    r.actor_id !== expected.actorId || !uuid.test(String(r.operation_id)) ||
    !uuid.test(String(r.actor_id)) || !Number.isSafeInteger(r.club_id) ||
    Number(r.club_id) <= 0 ||
    typeof r.kind !== "string" || !kinds.has(r.kind) ||
    typeof r.mime_type !== "string" || !mimeExtensions[r.mime_type] ||
    !Number.isSafeInteger(r.byte_length) || Number(r.byte_length) < 1 ||
    Number(r.byte_length) > mediaMaximumBytes ||
    typeof r.content_sha256 !== "string" ||
    !/^[0-9a-f]{64}$/.test(r.content_sha256) ||
    r.bucket !== mediaBucket ||
    r.storage_path !==
      mediaStoragePath({
        operationId: String(r.operation_id),
        clubId: Number(r.club_id),
        kind: r.kind,
        mimeType: r.mime_type,
      }) ||
    typeof r.status !== "string" || !statuses.has(r.status) ||
    (r.object_id !== null && !uuid.test(String(r.object_id))) ||
    (r.status === "completed" && r.object_id === null) ||
    (expected.clubId !== undefined && r.club_id !== expected.clubId) ||
    (expected.kind !== undefined && r.kind !== expected.kind) ||
    (expected.mimeType !== undefined && r.mime_type !== expected.mimeType) ||
    (expected.byteLength !== undefined &&
      r.byte_length !== expected.byteLength) ||
    (expected.contentSha256 !== undefined &&
      r.content_sha256 !== expected.contentSha256)
  ) throw new HttpError(502, "Image operation was not confirmed.");
  // Return the narrow canonical projection, never private lease/proof fields.
  return {
    operation_id: r.operation_id as string,
    actor_id: r.actor_id as string,
    club_id: r.club_id as number,
    kind: r.kind,
    mime_type: r.mime_type,
    byte_length: r.byte_length as number,
    content_sha256: r.content_sha256,
    bucket: mediaBucket,
    storage_path: r.storage_path as string,
    status: r.status as MediaUploadReceipt["status"],
    object_id: r.object_id as string | null,
  };
}
function rpcError(error: RpcResult["error"]) {
  if (error?.code === "42501") {
    throw new HttpError(
      403,
      "Verify your authenticator and current club access.",
    );
  }
  if (error?.code === "22023" || error?.code === "P0001") {
    throw new HttpError(
      409,
      "The original image operation could not be confirmed.",
    );
  }
  if (error) {
    throw new HttpError(
      503,
      "Image operation is unavailable. Keep the original request reference.",
    );
  }
}
export async function getMediaUploadStatus(
  authorization: string,
  operationId: string,
  actorId: string,
  client: MediaUserClient = createLifecycleUserClient(authorization),
) {
  const result = await client.rpc("get_admin_media_upload_status", {
    p_operation_id: operationId,
  });
  rpcError(result.error);
  return result.data === null
    ? null
    : validateMediaUploadReceipt(result.data, { operationId, actorId });
}

/** Releases only a never-admitted UUID; the caller JWT creates the tombstone. */
export async function releaseUnadmittedMediaUpload(
  authorization: string,
  operationId: string,
  actorId: string,
  clubId: number,
  client: MediaUserClient = createLifecycleUserClient(authorization),
): Promise<MediaReleaseReceipt> {
  const result = await client.rpc("release_unadmitted_admin_media_upload", {
    p_operation_id: operationId,
    p_club_id: clubId,
  });
  rpcError(result.error);
  const value = result.data as Record<string, unknown> | null;
  if (
    !value || Array.isArray(value) || value.operation_id !== operationId ||
    value.actor_id !== actorId || value.club_id !== clubId ||
    value.released !== true || !uuid.test(operationId) || !uuid.test(actorId) ||
    !Number.isSafeInteger(clubId) || clubId <= 0
  ) throw new HttpError(502, "Original image release was not confirmed.");
  return {
    operation_id: operationId,
    actor_id: actorId,
    club_id: clubId,
    released: true,
  };
}

export async function executeMediaUpload(
  authorization: string,
  command: MediaUploadCommand,
  bytes: Uint8Array,
  dependencies: {
    createUserClient?: (authorization: string) => MediaUserClient;
    createAdminClient?: () => MediaAdminClient;
    enforceRateLimit?: typeof enforceRateLimit;
    leaseId?: () => string;
  } = {},
): Promise<MediaUploadReceipt> {
  const user = dependencies.createUserClient?.(authorization) ??
    createLifecycleUserClient(authorization);
  const admission = await user.rpc("admit_admin_media_upload", {
    p_operation_id: command.operationId,
    p_club_id: command.clubId,
    p_kind: command.kind,
    p_mime_type: command.mimeType,
    p_byte_length: command.byteLength,
    p_content_sha256: command.contentSha256,
  });
  rpcError(admission.error);
  let receipt = validateMediaUploadReceipt(admission.data, command);
  if (receipt.status === "completed") return receipt;
  // This opaque identifier comes only from the same actual caller-JWT RPC.
  // Current proof renewal cannot authorize a delayed worker or caller flag.
  const dispatchProof = (admission.data as Record<string, unknown>)
    .dispatch_proof_id;
  if (typeof dispatchProof !== "string" || !uuid.test(dispatchProof)) {
    throw new HttpError(502, "Image operation was not confirmed.");
  }
  const admin = dependencies.createAdminClient?.() ??
    createMediaUploadAdminClient();
  await (dependencies.enforceRateLimit ?? enforceRateLimit)(
    admin,
    command.actorId,
    "admin-upload-image",
    { maxRequests: 10, windowSeconds: 3600, clubId: receipt.club_id },
  );
  const lease = dependencies.leaseId?.() ?? crypto.randomUUID();
  const claim = await admin.rpc("claim_admin_media_upload", {
    p_operation_id: command.operationId,
    p_lease_token: lease,
    p_dispatch_proof_id: dispatchProof,
  });
  rpcError(claim.error);
  receipt = validateMediaUploadReceipt(claim.data, command);
  const stage = claim.data as Record<string, unknown>;
  if (
    typeof stage.claimed !== "boolean" ||
    (stage.claimed ? stage.lease_token !== lease : stage.lease_token !== null)
  ) throw new HttpError(502, "Image operation was not confirmed.");
  if (!stage.claimed) return receipt;
  const storage = admin.storage.from(mediaBucket);
  async function record(
    outcome: "stored" | "unknown" | "failed",
    objectId: string | null = null,
  ) {
    try {
      const result = await admin.rpc("complete_admin_media_upload", {
        p_operation_id: command.operationId,
        p_lease_token: lease,
        p_outcome: outcome,
        p_object_id: objectId,
        p_verified_sha256: outcome === "stored" ? command.contentSha256 : null,
      });
      rpcError(result.error);
      return validateMediaUploadReceipt(result.data, command);
    } catch {
      // The durable admission/lease predates HTTP. A missing acknowledgement is
      // still uncertain; it cannot generate a URL or a replacement operation.
      return { ...receipt, status: "unknown" as const };
    }
  }
  async function reconcile() {
    const result = await storage.download(receipt.storage_path);
    if (result.error) {
      const status = Number(result.error.statusCode ?? result.error.status);
      return { status: status === 404 ? "absent" : "unknown" } as const;
    }
    if (
      !result.data || result.data.size !== command.byteLength ||
      result.data.type.split(";")[0] !== command.mimeType ||
      result.data.size > mediaMaximumBytes
    ) return { status: "mismatch" } as const;
    const stored = new Uint8Array(await result.data.arrayBuffer());
    if (await mediaSha256(stored) !== command.contentSha256) {
      return { status: "mismatch" } as const;
    }
    const info = await storage.info(receipt.storage_path);
    if (info.error || !info.data?.id || !uuid.test(info.data.id)) {
      return { status: "unknown" } as const;
    }
    return { status: "stored", objectId: info.data.id } as const;
  }
  try {
    const before = await reconcile();
    if (before.status === "stored") {
      return await record("stored", before.objectId);
    }
    if (before.status === "mismatch") return await record("failed");
    if (before.status === "unknown") return await record("unknown");
    // A lost reservation ACK is uncertain even if no upload was sent. A later
    // worker may reconcile the original object, but never initiate a second
    // remote attempt using the same operation.
    const begun = await admin.rpc("begin_admin_media_upload", {
      p_operation_id: command.operationId,
      p_lease_token: lease,
    });
    rpcError(begun.error);
    const permission = begun.data as Record<string, unknown> | null;
    if (
      !permission || permission.operation_id !== command.operationId ||
      permission.lease_token !== lease ||
      typeof permission.upload_permitted !== "boolean"
    ) throw new HttpError(502, "Image operation was not confirmed.");
    if (!permission.upload_permitted) return await record("unknown");
    // Always the same immutable path. Duplicate/timeout errors are reconciled
    // using actual bytes; neither one alone is evidence of success or failure.
    await storage.upload(receipt.storage_path, bytes, {
      cacheControl: "31536000",
      contentType: command.mimeType,
      upsert: false,
      metadata: {
        operation_id: command.operationId,
        lease_token: lease,
        content_sha256: command.contentSha256,
      },
    });
    const after = await reconcile();
    if (after.status === "stored") {
      return await record("stored", after.objectId);
    }
    return await record(after.status === "mismatch" ? "failed" : "unknown");
  } catch {
    return await record("unknown");
  }
}

export function mediaUploadResponse(
  receipt: MediaUploadReceipt,
): MediaUploadReceipt & { image_url?: string } {
  if (receipt.status !== "completed") return receipt;
  const publicUrl = `${
    getSupabaseUrl().replace(/\/$/, "")
  }/storage/v1/object/public/${mediaBucket}/${receipt.storage_path}`;
  return { ...receipt, image_url: publicUrl };
}
