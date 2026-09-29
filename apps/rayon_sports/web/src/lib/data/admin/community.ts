import type {
  AdminContributionSnapshot,
  AdminFanClub,
} from "@/lib/types";
import { normalizeAdminContributionSnapshot } from "./contributions";
import { normalizeAdminFanClubs } from "./fan-clubs";

export type CommunityBundle = {
  chapters: AdminFanClub[];
  snapshot: AdminContributionSnapshot;
};

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  monthlyTotal: 0,
};

export const emptyCommunityBundle: CommunityBundle = {
  chapters: [],
  snapshot: emptySnapshot,
};

export const communityBundleIsEmpty = (value: CommunityBundle) =>
  value.chapters.length === 0 &&
  value.snapshot.groups.length === 0 &&
  value.snapshot.contributions.length === 0;

export function normalizeCommunityBundle(value: unknown): CommunityBundle {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return emptyCommunityBundle;
  }
  const record = value as Record<string, unknown>;
  return {
    chapters: normalizeAdminFanClubs(record.chapters),
    snapshot: normalizeAdminContributionSnapshot(record.snapshot),
  };
}
