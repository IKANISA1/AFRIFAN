import {
  assertVerifiedStaffStepUp,
  getAuthorizationHeader,
  hasActiveAdminAssignment,
} from "../_shared/auth.ts";
import {
  executeImageGeneration,
  generationUuid,
  getImageGenerationStatus,
} from "../_shared/admin_image_generation.ts";
import { createLifecycleAdminClient } from "../_shared/account_lifecycle_client.ts";
import { getSupabaseUrl } from "../_shared/supabase.ts";
import { errorResponse } from "../_shared/response.ts";
import { withEdgeBoundary } from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";

import { isErrorResponse, validateRequest } from "../_shared/validation.ts";

type AdminImageKind =
  | "shop_product"
  | "news_article"
  | "home_banner"
  | "fan_club"
  | "match"
  | "squad_player"
  | "notification";

type GenerateAdminImageRequest = {
  operation_id?: unknown;
  mode?: unknown;
  clubId?: unknown;
  kind?: unknown;
  prompt?: unknown;
  subject?: unknown;
  aspectRatio?: unknown;
};

type ClubBrand = {
  club_name: string | null;
  primary_brand_colors: string | null;
  nickname_brand_identity: string | null;
  country_name: string | null;
  region: string | null;
  league: string | null;
};

const supportedKinds = new Set<AdminImageKind>([
  "shop_product",
  "news_article",
  "home_banner",
  "fan_club",
  "match",
  "squad_player",
  "notification",
]);

const supportedAspectRatios = new Set([
  "1:1",
  "2:3",
  "3:2",
  "3:4",
  "4:3",
  "4:5",
  "5:4",
  "9:16",
  "16:9",
  "21:9",
]);

const kindDirectives: Record<
  AdminImageKind,
  { aspectRatio: string; instruction: string }
> = {
  shop_product: {
    aspectRatio: "1:1",
    instruction:
      "Treat this as a premium ecommerce product image with clean lighting, a simple background, and a catalogue-ready composition.",
  },
  news_article: {
    aspectRatio: "16:9",
    instruction:
      "Treat this as a dramatic editorial header image for a football news article.",
  },
  home_banner: {
    aspectRatio: "16:9",
    instruction:
      "Treat this as a homepage hero banner with strong composition and room for UI overlays if needed.",
  },
  fan_club: {
    aspectRatio: "16:9",
    instruction:
      "Treat this as a supporters chapter banner that feels communal, energetic, and club-branded.",
  },
  match: {
    aspectRatio: "16:9",
    instruction:
      "Treat this as a matchday hero image or poster with a stadium-scale sports atmosphere.",
  },
  squad_player: {
    aspectRatio: "3:4",
    instruction:
      "Treat this as a player portrait or hero card image with the subject clearly framed.",
  },
  notification: {
    aspectRatio: "16:9",
    instruction:
      "Treat this as a concise promo visual for a notification or announcement, readable at small sizes.",
  },
};

function asTrimmedString(value: unknown) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeClubId(value: unknown) {
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = /^[1-9][0-9]*$/.test(value.trim())
      ? Number(value.trim())
      : NaN;
    return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
  }
  return null;
}

function normalizeKind(value: unknown) {
  const normalized = asTrimmedString(value)?.toLowerCase();
  if (!normalized || !supportedKinds.has(normalized as AdminImageKind)) {
    return null;
  }
  return normalized as AdminImageKind;
}

function normalizeAspectRatio(value: unknown, fallback: string) {
  const normalized = asTrimmedString(value);
  if (!normalized) {
    return fallback;
  }
  return supportedAspectRatios.has(normalized) ? normalized : fallback;
}

function buildPrompt(
  club: ClubBrand,
  kind: AdminImageKind,
  prompt: string,
  subject: string | null,
) {
  const directive = kindDirectives[kind];
  const clubName = club.club_name?.trim() || "the club";
  const brandColors = club.primary_brand_colors?.trim() ||
    "the club brand colors";
  const nickname = club.nickname_brand_identity?.trim() || "the supporters";
  const country = club.country_name?.trim() || "Africa";
  const region = club.region?.trim() || "regional";
  const league = club.league?.trim() || "football";

  return [
    "Create a single polished image for an African football club admin CMS.",
    directive.instruction,
    `Club context: ${clubName}, ${nickname}, ${brandColors}, ${country}, ${region}, ${league}.`,
    subject ? `Primary subject: ${subject}.` : null,
    "Respect the club brand palette and football context.",
    "Avoid watermarks, mock browser chrome, and unintended text unless the prompt explicitly asks for text.",
    `Admin prompt: ${prompt.trim()}`,
  ]
    .filter(Boolean)
    .join("\n");
}

export function createGenerateAdminImageHandler(dependencies: Partial<{
  validateRequest: typeof validateRequest;
  createAdminClient: typeof createLifecycleAdminClient;
  hasActiveAdminAssignment: typeof hasActiveAdminAssignment;
  executeImageGeneration: typeof executeImageGeneration;
  getImageGenerationStatus: typeof getImageGenerationStatus;
}> = {}) {
  const deps = {
    validateRequest,
    createAdminClient: createLifecycleAdminClient,
    hasActiveAdminAssignment,
    executeImageGeneration,
    getImageGenerationStatus,
    ...dependencies,
  };
  return async (request: Request) => {
    if (request.method === "OPTIONS") return corsPreflightResponse(request);
    if (request.method !== "POST") return jsonError("Method not allowed", 405);
    try {
      const authorization = getAuthorizationHeader(request) ?? "";
      const validated = await deps.validateRequest(request);
      if (isErrorResponse(validated)) return validated;
      const body = await readBoundedJson(request) as GenerateAdminImageRequest;
      const clubId = normalizeClubId(body.clubId);
      const operationId = asTrimmedString(body.operation_id);
      if (clubId == null || !operationId || !generationUuid.test(operationId)) {
        return jsonError("clubId and original operation_id are required.", 400);
      }
      if (body.mode !== undefined && body.mode !== "status") {
        return jsonError("Image mode is invalid.", 400);
      }
      const hasAccess = await deps.hasActiveAdminAssignment(
        deps.createAdminClient(),
        validated.userId,
        clubId,
      );
      if (!hasAccess) return jsonError("Club admin access is required.", 403);
      assertVerifiedStaffStepUp(
        authorization,
        validated.userId,
        validated.isAnonymous,
      );
      if (body.mode === "status") {
        const receipt = await deps.getImageGenerationStatus(
          authorization,
          operationId,
          validated.userId,
          clubId,
          "admin_image",
        );
        return receipt
          ? jsonOk(receipt)
          : jsonError("Original image operation was not found.", 404);
      }
      const kind = normalizeKind(body.kind);
      const prompt = asTrimmedString(body.prompt);
      const subject = asTrimmedString(body.subject);
      if (
        !kind || !prompt || prompt.length > 4000 || (subject?.length ?? 0) > 500
      ) return jsonError("Image kind, prompt or subject is invalid.", 400);
      const aspectRatio = normalizeAspectRatio(
        body.aspectRatio,
        kindDirectives[kind].aspectRatio,
      );
      const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
      if (!apiKey) {
        return jsonError(
          "Image generation is not configured on the server.",
          503,
        );
      }
      const model = Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() ||
        "gemini-2.5-flash-image";
      if (!/^[a-zA-Z0-9._-]{1,120}$/.test(model)) {
        return jsonError("Image generation is unavailable.", 503);
      }
      const receipt = await deps.executeImageGeneration(
        authorization,
        {
          operationId,
          actorId: validated.userId,
          clubId,
          domain: "admin_image",
          kind,
          request: { kind, prompt, subject, aspectRatio },
        },
        (brand) => ({
          model,
          public_origin: getSupabaseUrl().replace(/\/$/, ""),
          prompt_used: buildPrompt(brand as ClubBrand, kind, prompt, subject),
          aspect_ratio: aspectRatio,
        }),
        apiKey,
      );
      return jsonOk(receipt, receipt.status === "completed" ? 200 : 202);
    } catch (error) {
      logDiagnostic(
        "error",
        "generate_admin_image_generate_admin_image_failed",
        error,
      );
      return errorResponse(error);
    }
  };
}

if (import.meta.main) {
  Deno.serve(
    withEdgeBoundary((request) =>
      createGenerateAdminImageHandler()(request).then((response) =>
        new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: {
            ...Object.fromEntries(response.headers.entries()),
            ...corsHeaders(),
          },
        })
      )
    ),
  );
}
