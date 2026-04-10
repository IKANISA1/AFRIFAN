import webpush from "web-push";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getActiveClubReference } from "@/lib/club-context";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type PushSubscriptionKeys = {
  auth: string;
  p256dh: string;
};

type PushSubscriptionPayload = {
  endpoint: string;
  keys: PushSubscriptionKeys;
};

type SubscribeBody = {
  action: "subscribe";
  subscription: PushSubscriptionPayload;
  surface?: string;
  path?: string;
};

type UnsubscribeBody = {
  action: "unsubscribe";
  endpoint: string;
};

type TestBody = {
  action: "test";
  subscription: PushSubscriptionPayload;
  title?: string;
  body?: string;
  url?: string;
};

type PushBody = SubscribeBody | UnsubscribeBody | TestBody;

type PushSubscriptionInsert = {
  club_id: string;
  user_id: string | null;
  session_id: string | null;
  surface: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  path: string;
  language_code: string | null;
  user_agent: string | null;
  disabled_at: null;
  last_seen_at: string;
};

type WebPushSubscriptionsTable = {
  upsert: (
    values: PushSubscriptionInsert,
    options: { onConflict: string },
  ) => Promise<{ error: { message: string } | null }>;
  update: (
    values: { disabled_at: string },
  ) => {
    eq: (
      column: "endpoint",
      value: string,
    ) => Promise<{ error: { message: string } | null }>;
  };
};

function isSubscriptionPayload(
  value: unknown,
): value is PushSubscriptionPayload {
  if (typeof value !== "object" || value == null) {
    return false;
  }

  const entry = value as Record<string, unknown>;
  const keys = entry.keys as Record<string, unknown> | undefined;
  return (
    typeof entry.endpoint === "string" &&
    typeof keys?.auth === "string" &&
    typeof keys?.p256dh === "string"
  );
}

function resolveVapidConfig() {
  const publicKey =
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY?.trim() ||
    process.env.VAPID_PUBLIC_KEY?.trim() ||
    "";
  const privateKey = process.env.VAPID_PRIVATE_KEY?.trim() || "";
  const subject =
    process.env.VAPID_SUBJECT?.trim() || "mailto:support@gikundiro.com";

  if (publicKey && privateKey) {
    webpush.setVapidDetails(subject, publicKey, privateKey);
  }

  return {
    publicKey,
    privateKey,
  };
}

export async function POST(request: NextRequest) {
  const rejectedOrigin = rejectInsecureMutation(request);
  if (rejectedOrigin) {
    return rejectedOrigin;
  }

  const rejectedLimit = await rejectRateLimitedRequest(
    request,
    "pwa-push",
    30,
    60_000,
  );
  if (rejectedLimit) {
    return rejectedLimit;
  }

  const body = (await request.json().catch(() => ({}))) as Partial<PushBody>;
  if (!body.action) {
    return NextResponse.json(
      { error: "Push action is required." },
      { status: 400 },
    );
  }

  const adminClient = getAdminSupabase();
  const pushSubscriptions =
    adminClient == null
      ? null
      : (adminClient as unknown as {
          from: (table: "web_push_subscriptions") => WebPushSubscriptionsTable;
        }).from("web_push_subscriptions");
  const serverClient = await getServerSupabase();
  const {
    data: { user },
  } = serverClient
    ? await serverClient.auth.getUser()
    : { data: { user: null } };
  const club = await getActiveClubReference();

  if (body.action === "subscribe") {
    if (!isSubscriptionPayload(body.subscription)) {
      return NextResponse.json(
        { error: "A valid push subscription is required." },
        { status: 400 },
      );
    }

    if (adminClient == null) {
      return NextResponse.json(
        { error: "Server admin client is not configured." },
        { status: 503 },
      );
    }

    if (pushSubscriptions == null) {
      return NextResponse.json(
        { error: "Server admin client is not configured." },
        { status: 503 },
      );
    }

    const result = await pushSubscriptions.upsert(
      {
        club_id: club.slug,
        user_id: user?.id ?? null,
        session_id: request.cookies.get("sb-access-token")?.value ?? null,
        surface: body.surface ?? "site",
        endpoint: body.subscription.endpoint,
        p256dh: body.subscription.keys.p256dh,
        auth: body.subscription.keys.auth,
        path: body.path ?? request.nextUrl.pathname,
        language_code:
          request.headers.get("accept-language")?.split(",")[0] ?? null,
        user_agent: request.headers.get("user-agent"),
        disabled_at: null,
        last_seen_at: new Date().toISOString(),
      },
      {
        onConflict: "endpoint",
      },
    );

    if (result.error) {
      return NextResponse.json(
        { error: result.error.message },
        { status: 500 },
      );
    }

    return NextResponse.json({ success: true });
  }

  if (body.action === "unsubscribe") {
    if (!body.endpoint?.trim()) {
      return NextResponse.json(
        { error: "Push endpoint is required." },
        { status: 400 },
      );
    }

    if (adminClient == null) {
      return NextResponse.json({ success: true, stored: false });
    }

    if (pushSubscriptions == null) {
      return NextResponse.json({ success: true, stored: false });
    }

    const result = await pushSubscriptions
      .update({
        disabled_at: new Date().toISOString(),
      })
      .eq("endpoint", body.endpoint.trim());

    if (result.error) {
      return NextResponse.json(
        { error: result.error.message },
        { status: 500 },
      );
    }

    return NextResponse.json({ success: true });
  }

  if (body.action === "test") {
    if (!isSubscriptionPayload(body.subscription)) {
      return NextResponse.json(
        { error: "A valid push subscription is required." },
        { status: 400 },
      );
    }

    const vapid = resolveVapidConfig();
    if (!vapid.publicKey || !vapid.privateKey) {
      return NextResponse.json(
        { success: false, reason: "missing-vapid-config" },
        { status: 202 },
      );
    }

    try {
      await webpush.sendNotification(
        {
          endpoint: body.subscription.endpoint,
          keys: {
            auth: body.subscription.keys.auth,
            p256dh: body.subscription.keys.p256dh,
          },
        },
        JSON.stringify({
          title: body.title ?? "Official club alerts enabled",
          body:
            body.body ??
            "You will now receive timely match, membership, and supporter updates.",
          url: body.url ?? "/supporters",
          icon: "/icons/icon-192x192.png",
          badge: "/icons/icon-72x72.png",
          tag: "africlub-test-alert",
          requireInteraction: false,
          actions: [
            { action: "open", title: "Open app" },
            { action: "dismiss", title: "Dismiss" },
          ],
          badgeCount: 1,
        }),
      );
      return NextResponse.json({ success: true });
    } catch (error) {
      return NextResponse.json(
        {
          error:
            error instanceof Error ? error.message : "Push delivery failed.",
        },
        { status: 500 },
      );
    }
  }

  return NextResponse.json({ error: "Unknown push action." }, { status: 400 });
}
