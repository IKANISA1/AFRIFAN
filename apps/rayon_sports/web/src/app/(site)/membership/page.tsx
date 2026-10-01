import {headers} from 'next/headers';
import {browserPortalConfig} from '@/lib/browser-portal-server';
import {BrowserMembershipPortal} from '@/components/browser-membership-portal';
export const dynamic = 'force-dynamic';
export const revalidate = 0;
import { MembershipSurface } from "@/components/membership-surface";
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
  let browserConfig;
  try { browserConfig = await browserPortalConfig(club.id, (await headers()).get('host')); }
  catch { return <section className="circles-surface"><h1>Membership temporarily unavailable</h1><p role="alert">The membership service configuration could not be verified. This page has not submitted a new checkout. Previous requests may still need a result check.</p><a href="/support">Contact support</a></section>; }
  if (browserConfig) return <BrowserMembershipPortal origin={browserConfig.origin} clubId={browserConfig.clubId} clubName={club.shortName} />;
  return (
    <MembershipSurface
      locale={club.defaultLanguage}
      clubShortName={club.shortName}
      clubId={club.id}
      countryCode={club.countryCode}
      currencyCode={club.currencyCode}
      fanAppHref={resolveFanAppHref(club.clubSlug)}
      hasExternalAppUrl={hasFanAppDestination(club.clubSlug)}
    />
  );
}
