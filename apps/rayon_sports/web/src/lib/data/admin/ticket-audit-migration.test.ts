import { describe, expect, it } from "vitest";
import { readNormalizedFootballBaseline } from "./football-baseline-test-support";

const migration = readNormalizedFootballBaseline();

describe("ticket status database boundary", () => {
  it("is service-role only and records each mutation in the same function", () => {
    expect(migration).toMatch(/security definer/i);
    expect(migration).toMatch(
      /revoke all on function public\.admin_bulk_update_ticket_status_if_unchanged[\s\S]*from public;/i,
    );
    expect(migration).toMatch(
      /grant all on function public\.admin_bulk_update_ticket_status_if_unchanged[\s\S]*to service_role;/i,
    );
    expect(migration).toMatch(/insert into public\.admin_audit_log/i);
    expect(migration).toMatch(/update public\.tickets/i);
  });

  it("bounds selection, rejects cross-club records, and validates stale transitions", () => {
    expect(migration).toContain("v_requested_count > 100");
    expect(migration).toContain("p_actor_id is null");
    expect(migration).toContain("club_id = p_club_id");
    expect(migration).toContain("v_matched_count <> v_requested_count");
    expect(migration).toContain("stale or invalid status transition");
    expect(migration).toContain("status = 'pending'");
    expect(migration).toContain("status = 'valid'");
  });
});
