import { DIAGNOSTIC_EVENTS } from "./diagnostic_events.ts";

export type DiagnosticLevel = "error" | "warn" | "info" | "debug";

const ERROR_NAMES = new Set([
  "Error",
  "TypeError",
  "RangeError",
  "SyntaxError",
  "ReferenceError",
  "URIError",
  "EvalError",
  "AggregateError",
  "AbortError",
  "TimeoutError",
  "HttpError",
  "ApiFootballError",
  "RateLimitExceededError",
  "UnknownError",
]);
const ENUM_FIELDS: Record<string, ReadonlySet<string>> = {
  parser_provider: new Set(["gemini", "openai"]),
  parse_status: new Set(["pending", "parsed", "needs_review", "failed"]),
  match_status: new Set([
    "matched",
    "unmatched",
    "needs_review",
    "manual_review",
  ]),
  ingestion_source: new Set([
    "android_sms_listener",
    "android_sms_listener_foreground",
    "android_sms_listener_background",
    "android_sms_initial_sync",
    "android_sms_manual_sync",
  ]),
  source_provider: new Set(["livescore", "api_football"]),
  mode: new Set(["preview", "sync"]),
  error_name: ERROR_NAMES,
};
const NUMBER_FIELDS = new Set([
  "count",
  "attempt",
  "duration_ms",
  "retry_after_seconds",
  "error_count",
  "source_note_count",
  "access_issue_count",
  "allowed_competitions_loaded",
  "openai_requests_used",
  "raw_rows_seen",
  "rows_skipped",
  "non_livescore_rows_rejected",
  "competitions_filtered",
  "competitions_upserted",
  "seasons_upserted",
  "teams_upserted",
  "fixtures_upserted",
  "pools_settled",
]);

/** Only reviewed metrics/enums survive. No recursive traversal or serialization. */
export function diagnosticMetadata(
  value: unknown,
): Record<string, string | number | boolean> {
  const result: Record<string, string | number | boolean> = {};
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return result;
  }
  // Read own data properties only. A hostile getter/toJSON must never run.
  try {
    const fields = Object.getOwnPropertyDescriptors(value);
    for (const key of Object.keys(ENUM_FIELDS)) {
      const item = fields[key]?.value;
      if (typeof item === "string" && ENUM_FIELDS[key].has(item)) {
        result[key] = item;
      }
    }
    for (const key of NUMBER_FIELDS) {
      const item = fields[key]?.value;
      if (
        typeof item === "number" && Number.isSafeInteger(item) && item >= 0 &&
        item <= 1_000_000_000
      ) result[key] = item;
    }
    const status = fields.http_status?.value;
    if (
      typeof status === "number" && Number.isInteger(status) && status >= 100 &&
      status <= 599
    ) result.http_status = status;
    for (const key of ["retryable", "dry_run"]) {
      const item = fields[key]?.value;
      if (typeof item === "boolean") result[key] = item;
    }
  } catch {
    // Proxies and unusual objects fail closed, without dumping the input.
  }
  return result;
}

export function diagnosticError(
  error: unknown,
): Record<string, string | number | boolean> {
  if (error == null || typeof error !== "object") {
    return { error_name: "UnknownError" };
  }
  try {
    const name = Object.getOwnPropertyDescriptor(error, "name")?.value;
    const prototype = Object.getPrototypeOf(error);
    const inheritedName = Object.getOwnPropertyDescriptor(
      prototype ?? {},
      "name",
    )?.value;
    const errorName = typeof name === "string" ? name : inheritedName;
    const fields = diagnosticMetadata(error);
    const status = Object.getOwnPropertyDescriptor(error, "status")?.value;
    if (
      typeof status === "number" && Number.isInteger(status) && status >= 100 &&
      status <= 599
    ) fields.http_status = status;
    return {
      ...fields,
      error_name: typeof errorName === "string" && ERROR_NAMES.has(errorName)
        ? errorName
        : "UnknownError",
    };
  } catch {
    return { error_name: "UnknownError" };
  }
}

/** Console receives one JSON object with a catalog code and bounded safe facts. */
export function logDiagnostic(
  level: DiagnosticLevel,
  event: string,
  error?: unknown,
  metadata?: unknown,
): void {
  const payload = {
    event: DIAGNOSTIC_EVENTS.has(event) ? event : "unknown_diagnostic",
    ...diagnosticMetadata(metadata),
    ...(error === undefined ? {} : diagnosticError(error)),
  };
  const safeLevel = ["error", "warn", "info", "debug"].includes(level)
    ? level
    : "error";
  console[safeLevel](JSON.stringify(payload));
}

export const HEALTH_SERVICES = new Set([
  "edge_function",
  "sms_ingest",
  "momo_parsing",
  "client",
]);
export const HEALTH_FUNCTIONS = new Set([
  "admin-send-notification",
  "admin-settle-fixture",
  "admin-upload-image",
  "delete-account",
  "dispatch-scheduled-notifications",
  "football-sync",
  "generate-admin-image",
  "generate-product-image",
  "get-platform-config",
  "google-wallet-ticket-pass",
  "livescore-openai-sync",
  "parse-momo-sms",
  "record-operational-health",
  "send-notification",
  "send-sms",
  "settle-prediction-notifications",
  "sms-ingest",
  "sync-google-wallet-ticket-state",
]);
export const HEALTH_ISSUES = new Set([
  "parse_queue_failed",
  "payment_requires_review",
  "momo_parse_failed",
  "function_invocation_failed",
  "sms_ingest_failed",
  "operational_event",
]);

export function catalogValue(
  value: unknown,
  catalog: ReadonlySet<string>,
  fallback: string | null,
): string | null {
  return typeof value === "string" && catalog.has(value) ? value : fallback;
}
