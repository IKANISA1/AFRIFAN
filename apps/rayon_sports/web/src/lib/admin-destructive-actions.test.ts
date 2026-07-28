import type { AdminAccess } from "@/lib/types";
import {
  adminDestructiveActions,
  getAdminDestructiveActionContract,
  getAdminDestructivePermission,
  getAdminDestructiveRouteContract,
} from "./admin-destructive-actions";

function access(
  role: AdminAccess["role"],
  clubId: string | null = "24",
): AdminAccess {
  const isSuperAdmin = role === "super_admin" || role === "admin";
  return {
    hasAccess: role != null && role !== "fan",
    isAuthenticated: true,
    isSuperAdmin,
    userId: "00000000-0000-4000-8000-000000000024",
    role,
    clubId,
    availableClubIds: clubId == null ? [] : [clubId],
    canSelectClub: isSuperAdmin,
    assignmentCount: 1,
  };
}

describe("admin destructive action governance", () => {
  it("declares unique actions and route resources", () => {
    const ids = adminDestructiveActions.map((action) => action.id);
    const resources = adminDestructiveActions
      .map((action) => action.routeResource)
      .filter((resource): resource is string => resource != null);
    expect(new Set(ids).size).toBe(ids.length);
    expect(new Set(resources).size).toBe(resources.length);
    expect(adminDestructiveActions.length).toBeGreaterThanOrEqual(25);
  });

  it.each(adminDestructiveActions)(
    "$id declares review, scope, concurrency, audit, and recovery",
    (action) => {
      expect(action.label).not.toHaveLength(0);
      expect(action.source).not.toHaveLength(0);
      expect(action.selectionLimit).toBeGreaterThan(0);
      expect(action.review).toMatch(/structured_confirm|review_drawer/);
      expect(action.scope).toMatch(/active_club|platform|record_and_active_club/);
      expect(action.audit).toMatch(/atomic_delete_rpc|transactional_domain_rpc/);
      expect(action.concurrency).toMatch(
        /loaded_version|domain_state_and_version/,
      );
      expect(action.undo).toMatch(/manual_recovery|not_available/);
    },
  );

  it("limits reviewed bulk selection to the ticket workflow", () => {
    const bulk = adminDestructiveActions.filter(
      (action) => action.selection === "reviewed_bulk",
    );
    expect(bulk).toEqual([
      expect.objectContaining({
        id: "bulk-cancel-tickets",
        selectionLimit: 100,
        review: "review_drawer",
      }),
    ]);
  });

  it("allows a platform admin to execute platform and club actions", () => {
    for (const action of adminDestructiveActions) {
      expect(
        getAdminDestructivePermission(access("admin"), action),
      ).toEqual({ allowed: true, reason: null });
    }
  });

  it("allows club admins only club-scoped destructive actions", () => {
    expect(
      getAdminDestructivePermission(
        access("club_admin"),
        getAdminDestructiveActionContract("delete-match")!,
      ),
    ).toEqual({ allowed: true, reason: null });
    expect(
      getAdminDestructivePermission(
        access("club_admin"),
        getAdminDestructiveActionContract("delete-partner-offer")!,
      ),
    ).toEqual({
      allowed: false,
      reason: "Platform admin access is required.",
    });
  });

  it("denies moderators, fans, missing scope, and unauthenticated actors", () => {
    const contract = getAdminDestructiveActionContract("delete-match")!;
    expect(
      getAdminDestructivePermission(access("club_moderator"), contract),
    ).toEqual({
      allowed: false,
      reason: "Club-admin access is required.",
    });
    expect(
      getAdminDestructivePermission(access("club_admin", null), contract),
    ).toEqual({
      allowed: false,
      reason: "An active club scope is required.",
    });
    expect(
      getAdminDestructivePermission(access("fan"), contract).allowed,
    ).toBe(false);
  });

  it("maps every generic DELETE resource to an explicit contract", () => {
    for (const resource of [
      "access",
      "matches",
      "cms",
      "cms-config",
      "cms-content",
      "membership",
      "shop",
      "fan-clubs",
      "standings",
      "contributions",
      "squad",
      "gamification",
      "offers",
      "livescore-sources",
      "runtime-routes",
      "runtime-option-sets",
      "runtime-option-values",
      "runtime-copy",
      "runtime-navigation",
      "runtime-search",
      "runtime-venue-controls",
    ]) {
      expect(getAdminDestructiveRouteContract(resource)).not.toBeNull();
    }
  });
});
