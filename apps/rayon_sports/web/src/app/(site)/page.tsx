import { HomeSurface } from "@/components/home-surface";
import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    club,
    title: `Official ${club.clubName} website`,
    description: `Official ${club.clubName} website for confirmed fixtures, tickets, membership, club news, and merchandise.`,
    path: "/",
  });
}

export default async function HomePage() {
  const featureGate = await getFeaturePageGuard("home", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  return (
    <HomeSurface
      locale={club.defaultLanguage}
      clubId={club.id}
      clubShortName={club.shortName}
      currencyCode={club.currencyCode}
      fanAppHref={resolveFanAppHref()}
      hasExternalAppUrl={siteConfig.fanAppUrl.length > 0}
    />
  );
}
