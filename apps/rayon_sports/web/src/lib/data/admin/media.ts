import { acknowledgeStaffCommand, readPendingStaffCommand, retainStaffCommand, staffCommandSha256, withStaffCommandJournal, type StaffCommandReference } from "./staff-command-journal";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { acknowledgeAdminUpload, acknowledgeAdminUploadRelease, retainAdminUpload, withAdminUploadJournal, withAdminUploadReleaseJournal,
  type AdminUploadJournalEntry } from "./media-upload-journal";
export { readPendingAdminUpload, AdminUploadLegacyReferenceError } from "./media-upload-journal";
export type { AdminUploadJournalEntry } from "./media-upload-journal";

export const adminMediaBucket = "africlub-product-images";
export const adminMediaMaxFileBytes = 5 * 1024 * 1024;

const allowedMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

export type AdminMediaKind =
  | "shop_product"
  | "news_article"
  | "home_banner"
  | "fan_club"
  | "match"
  | "squad_player"
  | "notification";

export interface UploadedAdminImage {
  publicUrl: string;
  storagePath: string;
}

export interface GeneratedAdminImage extends UploadedAdminImage {
  model: string;
  promptUsed: string;
  aspectRatio: string;
}

export function defaultAspectRatioForAdminMediaKind(
  kind: AdminMediaKind,
): string {
  switch (kind) {
    case "shop_product":
      return "1:1";
    case "squad_player":
      return "3:4";
    case "news_article":
    case "home_banner":
    case "fan_club":
    case "match":
    case "notification":
      return "16:9";
  }
}

function resolveExtension(fileName: string, mimeType: string) {
  // The admitted MIME controls the deterministic path, never a filename suffix.
  void fileName;
  if (mimeType === "image/png") {
    return "png";
  }
  if (mimeType === "image/webp") {
    return "webp";
  }
  return "jpg";
}

function requireAdminClubId(access: Pick<AdminAccess, "clubId">) {
  const clubId = Number.parseInt(access.clubId ?? "", 10);
  if (!Number.isInteger(clubId) || clubId <= 0) {
    throw new Error("Choose a club scope before managing images.");
  }
  return clubId;
}

function validateImageFile(file: File) {
  if (!allowedMimeTypes.has(file.type)) {
    throw new Error("Upload a JPG, PNG, or WEBP image.");
  }
  if (file.size <= 0) {
    throw new Error("Choose a non-empty image file.");
  }
  if (file.size > adminMediaMaxFileBytes) {
    throw new Error("Images must be 5MB or smaller.");
  }
}
function validateImageBytes(bytes: Uint8Array, mimeType: string) {
  const matches = mimeType === "image/png"
    ? bytes.length >= 8 && [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((byte, i) => bytes[i] === byte)
    : mimeType === "image/jpeg"
      ? bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff
      : bytes.length >= 12 && new TextDecoder().decode(bytes.subarray(0, 4)) === "RIFF"
        && new TextDecoder().decode(bytes.subarray(8, 12)) === "WEBP";
  if (!matches) throw new Error("The image bytes do not match its JPG, PNG, or WEBP file type.");
}

export function buildAdminMediaStoragePath(options: {
  clubId: number;
  clubSlug?: string | null;
  kind: AdminMediaKind;
  fileName: string;
  mimeType: string;
  operationId: string;
}) {
  if (!Number.isSafeInteger(options.clubId) || options.clubId <= 0 || !allowedMimeTypes.has(options.mimeType)
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(options.operationId)) {
    throw new Error("The original upload binding is invalid.");
  }
  const folder = `club-${options.clubId}`;
  const extension = resolveExtension(options.fileName, options.mimeType);
  return `${folder}/admin/${options.kind}/${options.operationId}.${extension}`;
}

export type AdminImageUploadStatus = "pending" | "uploading" | "unknown" | "staged" | "completed" | "failed";
interface AdminImageUploadReceiptBase {
  operationId: string; actorId: string; clubId: number; kind: AdminMediaKind;
  mimeType: string; byteLength: number; contentSha256: string; bucket: string; storagePath: string;
}
export type AdminImageUploadReceipt = AdminImageUploadReceiptBase &
  ({ status: "completed"; publicUrl: string } | { status: Exclude<AdminImageUploadStatus, "completed">; publicUrl?: never });
export class AdminImageUploadPendingError extends Error {
  readonly code = "ADMIN_UPLOAD_UNCONFIRMED";
  constructor(readonly operationId: string, readonly status: AdminImageUploadStatus | null,
    readonly receipt: AdminImageUploadReceipt | null = null,
    message = "The original upload is not confirmed. Check its status or reselect the same file to retry its saved reference.") {
    super(message); this.name = "AdminImageUploadPendingError";
  }
}
type CurrentUploadOptions = { isCurrent?: () => boolean };
export type ScopedAdminUploadOptions = CurrentUploadOptions & { scopeKey: string };
export interface ReleasedAdminImageUpload {
  operationId: string;
  actorId: string;
  clubId: number;
  released: true;
}
function requireUploadAccess(access: AdminAccess, options: CurrentUploadOptions) {
  const clubId = requireAdminClubId(access);
  if (options.isCurrent?.() === false || !access.hasAccess || !access.isAuthenticated || !access.userId
    || !["admin", "super_admin", "club_admin", "club_moderator"].includes(access.role ?? "")
    || (!access.isSuperAdmin && !access.availableClubIds.includes(String(clubId)))) {
    throw new Error("Current staff permission is required before continuing this upload.");
  }
  return clubId;
}
async function verifyUploadOwner(client: SupabaseClient, access: AdminAccess, options: CurrentUploadOptions) {
  requireUploadAccess(access, options);
  const session = await client.auth.getSession();
  requireUploadAccess(access, options);
  if (session.error || !session.data.session || session.data.session.user.id !== access.userId) {
    throw new Error("The current verified account no longer owns this upload.");
  }
  // Session is only a transient token source. Provider getUser verifies this
  // exact token; pin it on invoke so the SDK cannot replace the caller midflight.
  const token = session.data.session.access_token;
  const { data, error } = await client.auth.getUser(token);
  requireUploadAccess(access, options);
  if (error || !data.user || data.user.id !== access.userId) throw new Error("The current verified account no longer owns this upload.");
  return token;
}
function parseUploadReceipt(client: SupabaseClient, value: unknown, entry: AdminUploadJournalEntry): AdminImageUploadReceipt {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Upload acknowledgement is invalid.");
  const r = value as Record<string, unknown>;
  const storagePath = buildAdminMediaStoragePath({ clubId: Number(entry.clubId), kind: entry.kind,
    fileName: "", mimeType: entry.mimeType, operationId: entry.operationId });
  if (r.operation_id !== entry.operationId || r.actor_id !== entry.userId || r.club_id !== Number(entry.clubId)
    || r.kind !== entry.kind || r.mime_type !== entry.mimeType || r.byte_length !== entry.byteLength
    || r.content_sha256 !== entry.contentSha256 || r.bucket !== adminMediaBucket || r.storage_path !== storagePath
    || !["pending", "uploading", "unknown", "staged", "completed", "failed"].includes(String(r.status))) {
    throw new Error("Upload acknowledgement does not match the original account, club and file.");
  }
  const base = { operationId: entry.operationId, actorId: entry.userId, clubId: Number(entry.clubId), kind: entry.kind,
    mimeType: entry.mimeType, byteLength: entry.byteLength, contentSha256: entry.contentSha256, bucket: adminMediaBucket, storagePath };
  if (r.status === "completed") {
    const publicUrl = client.storage.from(adminMediaBucket).getPublicUrl(storagePath).data.publicUrl;
    if (r.image_url !== publicUrl) throw new Error("Upload URL does not match the configured Storage object.");
    return { ...base, status: "completed", publicUrl };
  }
  if (r.image_url != null) throw new Error("An unconfirmed upload cannot expose an image URL.");
  return { ...base, status: r.status as Exclude<AdminImageUploadStatus, "completed"> };
}
async function statusForEntry(client: SupabaseClient, access: AdminAccess, entry: AdminUploadJournalEntry, options: CurrentUploadOptions) {
  const token = await verifyUploadOwner(client, access, options);
  requireUploadAccess(access, options);
  const { data, error } = await client.functions.invoke<unknown>("admin-upload-image", {
    headers: { Authorization: `Bearer ${token}` }, body: { operation_id: entry.operationId, mode: "status" } });
  await verifyUploadOwner(client, access, options);
  if (error) {
    if (error.context instanceof Response && error.context.status === 404) return null;
    throw new AdminImageUploadPendingError(entry.operationId, null);
  }
  try { return parseUploadReceipt(client, data, entry); }
  catch { throw new AdminImageUploadPendingError(entry.operationId, null, null, "The original upload acknowledgement could not be verified. Its saved reference remains pending."); }
}
export async function checkAdminImageUploadStatus(client: SupabaseClient, access: AdminAccess, kind: AdminMediaKind,
  options: ScopedAdminUploadOptions): Promise<AdminImageUploadReceipt | null> {
  requireUploadAccess(access, options);
  return withAdminUploadJournal(access, kind, options.scopeKey, async entry => {
    if (!entry) return null;
    const receipt = await statusForEntry(client, access, entry, options);
    requireUploadAccess(access, options);
    if (receipt?.status === "completed") acknowledgeAdminUpload(entry, receipt);
    return receipt;
  });
}
export async function releaseUnadmittedAdminImageUpload(client: SupabaseClient, access: AdminAccess, kind: AdminMediaKind,
  options: ScopedAdminUploadOptions): Promise<ReleasedAdminImageUpload | null> {
  requireUploadAccess(access, options);
  return withAdminUploadReleaseJournal(access, kind, options.scopeKey, async entry => {
    if (!entry) return null;
    const token = await verifyUploadOwner(client, access, options);
    requireUploadAccess(access, options);
    const { data, error } = await client.functions.invoke<unknown>("admin-upload-image", {
      headers: { Authorization: `Bearer ${token}` },
      body: { operation_id: entry.operationId, club_id: Number(entry.clubId), mode: "release" },
    });
    await verifyUploadOwner(client, access, options);
    if (error) throw new AdminImageUploadPendingError(entry.operationId, null, null,
      "The unused-reference release is not confirmed. Its original reference remains saved.");
    const receipt = data as Record<string, unknown> | null;
    if (!receipt || typeof receipt !== "object" || Array.isArray(receipt)
      || Object.keys(receipt).sort().join(",") !== "actor_id,club_id,operation_id,released"
      || receipt.operation_id !== entry.operationId || receipt.actor_id !== entry.userId
      || receipt.club_id !== Number(entry.clubId) || receipt.released !== true) {
      throw new AdminImageUploadPendingError(entry.operationId, null, null,
        "The unused-reference release acknowledgement could not be verified. Its original reference remains saved.");
    }
    requireUploadAccess(access, options);
    acknowledgeAdminUploadRelease(entry);
    return { operationId: entry.operationId, actorId: entry.userId, clubId: Number(entry.clubId), released: true };
  });
}

export async function uploadAdminImage(
  client: SupabaseClient,
  access: AdminAccess,
  options: {
    file: File;
    kind: AdminMediaKind;
    clubSlug?: string | null;
    isCurrent?: () => boolean;
    scopeKey: string;
  },
): Promise<UploadedAdminImage> {
  const clubId = requireUploadAccess(access, options);
  validateImageFile(options.file);
  const bytes = new Uint8Array(await options.file.arrayBuffer());
  if (bytes.length !== options.file.size) throw new Error("The selected image length changed.");
  validateImageBytes(bytes, options.file.type);
  const contentSha256 = [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))].map(b => b.toString(16).padStart(2, "0")).join("");
  requireUploadAccess(access, options);
  return withAdminUploadJournal(access, options.kind, options.scopeKey, async (prior, scopeHash) => {
    await verifyUploadOwner(client, access, options);
    const entry = retainAdminUpload(access, options.kind, scopeHash, { mimeType: options.file.type, byteLength: bytes.length, contentSha256 });
    try {
      if (prior) {
        const recovered = await statusForEntry(client, access, entry, options);
        if (recovered?.status === "completed") {
          requireUploadAccess(access, options); acknowledgeAdminUpload(entry, recovered); return recovered;
        }
      }
      let binary = "";
      for (let offset = 0; offset < bytes.length; offset += 0x8000) binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
      const token = await verifyUploadOwner(client, access, options);
      requireUploadAccess(access, options);
      const { data, error } = await client.functions.invoke<unknown>("admin-upload-image", { headers: { Authorization: `Bearer ${token}` }, body: {
        operation_id: entry.operationId, club_id: clubId, kind: options.kind, mime_type: entry.mimeType, image_data_base64: btoa(binary),
      } });
      await verifyUploadOwner(client, access, options);
      if (error) throw new AdminImageUploadPendingError(entry.operationId, null);
      const receipt = parseUploadReceipt(client, data, entry);
      if (receipt.status !== "completed") throw new AdminImageUploadPendingError(entry.operationId, receipt.status, receipt);
      requireUploadAccess(access, options); acknowledgeAdminUpload(entry, receipt);
      return { publicUrl: receipt.publicUrl, storagePath: receipt.storagePath };
    } catch (error) {
      if (error instanceof AdminImageUploadPendingError) throw error;
      throw new AdminImageUploadPendingError(entry.operationId, null, null,
        error instanceof Error ? error.message : "The original upload remains pending.");
    }
  });
}

type GenerationRequest = { kind: AdminMediaKind; prompt: string; subject: string | null; aspectRatio: string };
export interface AdminImageGenerationReceipt {
  operationId: string; status: "pending" | "generating" | "unknown" | "staged" | "completed" | "failed";
  request: GenerationRequest; image: GeneratedAdminImage | null;
}
export class AdminImageGenerationPendingError extends Error {
  constructor(readonly operationId: string, message = "The original image generation is unconfirmed. Keep its reference and check status before generating another image.") {
    super(message); this.name = "AdminImageGenerationPendingError";
  }
}
const generationRatios = new Set(["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9"]);
function canonicalGenerationRequest(request: GenerationRequest) {
  return JSON.stringify(Object.fromEntries(Object.keys(request).sort().map(key => [key, request[key as keyof GenerationRequest]])));
}
function normalizeGenerationRequest(options: { kind: AdminMediaKind; prompt: string; subject?: string | null; aspectRatio?: string }): GenerationRequest {
  const prompt = options.prompt.trim(), subject = options.subject?.trim() || null;
  if (!prompt || prompt.length > 4000 || (subject?.length ?? 0) > 500) throw new Error("Enter a prompt of up to 4,000 characters and a subject of up to 500 characters.");
  return { kind: options.kind, prompt, subject,
    aspectRatio: generationRatios.has(options.aspectRatio ?? "") ? options.aspectRatio! : defaultAspectRatioForAdminMediaKind(options.kind) };
}
async function generationDomain(kind: AdminMediaKind, scopeKey: string) {
  if (!scopeKey || scopeKey.length > 16384) throw new Error("A bounded record scope is required before generating an image.");
  return `image-generation:${kind}:${await staffCommandSha256(scopeKey)}`;
}
export async function readPendingAdminGeneration(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind, scopeKey: string) {
  return readPendingStaffCommand(access, await generationDomain(kind, scopeKey));
}
async function parseGenerationReceipt(client: SupabaseClient, raw: unknown, entry: StaffCommandReference, kind: AdminMediaKind): Promise<AdminImageGenerationReceipt> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("Image generation acknowledgement is invalid.");
  const r = raw as Record<string, unknown>, request = r.request as GenerationRequest;
  if (r.operation_id !== entry.operationId || r.actor_id !== entry.userId || r.club_id !== Number(entry.clubId)
    || r.domain !== "admin_image" || r.kind !== kind || r.target_conflict !== false
    || !["pending", "generating", "unknown", "staged", "completed", "failed"].includes(String(r.status))
    || !request || Object.keys(request).sort().join(",") !== "aspectRatio,kind,prompt,subject"
    || request.kind !== kind || typeof request.prompt !== "string" || !(request.subject === null || typeof request.subject === "string")
    || typeof request.aspectRatio !== "string" || !generationRatios.has(request.aspectRatio)
    || await staffCommandSha256(canonicalGenerationRequest(request)) !== entry.argumentsSha256) {
    throw new Error("Image acknowledgement does not match the original account, club, record and prompt.");
  }
  const status = r.status as AdminImageGenerationReceipt["status"];
  if (status !== "completed") {
    if (r.image_url != null || r.storage_path != null) throw new Error("Unconfirmed generation cannot expose an image.");
    return { operationId: entry.operationId, status, request, image: null };
  }
  const pathPattern = new RegExp(`^club-${entry.clubId}/admin/${kind}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.(png|jpg|webp)$`);
  if (typeof r.storage_path !== "string" || !pathPattern.test(r.storage_path)
    || r.image_url !== client.storage.from(adminMediaBucket).getPublicUrl(r.storage_path).data.publicUrl
    || typeof r.prompt_used !== "string" || r.prompt_used.length < 1 || r.prompt_used.length > 20000
    || typeof r.model !== "string" || !/^[a-zA-Z0-9._-]{1,120}$/.test(r.model) || r.aspect_ratio !== request.aspectRatio
    || r.success !== true) throw new Error("Completed image acknowledgement is invalid.");
  return { operationId: entry.operationId, status, request, image: { publicUrl: String(r.image_url), storagePath: r.storage_path,
    promptUsed: r.prompt_used, model: r.model, aspectRatio: request.aspectRatio } };
}
async function generationStatusForEntry(client: SupabaseClient, access: AdminAccess, entry: StaffCommandReference, kind: AdminMediaKind, options: CurrentUploadOptions) {
  const token = await verifyUploadOwner(client, access, options);
  const result = await client.functions.invoke<unknown>("generate-admin-image", { headers: { Authorization: `Bearer ${token}` },
    body: { mode: "status", operation_id: entry.operationId, clubId: Number(entry.clubId) } });
  await verifyUploadOwner(client, access, options);
  if (result.error) {
    if (result.error.context instanceof Response && result.error.context.status === 404) return null;
    throw new AdminImageGenerationPendingError(entry.operationId);
  }
  return parseGenerationReceipt(client, result.data, entry, kind);
}
export async function checkAdminImageGenerationStatus(client: SupabaseClient, access: AdminAccess, kind: AdminMediaKind,
  options: ScopedAdminUploadOptions): Promise<AdminImageGenerationReceipt | null> {
  requireUploadAccess(access, options);
  return withStaffCommandJournal(access, await generationDomain(kind, options.scopeKey), async entry => {
    if (!entry) return null;
    const receipt = await generationStatusForEntry(client, access, entry, kind, options);
    requireUploadAccess(access, options);
    if (receipt?.status === "completed") acknowledgeStaffCommand(entry, { state: "completed" });
    return receipt;
  });
}
export async function generateAdminImage(client: SupabaseClient, access: AdminAccess,
  options: { kind: AdminMediaKind; prompt: string; subject?: string | null; aspectRatio?: string } & ScopedAdminUploadOptions): Promise<GeneratedAdminImage> {
  requireUploadAccess(access, options);
  const request = normalizeGenerationRequest(options);
  const argumentsSha256 = await staffCommandSha256(canonicalGenerationRequest(request));
  requireUploadAccess(access, options);
  return withStaffCommandJournal(access, await generationDomain(options.kind, options.scopeKey), async prior => {
    await verifyUploadOwner(client, access, options);
    const entry = retainStaffCommand(access, await generationDomain(options.kind, options.scopeKey), argumentsSha256);
    try {
      if (prior) {
        const recovered = await generationStatusForEntry(client, access, entry, options.kind, options);
        if (recovered?.status === "completed" && recovered.image) {
          requireUploadAccess(access, options); acknowledgeStaffCommand(entry, { state: "completed" }); return recovered.image;
        }
        if (recovered && !["pending", "staged"].includes(recovered.status)) throw new AdminImageGenerationPendingError(entry.operationId);
      }
      const token = await verifyUploadOwner(client, access, options);
      const result = await client.functions.invoke<unknown>("generate-admin-image", { headers: { Authorization: `Bearer ${token}` },
        body: { operation_id: entry.operationId, clubId: Number(entry.clubId), ...request } });
      await verifyUploadOwner(client, access, options);
      if (result.error) throw new AdminImageGenerationPendingError(entry.operationId);
      const receipt = await parseGenerationReceipt(client, result.data, entry, options.kind);
      requireUploadAccess(access, options);
      if (receipt.status !== "completed" || !receipt.image) throw new AdminImageGenerationPendingError(entry.operationId);
      acknowledgeStaffCommand(entry, { state: "completed" }); return receipt.image;
    } catch (caught) {
      if (caught instanceof AdminImageGenerationPendingError) throw caught;
      throw new AdminImageGenerationPendingError(entry.operationId, caught instanceof Error ? caught.message : undefined);
    }
  });
}

export async function hasPendingAdminGeneration(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind, scopeKey: string) {
  return (await readPendingAdminGeneration(access, kind, scopeKey)) !== null;
}
