import { describe, expect, it } from "vitest";
import { normalizeAdminRoleAssignments } from "./page";

describe("admin access response normalization", () => {
  it("bounds records, removes extra private fields, and rejects invalid rows", () => {
    const input = [
      {
        id: "assignment-1",
        userId: "user-1",
        userName: "Aline Platform",
        userPhone: "+250788000001",
        userEmail: null,
        publicUserId: "AF-0001",
        role: "super_admin",
        clubId: null,
        clubName: null,
        partnerScopeId: null,
        partnerName: null,
        grantedBy: "governance-user",
        grantedByName: "Governance team",
        grantedAt: "2026-07-29T12:00:00.000Z",
        revokedAt: null,
        isActive: true,
        notes: null,
        accessToken: "private-token",
      },
      {
        id: "invalid",
        userId: "user-2",
        userName: "Invalid Role",
        role: "owner",
        grantedAt: "not-a-date",
      },
    ];

    const result = normalizeAdminRoleAssignments(input);

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      id: "assignment-1",
      userName: "Aline Platform",
      role: "super_admin",
      isActive: true,
    });
    expect(result[0]).not.toHaveProperty("accessToken");
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminRoleAssignments({ data: [] })).toEqual([]);
  });
});
