import type { AdminMembershipPackage } from "@/lib/types";

export const tierColors: Record<AdminMembershipPackage["tier"], string> = {
  fan: "bg-white/8 text-slate-300 border-border-soft",
  bronze: "bg-amber-700/15 text-amber-300 border-amber-700/30",
  gold: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  platinum: "bg-violet-500/15 text-violet-400 border-violet-500/30",
};

export type MembershipForm = {
  id: string;
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
  tier: "fan",
  title: "",
  description: "",
  annualPrice: "",
  perks: "",
  sortOrder: "0",
  isActive: true,
};
