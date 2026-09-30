/** Finite diagnostic events only. Error objects, URLs and caller text are never accepted. */
const events = {
  feature_config_rpc_failed: "error",
  feature_config_unavailable: "error",
  feature_guard_rpc_failed: "error",
  feature_guard_unavailable: "error",
  push_unconfigured: "warn",
  push_subscription_failed: "error",
  push_registration_failed: "error",
  share_fallback: "warn",
  offline_queue_write_failed: "error",
  offline_queue_clear_failed: "error",
  offline_mutation_outcome_unknown: "warn",
} as const;

export type ProductDiagnostic = keyof typeof events;

export function recordProductDiagnostic(event: ProductDiagnostic): boolean {
  try {
    if (typeof event !== "string" || !Object.hasOwn(events, event)) return false;
    const level = events[event];
    console[level](Object.freeze({ schemaVersion: 1, service: "web", event, level }));
    return true;
  } catch {
    // Diagnostics cannot change the original result or cause a command retry.
    return false;
  }
}
