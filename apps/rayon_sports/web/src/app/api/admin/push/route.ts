import { NextRequest, NextResponse } from "next/server";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";
import { enforceFeatureState } from "@/lib/server-feature-guard";

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

export const dynamic = "force-dynamic";

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
  return handleAdminApiRoute(request, async (_adminClient, access) => {
    const data: unknown = await request.json();

    if (!isValidPayload(data)) {
      throw new Error("Invalid push payload");
    }

    if (data.action === "send") {
      const featureState = await enforceFeatureState(
        "notifications",
        "web",
        "action",
        {
          clubId: access.clubId,
          isAuthenticated: access.isAuthenticated,
          roles: access.role ? [access.role] : [],
        },
      );

      if (!featureState.allowed) {
        throw new Error(
          featureState.error ?? "Notifications are currently unavailable.",
        );
      }
    }

    switch (data.action) {
      case "subscribe": {
        // Store subscription in database
        // In production: INSERT INTO push_subscriptions (endpoint, keys_auth, keys_p256dh, user_id)
        console.log("[push-api] Subscription registered:", data.subscription.endpoint.slice(0, 50));
        return { success: true, message: "Subscription stored" };
      }

      case "unsubscribe": {
        // Remove subscription from database
        // In production: DELETE FROM push_subscriptions WHERE endpoint = $1
        console.log("[push-api] Subscription removed:", data.endpoint.slice(0, 50));
        return { success: true, message: "Subscription removed" };
      }

      case "send": {
        // In production, iterate over subscriptions and call web-push library
        // For now, acknowledge the send request
        console.log("[push-api] Send requested:", data.title);
        return {
          success: true,
          message: "Push notification queued",
          payload: {
            title: data.title,
            body: data.body,
            url: data.url ?? "/admin",
            icon: data.icon ?? "/brand-mark.svg",
            badge: data.badge ?? "/brand-mark.svg",
            tag: data.tag ?? "admin-notification",
          },
        };
      }

      default:
        throw new Error("Unknown action");
    }
  });
}
