import type { Metadata } from "next";
import { ShopProductSurface } from "@/components/shop-surfaces";
import { resolveFanAppHref, hasFanAppDestination } from "@/lib/config";
import { getClubProfile, getProductById } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata({
  params,
}: PageProps<"/shop/[productId]">): Promise<Metadata> {
  const { productId } = await params;
  const [club, product] = await Promise.all([
    getClubProfile(),
    getProductById(productId),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  return buildPageMetadata({
    club,
    title: product?.name ?? copy.pages.shop.metaTitle(club),
    description: product?.subtitle ?? copy.pages.shop.metaDescription(club),
    path: `/shop/${productId}`,
    imagePath: product?.imageUrl ?? "/brand-surface.svg",
  });
}

export default async function ProductPage({
  params,
}: PageProps<"/shop/[productId]">) {
  const featureGate = await getFeaturePageGuard("shop", {
    allowControlledRouteEvidence: true,
  });
  if (featureGate) {
    return featureGate;
  }

  const { productId } = await params;
  const club = await getClubProfile();
  return (
    <ShopProductSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      clubId={club.id}
      currencyCode={club.currencyCode}
      fanAppHref={resolveFanAppHref(club.clubSlug)}
      hasExternalAppUrl={hasFanAppDestination(club.clubSlug)}
      productId={productId}
    />
  );
}
