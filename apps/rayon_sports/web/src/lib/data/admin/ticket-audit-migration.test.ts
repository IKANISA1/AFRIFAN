import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = resolve(
  process.cwd(),
  "../../../supabase/migrations/20260724203000_admin_ticket_status_audit.sql",
);
const migration = readFileSync(migrationPath, "utf8");

describe("ticket status database boundary", () => {
  it("is service-role only and records each mutation in the same function", () => {
    expect(migration).toMatch(/security definer/i);
    expect(migration).toMatch(/revoke all[\s\S]*from public, anon, authenticated/i);
    expect(migration).toMatch(/grant execute[\s\S]*to service_role/i);
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
