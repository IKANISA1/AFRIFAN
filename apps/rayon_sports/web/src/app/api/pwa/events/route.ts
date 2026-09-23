import type { NextRequest } from "next/server";
import { getActiveClubReference } from "@/lib/club-context";
import {
  controlledApiFailureResponse,
  controlledApiJson,
  withControlledApiTimeout,
} from "@/lib/controlled-api-response";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type PwaEventBody = {
  eventType?: string;
  surface?: string;
  path?: string;
  displayMode?: string;
  payload?: Record<string, unknown>;
};

type PwaEventInsert = {
  club_id: string;
  user_id: string | null;
  event_type: string;
  surface: string;
  path: string;
  display_mode: string;
  payload: Record<string, unknown>;
  user_agent: string | null;
};

const maximumEventBodyBytes = 16_384;
const allowedSurfaces = new Set([
  "site",
  "portal",
  "live",
  "admin",
  "ios-guide",
]);
const allowedDisplayModes = new Set(["browser", "standalone", "minimal-ui"]);
const sensitivePayloadKey = /(authorization|cookie|email|name|otp|password|phone|secret|token)/i;

function normalizeLabel(value: unknown, maximumLength: number) {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  if (
    !normalized ||
    normalized.length > maximumLength ||
    !/^[a-z0-9][a-z0-9_-]*$/i.test(normalized)
  ) {
    return null;
  }
  return normalized;
}

function normalizePath(value: unknown, fallback: string) {
  if (typeof value !== "string" || !value.startsWith("/")) {
    return fallback;
  }
  return value.slice(0, 512);
}

function sanitizePayload(value: unknown) {
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    return {};
  }

  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !sensitivePayloadKey.test(key))
      .slice(0, 10)
      .flatMap(([key, entry]) =>
        typeof entry === "string" ||
        typeof entry === "number" ||
        typeof entry === "boolean" ||
        entry == null
          ? [[key.slice(0, 64), typeof entry === "string" ? entry.slice(0, 256) : entry]]
          : [],
      ),
  );
}

export async function POST(request: NextRequest) {
  const rejectedOrigin = rejectInsecureMutation(request);
  if (rejectedOrigin) {
    return rejectedOrigin;
  }

  const rejectedLimit = await rejectRateLimitedRequest(
    request,
    "pwa-events",
    90,
    60_000,
  );
  if (rejectedLimit) {
    return rejectedLimit;
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumEventBodyBytes) {
    return controlledApiJson(
      {
        code: "PWA_EVENT_EMPTY",
        error: "The event payload is invalid.",
      },
      400,
    );
  }

  let body: PwaEventBody;
  try {
    body = JSON.parse(rawBody) as PwaEventBody;
  } catch {
    body = {};
  }
  const eventType = normalizeLabel(body.eventType, 64);
  const surface = normalizeLabel(body.surface, 32);

  if (!eventType || !surface || !allowedSurfaces.has(surface)) {
    return controlledApiJson(
      {
        code: "PWA_EVENT_EMPTY",
        error: "A valid eventType and surface are required.",
      },
      400,
    );
  }

  const adminClient = getAdminSupabase();
  if (adminClient == null) {
    return controlledApiFailureResponse(
      new Error("PWA event storage is unavailable."),
      "PWA_EVENT",
    );
  }

  try {
    let userId: string | null = null;
    const serverClient = await withControlledApiTimeout(getServerSupabase());
    if (serverClient) {
      const {
        data: { user },
      } = await withControlledApiTimeout(serverClient.auth.getUser());
      userId = user?.id ?? null;
    }
    const club = await withControlledApiTimeout(getActiveClubReference());
    const displayMode =
      normalizeLabel(body.displayMode, 32) ?? "browser";

    const insert = await withControlledApiTimeout(
      (adminClient as unknown as {
        from: (
          table: "pwa_engagement_events",
        ) => {
          insert: (
            values: PwaEventInsert,
          ) => Promise<{ error: { code?: string; message: string } | null }>;
        };
      })
        .from("pwa_engagement_events")
        .insert({
          club_id: club.slug,
          user_id: userId,
          event_type: eventType,
          surface,
          path: normalizePath(body.path, request.nextUrl.pathname),
          display_mode: allowedDisplayModes.has(displayMode)
            ? displayMode
            : "browser",
          payload: sanitizePayload(body.payload),
          user_agent: request.headers.get("user-agent")?.slice(0, 512) ?? null,
        }),
    );

    if (insert.error) {
      throw insert.error;
    }

    return controlledApiJson(
      {
        code: "PWA_EVENT_STORED",
        stored: true,
      },
      201,
    );
  } catch (error) {
    return controlledApiFailureResponse(error, "PWA_EVENT");
  }
}
