"use client";

import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { PredictionsWorkspace } from "@/components/admin/predictions/predictions-workspace";

export default function AdminPredictionsPage() {
  const { access } = useAdminPortal();
  return <PredictionsWorkspace key={`${access.userId}:${access.clubId}:${access.role}`} />;
}
