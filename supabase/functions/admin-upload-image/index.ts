import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireClubAdminCaller } from "../_shared/auth.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

const bucket = "africlub-product-images";
const maximumBytes = 5 * 1024 * 1024;
const maximumBase64Characters = Math.ceil(maximumBytes / 3) * 4 + 8;
const allowedKinds = new Set([
  "shop_product",
  "news_article",
  "home_banner",
  "fan_club",
  "match",
  "squad_player",
  "notification",
]);
const mimeExtensions = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
]);

type AdminClient = ReturnType<typeof createAdminClient>;
type Dependencies = {
  requireClubAdminCaller: typeof requireClubAdminCaller;
  createAdminClient: () => AdminClient;
  now: () => number;
  randomId: () => string;
};

const defaultDependencies: Dependencies = {
  requireClubAdminCaller,
  createAdminClient,
  now: () => Date.now(),
  randomId: () => crypto.randomUUID().slice(0, 8),
};

function requireClubId(value: unknown) {
  const clubId = typeof value === "number"
    ? value
    : typeof value === "string" && /^[1-9]\d*$/.test(value.trim())
    ? Number(value.trim())
    : NaN;
  if (!Number.isSafeInteger(clubId) || clubId <= 0) {
    throw new HttpError(400, "club_id is invalid.");
  }
  return clubId;
}

function validSignature(bytes: Uint8Array, mimeType: string) {
  if (mimeType === "image/png") {
    return bytes.length >= 8 &&
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every(
        (value, index) => bytes[index] === value,
      );
  }
  if (mimeType === "image/jpeg") {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  return bytes.length >= 12 &&
    new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
    new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP";
}

function decodeImage(value: unknown, mimeType: string) {
  if (
    typeof value !== "string" || value.length === 0 ||
    value.length > maximumBase64Characters ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(value)
  ) {
    throw new HttpError(400, "image_data_base64 is invalid.");
  }
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(
      atob(value),
      (character) => character.charCodeAt(0),
    );
  } catch {
    throw new HttpError(400, "image_data_base64 is invalid.");
  }
  if (bytes.length === 0 || bytes.length > maximumBytes) {
    throw new HttpError(400, "Image must be 5MB or smaller.");
  }
  if (!validSignature(bytes, mimeType)) {
    throw new HttpError(400, "Image content does not match its MIME type.");
  }
  return bytes;
}

export function createAdminUploadImageHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps = { ...defaultDependencies, ...dependencies };
  return async (request: Request) => {
    if (request.method === "OPTIONS") return corsPreflightResponse();
    if (request.method !== "POST") return jsonError("Method not allowed", 405);

    try {
      let input: unknown;
      try {
        input = await request.json();
      } catch {
        throw new HttpError(400, "Request must contain a JSON object.");
      }
      if (input === null || typeof input !== "object" || Array.isArray(input)) {
        throw new HttpError(400, "Request must contain a JSON object.");
      }
      const body = input as Record<string, unknown>;
      const clubId = requireClubId(body.club_id);
      await deps.requireClubAdminCaller(request, clubId);
      const kind = typeof body.kind === "string" ? body.kind.trim() : "";
      if (!allowedKinds.has(kind)) {
        throw new HttpError(400, "kind is invalid.");
      }
      const mimeType = typeof body.mime_type === "string"
        ? body.mime_type.trim().toLowerCase()
        : "";
      const extension = mimeExtensions.get(mimeType);
      if (!extension) throw new HttpError(400, "mime_type is invalid.");
      const bytes = decodeImage(body.image_data_base64, mimeType);
      const storagePath =
        `club-${clubId}/admin/${kind}/${deps.now()}-${deps.randomId()}.${extension}`;
      const adminClient = deps.createAdminClient();
      const { error } = await adminClient.storage.from(bucket).upload(
        storagePath,
        bytes,
        { cacheControl: "31536000", contentType: mimeType, upsert: false },
      );
      if (error) throw new HttpError(500, "Storage upload failed.");
      const { data } = adminClient.storage.from(bucket).getPublicUrl(
        storagePath,
      );
      return jsonOk({
        image_url: data.publicUrl,
        storage_path: storagePath,
        bucket,
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }
      return jsonError("Image upload failed.", 500);
    }
  };
}

if (import.meta.main) {
  const handler = createAdminUploadImageHandler();
  Deno.serve((request) =>
    handler(request).then((response) =>
      new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: {
          ...Object.fromEntries(response.headers.entries()),
          ...corsHeaders(),
        },
      })
    )
  );
}
