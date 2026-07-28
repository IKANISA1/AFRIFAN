import type { AdminMembershipPackage } from "@/lib/types";

export const tierColors: Record<AdminMembershipPackage["tier"], string> = {
  "ingenzi-imanzi": "bg-white/8 text-slate-300 border-border-soft",
  inyamibwa: "bg-sky-500/15 text-sky-300 border-sky-500/30",
  imena: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
  bronze: "bg-amber-700/15 text-amber-300 border-amber-700/30",
  silver: "bg-zinc-300/15 text-zinc-200 border-zinc-300/30",
  gold: "bg-amber-500/15 text-amber-400 border-amber-500/30",
};

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
