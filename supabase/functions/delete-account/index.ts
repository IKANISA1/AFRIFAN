import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  corsPreflightResponse,
  errorResponse,
  jsonError,
  jsonOk,
  withEdgeBoundary,
} from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import {
  HttpError,
  requireCronSecret,
  requireGlobalAdminCaller,
} from "../_shared/auth.ts";
import {
  createLifecycleAdminClient,
  createLifecycleUserClient,
} from "../_shared/account_lifecycle_client.ts";
import {
  lifecycleRpc,
  processAccountClosures,
  requestAccountClosure,
} from "../_shared/account_lifecycle.ts";

const defaults = {
  createAdminClient: createLifecycleAdminClient,
  createUserClient: createLifecycleUserClient,
  enforceRateLimit,
  requireCronSecret,
  requireGlobalAdminCaller,
  processAccountClosures,
};
export function createHandler(dependencies: Partial<typeof defaults> = {}) {
  const deps = { ...defaults, ...dependencies };
  return async function handleRequest(request: Request): Promise<Response> {
    if (request.method === "OPTIONS") return corsPreflightResponse(request);
    if (request.method !== "POST") return jsonError("Method not allowed", 405);
    try {
      const action = new URL(request.url).searchParams.get("action") ??
        "request";
      const admin = deps.createAdminClient();
      if (action === "status") {
        const body = await readBoundedJson<{ request_id: string }>(request, {
          maxBytes: 4096,
        });
        if (
          !/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i
            .test(body.request_id ?? "")
        ) throw new HttpError(400, "Valid request reference required.");
        await deps.enforceRateLimit(
          admin,
          "internal:account-erasure-status",
          "account-erasure-status",
          { maxRequests: 120, windowSeconds: 60 },
        );
        const { data, error } = await admin.rpc("get_account_erasure_status", {
          p_request_id: body.request_id,
        });
        if (error) {
          throw new HttpError(503, "Account closure status is unavailable.");
        }
        if (!data) {
          throw new HttpError(404, "Account closure request not found.");
        }
        return jsonOk({ success: true, data });
      }
      if (action === "process") {
        deps.requireCronSecret(request, [
          "ACCOUNT_ERASURE_CRON_SECRET",
          "CRON_JOB_SECRET",
        ]);
        await readBoundedJson(request, { allowEmpty: true, maxBytes: 4096 });
        return jsonOk(await deps.processAccountClosures(admin));
      }
      if (action === "acknowledge") {
        const actor = await deps.requireGlobalAdminCaller(request);
        const body = await readBoundedJson<
          { request_id: string; step: string; evidence_reference: string }
        >(request, { maxBytes: 4096 });
        return jsonOk(
          await lifecycleRpc(admin, "acknowledge_account_erasure_obligation", {
            p_job_id: body.request_id,
            p_actor_user_id: actor.userId,
            p_step: body.step,
            p_evidence_reference: body.evidence_reference,
          }),
        );
      }
      if (action !== "request") {
        throw new HttpError(400, "Unsupported account closure action.");
      }
      // This one endpoint accepts an already-pending account for idempotent receipt recovery.
      // It does not grant any mutation authority outside request_account_erasure.
      const authorization = request.headers.get("authorization");
      if (!authorization) throw new HttpError(401, "Authentication required.");
      const { data: { user }, error } = await deps.createUserClient(
        authorization,
      ).auth.getUser();
      if (error || !user) throw new HttpError(401, "Authentication required.");
      await deps.enforceRateLimit(admin, user.id, "delete-account", {
        maxRequests: 3,
        windowSeconds: 3600,
      });
      const body = await readBoundedJson<
        { user_id?: string; request_id?: string }
      >(request, {
        allowEmpty: true,
        maxBytes: 4096,
      });
      if (body.user_id && body.user_id !== user.id) {
        throw new HttpError(
          403,
          "You can only close the currently authenticated account.",
        );
      }
      if (
        body.request_id &&
        !/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i
          .test(body.request_id)
      ) throw new HttpError(400, "Valid request reference required.");
      const receipt = await requestAccountClosure(
        admin,
        user.id,
        body.request_id,
      );
      // No irreversible processor call occurs on the request route. The durable job
      // is the receipt; asynchronous work remains visible as pending or failed.
      return jsonOk({ success: true, data: receipt }, 202);
    } catch (error) {
      return errorResponse(error);
    }
  };
}
export const handleRequest = createHandler();
if (import.meta.main) Deno.serve(withEdgeBoundary(handleRequest));
