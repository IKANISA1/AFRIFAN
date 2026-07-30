import { FixturesSurface } from "@/components/fixtures-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.fixtures.metaTitle(club),
    description: copy.pages.fixtures.metaDescription(club),
    path: "/fixtures",
  });
}

export default async function FixturesPage() {
  const featureGate = await getFeaturePageGuard("live", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <FixturesSurface
      locale={club.defaultLanguage}
      currencyCode={club.currencyCode}
      copy={{
        eyebrow: copy.pages.fixtures.eyebrow,
        title: copy.pages.fixtures.title,
        description: copy.pages.fixtures.description(club),
        buyTickets: copy.buyTickets,
        recentResults: copy.common.recentResults,
      }}
    />
  );
}
