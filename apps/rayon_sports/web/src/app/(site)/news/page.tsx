import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { NewsCard } from "@/components/news-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getNewsArticles } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { formatDate, getReadingTime } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.news.metaTitle(club),
    description: copy.pages.news.metaDescription(club),
    path: "/news",
  });
}

export default async function NewsPage() {
  const [club, articles] = await Promise.all([
    getClubProfile(),
    getNewsArticles(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const [featuredArticle, ...secondaryArticles] = articles;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.news.eyebrow}
        title={copy.pages.news.title}
        description={copy.pages.news.description(club)}
        actions={
          <>
            <Link
              href="/fixtures"
              prefetch={false}
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.matchdaySchedule}
            </Link>
            <Link
              href="/membership"
              prefetch={false}
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.membershipStories}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.stories, value: articles.length.toString() },
          {
            label: copy.common.categories,
            value: new Set(articles.map((article) => article.category)).size.toString(),
          },
          {
            label: copy.common.featured,
            value: featuredArticle ? `${getReadingTime(featuredArticle.content)} ${copy.common.minuteRead}` : "0",
          },
        ]}
      />

      {featuredArticle ? (
        <section className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
          <Link
            href={`/news/${featuredArticle.id}`}
            prefetch={false}
            className="glass-panel card-interactive grid overflow-hidden rounded-[34px] lg:grid-cols-[1.05fr_0.95fr]"
          >
            <div className="p-6 sm:p-8">
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                {copy.common.featuredStory}
              </p>
              <h2 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white text-balance">
                {featuredArticle.title}
              </h2>
              <p className="mt-4 max-w-2xl text-sm leading-8 text-slate-300 sm:text-base">
                {featuredArticle.excerpt}
              </p>
              <div className="mt-6 flex flex-wrap gap-2">
                <span className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {featuredArticle.category}
                </span>
                <span className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {formatDate(featuredArticle.publishedAt)}
                </span>
                <span className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {getReadingTime(featuredArticle.content)} {copy.common.minuteRead}
                </span>
              </div>
              <div className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-white">
                {copy.common.openStory} <ArrowRight size={18} />
              </div>
            </div>
            <div className="img-zoom relative min-h-[18rem]">
              <Image
                src={featuredArticle.coverImageUrl ?? "/media/stadium-hero.jpg"}
                alt={featuredArticle.title}
                fill
                priority
                sizes="(min-width: 1280px) 38rem, (min-width: 1024px) 46vw, calc(100vw - 2rem)"
                quality={60}
                className="object-cover"
              />
              <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent_25%,rgba(3,10,24,0.58)_100%)]" />
            </div>
          </Link>

          <div className="glass-panel rounded-[34px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.pages.news.newsroomStandards}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.pages.news.newsroomStandardsTitle}
            </h2>
            <div className="mt-5 grid gap-4">
              {copy.pages.news.standardsPoints.map((point) => (
                <div
                  key={point}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
                >
                  {point}
                </div>
              ))}
            </div>
          </div>
        </section>
      ) : null}

      <section className="section-grid">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.pages.news.latestStories}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.pages.news.acrossTheClub}
            </h2>
          </div>
          <div className="flex flex-wrap gap-2">
            {Array.from(new Set(articles.map((article) => article.category))).map((category) => (
              <span
                key={category}
                className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
              >
                {category}
              </span>
            ))}
          </div>
        </div>
        <div className="grid gap-5 lg:grid-cols-3">
          {(secondaryArticles.length > 0 ? secondaryArticles : articles).map((article) => (
            <NewsCard key={article.id} article={article} />
          ))}
        </div>
      </section>
    </div>
  );
}
