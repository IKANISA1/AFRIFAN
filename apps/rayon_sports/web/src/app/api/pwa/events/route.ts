import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getActiveClubReference } from "@/lib/club-context";
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

  const body = (await request.json().catch(() => ({}))) as PwaEventBody;
  const eventType = body.eventType?.trim();
  const surface = body.surface?.trim();

  if (!eventType || !surface) {
    return NextResponse.json(
      { error: "eventType and surface are required." },
      { status: 400 },
    );
  }

  const adminClient = getAdminSupabase();
  if (adminClient == null) {
    return NextResponse.json({ stored: false, reason: "missing-server-config" });
  }

  let userId: string | null = null;
  const serverClient = await getServerSupabase();
  if (serverClient) {
    const {
      data: { user },
    } = await serverClient.auth.getUser();
    userId = user?.id ?? null;
  }
  const club = await getActiveClubReference();

  const insert = await ((adminClient as unknown as {
    from: (
      table: "pwa_engagement_events",
    ) => { insert: (values: PwaEventInsert) => Promise<{ error: { message: string } | null }> };
  }).from("pwa_engagement_events").insert({
    club_id: club.slug,
    user_id: userId,
    event_type: eventType,
    surface,
    path: body.path ?? request.nextUrl.pathname,
    display_mode: body.displayMode ?? "browser",
    payload: body.payload ?? {},
    user_agent: request.headers.get("user-agent"),
  }));

  if (insert.error) {
    return NextResponse.json(
      { stored: false, error: insert.error.message },
      { status: 500 },
    );
  }

  return NextResponse.json({ stored: true });
}
