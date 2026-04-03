import {
  buildContributionExcel,
  deriveAdminAccess,
  formatAdminRoleLabel,
} from "@/lib/data/admin";

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
    expect(access.role).toBe("club_admin");
  });

  it("falls back to metadata role when assignments are missing", () => {
    const access = deriveAdminAccess(
      {
        app_metadata: { role: "super_admin", club_id: "24" },
        user_metadata: {},
      },
      [],
    );

    expect(access.hasAccess).toBe(true);
    expect(access.isSuperAdmin).toBe(true);
    expect(formatAdminRoleLabel(access.role)).toBe("super admin");
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

  it("builds contribution Excel data structure", () => {
    const { headers, rows } = buildContributionExcel({
      groups: [
        {
          id: "group-1",
          name: "Blue Wall Fund",
          description: "Matchday tifo support",
          privacy: "public",
          groupType: "project",
          targetAmount: 1000000,
          currentTotal: 550000,
          currency: "RWF",
          memberCount: 32,
          inviteCode: "BLUE",
          isActive: true,
          creatorId: "user-1",
          createdAt: "2026-04-03T08:00:00.000Z",
          isClosed: false,
        },
      ],
      contributions: [],
      aliases: {},
      monthlyTotal: 550000,
    });

    expect(headers).toContain("Name");
    expect(headers).toContain("Total (RWF)");
    expect(rows.length).toBe(1);
    expect(rows[0][0]).toBe("Blue Wall Fund");
    expect(rows[0][1]).toBe("project");
    expect(rows[0][2]).toBe(550000);
  });
});

