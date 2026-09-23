import type { AdminMembershipPackage } from "@/lib/types";

export type MembershipForm = {
  id: string;
  expectedUpdatedAt: string;
  tier: AdminMembershipPackage["tier"];
  title: string;
  description: string;
  annualPrice: string;
  perks: string;
  sortOrder: string;
  isActive: boolean;
};

export const emptyForm: MembershipForm = {
  id: "",
  expectedUpdatedAt: "",
  tier: "imena",
  title: "",
  description: "",
  annualPrice: "",
  perks: "",
  sortOrder: "0",
  isActive: true,
};
