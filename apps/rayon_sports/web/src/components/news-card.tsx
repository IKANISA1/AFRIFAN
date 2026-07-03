import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import type { NewsArticle } from "@/lib/types";
import { formatDate, getReadingTime } from "@/lib/utils";
import { ui } from "@/ui-kit";

export function NewsCard({ article }: { article: NewsArticle }) {
  const readingTime = getReadingTime(article.content || article.excerpt);

  return (
    <Link
      href={`/news/${article.id}`}
      prefetch={false}
      className={`${ui.panel} ${ui.cardInteractive} group flex h-full flex-col gap-5 rounded-[32px] border-[1.2px] bg-slate-950/96 p-4 sm:p-5`}
    >
      <div className="img-zoom relative overflow-hidden rounded-[26px]">
        <Image
          src={article.coverImageUrl ?? "/brand-surface.svg"}
          alt={article.title}
          width={1200}
          height={720}
          sizes="(min-width: 1280px) 21rem, (min-width: 1024px) 30vw, calc(100vw - 4rem)"
          quality={60}
          className="h-56 w-full object-cover transition-transform duration-700 ease-out group-hover:scale-110"
        />
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,transparent_28%,rgba(3,10,24,0.92)_100%)]" />
        <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-3 px-4 py-3">
          <span className={`${ui.chip} bg-club-primary/65 px-3 py-1 text-[10px] text-white`}>
            {article.category}
          </span>
          <span className={ui.meta}>
            {readingTime} min read
          </span>
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex items-center justify-between gap-3 text-[11px] uppercase tracking-[0.2em] text-slate-100">
          <span>Club media</span>
          <span>{formatDate(article.publishedAt)}</span>
        </div>
        <h3 className="font-display text-[2rem] font-bold uppercase leading-[0.92] tracking-[-0.055em] text-balance text-white sm:text-[2.35rem]">
          {article.title}
        </h3>
        <p className="text-sm leading-7 text-slate-100">{article.excerpt}</p>
      </div>

      <div className="mt-auto flex items-center justify-between gap-3 border-t border-white/10 pt-4">
        <span className="text-sm font-semibold uppercase tracking-[0.18em] text-white/92">
          Read story
        </span>
        <ArrowRight size={18} className="text-slate-100 transition-transform duration-300 group-hover:translate-x-1" />
      </div>
    </Link>
  );
}
