import { HttpError } from "./auth.ts";
import { createLifecycleUserClient } from "./account_lifecycle_client.ts";
import {
  createMediaUploadAdminClient,
  executeMediaUpload,
  type MediaAdminClient,
  mediaMaximumBytes,
  mediaSha256,
  type MediaUserClient,
} from "./admin_media_upload.ts";
import { fetchBoundedJson } from "./http.ts";
import { getSupabaseUrl } from "./supabase.ts";

export const generationUuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const generationStagingBucket = "africlub-generated-image-staging";
const extensions: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/webp": "webp",
};
const statuses = new Set([
  "pending",
  "generating",
  "unknown",
  "staged",
  "completed",
  "failed",
]);
const kinds = new Set([
  "shop_product",
  "news_article",
  "home_banner",
  "fan_club",
  "match",
  "squad_player",
  "notification",
]);
export type GenerationDomain = "admin_image" | "product_image";
export type GenerationCommand = {
  operationId: string;
  actorId: string;
  clubId: number;
  domain: GenerationDomain;
  kind: string;
  request: Record<string, unknown>;
};
export type GenerationReceipt = {
  operation_id: string;
  actor_id: string;
  club_id: number;
  domain: GenerationDomain;
  kind: string;
  status:
    | "pending"
    | "generating"
    | "unknown"
    | "staged"
    | "completed"
    | "failed";
  request: Record<string, unknown>;
  target_conflict: boolean;
  image_url?: string;
  storage_path?: string;
  prompt_used?: string;
  model?: string;
  aspect_ratio?: string;
  club?: string;
  success?: true;
  product_type?: string | null;
};
export type GenerationProviderContext = {
  model: string;
  public_origin: string;
  prompt_used: string;
  aspect_ratio: string;
};
export type GenerationDependencies = {
  createUserClient?: (authorization: string) => MediaUserClient;
  createAdminClient?: () => MediaAdminClient;
  executeMediaUpload?: typeof executeMediaUpload;
  fetch?: typeof fetch;
  leaseId?: () => string;
};
function canonical(value: unknown): string {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return JSON.stringify(
      Object.fromEntries(
        Object.entries(value as Record<string, unknown>).sort(([a], [b]) =>
          a.localeCompare(b)
        ),
      ),
    );
  }
  return JSON.stringify(value);
}
function rpcError(error: { code?: string; message?: string } | null) {
  if (!error) return;
  if (error.code === "42501") {
    throw new HttpError(
      403,
      "Verify your authenticator and current club access.",
    );
  }
  if (error.code === "22023") {
    throw new HttpError(
      409,
      "Keep the original image request and check its status.",
    );
  }
  throw new HttpError(
    503,
    "Image operation is unavailable. Keep the original request reference.",
  );
}
export function validateGenerationReceipt(
  value: unknown,
  expected: Partial<GenerationCommand> & {
    operationId: string;
    actorId: string;
  },
): GenerationReceipt {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(502, "Image operation was not confirmed.");
  }
  const r = value as Record<string, unknown>;
  if (
    r.operation_id !== expected.operationId ||
    r.actor_id !== expected.actorId ||
    !generationUuid.test(String(r.operation_id)) ||
    !generationUuid.test(String(r.actor_id)) ||
    !Number.isSafeInteger(r.club_id) || Number(r.club_id) <= 0 ||
    !["admin_image", "product_image"].includes(String(r.domain)) ||
    !kinds.has(String(r.kind)) || !statuses.has(String(r.status)) ||
    typeof r.target_conflict !== "boolean" || !r.request ||
    typeof r.request !== "object" || Array.isArray(r.request) ||
    (expected.clubId !== undefined && r.club_id !== expected.clubId) ||
    (expected.domain !== undefined && r.domain !== expected.domain) ||
    (expected.kind !== undefined && r.kind !== expected.kind) ||
    (expected.request !== undefined &&
      canonical(r.request) !== canonical(expected.request))
  ) {
    throw new HttpError(502, "Image operation was not confirmed.");
  }
  const result: GenerationReceipt = {
    operation_id: String(r.operation_id),
    actor_id: String(r.actor_id),
    club_id: Number(r.club_id),
    domain: r.domain as GenerationDomain,
    kind: String(r.kind),
    status: r.status as GenerationReceipt["status"],
    request: r.request as Record<string, unknown>,
    target_conflict: r.target_conflict,
  };
  if (result.status === "completed") {
    const pattern = new RegExp(
      `^club-${result.club_id}/admin/${result.kind}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.(png|jpg|webp)$`,
    );
    if (
      typeof r.storage_path !== "string" || !pattern.test(r.storage_path) ||
      r.image_url !==
        `${
          getSupabaseUrl().replace(/\/$/, "")
        }/storage/v1/object/public/africlub-product-images/${r.storage_path}` ||
      typeof r.prompt_used !== "string" || r.prompt_used.length < 1 ||
      r.prompt_used.length > 20000 ||
      typeof r.model !== "string" || !/^[a-zA-Z0-9._-]{1,120}$/.test(r.model) ||
      typeof r.aspect_ratio !== "string" || typeof r.club !== "string"
    ) throw new HttpError(502, "Image operation was not confirmed.");
    Object.assign(result, {
      image_url: r.image_url,
      storage_path: r.storage_path,
      prompt_used: r.prompt_used,
      model: r.model,
      aspect_ratio: r.aspect_ratio,
      club: r.club,
      success: true,
      product_type: result.domain === "product_image"
        ? String(result.request.productType)
        : null,
    });
  }
  return result;
}
export async function getImageGenerationStatus(
  authorization: string,
  operationId: string,
  actorId: string,
  clubId: number,
  domain: GenerationDomain,
  client: MediaUserClient = createLifecycleUserClient(authorization),
) {
  const result = await client.rpc("get_admin_image_generation_status", {
    p_operation_id: operationId,
    p_club_id: clubId,
  });
  rpcError(result.error);
  return result.data === null ? null : validateGenerationReceipt(result.data, {
    operationId,
    actorId,
    clubId,
    domain,
  });
}
function validImage(bytes: Uint8Array, mime: string) {
  if (mime === "image/png") {
    return bytes.length >= 8 &&
      [137, 80, 78, 71, 13, 10, 26, 10].every((n, i) => bytes[i] === n);
  }
  if (mime === "image/jpeg") {
    return bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 &&
      bytes[2] === 255;
  }
  return mime === "image/webp" && bytes.length >= 12 &&
    new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
    new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP";
}
export function decodeGeneratedImage(value: unknown) {
  const body = value as {
    candidates?: Array<
      { content?: { parts?: Array<Record<string, unknown>> } }
    >;
  };
  const part = body?.candidates?.[0]?.content?.parts?.find((p) =>
    p.inlineData || p.inline_data
  );
  const inline = (part?.inlineData ?? part?.inline_data) as
    | Record<string, unknown>
    | undefined;
  const data = inline?.data;
  const mime = inline?.mimeType ?? inline?.mime_type;
  if (
    typeof data !== "string" || data.length === 0 ||
    data.length > Math.ceil(mediaMaximumBytes / 3) * 4 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(data) || typeof mime !== "string" ||
    !extensions[mime]
  ) throw new HttpError(502, "Provider image was invalid.");
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
  } catch {
    throw new HttpError(502, "Provider image was invalid.");
  }
  if (
    !bytes.length || bytes.length > mediaMaximumBytes ||
    !validImage(bytes, mime)
  ) throw new HttpError(502, "Provider image was invalid.");
  return { bytes, mime };
}

/** Original provider_started is committed before HTTP; no exception repeats it. */
export async function executeImageGeneration(
  authorization: string,
  command: GenerationCommand,
  contextFor: (brand: Record<string, unknown>) => GenerationProviderContext,
  apiKey: string,
  dependencies: GenerationDependencies = {},
): Promise<GenerationReceipt> {
  const user = dependencies.createUserClient?.(authorization) ??
    createLifecycleUserClient(authorization);
  const admission = await user.rpc("admit_admin_image_generation", {
    p_operation_id: command.operationId,
    p_club_id: command.clubId,
    p_domain: command.domain,
    p_request: command.request,
  });
  rpcError(admission.error);
  let receipt = validateGenerationReceipt(admission.data, command);
  if (receipt.status === "completed") return receipt;
  const admitted = admission.data as Record<string, unknown>;
  if (
    !generationUuid.test(String(admitted.dispatch_proof_id)) ||
    !admitted.brand_snapshot || typeof admitted.brand_snapshot !== "object" ||
    Array.isArray(admitted.brand_snapshot)
  ) {
    throw new HttpError(502, "Image operation was not confirmed.");
  }
  const context = contextFor(
    admitted.brand_snapshot as Record<string, unknown>,
  );
  const lease = dependencies.leaseId?.() ?? crypto.randomUUID();
  let admin = dependencies.createAdminClient?.() ??
    createMediaUploadAdminClient();
  let claim: Record<string, unknown>;
  try {
    const result = await admin.rpc("claim_admin_image_generation", {
      p_operation_id: command.operationId,
      p_lease_token: lease,
      p_dispatch_proof_id: admitted.dispatch_proof_id,
      p_provider_context: context,
    });
    rpcError(result.error);
    receipt = validateGenerationReceipt(result.data, command);
    claim = result.data as Record<string, unknown>;
  } catch (error) {
    if (error instanceof HttpError && [403, 409].includes(error.status)) {
      throw error;
    }
    return { ...receipt, status: "unknown" };
  }
  if (
    Number.isSafeInteger(claim.retry_after_seconds) &&
    Number(claim.retry_after_seconds) > 0
  ) {
    throw new HttpError(429, "Please wait before generating another image.", {
      "Retry-After": String(claim.retry_after_seconds),
    });
  }
  if (
    typeof claim.claimed !== "boolean" ||
    typeof claim.reconcile !== "boolean" || (claim.claimed && claim.reconcile)
  ) throw new HttpError(502, "Image operation was not confirmed.");
  if (!claim.claimed && !claim.reconcile) return receipt;
  if (
    claim.lease_token !== lease ||
    !generationUuid.test(String(claim.public_upload_id))
  ) throw new HttpError(502, "Image operation was not confirmed.");
  const provider = claim.provider_context as GenerationProviderContext;
  if (!provider || canonical(provider) !== canonical(context)) {
    // A recovered command uses the frozen provider context, never a changed
    // model/brand/prompt from a later runtime. It cannot generate again.
    if (
      claim.claimed || !provider ||
      provider.public_origin !== getSupabaseUrl().replace(/\/$/, "")
    ) throw new HttpError(502, "Image operation was not confirmed.");
  }
  let bytes: Uint8Array;
  let mime: string;
  let sha: string;
  let path: string;
  async function record(outcome: string, objectId: string | null = null) {
    const result = await admin.rpc("record_admin_image_generation_result", {
      p_operation_id: command.operationId,
      p_lease_token: lease,
      p_outcome: outcome,
      p_object_id: objectId,
      p_content_sha256: sha ?? null,
      p_mime_type: mime ?? null,
      p_byte_length: bytes?.length ?? null,
    });
    rpcError(result.error);
    return validateGenerationReceipt(result.data, command);
  }
  async function uncertain(outcome: "unknown" | "failed") {
    try {
      return await record(outcome);
    } catch {
      return { ...receipt, status: outcome };
    }
  }
  if (claim.claimed) {
    let response: unknown;
    try {
      response = await fetchBoundedJson(
        dependencies.fetch ?? fetch,
        `https://generativelanguage.googleapis.com/v1beta/models/${provider.model}:generateContent`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            contents: [{
              role: "user",
              parts: [{ text: provider.prompt_used }],
            }],
            generationConfig: {
              candidateCount: 1,
              responseModalities: ["IMAGE", "TEXT"],
              imageConfig: { aspectRatio: provider.aspect_ratio },
            },
          }),
        },
        { maxBytes: 8 * 1024 * 1024, timeoutMs: 45000 },
      );
    } catch {
      admin = dependencies.createAdminClient?.() ??
        createMediaUploadAdminClient();
      return await uncertain("unknown");
    }
    // Instantiate the bounded SDK phase after Google; its own deadline must not
    // expire merely because the provider consumed its separate 45s allowance.
    admin = dependencies.createAdminClient?.() ??
      createMediaUploadAdminClient();
    try {
      const image = decodeGeneratedImage(response);
      bytes = image.bytes;
      mime = image.mime;
    } catch {
      return await uncertain("failed");
    }
    sha = await mediaSha256(bytes);
    path = `club-${command.clubId}/${command.operationId}.${extensions[mime]}`;
    try {
      receipt = await record("prepared");
    } catch {
      return { ...receipt, status: "unknown" };
    }
  } else {
    mime = String(claim.mime_type);
    sha = String(claim.content_sha256);
    path = String(claim.staging_path);
    if (
      !extensions[mime] || !/^[0-9a-f]{64}$/.test(sha) ||
      path !==
        `club-${command.clubId}/${command.operationId}.${extensions[mime]}` ||
      !Number.isSafeInteger(claim.byte_length) ||
      Number(claim.byte_length) <= 0 ||
      Number(claim.byte_length) > mediaMaximumBytes
    ) throw new HttpError(502, "Image operation was not confirmed.");
    bytes = new Uint8Array();
  }
  const storage = admin.storage.from(generationStagingBucket);
  async function readback() {
    const result = await storage.download(path);
    if (result.error) {
      return {
        status: Number(result.error.statusCode ?? result.error.status) === 404
          ? "absent"
          : "unknown",
      } as const;
    }
    const size = claim.claimed ? bytes.length : Number(claim.byte_length);
    if (
      !result.data || result.data.size !== size ||
      result.data.size > mediaMaximumBytes ||
      result.data.type.split(";")[0] !== mime
    ) return { status: "mismatch" } as const;
    const actual = new Uint8Array(await result.data.arrayBuffer());
    if (!validImage(actual, mime) || await mediaSha256(actual) !== sha) {
      return { status: "mismatch" } as const;
    }
    const info = await storage.info(path);
    if (info.error || !generationUuid.test(String(info.data?.id))) {
      return { status: "unknown" } as const;
    }
    return {
      status: "stored",
      bytes: actual,
      id: String(info.data!.id),
    } as const;
  }
  try {
    let actual = await readback();
    if (actual.status === "absent" && claim.claimed) {
      try {
        await storage.upload(path, bytes, {
          cacheControl: "0",
          contentType: mime,
          upsert: false,
          metadata: {
            operation_id: command.operationId,
            lease_token: lease,
            content_sha256: sha,
          },
        });
      } catch {
        /* Reconcile actual object, including a lost acknowledgement. */
      }
      actual = await readback();
    }
    if (actual.status !== "stored") {
      return await uncertain(
        actual.status === "mismatch" ? "failed" : "unknown",
      );
    }
    bytes = actual.bytes;
    receipt = await record("stored", actual.id);
  } catch {
    return await uncertain("unknown");
  }
  try {
    const publicationClient = (): MediaAdminClient => {
      const original = dependencies.createAdminClient?.() ??
        createMediaUploadAdminClient();
      return {
        rpc: (name, args) => original.rpc(name, args),
        storage: {
          from: (bucket) => {
            const storage = original.storage.from(bucket);
            return {
              ...storage,
              // SQL28 independently checks the exact original admission proof
              // after Storage waits. SQL27's current proof cannot renew this
              // delayed generation worker. No private metadata enters a reply.
              upload: (path, data, options) =>
                storage.upload(path, data, {
                  ...options,
                  metadata: {
                    ...options.metadata,
                    generation_operation_id: command.operationId,
                    generation_lease_token: lease,
                    generation_proof_id: String(admitted.dispatch_proof_id),
                  },
                }),
              download: (path) => storage.download(path),
              info: (path) => storage.info(path),
              getPublicUrl: (path) => storage.getPublicUrl(path),
            };
          },
        },
      };
    };
    const publicUpload =
      await (dependencies.executeMediaUpload ?? executeMediaUpload)(
        authorization,
        {
          operationId: String(claim.public_upload_id),
          actorId: command.actorId,
          clubId: command.clubId,
          kind: command.kind,
          mimeType: mime,
          byteLength: bytes.length,
          contentSha256: sha,
        },
        bytes,
        {
          createUserClient: dependencies.createUserClient,
          createAdminClient: publicationClient,
        },
      );
    if (publicUpload.status !== "completed") {
      return { ...receipt, status: "staged" };
    }
    const result = await user.rpc("commit_admin_image_generation", {
      p_operation_id: command.operationId,
      p_club_id: command.clubId,
    });
    rpcError(result.error);
    return validateGenerationReceipt(result.data, command);
  } catch {
    return { ...receipt, status: "staged" };
  }
}
