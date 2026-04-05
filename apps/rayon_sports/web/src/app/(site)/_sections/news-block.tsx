import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { NewsCard } from "@/components/news-card";
import { SectionHeading } from "@/components/section-heading";
import { getNewsArticles } from "@/lib/data/public";

export async function NewsBlock() {
  const news = await getNewsArticles();

  return (
    <section className="page-shell section-grid">
      <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <SectionHeading
          eyebrow="Editorial"
          title="Inside Rayon Sports."
        />
        <Link
          href="/news"
          prefetch={false}
          className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          Newsroom <ArrowRight size={18} />
        </Link>
      </div>
      <div className="grid gap-5 xl:grid-cols-3">
        {news.slice(0, 3).map((article) => (
          <NewsCard key={article.id} article={article} />
        ))}
      </div>
    </section>
  );
}
