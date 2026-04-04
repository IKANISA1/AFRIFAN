import type { AdminNotificationContext } from "@/lib/types";

export type NotificationForm = {
  title: string;
  body: string;
  audience: "all_fans" | "by_tier" | "by_group";
  tier: string;
  groupId: string;
  deliveryMode: "send_now" | "schedule";
  scheduledAt: string;
  imageUrl: string;
};

export const emptyContext: AdminNotificationContext = {
  groups: [],
  history: [],
};

export const emptyForm: NotificationForm = {
  title: "",
  body: "",
  audience: "all_fans",
  tier: "bronze",
  groupId: "",
  deliveryMode: "send_now",
  scheduledAt: "",
  imageUrl: "",
};

export const notifStatusColors: Record<string, string> = {
  sent: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  delivered: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  scheduled: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  failed: "bg-rose-500/15 text-rose-300 border-rose-500/30",
  pending: "bg-white/8 text-slate-300 border-border-soft",
};
