import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  type OperationalEventSeverity,
  type OperationalEventStatus,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type RecordOperationalHealthDependencies = {
  createAdminClient: typeof createAdminClient;
  recordOperationalHealthEvent: typeof recordOperationalHealthEvent;
  validateRequest: typeof validateRequest;
};

type RecordOperationalHealthRequest = {
  service?: unknown;
  component?: unknown;
  status?: unknown;
  severity?: unknown;
  issueCode?: unknown;
  issue_code?: unknown;
  message?: unknown;
  functionName?: unknown;
  function_name?: unknown;
  userId?: unknown;
  user_id?: unknown;
  subjectType?: unknown;
  subject_type?: unknown;
  subjectId?: unknown;
  subject_id?: unknown;
  metadata?: unknown;
  occurredAt?: unknown;
  occurred_at?: unknown;
  event_type?: unknown;
  source?: unknown;
};

const defaultDependencies: RecordOperationalHealthDependencies = {
  createAdminClient,
  recordOperationalHealthEvent,
  validateRequest,
};

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function asMetadata(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function normalizeStatus(value: unknown): OperationalEventStatus {
  const normalized = asTrimmedString(value)?.toLowerCase();
  if (normalized == "warn") return "warn";
  if (normalized == "error") return "error";
  return "ok";
}

function normalizeSeverity(value: unknown): OperationalEventSeverity | undefined {
  const normalized = asTrimmedString(value)?.toLowerCase();
  if (normalized == "info") return "info";
  if (normalized == "warning") return "warning";
  if (normalized == "critical") return "critical";
  return undefined;
}

function deriveService(body: RecordOperationalHealthRequest): string | null {
  return asTrimmedString(body.service) ??
    asTrimmedString(body.source) ??
    (asTrimmedString(body.event_type) != null ? "client" : null);
}

function deriveComponent(body: RecordOperationalHealthRequest): string | null {
  return asTrimmedString(body.component) ??
    asTrimmedString(body.event_type) ??
    asTrimmedString(body.source);
}

function deriveMessage(body: RecordOperationalHealthRequest): string | null {
  return asTrimmedString(body.message) ??
    asTrimmedString(body.event_type);
}

export function createRecordOperationalHealthHandler(
  dependencies: Partial<RecordOperationalHealthDependencies> = {},
) {
  const deps: RecordOperationalHealthDependencies = {
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
      const validated = await deps.validateRequest(request);
      if (isErrorResponse(validated)) return validated;
      const { userId } = validated;

      const body = await request.json() as RecordOperationalHealthRequest;
      const service = deriveService(body);
      const message = deriveMessage(body);

      if (service == null || message == null) {
        return jsonError("service and message are required.", 400);
      }

      await deps.recordOperationalHealthEvent(deps.createAdminClient(), {
        service,
        component: deriveComponent(body),
        status: normalizeStatus(body.status),
        severity: normalizeSeverity(body.severity),
        issueCode: asTrimmedString(body.issueCode ?? body.issue_code),
        message,
        functionName: asTrimmedString(body.functionName ?? body.function_name),
        userId: userId,
        subjectType: asTrimmedString(body.subjectType ?? body.subject_type),
        subjectId: asTrimmedString(body.subjectId ?? body.subject_id),
        metadata: asMetadata(body.metadata),
        occurredAt: asTrimmedString(body.occurredAt ?? body.occurred_at),
        ingestOrigin: "mobile_app",
      });

      return jsonOk({ success: true });
    } catch (error) {
      console.error("record-operational-health error:", error);
      return jsonError(
        error instanceof Error ? error.message : "Unknown error",
        500,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createRecordOperationalHealthHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, {
      status: res.status,
      statusText: res.statusText,
      headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() },
    })
  ));
}
