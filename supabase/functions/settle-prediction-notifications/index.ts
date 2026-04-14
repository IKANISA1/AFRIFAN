import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireCronSecret } from "../_shared/auth.ts";
import { sendToUser } from "../_shared/fcm.ts";
import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

/**
 * settle-prediction-notifications
 *
 * Cron-invocable edge function that:
 * 1. Fetches pending prediction settlement notifications via RPC
 * 2. Sends FCM push to each user via sendToUser()
 * 3. Marks notifications as sent via RPC
 *
 * Auth: CRON_SECRET header (same as dispatch-scheduled-notifications)
 */

type AdminClientLike = ReturnType<typeof createAdminClient>;

type Dependencies = {
  createAdminClient: () => AdminClientLike;
  requireCronSecret: typeof requireCronSecret;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  requireCronSecret,
};

export function createSettlePredictionNotificationsHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
    }

    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    try {
      deps.requireCronSecret(request);

      const adminClient = deps.createAdminClient();

      // 1. Fetch pending prediction notifications
      const { data: pending, error: fetchError } = await adminClient.rpc(
        "prediction_get_pending_notifications",
      );

      if (fetchError) {
        throw new HttpError(500, `Failed to fetch pending notifications: ${fetchError.message}`);
      }

      const pendingPayload =
        pending && typeof pending === "object" && !Array.isArray(pending)
          ? pending as Record<string, unknown>
          : null;

      const notifications = Array.isArray(pendingPayload?.notifications)
        ? pendingPayload!.notifications as Record<string, unknown>[]
        : Array.isArray(pending)
          ? pending as Record<string, unknown>[]
          : [];

      if (notifications.length === 0) {
        return jsonOk({
          success: true,
          data: { processed: 0, sent: 0, failed: 0, message: "No pending notifications." },
        });
      }

      let sent = 0;
      let failed = 0;
      const sentIds: string[] = [];

      for (const notif of notifications) {
        const notificationId = notif.id?.toString() ?? "";
        const userId = notif.user_id?.toString() ?? "";
        const title = notif.title?.toString() ?? "Prediction Result";
        const body = notif.body?.toString() ?? "Your prediction has been settled!";
        const payload =
          notif.payload && typeof notif.payload === "object"
            ? notif.payload as Record<string, unknown>
            : {};

        if (!notificationId || !userId) {
          failed++;
          continue;
        }

        try {
          const result = await sendToUser(userId, { title, body }, {
            type: "prediction_settlement",
            prediction_id: payload.prediction_id?.toString() ?? "",
            fixture_id: payload.fixture_id?.toString() ?? "",
            result: notif.result?.toString() ?? "unknown",
            route: payload.route?.toString() ?? "",
          });

          if (result.success) {
            sent++;
            sentIds.push(notificationId);
          } else {
            failed++;
            console.error(
              `FCM send failed for user ${userId}:`,
              result.errors,
            );
            // Still mark as sent to avoid infinite retry on token issues
            sentIds.push(notificationId);
          }
        } catch (sendError) {
          failed++;
          console.error(
            `FCM dispatch error for user ${userId}:`,
            sendError,
          );
          // Mark as sent to prevent re-processing on transient errors
          sentIds.push(notificationId);
        }
      }

      // 2. Mark all processed notifications as sent
      if (sentIds.length > 0) {
        const { error: markError } = await adminClient.rpc(
          "prediction_mark_notifications_sent",
          { p_notification_ids: sentIds },
        );

        if (markError) {
          console.error("Failed to mark notifications as sent:", markError);
        }
      }

      return jsonOk({
        success: true,
        data: {
          processed: notifications.length,
          sent,
          failed,
          marked_sent: sentIds.length,
        },
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }

      console.error("settle-prediction-notifications failed:", error);
      return jsonError(
        error instanceof Error
          ? error.message
          : "Prediction notification dispatch failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createSettlePredictionNotificationsHandler();
  Deno.serve((req: Request) =>
    handler(req).then(
      (res) =>
        new Response(res.body, {
          ...res,
          headers: {
            ...Object.fromEntries(res.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  );
}
