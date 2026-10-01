import { describe, expect, it } from "vitest";
import { inspectStaffAssurance } from "./staff-assurance";

const now = 1_790_881_000;
const claims = { sub: "staff-a", role: "authenticated", is_anonymous: false, aal: "aal2", exp: now + 600, amr: [{ method: "totp", timestamp: now - 20 }] };

describe("staff assurance from verified claims", () => {
  it.each(["totp", "mfa/totp"])("accepts fresh %s and bounds expiry by token and actual second-factor time", (method) => {
    expect(inspectStaffAssurance({ ...claims, amr: [{ method, timestamp: now - 20 }] }, "staff-a", now)).toEqual({ allowed: true, expiresAt: now + 280 });
    expect(inspectStaffAssurance({ ...claims, exp: now + 10 }, "staff-a", now).expiresAt).toBe(now + 10);
  });
  it.each([
    { aal: "aal1" }, { sub: "staff-b" }, { role: "service_role" }, { is_anonymous: true },
    { is_anonymous: undefined }, { is_anonymous: "false" },
    { exp: now }, { exp: String(now + 600) }, { amr: [] }, { amr: ["totp"] },
    { amr: [{ method: "otp", timestamp: now }] }, { amr: [{ method: "totp", timestamp: now - 300 }] },
    { amr: [{ method: "totp", timestamp: now + 31 }] }, { amr: [{ method: "totp", timestamp: String(now) }] },
    { amr: [{ method: "totp", timestamp: now + 0.5 }] }, { amr: Array(17).fill({ method: "totp", timestamp: now }) },
  ])("denies absent, stale, foreign or invalid assurance %j", (override) => {
    expect(inspectStaffAssurance({ ...claims, ...override }, "staff-a", now).allowed).toBe(false);
  });
  it("ignores metadata assurances and denies malformed claims", () => {
    expect(inspectStaffAssurance({ ...claims, aal: "aal1", app_metadata: { aal: "aal2", mfa: true } }, "staff-a", now).allowed).toBe(false);
    expect(inspectStaffAssurance(null, "staff-a", now).allowed).toBe(false);
    expect(inspectStaffAssurance(claims, "", now).allowed).toBe(false);
  });
});
