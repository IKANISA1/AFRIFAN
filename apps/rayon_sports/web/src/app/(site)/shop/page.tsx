import { ShopSurface } from "@/components/shop-surfaces";
import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
    title: copy.pages.shop.metaTitle(club),
    description: copy.pages.shop.metaDescription(club),
    path: "/shop",
  });
}

export default async function ShopPage() {
  const featureGate = await getFeaturePageGuard("shop", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const club = await getClubProfile();
  return (
    <ShopSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      fanAppHref={resolveFanAppHref()}
      hasExternalAppUrl={siteConfig.fanAppUrl.length > 0}
    />
  );
}
