import {
  catalogValue,
  diagnosticError,
  diagnosticMetadata,
  HEALTH_FUNCTIONS,
  HEALTH_ISSUES,
  HEALTH_SERVICES,
  logDiagnostic,
} from "./diagnostics.ts";
import type { createAdminClient } from "./supabase.ts";

type AdminClient = ReturnType<typeof createAdminClient>;

export type OperationalEventStatus = "ok" | "warn" | "error";
export type OperationalEventSeverity = "info" | "warning" | "critical";
export type OperationalEventIngestOrigin = "system" | "mobile_app";

export type OperationalHealthEventInput = {
  service: string;
  component?: string | null;
  status?: OperationalEventStatus;
  severity?: OperationalEventSeverity;
  issueCode?: string | null;
  message: string;
  functionName?: string | null;
  userId?: string | null;
  subjectType?: string | null;
  subjectId?: string | null;
  metadata?: Record<string, unknown>;
  occurredAt?: string | null;
  ingestOrigin?: OperationalEventIngestOrigin;
};

function defaultSeverity(
  status: OperationalEventStatus | undefined,
): OperationalEventSeverity {
  switch (status) {
    case "warn":
      return "warning";
    case "error":
      return "critical";
    default:
      return "info";
  }
}

export async function recordOperationalHealthEvent(
  adminClient: AdminClient,
  event: OperationalHealthEventInput,
) {
  try {
    const service = catalogValue(event.service, HEALTH_SERVICES, "client");
    const functionName = catalogValue(
      event.functionName,
      HEALTH_FUNCTIONS,
      null,
    );
    const issueCode = event.issueCode == null
      ? null
      : catalogValue(event.issueCode, HEALTH_ISSUES, "operational_event");
    const status = ["ok", "warn", "error"].includes(event.status ?? "")
      ? event.status
      : "ok";
    const severity =
      ["info", "warning", "critical"].includes(event.severity ?? "")
        ? event.severity
        : defaultSeverity(status);
    const occurredAt = typeof event.occurredAt === "string" &&
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(
          event.occurredAt,
        ) &&
        Number.isFinite(Date.parse(event.occurredAt))
      ? event.occurredAt
      : new Date().toISOString();
    const { error } = await adminClient
      .from("operational_health_events")
      .insert({
        service,
        component: catalogValue(event.component, HEALTH_FUNCTIONS, "general"),
        status,
        severity,
        issue_code: issueCode,
        message: status === "error"
          ? "Operational health failure."
          : status === "warn"
          ? "Operational health requires review."
          : "Operational health event.",
        function_name: functionName,
        // These are diagnostics. Transaction/receipt/audit tables keep their
        // authorised identities; health telemetry does not duplicate them.
        user_id: null,
        subject_type: null,
        subject_id: null,
        metadata: diagnosticMetadata(event.metadata),
        occurred_at: occurredAt,
        ingest_origin: event.ingestOrigin === "mobile_app"
          ? "mobile_app"
          : "system",
      });

    if (error) {
      logDiagnostic(
        "error",
        "observability_operational_health_event_insert_failed",
        error,
      );
    }
  } catch (error) {
    logDiagnostic(
      "error",
      "observability_operational_health_event_insert_crashed",
      error,
    );
  }
}

export async function recordEdgeFunctionFailure(
  adminClient: AdminClient,
  options: {
    functionName: string;
    error: unknown;
    userId?: string | null;
    issueCode?: string | null;
    subjectType?: string | null;
    subjectId?: string | null;
    metadata?: Record<string, unknown>;
  },
) {
  await recordOperationalHealthEvent(adminClient, {
    service: "edge_function",
    component: options.functionName,
    status: "error",
    severity: "critical",
    issueCode: options.issueCode ?? "function_invocation_failed",
    message: "Edge Function invocation failed.",
    functionName: options.functionName,
    userId: options.userId,
    subjectType: options.subjectType,
    subjectId: options.subjectId,
    metadata: {
      ...diagnosticMetadata(options.metadata),
      ...diagnosticError(options.error),
    },
  });
}
