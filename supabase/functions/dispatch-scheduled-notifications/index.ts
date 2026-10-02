import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { errorResponse } from "../_shared/response.ts";
import { withEdgeBoundary } from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireCronSecret } from "../_shared/auth.ts";
import { dispatchNotificationCommand } from "../_shared/notification_dispatch.ts";
import { prepareNotificationDeviceSender } from "../_shared/notification_fcm.ts";
import { createLifecycleAdminClient } from "../_shared/account_lifecycle_client.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";

type Dependencies = {
  createAdminClient: typeof createLifecycleAdminClient;
  requireCronSecret: typeof requireCronSecret;
  enforceRateLimit: typeof enforceRateLimit;
  dispatchCommand: typeof dispatchNotificationCommand;
  prepareSender: typeof prepareNotificationDeviceSender;
};
const defaultDependencies: Dependencies = {
  enforceRateLimit,
  createAdminClient: createLifecycleAdminClient,
  requireCronSecret,
  dispatchCommand: dispatchNotificationCommand,
  prepareSender: prepareNotificationDeviceSender,
};
function parseLimit(body: Record<string, unknown>): number {
  if (body.limit === undefined) return 25;
  const raw = typeof body.limit === "string" && /^[1-9][0-9]*$/.test(body.limit)
    ? Number(body.limit)
    : body.limit;
  if (!Number.isSafeInteger(raw) || Number(raw) < 1 || Number(raw) > 50) {
    throw new HttpError(400, "limit must be an integer from 1 to 50.");
  }
  return Number(raw);
}
export function createDispatchScheduledNotificationsHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps = { ...defaultDependencies, ...dependencies };
  return async (request: Request) => {
    if (request.method === "OPTIONS") return corsPreflightResponse(request);
    if (request.method !== "POST") return jsonError("Method not allowed", 405);
    try {
      deps.requireCronSecret(request);
      const body = await readBoundedJson(request, {
        allowEmpty: true,
        maxBytes: 1024,
      });
      if (Object.keys(body).some((key) => key !== "limit")) {
        throw new HttpError(400, "Unexpected dispatcher fields.");
      }
      const limit = parseLimit(body);
      const admin = deps.createAdminClient();
      await deps.enforceRateLimit(
        admin,
        "internal-notification-dispatch",
        "dispatch-scheduled-notifications",
        { maxRequests: 20, windowSeconds: 60 },
      );
      const due = await admin.rpc("list_due_admin_notification_commands", {
        p_limit: limit,
      });
      if (due.error || !Array.isArray(due.data) || due.data.length > limit) {
        throw new HttpError(
          502,
          "Scheduled notification commands could not be loaded.",
        );
      }
      const counts = {
        processed: 0,
        sent: 0,
        partial: 0,
        failed: 0,
        unknown: 0,
        processing: 0,
        fetched: due.data.length,
      };
      const deadlineAt = Date.now() + 30000;
      for (const item of due.data) {
        if (Date.now() >= deadlineAt) break;
        if (
          !item || typeof item.operation_id !== "string" ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
            .test(item.operation_id)
        ) {
          throw new HttpError(
            502,
            "Invalid scheduled notification command identity.",
          );
        }
        try {
          const receipt = await deps.dispatchCommand(admin, item.operation_id, {
            prepareSender: deps.prepareSender,
          }, { deadlineAt });
          if (!receipt) continue;
          counts.processed++;
          const status = receipt.delivery?.status;
          if (status && status !== "scheduled") counts[status]++;
        } catch (error) {
          // Per-device started rows and the lease remain authoritative on unknown outcomes.
          // A later worker may claim only devices which never started.
          counts.unknown++;
          logDiagnostic(
            "error",
            "scheduled_notification_command_uncertain",
            error,
          );
        }
      }
      return jsonOk({ success: true, data: counts });
    } catch (error) {
      logDiagnostic(
        "error",
        "dispatch_scheduled_notification_commands_failed",
        error,
      );
      return errorResponse(error);
    }
  };
}

if (import.meta.main) {
  const handler = createDispatchScheduledNotificationsHandler();
  Deno.serve(withEdgeBoundary((req: Request) =>
    handler(req).then(
      (res) =>
        new Response(res.body, {
          status: res.status,
          statusText: res.statusText,
          headers: {
            ...Object.fromEntries(res.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  ));
}
