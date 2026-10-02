import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { errorResponse } from "../_shared/response.ts";
import { withEdgeBoundary } from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  parseNotificationCommand,
  resolveNotificationCommand,
} from "../_shared/notification_command.ts";
import { dispatchNotificationCommand } from "../_shared/notification_dispatch.ts";
import { prepareNotificationDeviceSender } from "../_shared/notification_fcm.ts";
import { createLifecycleAdminClient } from "../_shared/account_lifecycle_client.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { enforceFeature } from "../_shared/feature_guard.ts";
import { isErrorResponse, validateRequest } from "../_shared/validation.ts";

type Dependencies = {
  createAdminClient: typeof createLifecycleAdminClient;
  validateRequest: typeof validateRequest;
  enforceFeature: typeof enforceFeature;
  enforceRateLimit: typeof enforceRateLimit;
  resolveCommand: typeof resolveNotificationCommand;
  dispatchCommand: typeof dispatchNotificationCommand;
  prepareSender: typeof prepareNotificationDeviceSender;
};
const defaultDependencies: Dependencies = {
  enforceRateLimit,
  createAdminClient: createLifecycleAdminClient,
  validateRequest,
  enforceFeature,
  resolveCommand: resolveNotificationCommand,
  dispatchCommand: dispatchNotificationCommand,
  prepareSender: prepareNotificationDeviceSender,
};

export function createAdminSendNotificationHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps = { ...defaultDependencies, ...dependencies };
  return async (request: Request) => {
    if (request.method === "OPTIONS") return corsPreflightResponse(request);
    if (request.method !== "POST") return jsonError("Method not allowed", 405);
    try {
      // The actual current GLOBAL assignment and provider-verified same JWT remain
      // required. Selected club is explicitly admitted by SQL, never metadata authority.
      const validated = await deps.validateRequest(request, {
        requireAdmin: true,
      });
      if (isErrorResponse(validated)) return validated;
      const command = parseNotificationCommand(
        await readBoundedJson(request, { maxBytes: 8192 }),
      );
      if (command.action === "submit") {
        const guard = await deps.enforceFeature(validated.supabase, {
          featureKey: "notifications",
          channel: "mobile",
          clubId: command.clubId,
          isAuthenticated: true,
          roles: validated.roles,
        });
        if (guard) return guard;
      }
      const admin = deps.createAdminClient();
      await deps.enforceRateLimit(
        admin,
        validated.userId,
        command.action === "status"
          ? "admin-notification-status"
          : "admin-send-notification",
        {
          maxRequests: command.action === "status" ? 40 : 10,
          windowSeconds: 60,
          clubId: command.clubId,
        },
      );
      const authorization = request.headers.get("authorization")!;
      let receipt = await deps.resolveCommand(
        authorization,
        validated.userId,
        command,
      );
      // Status can only recover an existing outcome. It never starts or renews work.
      if (
        command.action === "submit" &&
        receipt.command.delivery_mode === "send_now" &&
        ["admitted", "processing"].includes(receipt.command.state)
      ) {
        await deps.dispatchCommand(admin, command.operationId, {
          prepareSender: deps.prepareSender,
        }, {
          deadlineAt: Date.now() + 30000,
          proofId: receipt.dispatch_proof_id,
        });
        receipt = await deps.resolveCommand(authorization, validated.userId, {
          ...command,
          action: "status",
          arguments: null,
        });
      }
      return jsonOk({ success: true, data: receipt });
    } catch (error) {
      // Never mark an uncertain provider call failed or mint a replacement operation.
      logDiagnostic("error", "admin_send_notification_command_failed", error);
      return errorResponse(error);
    }
  };
}

if (import.meta.main) {
  const handler = createAdminSendNotificationHandler();
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
