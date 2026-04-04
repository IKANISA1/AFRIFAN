import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  audienceColumns,
  buildDeliveryUpdate,
  dispatchNotification,
  parseNotificationRequest,
  selectRecipientUserIds,
} from "../_shared/notifications.ts";
import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type AdminClientLike = ReturnType<typeof createAdminClient>;

type Dependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  validateRequest,
};

export function createAdminSendNotificationHandler(
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
      // Extract userId and clubId from JWT based on new shared architecture
      const validated = await deps.validateRequest(request, { requireClubId: true, requireAdmin: true });
      if (isErrorResponse(validated)) return validated;
      const { userId, clubId } = validated;
      const numericClubId = Number(clubId);
      
      const adminClient = deps.createAdminClient();

      const body = await request.json() as Record<string, unknown>;
      const payload = parseNotificationRequest(body);

      const seedRow = {
        club_id: numericClubId,
        created_by: userId,
        title: payload.title,
        body: payload.body,
        image_url: payload.imageUrl,
        ...audienceColumns(payload.audience),
        delivery_mode: payload.deliveryMode,
        scheduled_at: payload.scheduledAt,
        status: payload.deliveryMode === "schedule"
          ? "scheduled"
          : "processing",
      };

      const { data: created, error: insertError } = await adminClient
        .from("notifications")
        .insert(seedRow)
        .select("*")
        .single();

      if (insertError || !created) {
        throw new Error("Failed to create notification job.");
      }

      if (payload.deliveryMode === "schedule") {
        const recipients = await selectRecipientUserIds(
          adminClient,
          numericClubId,
          payload.audience,
        );

        const update = {
          requested_recipient_count: recipients.length,
          delivery_summary: {
            requested_recipient_count: recipients.length,
            scheduled_at: payload.scheduledAt,
          },
        };

        const { data: scheduled, error: updateError } = await adminClient
          .from("notifications")
          .update(update)
          .eq("id", created["id"])
          .select("*")
          .single();

        if (updateError || !scheduled) {
          throw new Error("Failed to finalize scheduled notification.");
        }

        return jsonOk({
          success: true,
          data: {
            notification: scheduled,
            delivery: {
              status: scheduled["status"],
              requested_recipient_count: scheduled["requested_recipient_count"],
              sent_count: scheduled["sent_count"],
              failed_count: scheduled["failed_count"],
              cleaned_tokens: scheduled["cleaned_tokens"],
              scheduled_at: scheduled["scheduled_at"],
            },
          },
        });
      }

      try {
        const delivery = await dispatchNotification(adminClient, created);
        const { data: delivered, error: updateError } = await adminClient
          .from("notifications")
          .update(buildDeliveryUpdate(delivery))
          .eq("id", created["id"])
          .select("*")
          .single();

        if (updateError || !delivered) {
          throw new Error("Failed to persist notification delivery result.");
        }

        return jsonOk({
          success: true,
          data: {
            notification: delivered,
            delivery: {
              status: delivery.status,
              requested_recipient_count: delivery.requestedRecipientCount,
              successful_user_count: delivery.successfulUserCount,
              failed_user_count: delivery.failedUserCount,
              sent_count: delivery.sentCount,
              failed_count: delivery.failedCount,
              cleaned_tokens: delivery.cleanedTokens,
              errors: delivery.errors,
            },
          },
        });
      } catch (error) {
        const failureMessage = error instanceof Error
          ? error.message
          : "Notification delivery failed.";

        await adminClient
          .from("notifications")
          .update({
            status: "failed",
            last_error: failureMessage,
            sent_at: new Date().toISOString(),
            delivery_summary: { errors: [failureMessage] },
          })
          .eq("id", created["id"]);

        throw error;
      }
    } catch (error) {
      console.error("admin-send-notification failed:", error);
      return jsonError(
        error instanceof Error
          ? error.message
          : "Notification delivery failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createAdminSendNotificationHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
