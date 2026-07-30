import { MembershipSurface } from "@/components/membership-surface";
import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.membership.metaTitle(club),
    description: copy.pages.membership.metaDescription(club),
    path: "/membership",
  });
}

export default async function MembershipPage() {
  const featureGate = await getFeaturePageGuard("membership", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  return (
    <MembershipSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      fanAppHref={resolveFanAppHref()}
      hasExternalAppUrl={siteConfig.fanAppUrl.length > 0}
    />
  );
}
