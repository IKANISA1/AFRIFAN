import type { ReactNode } from "react";
import { Breadcrumbs } from "@/components/breadcrumbs";
import { MatchRibbon } from "@/components/match-ribbon";
import { MobileBottomBar } from "@/components/mobile-bottom-bar";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { getClubProfile, getMatches, getSiteSearchIndex } from "@/lib/data/public";

export default async function SiteLayout({
  children,
}: {
  children: ReactNode;
}) {
  const [club, matches, searchItems] = await Promise.all([
    getClubProfile(),
    getMatches(),
    getSiteSearchIndex(),
  ]);
  const liveMatch = matches.find((match) => match.matchStatus === "live") ?? null;

  return (
    <>
      <MatchRibbon match={liveMatch} />
      <SiteHeader club={club} searchItems={searchItems} />
      <Breadcrumbs />
      <main className="flex-1 pb-16 md:pb-0">{children}</main>
      <SiteFooter />
      <MobileBottomBar />
    </>
  );
}

