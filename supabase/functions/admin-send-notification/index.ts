import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireAdminCaller } from "../_shared/auth.ts";
import {
  audienceColumns,
  buildDeliveryUpdate,
  dispatchNotification,
  parseNotificationRequest,
  resolveCallerClubId,
  selectRecipientUserIds,
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
  requireAdminCaller: typeof requireAdminCaller;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  requireAdminCaller,
};

export function createAdminSendNotificationHandler(
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
      const caller = await deps.requireAdminCaller(request);
      const adminClient = deps.createAdminClient();

      const body = await request.json() as Record<string, unknown>;
      const payload = parseNotificationRequest(body);
      const clubId = await resolveCallerClubId(adminClient, caller);

      const seedRow = {
        club_id: clubId,
        created_by: caller.userId,
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
        throw new HttpError(500, "Failed to create notification job.");
      }

      if (payload.deliveryMode === "schedule") {
        const recipients = await selectRecipientUserIds(
          adminClient,
          clubId,
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
          throw new HttpError(
            500,
            "Failed to finalize scheduled notification.",
          );
        }

        return jsonResponse({
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
          throw new HttpError(
            500,
            "Failed to persist notification delivery result.",
          );
        }

        return jsonResponse({
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
      if (error instanceof HttpError) {
        return errorResponse(error.message, error.status);
      }

      return errorResponse(
        error instanceof Error
          ? error.message
          : "Notification delivery failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createAdminSendNotificationHandler());
}
