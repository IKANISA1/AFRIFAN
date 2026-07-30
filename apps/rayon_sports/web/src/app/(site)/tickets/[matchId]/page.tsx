import { MatchDetailSurface } from "@/components/match-detail-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ matchId: string }>;
}) {
  const { matchId } = await params;
  return buildPageMetadata({
    title: "Ticket detail",
    description: "Confirmed public match pricing, availability, and supporter-app handoff.",
    path: `/tickets/${encodeURIComponent(matchId)}`,
  });
}

export default async function TicketDetailPage({
  params,
}: {
  params: Promise<{ matchId: string }>;
}) {
  const featureGate = await getFeaturePageGuard("ticketing", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) return featureGate;

  const [{ matchId }, club] = await Promise.all([params, getClubProfile()]);
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <MatchDetailSurface
      matchId={matchId}
      mode="ticket"
      locale={club.defaultLanguage}
      currencyCode={club.currencyCode}
      copy={{
        backLabel: copy.pages.tickets.eyebrow,
        eyebrow: copy.pages.tickets.eyebrow,
        description: copy.pages.tickets.description(club),
        continueInFanApp: copy.common.continueInFanApp,
        membership: copy.membership,
      }}
    />
  );
}
