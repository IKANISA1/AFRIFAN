import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { NewsCard } from "@/components/news-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getNewsArticles } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
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
  const featureGate = await getFeaturePageGuard("news");
  if (featureGate) {
    return featureGate;
  }

  const [club, articles] = await Promise.all([
    getClubProfile(),
    getNewsArticles(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const [featuredArticle, ...secondaryArticles] = articles;

  return (
    <div className="bg-white min-h-screen pt-24 pb-20 lg:pt-32">
      <div className="page-shell">
        <header className="mb-16 border-b border-slate-100 pb-12">
          <p className="text-xs font-bold uppercase tracking-[0.4em] text-[var(--club-primary)] mb-4">{copy.pages.news.eyebrow}</p>
          <h1 className="font-display text-6xl font-black uppercase italic leading-none tracking-tighter text-slate-900 lg:text-9xl">
            {copy.pages.news.title}
          </h1>
        </header>

        {featuredArticle && (
          <section className="mb-24">
            <Link href={`/news/${featuredArticle.id}`} className="group grid gap-8 lg:grid-cols-12 lg:gap-16">
              <div className="lg:col-span-7">
                <div className="relative aspect-[16/9] overflow-hidden rounded-3xl bg-slate-100 shadow-2xl">
                  <Image
                    src={featuredArticle.coverImageUrl ?? "/brand-surface.svg"}
                    alt={featuredArticle.title}
                    fill
                    priority
                    className="object-cover transition-transform duration-700 group-hover:scale-105"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                </div>
              </div>
              <div className="flex flex-col justify-center lg:col-span-5">
                <div className="flex items-center gap-4 mb-6">
                  <span className="rounded-full bg-[var(--club-primary)] px-4 py-1 text-[10px] font-black uppercase tracking-widest text-white">
                    {featuredArticle.category}
                  </span>
                  <time className="text-[10px] font-bold uppercase tracking-widest text-slate-400">
                    {formatDate(featuredArticle.publishedAt)}
                  </time>
                </div>
                <h2 className="font-display text-4xl font-black uppercase italic leading-[0.9] tracking-tight text-slate-900 mb-6 group-hover:text-[var(--club-primary)] transition-colors lg:text-6xl">
                  {featuredArticle.title}
                </h2>
                <p className="text-lg text-slate-600 leading-relaxed mb-8">
                  {featuredArticle.excerpt}
                </p>
                <div className="inline-flex items-center gap-3 text-xs font-black uppercase tracking-widest text-[var(--club-primary)]">
                  Read Full Story <ArrowRight size={16} />
                </div>
              </div>
            </Link>
          </section>
        )}

        <section className="grid gap-12 md:grid-cols-2 lg:grid-cols-3">
          {secondaryArticles.map((article) => (
            <Link key={article.id} href={`/news/${article.id}`} className="group">
              <div className="relative mb-6 aspect-video overflow-hidden rounded-2xl bg-slate-100 shadow-lg">
                <Image
                  src={article.coverImageUrl ?? "/brand-surface.svg"}
                  alt={article.title}
                  fill
                  className="object-cover transition-transform duration-500 group-hover:scale-105"
                />
              </div>
              <div className="flex items-center gap-3 mb-4">
                <span className="text-[9px] font-black uppercase tracking-widest text-[var(--club-primary)]">
                  {article.category}
                </span>
                <span className="h-1 w-1 rounded-full bg-slate-200" />
                <time className="text-[9px] font-bold uppercase tracking-widest text-slate-400">
                  {formatDate(article.publishedAt)}
                </time>
              </div>
              <h3 className="font-display text-2xl font-black uppercase italic leading-tight text-slate-900 group-hover:text-[var(--club-primary)] transition-colors">
                {article.title}
              </h3>
            </Link>
          ))}
        </section>
      </div>
    </div>
  );
}
