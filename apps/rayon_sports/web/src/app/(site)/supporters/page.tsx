import { SupportersSurface } from "@/components/supporters-surface";
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
    title: copy.pages.supporters.metaTitle,
    description: copy.pages.supporters.metaDescription,
    path: "/supporters",
  });
}

export default async function SupportersPage() {
  const featureGate = await getFeaturePageGuard("gamification", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  return (
    <SupportersSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      fanAppHref={resolveFanAppHref(club.clubSlug)}
      hasExternalAppUrl={hasFanAppDestination(club.clubSlug)}
    />
  );
}
