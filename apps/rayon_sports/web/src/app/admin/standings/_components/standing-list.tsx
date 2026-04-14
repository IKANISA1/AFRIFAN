import { Trash2 } from "lucide-react";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminStandingRow } from "@/lib/types";

const formBadge: Record<string, string> = {
  W: "bg-emerald-500/18 text-emerald-300",
  D: "bg-white/8 text-slate-200",
  L: "bg-rose-500/18 text-rose-300",
};

interface StandingListProps {
  rows: AdminStandingRow[];
  loading: boolean;
  highlightedClubId: string | null;
  highlightedClubSlug: string | null;
  onEdit: (row: AdminStandingRow) => void;
  onDelete: (row: AdminStandingRow) => Promise<void>;
}

export function StandingList({
  rows,
  loading,
  highlightedClubId,
  highlightedClubSlug,
  onEdit,
  onDelete,
}: StandingListProps) {
  return (
    <section className="glass-panel overflow-hidden rounded-[32px]">
      <div className="p-6">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          League table
        </p>
      </div>
      {loading ? (
        <div className="space-y-3 px-6 pb-6">
          {Array.from({ length: 5 }).map((_, index) => (
            <div key={index} className="flex gap-4">
              <Skeleton className="h-8 w-10" />
              <Skeleton className="skeleton-text h-8 flex-1" />
            </div>
          ))}
        </div>
      ) : rows.length === 0 ? (
        <p className="px-6 pb-6 text-sm text-slate-300">
          No standings data yet.
        </p>
      ) : (
        <table className="w-full text-left text-sm">
          <thead className="bg-white/8 text-xs uppercase tracking-[0.24em] text-slate-400">
            <tr>
              <th className="px-4 py-3 text-center">Pos</th>
              <th className="px-4 py-3">Club</th>
              <th className="px-4 py-3 text-center">P</th>
              <th className="px-4 py-3 text-center">GD</th>
              <th className="px-4 py-3 text-center">Pts</th>
              <th className="px-4 py-3">Form</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const isHighlightedClub =
                (row.clubId != null &&
                  highlightedClubId != null &&
                  String(row.clubId) === highlightedClubId) ||
                (highlightedClubSlug != null &&
                  row.clubSlug === highlightedClubSlug);

              return (
                <tr
                  key={row.id}
                  className={cn(
                    "border-t border-white/6",
                    isHighlightedClub && "bg-club-primary/15",
                  )}
                >
                  <td className="px-4 py-3 text-center font-mono text-xs text-slate-400">
                    {row.position}
                  </td>
                  <td className="px-4 py-3 font-semibold text-white">
                    {row.club}
                  </td>
                  <td className="px-4 py-3 text-center">{row.played}</td>
                  <td className="px-4 py-3 text-center">
                    {row.goalDifference}
                  </td>
                  <td className="px-4 py-3 text-center font-semibold text-white">
                    {row.points}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1">
                      {row.form.map((item, index) => (
                        <span
                          key={`${row.id}-${index}`}
                          className={cn(
                            "flex h-6 w-6 items-center justify-center rounded-full text-[9px] font-bold",
                            formBadge[item] ?? formBadge.D,
                          )}
                        >
                          {item}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1.5">
                      <button
                        type="button"
                        onClick={() => onEdit(row)}
                        className="rounded-full border border-border-soft p-1.5 text-slate-300 transition hover:bg-white/8"
                        title="Edit"
                      >
                        <span className="text-[10px]">✏️</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          onDelete(row).catch(() => {});
                        }}
                        className="rounded-full border border-border-soft p-1.5 text-slate-300 transition hover:bg-rose-500/15 hover:text-rose-300"
                        title="Remove"
                      >
                        <Trash2 size={12} />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </section>
  );
}
