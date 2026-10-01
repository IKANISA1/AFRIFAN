import { CirclesSurface } from "@/components/circles-surface";
import { resolveFanAppHref, hasFanAppDestination } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
    title: copy.pages.Groups.metaTitle(club),
    description: copy.pages.Groups.metaDescription(club),
    path: "/circles",
  });
}

export default async function CirclesPage() {
  const featureGate = await getFeaturePageGuard("contributions", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  return (
    <CirclesSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      fanAppHref={resolveFanAppHref(club.clubSlug)}
      hasExternalAppUrl={hasFanAppDestination(club.clubSlug)}
    />
  );
}
