import { NextRequest, NextResponse } from "next/server";

/**
 * Push subscription management API.
 *
 * POST /api/admin/push
 *   body: { action: "subscribe", subscription: PushSubscriptionJSON }
 *   body: { action: "unsubscribe", endpoint: string }
 *   body: { action: "send", title: string, body: string, ... }
 *
 * In production, subscriptions would be stored in Supabase.
 * For now, we validate the shape and return success.
 */

interface SubscribePayload {
  action: "subscribe";
  subscription: {
    endpoint: string;
    keys: { auth: string; p256dh: string };
  };
}

interface UnsubscribePayload {
  action: "unsubscribe";
  endpoint: string;
}

interface SendPayload {
  action: "send";
  title: string;
  body: string;
  url?: string;
  icon?: string;
  badge?: string;
  tag?: string;
}

type PushPayload = SubscribePayload | UnsubscribePayload | SendPayload;

function isValidPayload(data: unknown): data is PushPayload {
  if (typeof data !== "object" || data === null) return false;
  const payload = data as Record<string, unknown>;
  if (typeof payload.action !== "string") return false;

  switch (payload.action) {
    case "subscribe":
      return (
        typeof payload.subscription === "object" &&
        payload.subscription !== null &&
        typeof (payload.subscription as Record<string, unknown>).endpoint === "string"
      );
    case "unsubscribe":
      return typeof payload.endpoint === "string";
    case "send":
      return typeof payload.title === "string" && typeof payload.body === "string";
    default:
      return false;
  }
}

export async function POST(request: NextRequest) {
  try {
    const data: unknown = await request.json();

    if (!isValidPayload(data)) {
      return NextResponse.json(
        { error: "Invalid push payload" },
        { status: 400 },
      );
    }

    switch (data.action) {
      case "subscribe": {
        // Store subscription in database
        // In production: INSERT INTO push_subscriptions (endpoint, keys_auth, keys_p256dh, user_id)
        console.log("[push-api] Subscription registered:", data.subscription.endpoint.slice(0, 50));
        return NextResponse.json({ success: true, message: "Subscription stored" });
      }

      case "unsubscribe": {
        // Remove subscription from database
        // In production: DELETE FROM push_subscriptions WHERE endpoint = $1
        console.log("[push-api] Subscription removed:", data.endpoint.slice(0, 50));
        return NextResponse.json({ success: true, message: "Subscription removed" });
      }

      case "send": {
        // In production, iterate over subscriptions and call web-push library
        // For now, acknowledge the send request
        console.log("[push-api] Send requested:", data.title);
        return NextResponse.json({
          success: true,
          message: "Push notification queued",
          payload: {
            title: data.title,
            body: data.body,
            url: data.url ?? "/admin",
            icon: data.icon ?? "/icons/icon-192x192.png",
            badge: data.badge ?? "/icons/icon-72x72.png",
            tag: data.tag ?? "admin-notification",
          },
        });
      }

      default:
        return NextResponse.json({ error: "Unknown action" }, { status: 400 });
    }
  } catch {
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 },
    );
  }
}
