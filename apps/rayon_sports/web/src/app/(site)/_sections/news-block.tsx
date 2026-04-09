import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { NewsCard } from "@/components/news-card";
import { SectionHeading } from "@/components/section-heading";
import { getClubProfile, getNewsArticles } from "@/lib/data/public";

export async function NewsBlock() {
  const [club, news] = await Promise.all([getClubProfile(), getNewsArticles()]);

  return (
    <section className="page-shell section-grid">
      <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <SectionHeading
          eyebrow="Editorial"
          title={`Inside ${club.shortName}.`}
        />
        <Link
          href="/news"
          prefetch={false}
          className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          Newsroom <ArrowRight size={18} />
        </Link>
      </div>
      <div className="flex gap-5 scroll-snap-x lg:grid lg:grid-cols-3 lg:overflow-visible">
        {news.slice(0, 3).map((article) => (
          <div key={article.id} className="min-w-[85vw] sm:min-w-[340px] lg:min-w-0">
            <NewsCard article={article} />
          </div>
        ))}
      </div>
    </section>
  );
}
