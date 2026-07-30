import { VenuesSurface } from "@/components/venues-surface";
import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";

export async function generateMetadata() {
  return buildPageMetadata({
    title: "Partner venues",
    description:
      "Approved Rayon Sports partner venues with fan-app handoff for check-in and matchday ordering.",
    path: "/venues",
  });
}

export default async function PublicVenuesPage() {
  const featureGate = await getFeaturePageGuard("venue_app", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  return (
    <VenuesSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      fanAppHref={resolveFanAppHref()}
      hasExternalAppUrl={siteConfig.fanAppUrl.length > 0}
    />
  );
}
