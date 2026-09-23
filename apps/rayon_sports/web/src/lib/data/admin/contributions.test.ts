import { describe, expect, it } from "vitest";
import type {
  AdminContributionGroup,
  AdminContributionItem,
  AdminContributionSnapshot,
} from "@/lib/types";
import {
  buildContributionExcel,
  buildContributionGroupMutationPayload,
  calculateContributionMonthlyTotal,
  normalizeAdminContributionSnapshot,
  normalizeContributionGroupInput,
} from "./contributions";

const group: AdminContributionGroup = {
  id: "group-1",
  name: "Blue Wall Fund",
  description: "",
  groupType: "project",
  targetAmount: 1_000_000,
  currentTotal: 550_000,
  currency: "RWF",
  memberCount: 32,
  isActive: true,
  creatorId: "supporter-owner-1",
  createdAt: "2026-07-03T08:00:00.000Z",
  updatedAt: "2026-07-03T08:05:00.000Z",
  isClosed: false,
};

const contributions: AdminContributionItem[] = [
  {
    id: "confirmed",
    groupId: group.id,
    userId: "supporter-1",
    amount: 10_000,
    status: "confirmed",
    createdAt: "2026-07-05T09:00:00.000Z",
  },
  {
    id: "completed",
    groupId: group.id,
    userId: "supporter-2",
    amount: 20_000,
    status: "completed",
    createdAt: "2026-07-06T09:00:00.000Z",
  },
  {
    id: "pending",
    groupId: group.id,
    userId: "supporter-3",
    amount: 40_000,
    status: "pending",
    createdAt: "2026-07-07T09:00:00.000Z",
  },
  {
    id: "prior-month",
    groupId: group.id,
    userId: "supporter-4",
    amount: 80_000,
    status: "confirmed",
    createdAt: "2026-06-30T23:59:59.000Z",
  },
];

describe("admin contribution integrity boundaries", () => {
  it("counts only confirmed or completed entries in the current UTC month", () => {
    expect(
      calculateContributionMonthlyTotal(
        contributions,
        new Date("2026-07-29T12:00:00.000Z"),
      ),
    ).toBe(30_000);
  });

  it("accepts bounded empty descriptions and excludes malformed financial rows", () => {
    const snapshot = normalizeAdminContributionSnapshot({
      groups: [group],
      contributions: [
        ...contributions,
        {
          ...contributions[0],
          id: "invalid-negative",
          amount: -1,
        },
        {
          ...contributions[0],
          id: "private-orphan",
          groupId: "not-in-scope",
          accessToken: "private",
        },
      ],
      monthlyTotal: 30_000,
      privateMetadata: { token: "private" },
    });

    expect(snapshot.groups).toEqual([group]);
    expect(snapshot.contributions).toHaveLength(4);
    expect(snapshot.monthlyTotal).toBe(30_000);
    expect(JSON.stringify(snapshot)).not.toContain("private");
  });

  it("normalizes mutation fields and rejects invalid money, identifiers, and currency", () => {
    expect(
      normalizeContributionGroupInput({
        id: null,
        expectedUpdatedAt: null,
        name: "  Stadium access fund  ",
        description: "  Accessible supporter transport.  ",
        groupType: "community",
        targetAmount: 250_000,
        currentTotal: 0,
        currency: "rwf",
        memberCount: 0,
        isClosed: false,
      }),
    ).toMatchObject({
      name: "Stadium access fund",
      description: "Accessible supporter transport.",
      currency: "RWF",
    });

    expect(() =>
      normalizeContributionGroupInput({
        id: "x".repeat(129),
        expectedUpdatedAt: "not-a-date",
        name: "",
        description: "",
        groupType: "project",
        targetAmount: Number.POSITIVE_INFINITY,
        currentTotal: -1,
        currency: "RWF-SECRET",
        memberCount: 0.5,
        isClosed: false,
      }),
    ).toThrow("Contribution initiative fields are invalid.");
  });

  it("never permits initiative mutations to overwrite derived ledger totals", () => {
    const createInput = normalizeContributionGroupInput({
      id: null,
      expectedUpdatedAt: null,
      name: "New fund",
      description: "",
      groupType: "project",
      targetAmount: 100_000,
      currentTotal: 99_999,
      currency: "RWF",
      memberCount: 999,
      isClosed: false,
    });
    const editInput = normalizeContributionGroupInput({
      ...createInput,
      id: "group-1",
      expectedUpdatedAt: "2026-07-29T12:00:00.000Z",
    });

    expect(
      buildContributionGroupMutationPayload(createInput, "club-1")[0],
    ).toMatchObject({
      current_total: 0,
      member_count: 0,
    });
    expect(
      buildContributionGroupMutationPayload(editInput, "club-1")[0],
    ).not.toHaveProperty("current_total");
    expect(
      buildContributionGroupMutationPayload(editInput, "club-1")[0],
    ).not.toHaveProperty("member_count");
  });

  it("exports each initiative currency and neutralizes spreadsheet formulas", () => {
    const snapshot: AdminContributionSnapshot = {
      groups: [{ ...group, name: '=HYPERLINK("https://bad")' }],
      contributions: [],
      monthlyTotal: 0,
    };
    const { headers, rows } = buildContributionExcel(snapshot);

    expect(headers).toEqual([
      "Name",
      "Type",
      "Currency",
      "Total",
      "Target",
      "Contributors",
      "Status",
      "Created",
    ]);
    expect(rows[0]?.slice(0, 6)).toEqual([
      '\'=HYPERLINK("https://bad")',
      "project",
      "RWF",
      550_000,
      1_000_000,
      32,
    ]);
  });
});
