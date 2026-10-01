import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { controlledApiJson, withControlledApiTimeout } from "@/lib/controlled-api-response";
import { inspectStaffAssurance } from "@/lib/staff-assurance";

/** Called only after getUser and current assignment authorization succeed. */
export async function rejectStaffWithoutStepUp(client: SupabaseClient, verifiedUserId: string) {
  try {
    // getClaims verifies the current cookie's token with the configured Auth
    // issuer. Cached session/user metadata cannot establish assurance.
    const { data, error } = await withControlledApiTimeout(client.auth.getClaims());
    if (error || !data?.claims) throw new Error("Staff token verification unavailable");
    if (!inspectStaffAssurance(data.claims, verifiedUserId).allowed) {
      return controlledApiJson({
        code: "STAFF_STEP_UP_REQUIRED",
        error: "Verify your authenticator code to continue.",
        retryable: false,
        change_confirmed: false,
      }, 403);
    }
    return null;
  } catch {
    return controlledApiJson({
      code: "STAFF_ASSURANCE_UNAVAILABLE",
      error: "Staff authentication could not be verified. Try again.",
      retryable: true,
      change_confirmed: false,
    }, 503);
  }
}
