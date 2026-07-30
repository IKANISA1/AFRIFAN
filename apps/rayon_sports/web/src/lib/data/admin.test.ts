import {
  buildContributionExcel,
  deriveAdminAccess,
  formatAdminRoleLabel,
} from "@/lib/data/admin";
import {
  adminClubIdOrNull,
  requireAdminClubId,
} from "@/lib/data/admin/helpers";

describe("admin data helpers", () => {
  it("grants club access when assignment matches the active club", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: { club_id: "rayon_sports_rw" },
      },
      [{ role: "club_admin", club_id: 24, is_active: true }],
    );

    expect(access.hasAccess).toBe(true);
    expect(access.clubId).toBe("24");
    expect(access.availableClubIds).toEqual(["24"]);
    expect(access.canSelectClub).toBe(false);
    expect(access.role).toBe("club_admin");
  });

  it("denies access when assignments are missing (metadata alone is insufficient)", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: { role: "super_admin", club_id: "24" },
        user_metadata: {},
      },
      [],
    );

    // Fail-closed: metadata-only role is visible but does NOT grant access.
    expect(access.hasAccess).toBe(false);
    expect(access.isSuperAdmin).toBe(false);
    expect(access.role).toBe("super_admin"); // still resolved, just not trusted
    expect(formatAdminRoleLabel(access.role)).toBe("super admin");
  });

  it("grants access when assignment exists even with empty metadata", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: {},
      },
      [{ role: "admin", club_id: null, is_active: true }],
    );

    expect(access.hasAccess).toBe(true);
    expect(access.isSuperAdmin).toBe(true);
    expect(access.role).toBe("admin");
    expect(access.canSelectClub).toBe(true);
  });

  it("prefers app_metadata.role over user_metadata.role for display", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: { role: "club_admin" },
        user_metadata: { role: "super_admin" },
      },
      [],
    );

    // app_metadata.role takes priority for the resolved role display
    expect(access.role).toBe("club_admin");
    // But still no access without assignment
    expect(access.hasAccess).toBe(false);
  });

  it("maps legacy live admin roles into the web access model", () => {
    const clubAccess = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: { club_id: 1 },
      },
      [{ role: "rayon_sport", club_id: 1, is_active: true }],
    );

    const bankAccess = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: { club_id: 1 },
      },
      [{ role: "bank", club_id: 1, is_active: true }],
    );

    expect(clubAccess.hasAccess).toBe(true);
    expect(clubAccess.role).toBe("club_admin");
    expect(bankAccess.hasAccess).toBe(true);
    expect(bankAccess.role).toBe("club_moderator");
  });

  it("allows a privileged admin to select a requested club context", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: {},
      },
      [
        { role: "admin", club_id: 24, is_active: true },
        { role: "admin", club_id: 48, is_active: true },
      ],
      { requestedClubId: "48" },
    );

    expect(access.hasAccess).toBe(true);
    expect(access.clubId).toBe("48");
    expect(access.availableClubIds).toEqual(["24", "48"]);
    expect(access.canSelectClub).toBe(true);
  });

  it("denies a club admin who requests an unauthorized club context", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: { club_id: 24 },
      },
      [{ role: "club_admin", club_id: 24, is_active: true }],
      { requestedClubId: "99" },
    );

    expect(access.hasAccess).toBe(false);
    expect(access.clubId).toBeNull();
    expect(access.availableClubIds).toEqual(["24"]);
    expect(access.role).toBe("club_admin");
  });

  it("exposes all assigned clubs for multi-club admins without changing access scope", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: {},
        user_metadata: { club_id: 24 },
      },
      [
        { role: "club_admin", club_id: 24, is_active: true },
        { role: "club_admin", club_id: 48, is_active: true },
      ],
    );

    expect(access.hasAccess).toBe(true);
    expect(access.clubId).toBe("24");
    expect(access.availableClubIds).toEqual(["24", "48"]);
    expect(access.canSelectClub).toBe(true);
  });

  it("denies access for null user", () => {
    const access = deriveAdminAccess(null, []);

    expect(access.hasAccess).toBe(false);
    expect(access.isAuthenticated).toBe(false);
    expect(access.role).toBeNull();
  });

  it("normalizes the active club id for scoped admin modules", () => {
    expect(adminClubIdOrNull({ clubId: "24" })).toBe(24);
    expect(adminClubIdOrNull({ clubId: null })).toBeNull();
  });

  it("fails closed when a scoped admin module has no club context", () => {
    expect(() =>
      requireAdminClubId({ clubId: null }, "load scoped admin data"),
    ).toThrow(/Club context is required/i);
  });

  it("builds contribution Excel data structure", () => {
    const { headers, rows } = buildContributionExcel({
      groups: [
        {
          id: "group-1",
          name: "Blue Wall Fund",
          description: "Matchday tifo support",
          groupType: "project",
          targetAmount: 1000000,
          currentTotal: 550000,
          currency: "RWF",
          memberCount: 32,
          isActive: true,
          creatorId: "user-1",
          createdAt: "2026-04-03T08:00:00.000Z",
          updatedAt: "2026-04-03T08:05:00.000Z",
          isClosed: false,
        },
      ],
      contributions: [],
      monthlyTotal: 550000,
    });

    expect(headers).toContain("Name");
    expect(headers).toContain("Currency");
    expect(headers).toContain("Total");
    expect(rows.length).toBe(1);
    expect(rows[0][0]).toBe("Blue Wall Fund");
    expect(rows[0][1]).toBe("project");
    expect(rows[0][2]).toBe("RWF");
    expect(rows[0][3]).toBe(550000);
  });
});
