import { StandingsSurface } from "@/components/standings-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
    title: copy.pages.standings.metaTitle(club),
    description: copy.pages.standings.metaDescription(club),
    path: "/standings",
  });
}

export default async function StandingsPage() {
  const featureGate = await getFeaturePageGuard("live", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) return featureGate;

  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <StandingsSurface
      locale={club.defaultLanguage}
      clubName={club.shortName}
      copy={{
        eyebrow: copy.pages.standings.eyebrow,
        title: copy.pages.standings.title,
        description: copy.pages.standings.description(club),
        fixtureHub: copy.common.fixtureHub,
        recentResults: copy.common.recentResults,
        positionInRace: copy.pages.standings.positionInRace,
        highlightedClub: copy.pages.standings.highlightedClub,
        summaryPoints: copy.pages.standings.summaryPoints,
        clubsShown: copy.common.clubsShown,
        clubPosition: copy.pages.standings.clubPosition(club),
        points: copy.common.points,
        position: copy.common.position,
        club: copy.common.club,
        played: copy.common.played,
        goalDifference: copy.common.goalDifference,
        form: copy.common.form,
        recentScorelines: copy.common.recentScorelines,
        upcomingMatches: copy.common.upcomingMatches,
      }}
    />
  );
}
