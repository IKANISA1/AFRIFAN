import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";
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

type GeminiImageResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<Record<string, unknown>>;
    };
  }>;
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
  if (typeof value === "number" && Number.isInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
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

async function ensureClubAdminAccess(
  adminClient: ReturnType<typeof createAdminClient>,
  options: { userId: string; clubId: number },
) {
  const [userResponse, assignmentResponse] = await Promise.all([
    adminClient
      .from("users")
      .select("is_admin")
      .eq("id", options.userId)
      .maybeSingle(),
    adminClient
      .from("admin_role_assignments")
      .select("role, club_id, is_active, revoked_at")
      .eq("user_id", options.userId)
      .eq("is_active", true)
      .is("revoked_at", null),
  ]);

  if (userResponse.error) {
    throw new Error(userResponse.error.message);
  }
  if (assignmentResponse.error) {
    throw new Error(assignmentResponse.error.message);
  }

  if (userResponse.data?.is_admin === true) {
    return true;
  }

  const assignments = Array.isArray(assignmentResponse.data)
    ? assignmentResponse.data
    : [];

  return assignments.some((assignment) => {
    const role = asTrimmedString(assignment.role)?.toLowerCase();
    if (!role) {
      return false;
    }
    if (role === "admin" || role === "super_admin") {
      return true;
    }
    return (
      (role === "club_admin" || role === "club_moderator") &&
      Number(assignment.club_id) === options.clubId
    );
  });
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

function extractInlineImagePart(parts: Array<Record<string, unknown>>) {
  return parts.find((part) =>
    Object.hasOwn(part, "inlineData") || Object.hasOwn(part, "inline_data")
  );
}

const handler = async (request: Request) => {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    const validated = await validateRequest(request);
    if (isErrorResponse(validated)) {
      return validated;
    }

    const body = (await request.json()) as GenerateAdminImageRequest;
    const clubId = normalizeClubId(body.clubId);
    const kind = normalizeKind(body.kind);
    const prompt = asTrimmedString(body.prompt);

    if (clubId == null || kind == null || !prompt) {
      return jsonError("clubId, kind, and prompt are required.", 400);
    }

    const adminClient = createAdminClient();
    const hasAccess = await ensureClubAdminAccess(adminClient, {
      userId: validated.userId,
      clubId,
    });
    if (!hasAccess) {
      return jsonError("Club admin access is required.", 403);
    }

    const { data: club, error: clubError } = await adminClient
      .from("african_football_clubs")
      .select(
        "club_name, primary_brand_colors, nickname_brand_identity, country_name, region, league",
      )
      .eq("id", clubId)
      .single();

    if (clubError || !club) {
      return jsonError("Club not found.", 404);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    if (!geminiKey) {
      return jsonError(
        "GEMINI_API_KEY is not configured for this project.",
        503,
      );
    }

    const model = Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() ||
      "gemini-2.5-flash-image";
    const aspectRatio = normalizeAspectRatio(
      body.aspectRatio,
      kindDirectives[kind].aspectRatio,
    );
    const subject = asTrimmedString(body.subject);
    const resolvedPrompt = buildPrompt(
      club as ClubBrand,
      kind,
      prompt,
      subject,
    );

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": geminiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [{ text: resolvedPrompt }],
            },
          ],
          generationConfig: {
            imageConfig: {
              aspectRatio,
            },
          },
        }),
      },
    );

    if (!geminiResponse.ok) {
      const detail = await geminiResponse.text();
      return jsonError(
        `Gemini image generation failed with ${geminiResponse.status}.`,
        502,
      );
    }

    const geminiBody = (await geminiResponse.json()) as GeminiImageResponse;
    const parts = geminiBody.candidates?.[0]?.content?.parts ?? [];
    const imagePart = extractInlineImagePart(parts);
    if (!imagePart) {
      return jsonError("Gemini did not return an image.", 502);
    }

    const inlineData = (imagePart.inlineData ?? imagePart.inline_data) as
      | Record<string, unknown>
      | undefined;
    const base64Data = asTrimmedString(inlineData?.data);
    const mimeType =
      asTrimmedString(inlineData?.mimeType ?? inlineData?.mime_type) ||
      "image/png";

    if (!base64Data) {
      return jsonError("Gemini returned an invalid image payload.", 502);
    }

    const extension = mimeType.includes("webp")
      ? "webp"
      : mimeType.includes("png")
      ? "png"
      : "jpg";
    const clubFolder = `club-${clubId}`;
    const storagePath = `${clubFolder}/admin/${kind}/${Date.now()}-${
      crypto.randomUUID().slice(0, 8)
    }.${extension}`;
    const imageBytes = Uint8Array.from(
      atob(base64Data),
      (char) => char.charCodeAt(0),
    );

    const { error: uploadError } = await adminClient.storage
      .from("africlub-product-images")
      .upload(storagePath, imageBytes, {
        contentType: mimeType,
        upsert: false,
      });

    if (uploadError) {
      return jsonError(`Storage upload failed: ${uploadError.message}`, 500);
    }

    const { data: publicUrlData } = adminClient.storage
      .from("africlub-product-images")
      .getPublicUrl(storagePath);

    return jsonOk({
      image_url: publicUrlData.publicUrl,
      storage_path: storagePath,
      prompt_used: resolvedPrompt,
      model,
      aspect_ratio: aspectRatio,
      club: (club as ClubBrand).club_name,
      kind,
    });
  } catch (error) {
    logDiagnostic("error", "generate_admin_image_generate_admin_image_failed", error);
    return jsonError(
      error instanceof Error ? error.message : "Image generation failed.",
      500,
    );
  }
};

if (import.meta.main) {
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
