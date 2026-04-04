import { Trash2 } from "lucide-react";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminFanClub } from "@/lib/types";

interface CommunityContentListProps {
  clubs: AdminFanClub[];
  loading: boolean;
  onBeginEdit: (club: AdminFanClub) => void;
  onRemove: (club: AdminFanClub) => void;
}

export function CommunityContentList({
  clubs,
  loading,
  onBeginEdit,
  onRemove,
}: CommunityContentListProps) {
  return (
    <section className="glass-panel rounded-[32px] p-6">
      <p className="font-display text-3xl font-bold uppercase leading-none">
        Chapters
      </p>
      <div className="mt-5 space-y-3">
        {loading
          ? Array.from({ length: 3 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[26px] border border-border-soft bg-white/5 p-5"
              >
                <Skeleton className="skeleton-text h-6 w-2/5" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
              </div>
            ))
          : null}
        {!loading && clubs.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            No chapters registered yet.
          </p>
        ) : null}
        {!loading &&
          clubs.map((club) => (
            <article
              key={club.id}
              className={cn(
                "card-interactive rounded-[26px] border border-border-soft p-5",
                club.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60",
              )}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="flex flex-wrap items-center gap-3">
                    <p className="font-display text-2xl font-bold uppercase leading-none">
                      {club.name}
                    </p>
                    {!club.isActive ? (
                      <span className="rounded-full border border-rose-400/30 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-rose-300">
                        Inactive
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1 text-sm uppercase tracking-[0.2em] text-club-accent">
                    {club.region}
                  </p>
                  <p className="mt-2 text-sm text-slate-300">
                    {club.description}
                  </p>
                </div>
                <div className="flex flex-shrink-0 gap-2">
                  <button
                    type="button"
                    onClick={() => onBeginEdit(club)}
                    className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-white/8"
                    title="Edit"
                  >
                    <span className="text-xs">✏️</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => onRemove(club)}
                    className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:border-rose-400/30 hover:bg-rose-500/15 hover:text-rose-300"
                    title="Remove"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                    Members
                  </p>
                  <p className="mt-2 font-display text-xl font-bold">
                    {club.memberCount}
                  </p>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                    Events
                  </p>
                  <p className="mt-2 font-display text-xl font-bold">
                    {club.eventCount}
                  </p>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                    Rating
                  </p>
                  <p className="mt-2 font-display text-xl font-bold">
                    {club.rating.toFixed(1)}
                  </p>
                </div>
              </div>
            </article>
          ))}
      </div>
    </section>
  );
}
