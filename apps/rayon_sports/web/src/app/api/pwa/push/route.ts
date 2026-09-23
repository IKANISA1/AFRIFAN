import webpush from "web-push";
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
  let endpoint: URL;
  try {
    endpoint = new URL(typeof entry.endpoint === "string" ? entry.endpoint : "");
  } catch {
    return false;
  }
  return (
    endpoint.protocol === "https:" &&
    endpoint.toString().length <= 2_048 &&
    typeof keys?.auth === "string" &&
    keys.auth.length >= 8 &&
    keys.auth.length <= 512 &&
    typeof keys?.p256dh === "string" &&
    keys.p256dh.length >= 32 &&
    keys.p256dh.length <= 512
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
    return controlledApiJson(
      {
        code: "PWA_PUSH_EMPTY",
        error: "Push action is required.",
      },
      400,
    );
  }

  const adminClient = getAdminSupabase();
  if (adminClient == null) {
    return controlledApiFailureResponse(
      new Error("Push storage is unavailable."),
      "PWA_PUSH",
    );
  }
  const pushSubscriptions = (adminClient as unknown as {
    from: (table: "web_push_subscriptions") => WebPushSubscriptionsTable;
  }).from("web_push_subscriptions");

  try {
    const serverClient = await withControlledApiTimeout(getServerSupabase());
    const {
      data: { user },
    } = serverClient
      ? await withControlledApiTimeout(serverClient.auth.getUser())
      : { data: { user: null } };
    const club = await withControlledApiTimeout(getActiveClubReference());

    if (body.action === "subscribe") {
      if (!isSubscriptionPayload(body.subscription)) {
        return controlledApiJson(
          {
            code: "PWA_PUSH_EMPTY",
            error: "A valid push subscription is required.",
          },
          400,
        );
      }

      const result = await withControlledApiTimeout(
        pushSubscriptions.upsert(
          {
            club_id: club.slug,
            user_id: user?.id ?? null,
            // Never persist the Supabase access-token cookie as a session ID.
            session_id: null,
            surface:
              typeof body.surface === "string"
                ? body.surface.trim().slice(0, 32) || "site"
                : "site",
            endpoint: body.subscription.endpoint,
            p256dh: body.subscription.keys.p256dh,
            auth: body.subscription.keys.auth,
            path:
              typeof body.path === "string" && body.path.startsWith("/")
                ? body.path.slice(0, 512)
                : request.nextUrl.pathname,
            language_code:
              request.headers.get("accept-language")?.split(",")[0]?.slice(0, 32) ??
              null,
            user_agent:
              request.headers.get("user-agent")?.slice(0, 512) ?? null,
            disabled_at: null,
            last_seen_at: new Date().toISOString(),
          },
          {
            onConflict: "endpoint",
          },
        ),
      );

      if (result.error) {
        throw result.error;
      }

      return controlledApiJson(
        {
          code: "PWA_PUSH_SUBSCRIBED",
          success: true,
        },
        201,
      );
    }

    if (body.action === "unsubscribe") {
      if (!body.endpoint?.trim()) {
        return controlledApiJson(
          {
            code: "PWA_PUSH_EMPTY",
            error: "Push endpoint is required.",
          },
          400,
        );
      }

      const result = await withControlledApiTimeout(
        pushSubscriptions
          .update({
            disabled_at: new Date().toISOString(),
          })
          .eq("endpoint", body.endpoint.trim()),
      );

      if (result.error) {
        throw result.error;
      }

      return controlledApiJson({
        code: "PWA_PUSH_UNSUBSCRIBED",
        success: true,
      });
    }

    if (body.action === "test") {
      if (!isSubscriptionPayload(body.subscription)) {
        return controlledApiJson(
          {
            code: "PWA_PUSH_EMPTY",
            error: "A valid push subscription is required.",
          },
          400,
        );
      }

      const vapid = resolveVapidConfig();
      if (!vapid.publicKey || !vapid.privateKey) {
        return controlledApiJson(
          {
            code: "PWA_PUSH_SYNCING",
            success: false,
            retryable: true,
            reason: "Push delivery is not configured yet.",
          },
          202,
        );
      }

      await withControlledApiTimeout(
        webpush.sendNotification(
          {
            endpoint: body.subscription.endpoint,
            keys: {
              auth: body.subscription.keys.auth,
              p256dh: body.subscription.keys.p256dh,
            },
          },
          JSON.stringify({
            title: "Official club alerts",
            body:
            "You will now receive timely match, membership, and supporter updates.",
            url: "/supporters",
            icon: "/brand-mark.svg",
            badge: "/brand-mark.svg",
            tag: "africlub-test-alert",
            requireInteraction: false,
            actions: [
              { action: "open", title: "Open app" },
              { action: "dismiss", title: "Dismiss" },
            ],
            badgeCount: 1,
          }),
        ),
      );

      return controlledApiJson({
        code: "PWA_PUSH_DELIVERED",
        success: true,
      });
    }

    return controlledApiJson(
      {
        code: "PWA_PUSH_EMPTY",
        error: "Unknown push action.",
      },
      400,
    );
  } catch (error) {
    return controlledApiFailureResponse(error, "PWA_PUSH");
  }
}
