import { PencilLine, Trash2 } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { Skeleton } from "@/components/skeleton";
import { formatCurrency } from "@/lib/utils";
import type { AdminMembershipPackage } from "@/lib/types";

interface MembershipListProps {
  packages: AdminMembershipPackage[];
  currencyCode: string;
  loading: boolean;
  onEdit: (pkg: AdminMembershipPackage) => void;
  onDelete: (pkg: AdminMembershipPackage) => Promise<void>;
}

function tierTone(tier: string) {
  if (tier === "gold" || tier === "silver") return "accent" as const;
  if (tier === "bronze") return "warning" as const;
  return "neutral" as const;
}

export function MembershipList({
  packages,
  currencyCode,
  loading,
  onEdit,
  onDelete,
}: MembershipListProps) {
  return (
    <AdminSurface
      title="Tier catalogue"
      flush
    >
      {loading ? (
        <div className="space-y-3 p-5 sm:p-6">
          {Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="rounded-[20px] border border-border-soft bg-white/5 p-4">
              <Skeleton className="skeleton-text h-5 w-2/5" />
              <Skeleton className="skeleton-text mt-2 h-3 w-full" />
            </div>
          ))}
        </div>
      ) : packages.length === 0 ? (
        <AdminEmptyState
          title="No membership tiers configured"
          description="Create a tier from the editor to define supporter access."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Tier</th>
                <th>Status</th>
                <th>Price</th>
                <th>Perks</th>
                <th>Order</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {packages.map((pkg) => (
                <tr key={pkg.id} className="admin-table-row">
                  <td className="admin-table-cell" data-column-label="Tier">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="admin-row-title">{pkg.title}</p>
                      <AdminStatusBadge label={pkg.tier} tone={tierTone(pkg.tier)} />
                    </div>
                    <p className="admin-row-copy">{pkg.description}</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Status">
                    <AdminStatusBadge
                      label={pkg.isActive ? "Visible" : "Hidden"}
                      tone={pkg.isActive ? "success" : "neutral"}
                    />
                  </td>
                  <td className="admin-table-cell" data-column-label="Price">
                    <p className="text-sm font-medium text-white">
                      {formatCurrency(pkg.annualPrice, currencyCode)}
                    </p>
                    <p className="admin-row-meta">
                      {pkg.annualPrice > 0 ? "annual plan" : "free tier"}
                    </p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Perks">
                    <p className="text-sm font-medium text-white">{pkg.perks.length}</p>
                    <p className="admin-row-meta">
                      {pkg.perks.slice(0, 2).join(" · ") || "No perks listed"}
                    </p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Order">
                    <p className="text-sm font-medium text-white">{pkg.sortOrder}</p>
                    <p className="admin-row-meta">display order</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Actions">
                    <div className="flex flex-wrap justify-start gap-2 sm:justify-end">
                      <button
                        type="button"
                        onClick={() => onEdit(pkg)}
                        className="admin-action-button"
                      >
                        <PencilLine size={13} />
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          onDelete(pkg).catch(() => {});
                        }}
                        className="admin-action-button admin-action-button-danger"
                      >
                        <Trash2 size={13} />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </AdminSurface>
  );
}
