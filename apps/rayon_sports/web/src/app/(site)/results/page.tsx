import { MatchCollectionSurface } from "@/components/match-collection-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.results.metaTitle(club),
    description: copy.pages.results.metaDescription(club),
    path: "/results",
  });
}

export default async function ResultsPage() {
  const featureGate = await getFeaturePageGuard("live", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) return featureGate;

  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <MatchCollectionSurface
      mode="results"
      locale={club.defaultLanguage}
      currencyCode={club.currencyCode}
      clubName={club.shortName}
      copy={{
        eyebrow: copy.pages.results.eyebrow,
        title: copy.pages.results.title,
        description: copy.pages.results.description(club),
        primaryAction: copy.common.backToFixtures,
        secondaryAction: copy.common.leagueTable,
        selectedLabel: copy.pages.results.recentForm,
        viewDetails: copy.details,
        emptyTitle: "No completed results are confirmed yet.",
        emptyDetail: "Return later for the confirmed public scoreline record.",
        supportingTitle: copy.pages.results.resultsWithContext,
        supportingPoints: copy.pages.results.contextPoints,
      }}
    />
  );
}
