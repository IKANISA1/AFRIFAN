import { Trash2 } from "lucide-react";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminNewsArticle } from "@/lib/types";
import { wordCount } from "./cms-state";

interface CMSContentListProps {
  articles: AdminNewsArticle[];
  loading: boolean;
  onRefresh: () => void;
  onBeginEdit: (article: AdminNewsArticle) => void;
  onToggleField: (article: AdminNewsArticle, field: "isPublished" | "isFeatured") => void;
  onRemove: (article: AdminNewsArticle) => void;
}

export function CMSContentList({
  articles,
  loading,
  onRefresh,
  onBeginEdit,
  onToggleField,
  onRemove,
}: CMSContentListProps) {
  return (
    <section className="glass-panel rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          Article feed
        </p>
        <button
          type="button"
          onClick={onRefresh}
          className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
        >
          Refresh
        </button>
      </div>
      <div className="mt-5 space-y-3">
        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                <Skeleton className="skeleton-text h-6 w-3/5" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                <div className="mt-4 flex gap-2">
                  <Skeleton className="h-6 w-16 rounded-full" />
                  <Skeleton className="h-6 w-12 rounded-full" />
                </div>
              </div>
            ))}
          </div>
        ) : null}
        {!loading && articles.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            No articles yet. Use the composer to publish the first story.
          </p>
        ) : null}
        {!loading && articles.map((article) => (
          <article
            key={article.id}
            className={cn(
              "card-interactive rounded-[26px] border border-border-soft p-5 transition",
              article.isPublished ? "bg-white/5" : "bg-white/[0.02] opacity-70",
            )}
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="flex gap-4">
                {article.imageUrl ? (
                  <div className="hidden sm:block h-16 w-16 flex-shrink-0 overflow-hidden rounded-xl border border-border-soft">
                    {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs. */}
                    <img src={article.imageUrl} alt="" className="h-full w-full object-cover" />
                  </div>
                ) : null}
                <div className="space-y-2">
                  <p className="font-display text-2xl font-bold uppercase leading-none">
                    {article.title}
                  </p>
                  <p className="text-sm leading-6 text-slate-300">
                    {article.excerpt}
                  </p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => onBeginEdit(article)}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => onToggleField(article, "isPublished")}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                >
                  {article.isPublished ? "Unpublish" : "Publish"}
                </button>
                <button
                  type="button"
                  onClick={() => onToggleField(article, "isFeatured")}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                >
                  {article.isFeatured ? "Unfeature" : "Feature"}
                </button>
                <button
                  type="button"
                  onClick={() => onRemove(article)}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                >
                  <span className="inline-flex items-center gap-1.5">
                    <Trash2 size={12} />
                    Delete
                  </span>
                </button>
              </div>
            </div>
            <div className="mt-4 flex flex-wrap items-center gap-2">
              <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">
                {article.category}
              </span>
              <span className={cn(
                "rounded-full border px-3 py-1.5 text-xs uppercase tracking-[0.18em]",
                article.isPublished
                  ? "border-emerald-500/30 text-emerald-400"
                  : "border-border-soft text-slate-400",
              )}>
                {article.isPublished ? "Live" : "Draft"}
              </span>
              {article.isFeatured ? (
                <span className="rounded-full border border-club-accent/40 bg-club-accent/10 px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-club-accent">
                  Featured
                </span>
              ) : null}
              <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-slate-400">
                {wordCount(article.body)} words
              </span>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
