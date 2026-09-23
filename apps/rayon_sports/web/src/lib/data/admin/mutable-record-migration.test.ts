import { describe, expect, it } from "vitest";
import { readNormalizedFootballBaseline } from "./football-baseline-test-support";

const migration = readNormalizedFootballBaseline();

describe("mutable-record database concurrency boundary", () => {
  it("versions contribution rows and compares the loaded token", () => {
    expect(migration).toContain(
      "alter table public.group_contributions",
    );
    expect(migration).toContain(
      "trg_group_contributions_set_updated_at",
    );
    expect(migration).toMatch(
      /updated_at\s*=\s*p_expected_updated_at/i,
    );
  });

  it("keeps supporter order cancellation scoped and fail-closed", () => {
    expect(migration).toContain(
      "cancel_shop_order_if_unchanged",
    );
    expect(migration).toContain("user_id = v_actor_id");
    expect(migration).toContain("status = 'pending'");
    expect(migration).toContain("to authenticated");
  });

  it("audits contribution review in the same atomic function", () => {
    expect(migration).toContain(
      "admin_review_group_contribution_if_unchanged",
    );
    expect(migration).toMatch(/security definer/i);
    expect(migration).toMatch(
      /insert into public\.admin_audit_log/i,
    );
    expect(migration).toMatch(
      /revoke all on function public\.admin_review_group_contribution_if_unchanged[\s\S]*from public;/i,
    );
    expect(migration).toMatch(
      /grant all on function public\.admin_review_group_contribution_if_unchanged[\s\S]*to service_role;/i,
    );
  });

  it("reviews membership applications and materializes approvals atomically", () => {
    expect(migration).toContain(
      "admin_review_membership_application_if_unchanged",
    );
    expect(migration).toContain(
      "v_previous.updated_at is distinct from p_expected_updated_at",
    );
    expect(migration).toContain(
      "v_previous.payment_status <> 'paid'",
    );
    expect(migration).toContain("public.apply_membership_points");
    expect(migration).toContain(
      "'membership_application_review'",
    );
  });

  it("treats feature, channel, and rule configuration as one versioned aggregate", () => {
    expect(migration).toContain(
      "touch_platform_feature_parent_version",
    );
    expect(migration).toContain(
      "trg_platform_feature_channels_touch_parent",
    );
    expect(migration).toContain(
      "trg_platform_feature_rules_touch_parent",
    );
    expect(migration).toContain(
      "admin_update_platform_feature_if_unchanged",
    );
    expect(migration).toContain("on conflict (feature_id, channel)");
    expect(migration).toContain("on conflict (feature_id)");
    expect(migration).toContain("'platform_feature_update'");
  });
});
