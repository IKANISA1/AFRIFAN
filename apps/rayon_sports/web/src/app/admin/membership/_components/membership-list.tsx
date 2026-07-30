"use client";

import { PencilLine, Search, Trash2 } from "lucide-react";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { Skeleton } from "@/components/skeleton";
import { formatCurrency } from "@/lib/utils";
import type { AdminMembershipPackage } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";

interface MembershipListProps {
  packages: AdminMembershipPackage[];
  currencyCode: string;
  loading: boolean;
  mutationDisabled: boolean;
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
  mutationDisabled,
  onEdit,
  onDelete,
}: MembershipListProps) {
  const packageCollection = useAdminCollection({
    records: packages,
    getId: (pkg) => pkg.id,
    getSearchValues: (pkg) => [
      pkg.title,
      pkg.tier,
      pkg.description,
      pkg.perks.join(" "),
      pkg.isActive ? "visible active" : "hidden inactive",
    ],
    getSortValue: (
      pkg,
      key: "tier" | "status" | "price" | "perks" | "order",
    ) => {
      switch (key) {
        case "tier": return pkg.title;
        case "status": return pkg.isActive;
        case "price": return pkg.annualPrice;
        case "perks": return pkg.perks.length;
        case "order": return pkg.sortOrder;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 25,
  });

  return (
    <AdminSurface
      title="Tier catalogue"
      toolbar={
        <AdminFilterBar>
          <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search membership tiers</span><input type="search" value={packageCollection.query} onChange={(event) => packageCollection.setQuery(event.target.value)} placeholder="Search tier, perks, or status" /></label>
        </AdminFilterBar>
      }
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
      ) : (
        <>
          <AdminDataGrid
            caption="Membership tier catalogue"
            onRowActivate={(rowId) => {
              const pkg = packages.find((item) => item.id === rowId);
              if (pkg) onEdit(pkg);
            }}
            columns={[
              { key: "tier", label: "Tier", priority: "primary", sortable: true, sortDirection: packageCollection.sortDirectionFor("tier"), onSort: () => packageCollection.toggleSort("tier") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: packageCollection.sortDirectionFor("status"), onSort: () => packageCollection.toggleSort("status") },
              { key: "price", label: "Price", priority: "primary", sortable: true, sortDirection: packageCollection.sortDirectionFor("price"), onSort: () => packageCollection.toggleSort("price") },
              { key: "perks", label: "Perks", priority: "secondary", sortable: true, sortDirection: packageCollection.sortDirectionFor("perks"), onSort: () => packageCollection.toggleSort("perks") },
              { key: "order", label: "Order", priority: "secondary", sortable: true, sortDirection: packageCollection.sortDirectionFor("order"), onSort: () => packageCollection.toggleSort("order") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
            {packageCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={6}><AdminEmptyState title="No membership tiers configured" description={packageCollection.query ? "No tiers match the current search." : "Create a tier from the editor to define supporter access."} /></td></tr>
            ) : packageCollection.pageResult.items.map((pkg) => (
                <tr key={pkg.id} data-row-id={pkg.id}>
                  <td>
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="admin-row-title">{pkg.title}</p>
                      <AdminStatusBadge label={pkg.tier} tone={tierTone(pkg.tier)} />
                    </div>
                    <p className="admin-row-copy">{pkg.description}</p>
                  </td>
                  <td>
                    <AdminStatusBadge
                      label={pkg.isActive ? "Visible" : "Hidden"}
                      tone={pkg.isActive ? "success" : "neutral"}
                    />
                  </td>
                  <td>
                    <p className="text-sm font-medium text-white">
                      {formatCurrency(pkg.annualPrice, currencyCode)}
                    </p>
                    <p className="admin-row-meta">
                      {pkg.annualPrice > 0 ? "annual plan" : "free tier"}
                    </p>
                  </td>
                  <td>
                    <p className="text-sm font-medium text-white">{pkg.perks.length}</p>
                    <p className="admin-row-meta">
                      {pkg.perks.slice(0, 2).join(" · ") || "No perks listed"}
                    </p>
                  </td>
                  <td>
                    <p className="text-sm font-medium text-white">{pkg.sortOrder}</p>
                    <p className="admin-row-meta">display order</p>
                  </td>
                  <td>
                    <div className="flex flex-wrap justify-start gap-2 sm:justify-end">
                      <button
                        type="button"
                        onClick={() => onEdit(pkg)}
                        disabled={mutationDisabled}
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
                        disabled={mutationDisabled}
                        className="admin-action-button admin-action-button-danger"
                      >
                        <Trash2 size={13} />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
          </AdminDataGrid>
          <AdminPagination page={packageCollection.pageResult} onPageChange={packageCollection.setPage} label="Membership tiers" />
        </>
      )}
    </AdminSurface>
  );
}
