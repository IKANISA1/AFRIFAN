import type { Metadata } from "next";
import { NewsArticleSurface } from "@/components/news-article-surface";
import { getClubProfile, getNewsArticleById } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ articleId: string }>;
}): Promise<Metadata> {
  const { articleId } = await params;
  const [club, article] = await Promise.all([
    getClubProfile(),
    getNewsArticleById(articleId),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  if (article == null) {
    return buildPageMetadata({
      title: copy.pages.news.metaTitle(club),
      description: copy.pages.news.metaDescription(club),
      path: `/news/${articleId}`,
      type: "article",
    });
  }

  return buildPageMetadata({
    title: article.title,
    description: article.excerpt,
    path: `/news/${article.id}`,
    imagePath: article.coverImageUrl ?? "/brand-surface.svg",
    type: "article",
  });
}

export default async function ArticlePage({
  params,
}: {
  params: Promise<{ articleId: string }>;
}) {
  const featureGate = await getFeaturePageGuard("news", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const [{ articleId }, club] = await Promise.all([
    params,
    getClubProfile(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <NewsArticleSurface
      articleId={articleId}
      locale={club.defaultLanguage}
      copy={{
        newsroom: copy.common.clubNewsroom,
        details: copy.details,
        standards: copy.pages.news.newsroomStandards,
        standardsTitle: copy.pages.news.newsroomStandardsTitle,
        standardsPoints: copy.pages.news.standardsPoints,
        minuteRead: copy.common.minuteRead,
        matchdayCoverage: copy.common.matchdayCoverage,
      }}
    />
  );
}
