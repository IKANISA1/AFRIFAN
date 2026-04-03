import Image from "next/image";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { NewsCard } from "@/components/news-card";
import { getNewsArticleById, getNewsArticles } from "@/lib/data/public";
import { formatDate, getReadingTime } from "@/lib/utils";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ articleId: string }>;
}): Promise<Metadata> {
  const { articleId } = await params;
  const article = await getNewsArticleById(articleId);

  if (article == null) {
    return {
      title: "Club article",
    };
  }

  return {
    title: article.title,
    description: article.excerpt,
  };
}

export default async function ArticlePage({
  params,
}: {
  params: Promise<{ articleId: string }>;
}) {
  const { articleId } = await params;
  const [article, articles] = await Promise.all([
    getNewsArticleById(articleId),
    getNewsArticles(),
  ]);

  if (article == null) {
    notFound();
  }

  const relatedArticles = articles.filter((entry) => entry.id !== article.id).slice(0, 3);
  const paragraphs = article.content
    .split(/(?<=[.!?])\s+/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);

  return (
    <article className="page-shell section-grid py-12">
      <section className="glass-panel-elevated overflow-hidden rounded-[38px] border border-border-soft">
        <div className="grid gap-8 lg:grid-cols-[0.95fr_1.05fr]">
          <div className="img-zoom relative min-h-[20rem]">
            <Image
              src={article.coverImageUrl ?? "/media/stadium-hero.jpg"}
              alt={article.title}
              fill
              sizes="(min-width: 1024px) 42vw, 100vw"
              className="object-cover"
            />
            <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent_25%,rgba(3,10,24,0.74)_100%)]" />
          </div>
          <div className="p-6 sm:p-8">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {article.category} • {formatDate(article.publishedAt)}
            </p>
            <h1 className="mt-4 font-display text-6xl font-bold uppercase leading-none text-balance text-white">
              {article.title}
            </h1>
            <p className="mt-4 max-w-3xl text-base leading-8 text-slate-300">
              {article.excerpt}
            </p>
            <div className="mt-5 flex flex-wrap gap-2">
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                By {article.author}
              </span>
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                {getReadingTime(article.content)} min read
              </span>
            </div>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/news"
                className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
              >
                Back to newsroom
              </Link>
              <Link
                href="/fixtures"
                className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Matchday context
              </Link>
            </div>
          </div>
        </div>
      </section>

      <div className="grid gap-8 lg:grid-cols-[0.95fr_1.05fr]">
        <div className="glass-panel rounded-[32px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
            Full story
          </p>
          <div className="mt-5 space-y-5 text-base leading-8 text-slate-200">
            {paragraphs.map((paragraph, index) => (
              <p key={`${index}-${paragraph.slice(0, 20)}`}>{paragraph}</p>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
              Story framing
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              Editorial should always point somewhere
            </h2>
            <div className="mt-5 grid gap-4">
              {[
                "Matchday stories should connect back to fixtures and ticketing.",
                "Membership stories should help supporters understand plan value.",
                "Retail stories should support product launches instead of duplicating them.",
              ].map((point) => (
                <div
                  key={point}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
                >
                  {point}
                </div>
              ))}
            </div>
          </div>

          {relatedArticles.length > 0 ? (
            <section className="section-grid">
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                  More stories
                </p>
                <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
                  Related coverage
                </h2>
              </div>
              <div className="grid gap-5">
                {relatedArticles.map((relatedArticle) => (
                  <NewsCard key={relatedArticle.id} article={relatedArticle} />
                ))}
              </div>
            </section>
          ) : null}
        </div>
      </div>
    </article>
  );
}
