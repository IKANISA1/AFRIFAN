import { MatchCollectionSurface } from "@/components/match-collection-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
    title: copy.pages.tickets.metaTitle(club),
    description: copy.pages.tickets.metaDescription(club),
    path: "/tickets",
  });
}

export default async function TicketsPage() {
  const featureGate = await getFeaturePageGuard("ticketing", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) return featureGate;

  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <MatchCollectionSurface
      mode="tickets"
      locale={club.defaultLanguage}
      currencyCode={club.currencyCode}
      clubName={club.shortName}
      copy={{
        eyebrow: copy.pages.tickets.eyebrow,
        title: copy.pages.tickets.title,
        description: copy.pages.tickets.description(club),
        primaryAction: copy.common.continueInFanApp,
        secondaryAction: copy.common.unlockPriorityAccess,
        selectedLabel: copy.pages.tickets.matchdayEssentials,
        viewDetails: copy.details,
        emptyTitle: "No tickets are currently on sale.",
        emptyDetail: "Return later for confirmed matchday availability.",
        supportingTitle: copy.pages.tickets.buyWithConfidence,
        supportingPoints: copy.pages.tickets.confidencePoints,
      }}
    />
  );
}
