import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireCronSecret } from "../_shared/auth.ts";
import {
  buildDeliveryUpdate,
  dispatchNotification,
} from "../_shared/notifications.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type AdminClientLike = ReturnType<typeof createAdminClient>;

type Dependencies = {
  createAdminClient: () => AdminClientLike;
  requireCronSecret: typeof requireCronSecret;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  requireCronSecret,
};

function parseLimit(body: Record<string, unknown>): number {
  const raw = body["limit"];
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return Math.max(1, Math.min(50, Math.trunc(raw)));
  }
  if (typeof raw === "string") {
    const parsed = Number.parseInt(raw.trim(), 10);
    if (Number.isFinite(parsed)) {
      return Math.max(1, Math.min(50, parsed));
    }
  }
  return 25;
}

export function createDispatchScheduledNotificationsHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    const corsResponse = handleCors(request);
    if (corsResponse) {
      return corsResponse;
    }

    if (request.method !== "POST") {
      return methodNotAllowed("POST");
    }

    try {
      deps.requireCronSecret(request);

      let body: Record<string, unknown> = {};
      try {
        body = await request.json() as Record<string, unknown>;
      } catch (_) {
        body = {};
      }

      const limit = parseLimit(body);
      const adminClient = deps.createAdminClient();
      const now = new Date().toISOString();

      const { data, error } = await adminClient
        .from("notifications")
        .select("*")
        .eq("status", "scheduled")
        .lte("scheduled_at", now)
        .order("scheduled_at", { ascending: true })
        .limit(limit);

      if (error) {
        throw new HttpError(500, "Failed to load scheduled notifications.");
      }

      const items = Array.isArray(data) ? data : [];
      let processed = 0;
      let sent = 0;
      let partial = 0;
      let failed = 0;

      for (const notification of items) {
        const { data: claimed } = await adminClient
          .from("notifications")
          .update({ status: "processing", last_error: null })
          .eq("id", notification["id"])
          .eq("status", "scheduled")
          .select("id")
          .maybeSingle();

        if (!claimed) {
          continue;
        }

        processed++;

        try {
          const delivery = await dispatchNotification(
            adminClient,
            notification,
          );
          await adminClient
            .from("notifications")
            .update(buildDeliveryUpdate(delivery))
            .eq("id", notification["id"]);

          switch (delivery.status) {
            case "sent":
              sent++;
              break;
            case "partial":
              partial++;
              break;
            case "failed":
              failed++;
              break;
            default:
              break;
          }
        } catch (error) {
          failed++;
          await adminClient
            .from("notifications")
            .update({
              status: "failed",
              sent_at: new Date().toISOString(),
              last_error: error instanceof Error
                ? error.message
                : "Scheduled notification dispatch failed.",
              delivery_summary: {
                errors: [
                  error instanceof Error
                    ? error.message
                    : "Scheduled notification dispatch failed.",
                ],
              },
            })
            .eq("id", notification["id"]);
        }
      }

      return jsonResponse({
        success: true,
        data: {
          processed,
          sent,
          partial,
          failed,
          fetched: items.length,
        },
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return errorResponse(error.message, error.status);
      }

      return errorResponse(
        error instanceof Error
          ? error.message
          : "Scheduled notification dispatch failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createDispatchScheduledNotificationsHandler());
}
