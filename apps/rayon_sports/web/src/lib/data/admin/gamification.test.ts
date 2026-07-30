import { describe, expect, it } from "vitest";
import { normalizeAdminFanEngagementTokens } from "./gamification";

const token = {
  id: "fet-1",
  clubId: 24,
  code: "G001",
  templateScope: "generic",
  category: "Matchday",
  itemName: "Correct score reward",
  fetValue: 100,
  triggerCondition: "Submit a correct score before kick-off.",
  activationTiming: "After result confirmation",
  description: "Awards a bounded supporter reward.",
  badgeName: "Goal reader",
  implementationNotes: "Review settlement audit before activation.",
  sortOrder: 10,
  isActive: true,
  createdAt: "2026-07-29T10:00:00.000Z",
  updatedAt: "2026-07-29T10:00:00.000Z",
};

describe("gamification admin normalization", () => {
  it("keeps only strict bounded catalog fields", () => {
    const normalized = normalizeAdminFanEngagementTokens([
      {
        ...token,
        privateSettlementKey: "private",
        metadata: { accessToken: "private" },
      },
    ]);

    expect(normalized).toEqual([token]);
    expect(JSON.stringify(normalized)).not.toContain("privateSettlementKey");
    expect(JSON.stringify(normalized)).not.toContain("accessToken");
  });

  it("drops malformed and duplicate records", () => {
    const normalized = normalizeAdminFanEngagementTokens([
      token,
      { ...token, itemName: "Duplicate" },
      { ...token, id: "fet-2", code: "reward-one" },
      { ...token, id: "fet-3", fetValue: Number.POSITIVE_INFINITY },
      { ...token, id: "fet-4", updatedAt: "not-a-date" },
    ]);

    expect(normalized).toEqual([token]);
  });

  it("caps the projected catalog at 500 rows", () => {
    const rows = Array.from({ length: 510 }, (_, index) => ({
      ...token,
      id: `fet-${index}`,
      code: `G${String(index % 1_000).padStart(3, "0")}`,
    }));

    expect(normalizeAdminFanEngagementTokens(rows)).toHaveLength(500);
  });
});
