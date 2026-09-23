import { NewsSurface } from "@/components/news-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
    title: copy.pages.news.metaTitle(club),
    description: copy.pages.news.metaDescription(club),
    path: "/news",
  });
}

export default async function NewsPage() {
  const featureGate = await getFeaturePageGuard("news", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <NewsSurface
      locale={club.defaultLanguage}
      identity={club.nickname || club.shortName}
      copy={{
        eyebrow: copy.pages.news.eyebrow,
        title: copy.pages.news.title,
        description: copy.pages.news.description(club),
        newsroomStandards: copy.pages.news.newsroomStandards,
        newsroomStandardsTitle: copy.pages.news.newsroomStandardsTitle,
        standardsPoints: copy.pages.news.standardsPoints,
      }}
    />
  );
}
