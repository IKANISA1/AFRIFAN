import { fallbackClubProfile } from "@/lib/content";
import type { AdminContributionGroup } from "@/lib/types";

export type GroupForm = {
  id: string;
  name: string;
  description: string;
  privacy: AdminContributionGroup["privacy"];
  groupType: AdminContributionGroup["groupType"];
  targetAmount: string;
  currentTotal: string;
  currency: string;
  memberCount: string;
  inviteCode: string;
  isClosed: boolean;
};

export const emptyGroupForm: GroupForm = {
  id: "",
  name: "",
  description: "",
  privacy: "public",
  groupType: "project",
  targetAmount: "0",
  currentTotal: "0",
  currency: fallbackClubProfile.currencyCode,
  memberCount: "0",
  inviteCode: "",
  isClosed: false,
};

export function groupToFormState(group: AdminContributionGroup): GroupForm {
  return {
    id: group.id,
    name: group.name,
    description: group.description,
    privacy: group.privacy,
    groupType: group.groupType,
    targetAmount: String(group.targetAmount),
    currentTotal: String(group.currentTotal),
    currency: group.currency,
    memberCount: String(group.memberCount),
    inviteCode: group.inviteCode ?? "",
    isClosed: group.isClosed,
  };
}
