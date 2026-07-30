import { HistorySurface } from "@/components/history-surface";
import { getClubProfile } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.history.metaTitle(club),
    description: copy.pages.history.metaDescription(club),
    path: "/history",
  });
}

export default async function HistoryPage() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <HistorySurface
      locale={club.defaultLanguage}
      identity={club.nickname || club.shortName}
      copy={{
        eyebrow: copy.pages.history.eyebrow,
        title: copy.pages.history.title(club),
        description: copy.pages.history.description(club),
        newsroom: copy.common.clubNewsroom,
        supporterChapters: copy.common.supporterChapters,
        moments: copy.common.moments,
        identity: copy.common.identity,
        surface: copy.common.surface,
        surfaceValue: copy.pages.history.surfaceValue,
        clubIdentity: copy.pages.history.clubIdentity,
        historyAcrossClub: copy.pages.history.historyAcrossClub,
        identityParagraph: copy.pages.history.identityParagraph,
        seeMembershipIdentity: copy.pages.history.seeMembershipIdentity,
      }}
    />
  );
}
