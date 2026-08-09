import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";

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
  const normalizedName = fileName.trim().toLowerCase();
  if (normalizedName.endsWith(".jpg") || normalizedName.endsWith(".jpeg")) {
    return "jpg";
  }
  if (normalizedName.endsWith(".png")) {
    return "png";
  }
  if (normalizedName.endsWith(".webp")) {
    return "webp";
  }
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

export function buildAdminMediaStoragePath(options: {
  clubId: number;
  clubSlug?: string | null;
  kind: AdminMediaKind;
  fileName: string;
  mimeType: string;
}) {
  const folder = `club-${options.clubId}`;
  const extension = resolveExtension(options.fileName, options.mimeType);
  const nonce = crypto.randomUUID().slice(0, 8);
  return `${folder}/admin/${options.kind}/${Date.now()}-${nonce}.${extension}`;
}

export async function uploadAdminImage(
  client: SupabaseClient,
  access: Pick<AdminAccess, "clubId">,
  options: {
    file: File;
    kind: AdminMediaKind;
    clubSlug?: string | null;
  },
): Promise<UploadedAdminImage> {
  const clubId = requireAdminClubId(access);
  validateImageFile(options.file);
  const bytes = new Uint8Array(await options.file.arrayBuffer());
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }

  const { data, error } = await client.functions.invoke<{
    image_url?: string;
    storage_path?: string;
    bucket?: string;
  }>("admin-upload-image", {
    body: {
      club_id: clubId,
      kind: options.kind,
      mime_type: options.file.type,
      image_data_base64: btoa(binary),
    },
  });
  if (error) throw new Error(`Image upload failed: ${error.message}`);
  if (
    !data?.image_url || !data.storage_path ||
    data.bucket !== adminMediaBucket
  ) {
    throw new Error("Image upload returned an incomplete response.");
  }

  return {
    publicUrl: data.image_url,
    storagePath: data.storage_path,
  };
}

export async function generateAdminImage(
  client: SupabaseClient,
  access: Pick<AdminAccess, "clubId">,
  options: {
    kind: AdminMediaKind;
    prompt: string;
    subject?: string | null;
    aspectRatio?: string;
  },
): Promise<GeneratedAdminImage> {
  const clubId = requireAdminClubId(access);
  const prompt = options.prompt.trim();
  if (!prompt) {
    throw new Error("Enter a prompt before generating an image.");
  }

  const { data, error } = await client.functions.invoke<{
    image_url?: string;
    storage_path?: string;
    prompt_used?: string;
    model?: string;
    aspect_ratio?: string;
  }>("generate-admin-image", {
    body: {
      clubId,
      kind: options.kind,
      prompt,
      subject: options.subject?.trim() || null,
      aspectRatio:
        options.aspectRatio ??
        defaultAspectRatioForAdminMediaKind(options.kind),
    },
  });

  if (error) {
    throw new Error(error.message || "Image generation failed.");
  }

  if (!data?.image_url || !data.storage_path || !data.prompt_used) {
    throw new Error("Image generation returned an incomplete response.");
  }

  return {
    publicUrl: data.image_url,
    storagePath: data.storage_path,
    promptUsed: data.prompt_used,
    model: data.model || "gemini-2.5-flash-image",
    aspectRatio:
      data.aspect_ratio ||
      options.aspectRatio ||
      defaultAspectRatioForAdminMediaKind(options.kind),
  };
}
