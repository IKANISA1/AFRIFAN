import { describe, expect, it } from "vitest";
import {
  normalizeAdminSupporters,
} from "./membership-ops";

const supporter = {
  id: "supporter-1",
  userId: "user-1",
  displayName: "Verified supporter",
  phone: "+250788123456",
  tier: "gold",
  status: "active",
  points: 420,
  chapter: "Kigali",
  membershipNumber: "RS-0001",
  joinedAt: "2026-07-29T10:00:00.000Z",
};

describe("membership operations normalization", () => {
  it("projects supporter records and drops private extras", () => {
    const normalized = normalizeAdminSupporters([
      { ...supporter, privateEmail: "private@example.com" },
    ]);
    expect(normalized).toEqual([supporter]);
    expect(JSON.stringify(normalized)).not.toContain("privateEmail");
  });

  it("rejects malformed and duplicate supporter records", () => {
    expect(
      normalizeAdminSupporters([
        supporter,
        { ...supporter, displayName: "Duplicate" },
        { ...supporter, id: "supporter-2", status: "unknown" },
        { ...supporter, id: "supporter-3", points: -1 },
        { ...supporter, id: "supporter-4", joinedAt: "not-a-date" },
      ]),
    ).toEqual([supporter]);
  });

  it("caps each collection at 500 input records", () => {
    expect(
      normalizeAdminSupporters(
        Array.from({ length: 510 }, (_, index) => ({
          ...supporter,
          id: `supporter-${index}`,
          userId: `user-${index}`,
        })),
      ),
    ).toHaveLength(500);

  });
});
