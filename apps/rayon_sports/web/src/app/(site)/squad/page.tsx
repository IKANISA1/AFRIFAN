import { SquadSurface } from "@/components/squad-surface";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.squad.metaTitle(club),
    description: copy.pages.squad.metaDescription(club),
    path: "/squad",
  });
}

export default async function SquadPage() {
  const featureGate = await getFeaturePageGuard("squad", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) return featureGate;

  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <SquadSurface
      locale={club.defaultLanguage}
      copy={{
        eyebrow: copy.pages.squad.eyebrow,
        title: copy.pages.squad.title,
        description: copy.pages.squad.description(club),
        fixtureHub: copy.common.fixtureHub,
        leagueTable: copy.common.leagueTable,
        playersShown: copy.common.players,
        unitsShown: copy.common.coreUnits,
        selectedNumber: copy.common.position,
        selectedPlayer: copy.pages.squad.unitView,
        unitView: copy.pages.squad.unitView,
        tacticalShape: copy.pages.squad.tacticalShape,
        rosterNote: copy.pages.squad.rosterNote,
        goalkeepers: copy.pages.squad.goalkeepers,
        defenders: copy.pages.squad.defenders,
        midfielders: copy.pages.squad.midfielders,
        attackers: copy.pages.squad.attackers,
        nationality: copy.common.nationalities,
        playerRole: copy.common.position,
      }}
    />
  );
}
