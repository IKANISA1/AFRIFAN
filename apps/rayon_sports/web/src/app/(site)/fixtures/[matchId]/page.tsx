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
    title: "Fixture detail",
    description: "Confirmed public fixture, venue, kickoff, and access details.",
    path: `/fixtures/${encodeURIComponent(matchId)}`,
  });
}

export default async function FixtureDetailPage({
  params,
}: {
  params: Promise<{ matchId: string }>;
}) {
  const featureGate = await getFeaturePageGuard("live", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) return featureGate;

  const [{ matchId }, club] = await Promise.all([params, getClubProfile()]);
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <MatchDetailSurface
      matchId={matchId}
      mode="fixture"
      locale={club.defaultLanguage}
      currencyCode={club.currencyCode}
      copy={{
        backLabel: copy.pages.fixtures.eyebrow,
        eyebrow: copy.pages.fixtures.eyebrow,
        description: copy.pages.fixtures.description(club),
        continueInFanApp: copy.common.continueInFanApp,
        membership: copy.membership,
      }}
    />
  );
}
