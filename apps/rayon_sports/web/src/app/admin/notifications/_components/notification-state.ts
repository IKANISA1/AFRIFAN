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
