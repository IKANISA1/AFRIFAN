import { describe, expect, it } from "vitest";
import { normalizeCommunityBundle } from "@/app/admin/community/page";
import { normalizeAdminContributionSnapshot } from "./contributions";
import { normalizeAdminFanClubs } from "./fan-clubs";

const validChapter = {
  id: "chapter-1",
  clubId: 1,
  name: "Kigali Chapter",
  region: "Kigali",
  description: "Official supporter chapter.",
  memberCount: 240,
  eventCount: 12,
  rating: 4.8,
  bannerImageUrl: "/admin/community/kigali-banner",
  isActive: true,
  createdAt: "2026-07-29T12:00:00.000Z",
  updatedAt: "2026-07-29T12:30:00.000Z",
  actorEmail: "private@example.com",
  accessToken: "private-token",
};

const validGroup = {
  id: "group-1",
  name: "Away Travel",
  description: "Confirmed supporter travel initiative.",
  groupType: "community",
  targetAmount: 1_000_000,
  currentTotal: 250_000,
  currency: "RWF",
  memberCount: 64,
  isActive: true,
  creatorId: "creator-1",
  createdAt: "2026-07-29T12:00:00.000Z",
  updatedAt: "2026-07-29T12:30:00.000Z",
  isClosed: false,
  contributorPhone: "+250788000001",
};

const validContribution = {
  id: "contribution-1",
  groupId: "group-1",
  userId: "supporter-1",
  amount: 10_000,
  status: "confirmed",
  createdAt: "2026-07-29T12:10:00.000Z",
  momoReference: "private-reference",
};

describe("admin community response normalization", () => {
  it("projects bounded chapter fields and removes private extras", () => {
    const [chapter] = normalizeAdminFanClubs([validChapter]);

    expect(chapter).toEqual({
      id: "chapter-1",
      clubId: 1,
      name: "Kigali Chapter",
      region: "Kigali",
      description: "Official supporter chapter.",
      memberCount: 240,
      eventCount: 12,
      rating: 4.8,
      bannerImageUrl: "/admin/community/kigali-banner",
      isActive: true,
      createdAt: "2026-07-29T12:00:00.000Z",
      updatedAt: "2026-07-29T12:30:00.000Z",
    });
    expect(JSON.stringify(chapter)).not.toContain("private");
  });

  it("rejects malformed chapters, unsafe media, and caps the collection", () => {
    const result = normalizeAdminFanClubs(
      Array.from({ length: 510 }, (_, index) => ({
        ...validChapter,
        id: `chapter-${index + 1}`,
        bannerImageUrl:
          index === 0 ? "javascript:alert(1)" : validChapter.bannerImageUrl,
      })),
    );

    expect(result).toHaveLength(500);
    expect(result[0]?.bannerImageUrl).toBeNull();
    expect(
      normalizeAdminFanClubs([
        { ...validChapter, id: "" },
        { ...validChapter, memberCount: -1 },
        { ...validChapter, rating: 7 },
        { ...validChapter, updatedAt: "not-a-date" },
        null,
      ]),
    ).toEqual([]);
    expect(normalizeAdminFanClubs({ data: [validChapter] })).toEqual([]);
  });

  it("projects bounded contribution data and drops orphaned or invalid rows", () => {
    const snapshot = normalizeAdminContributionSnapshot({
      groups: [validGroup],
      contributions: [
        validContribution,
        { ...validContribution, id: "orphan", groupId: "unknown-group" },
        { ...validContribution, id: "unsafe-status", status: "refunded" },
      ],
      monthlyTotal: 10_000,
      secret: "private-secret",
    });

    expect(snapshot).toEqual({
      groups: [
        {
          id: "group-1",
          name: "Away Travel",
          description: "Confirmed supporter travel initiative.",
          groupType: "community",
          targetAmount: 1_000_000,
          currentTotal: 250_000,
          currency: "RWF",
          memberCount: 64,
          isActive: true,
          creatorId: "creator-1",
          createdAt: "2026-07-29T12:00:00.000Z",
          updatedAt: "2026-07-29T12:30:00.000Z",
          isClosed: false,
        },
      ],
      contributions: [
        {
          id: "contribution-1",
          groupId: "group-1",
          userId: "supporter-1",
          amount: 10_000,
          status: "confirmed",
          createdAt: "2026-07-29T12:10:00.000Z",
        },
      ],
      monthlyTotal: 10_000,
    });
    expect(JSON.stringify(snapshot)).not.toContain("private");
  });

  it("caps groups and contributions at 500 and fails closed for malformed bundles", () => {
    const groups = Array.from({ length: 510 }, (_, index) => ({
      ...validGroup,
      id: `group-${index + 1}`,
    }));
    const contributions = Array.from({ length: 510 }, (_, index) => ({
      ...validContribution,
      id: `contribution-${index + 1}`,
      groupId: `group-${(index % 500) + 1}`,
    }));
    const snapshot = normalizeAdminContributionSnapshot({
      groups,
      contributions,
      monthlyTotal: 100,
    });

    expect(snapshot.groups).toHaveLength(500);
    expect(snapshot.contributions).toHaveLength(500);
    expect(normalizeAdminContributionSnapshot([])).toEqual({
      groups: [],
      contributions: [],
      monthlyTotal: 0,
    });
    expect(
      normalizeAdminContributionSnapshot({
        groups: {},
        contributions: [],
        monthlyTotal: 0,
      }),
    ).toEqual({
      groups: [],
      contributions: [],
      monthlyTotal: 0,
    });
  });

  it("normalizes the complete dual-resource bundle", () => {
    const bundle = normalizeCommunityBundle({
      chapters: [validChapter],
      snapshot: {
        groups: [validGroup],
        contributions: [validContribution],
        monthlyTotal: 10_000,
      },
      privateMetadata: { token: "private" },
    });

    expect(bundle.chapters).toHaveLength(1);
    expect(bundle.snapshot.groups).toHaveLength(1);
    expect(bundle.snapshot.contributions).toHaveLength(1);
    expect(JSON.stringify(bundle)).not.toContain("private");
  });
});
