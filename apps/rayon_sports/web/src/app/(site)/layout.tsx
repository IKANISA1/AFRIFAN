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
  const liveMatch = matches.find((m) => m.matchStatus === "live");
  const nextMatch =
    liveMatch ??
    matches.find((m) => m.matchStatus === "scheduled" || m.matchStatus === "upcoming") ??
    null;

  return (
    <>
      <a
        href="#main-content"
        className="sr-only fixed left-4 top-4 z-[80] rounded-full bg-white px-4 py-2 text-sm font-semibold text-club-ink shadow-lg focus:not-sr-only"
      >
        Skip to content
      </a>
      <MatchRibbon match={nextMatch} />
      <SiteHeader club={club} searchItems={searchItems} />
      <Breadcrumbs />
      <main id="main-content" className="flex-1 pb-16 md:pb-0">
        {children}
      </main>
      <SiteFooter />
      <MobileBottomBar />
    </>
  );
}
