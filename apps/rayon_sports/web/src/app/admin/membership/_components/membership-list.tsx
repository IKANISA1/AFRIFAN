import { Trash2 } from "lucide-react";
import { Skeleton } from "@/components/skeleton";
import { cn, formatCurrency } from "@/lib/utils";
import type { AdminMembershipPackage } from "@/lib/types";
import { tierColors } from "./membership-state";

interface MembershipListProps {
  packages: AdminMembershipPackage[];
  loading: boolean;
  onEdit: (pkg: AdminMembershipPackage) => void;
  onDelete: (pkg: AdminMembershipPackage) => Promise<void>;
}

export function MembershipList({
  packages,
  loading,
  onEdit,
  onDelete,
}: MembershipListProps) {
  return (
    <section className="glass-panel rounded-[32px] p-6">
      <p className="font-display text-3xl font-bold uppercase leading-none">
        Tier cards
      </p>
      <div className="mt-5 space-y-3">
        {loading
          ? Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[26px] border border-border-soft bg-white/5 p-5"
              >
                <Skeleton className="skeleton-text h-6 w-2/5" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
              </div>
            ))
          : null}
        {!loading && packages.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            No membership tiers configured.
          </p>
        ) : null}
        {!loading &&
          packages.map((pkg) => (
            <article
              key={pkg.id}
              className={cn(
                "card-interactive rounded-[26px] border border-border-soft p-5 transition",
                pkg.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60",
              )}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-3">
                    <p className="font-display text-2xl font-bold uppercase leading-none">
                      {pkg.title}
                    </p>
                    <span
                      className={cn(
                        "rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]",
                        tierColors[pkg.tier],
                      )}
                    >
                      {pkg.tier}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-slate-300">
                    {pkg.description}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-display text-2xl font-bold">
                    {formatCurrency(pkg.annualPrice)}
                  </p>
                  <p className="text-xs text-slate-400">/year</p>
                </div>
              </div>
              {pkg.perks.length > 0 ? (
                <div className="mt-4 flex flex-wrap gap-2">
                  {pkg.perks.map((perk) => (
                    <span
                      key={perk}
                      className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-xs text-slate-200"
                    >
                      {perk}
                    </span>
                  ))}
                </div>
              ) : null}
              <div className="mt-4 flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => onEdit(pkg)}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => {
                    onDelete(pkg).catch(() => {});
                  }}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                >
                  <span className="inline-flex items-center gap-1.5">
                    <Trash2 size={12} />
                    Delete
                  </span>
                </button>
              </div>
            </article>
          ))}
      </div>
    </section>
  );
}
