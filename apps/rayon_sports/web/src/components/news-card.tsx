import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import type { NewsArticle } from "@/lib/types";
import { formatDate, getReadingTime } from "@/lib/utils";

export function NewsCard({ article }: { article: NewsArticle }) {
  const readingTime = getReadingTime(article.content || article.excerpt);

  return (
    <Link
      href={`/news/${article.id}`}
      prefetch={false}
      className="glass-panel card-interactive flex h-full flex-col gap-4 rounded-[30px] border border-border-soft p-4"
    >
      <div className="img-zoom relative overflow-hidden rounded-[24px]">
        <Image
          src={article.coverImageUrl ?? "/media/stadium-hero.jpg"}
          alt={article.title}
          width={1200}
          height={720}
          sizes="(min-width: 1280px) 21rem, (min-width: 1024px) 30vw, calc(100vw - 4rem)"
          quality={60}
          className="h-56 w-full object-cover"
        />
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,transparent_35%,rgba(3,10,24,0.82)_100%)]" />
        <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-3 px-4 py-3">
          <span className="rounded-full bg-club-primary/80 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-white">
            {article.category}
          </span>
          <span className="text-[10px] uppercase tracking-[0.22em] text-slate-200">
            {readingTime} min read
          </span>
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex items-center justify-between gap-3 text-[11px] uppercase tracking-[0.22em] text-slate-400">
          <span>Club media</span>
          <span>{formatDate(article.publishedAt)}</span>
        </div>
        <h3 className="font-display text-3xl font-bold uppercase leading-none text-balance text-white">
          {article.title}
        </h3>
        <p className="text-sm leading-7 text-slate-300">{article.excerpt}</p>
      </div>

      <div className="mt-auto flex items-center justify-between gap-3 border-t border-white/8 pt-4">
        <span className="text-sm font-semibold text-white">Read story</span>
        <ArrowRight size={18} className="text-slate-400" />
      </div>
    </Link>
  );
}
