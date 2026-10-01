import type { AdminMembershipPackage } from "@/lib/types";

export type MembershipForm = {
  id: string;
  creationId: string;
  partnerId: string;
  expectedUpdatedAt: string;
  tier: AdminMembershipPackage["tier"];
  title: string;
  subtitle: string;
  description: string;
  annualPrice: string;
  perks: string;
  sortOrder: string;
  isActive: boolean;
};

export const emptyForm: MembershipForm = {
  id: "",
  creationId: "",
  partnerId: "",
  expectedUpdatedAt: "",
  tier: "imena",
  title: "",
  subtitle: "",
  description: "",
  annualPrice: "",
  perks: "",
  sortOrder: "0",
  isActive: false,
};
