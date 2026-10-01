"use client";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { PaymentRefundsWorkspace } from "@/components/admin/refunds/payment-refunds-workspace";
export default function AdminRefundsPage() {
  const { access } = useAdminPortal();
  return <PaymentRefundsWorkspace key={`${access.userId}:${access.clubId}:${access.role}`} />;
}
