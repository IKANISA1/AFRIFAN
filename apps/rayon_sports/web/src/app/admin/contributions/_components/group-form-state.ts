import type { AdminContributionGroup } from "@/lib/types";

export type GroupForm = {
  id: string;
  name: string;
  description: string;
  groupType: AdminContributionGroup["groupType"];
  targetAmount: string;
  currentTotal: string;
  currency: string;
  memberCount: string;
  isClosed: boolean;
};

export const emptyGroupForm: GroupForm = {
  id: "",
  name: "",
  description: "",
  groupType: "project",
  targetAmount: "0",
  currentTotal: "0",
  currency: "",
  memberCount: "0",
  isClosed: false,
};

export function groupToFormState(group: AdminContributionGroup): GroupForm {
  return {
    id: group.id,
    name: group.name,
    description: group.description,
    groupType: group.groupType,
    targetAmount: String(group.targetAmount),
    currentTotal: String(group.currentTotal),
    currency: group.currency,
    memberCount: String(group.memberCount),
    isClosed: group.isClosed,
  };
}
