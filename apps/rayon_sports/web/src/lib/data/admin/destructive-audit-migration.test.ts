import { readNormalizedFootballBaseline } from "./football-baseline-test-support";

const migration = readNormalizedFootballBaseline();

describe("admin destructive action audit migration", () => {
  it("keeps role validation, delete, and immutable audit evidence atomic", () => {
    expect(migration).toMatch(
      /create or replace function public\.admin_delete_mutable_record_if_unchanged/i,
    );
    expect(migration).toMatch(/admin_role_assignments/i);
    expect(migration).toMatch(/assignment\.role = 'club_admin'/i);
    expect(migration).toMatch(/assignment\.club_id = p_club_id/i);
    expect(migration).toMatch(/delete from public\.\%I/i);
    expect(migration).toMatch(/updated_at = \$2/i);
    expect(migration).toMatch(/insert into public\.admin_audit_log/i);
  });

  it("is service-role only and restricts deletion to an explicit table allowlist", () => {
    expect(migration).toMatch(/v_allowed_tables constant text\[\]/i);
    expect(migration).toMatch(/not \(p_table_name = any\(v_allowed_tables\)\)/i);
    expect(migration).toMatch(
      /revoke all on function public\.admin_delete_mutable_record_if_unchanged[\s\S]+from public;/i,
    );
    expect(migration).toMatch(
      /grant all on function public\.admin_delete_mutable_record_if_unchanged[\s\S]+to service_role;/i,
    );
  });

  it("adds immutable audit evidence for SMS rejection transitions", () => {
    expect(migration).toMatch(
      /create or replace function public\.audit_admin_sms_review_rejection/i,
    );
    expect(migration).toMatch(
      /after update of match_status on public\.momo_reconciliations/i,
    );
    expect(migration).toMatch(/new\.match_status = 'rejected'/i);
    expect(migration).toMatch(/'reject_sms_manual_review'/i);
    expect(migration).toMatch(/insert into public\.admin_audit_log/i);
  });
});
