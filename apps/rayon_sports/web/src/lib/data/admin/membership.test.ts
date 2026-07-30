import { describe, expect, it } from "vitest";
import { normalizeAdminMembershipPackages } from "./membership";

const membershipPackage = {
  id: "tier-1",
  clubId: 24,
  tier: "gold",
  title: "Gold supporter",
  description: "Annual supporter package.",
  sortOrder: 10,
  perks: ["Priority ticketing", "Member events"],
  annualPrice: 75_000,
  isActive: true,
  createdAt: "2026-07-29T10:00:00.000Z",
  updatedAt: "2026-07-29T10:00:00.000Z",
};

describe("membership package normalization", () => {
  it("keeps only strict bounded fields", () => {
    const normalized = normalizeAdminMembershipPackages([
      {
        ...membershipPackage,
        privatePaymentReference: "private",
        metadata: { accessToken: "private" },
      },
    ]);

    expect(normalized).toEqual([membershipPackage]);
    expect(JSON.stringify(normalized)).not.toContain("privatePaymentReference");
    expect(JSON.stringify(normalized)).not.toContain("accessToken");
  });

  it("drops malformed and duplicate packages", () => {
    expect(
      normalizeAdminMembershipPackages([
        membershipPackage,
        { ...membershipPackage, title: "Duplicate" },
        { ...membershipPackage, id: "tier-2", tier: "unknown" },
        { ...membershipPackage, id: "tier-3", annualPrice: -1 },
        { ...membershipPackage, id: "tier-4", updatedAt: "not-a-date" },
      ]),
    ).toEqual([membershipPackage]);
  });

  it("caps the catalogue at 100 input records", () => {
    const records = Array.from({ length: 110 }, (_, index) => ({
      ...membershipPackage,
      id: `tier-${index}`,
    }));

    expect(normalizeAdminMembershipPackages(records)).toHaveLength(100);
  });
});
