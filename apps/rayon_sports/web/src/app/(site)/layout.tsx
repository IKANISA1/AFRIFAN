import type { ReactNode } from "react";
import { MatchRibbon } from "@/components/match-ribbon";
import { AppBottomNav } from "@/components/app-bottom-nav";
import { FloatingSearchButton } from "@/components/floating-search-button";
import { FocusOnRouteChange } from "@/components/focus-on-route-change";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { getClubProfile, getMatches } from "@/lib/data/public";
import { buildClubThemeStyle } from "@/lib/club-theme";
import { getSiteChromeCopy } from "@/lib/site-copy";
import { ui } from "@/design-system";

export default async function SiteLayout({
  children,
}: {
  children: ReactNode;
}) {
  const [club, matches] = await Promise.all([getClubProfile(), getMatches()]);
  const copy = getSiteChromeCopy(club.defaultLanguage);
  const themeStyle = buildClubThemeStyle(club);
  const liveMatch = matches.find((match) => match.matchStatus === "live");
  const nextMatch =
    liveMatch ??
    matches.find(
      (match) =>
        match.matchStatus === "scheduled" || match.matchStatus === "upcoming",
    ) ??
    null;

  const publicSwBootstrap = `
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      const registerWorker = () => {
        window.setTimeout(() => {
          navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(() => {});
        }, 4000);
      };

      if (document.readyState === 'complete') {
        registerWorker();
      } else {
        window.addEventListener('load', registerWorker, { once: true });
      }
    }
  `;

  return (
    <div
      className="club-site relative isolate flex min-h-screen flex-col overflow-hidden"
      style={themeStyle}
      lang={club.defaultLanguage}
      data-club-locale={club.defaultLanguage}
    >
      <div className="club-site-atmosphere" aria-hidden="true" />
      <div className="club-site-grid" aria-hidden="true" />
      <a
        href="#main-content"
        className={`sr-only fixed left-4 top-4 z-[80] ${ui.buttonPrimary} px-4 py-2 text-sm focus:not-sr-only`}
      >
        Skip to content
      </a>

      <MatchRibbon match={nextMatch} copy={copy} />
      <SiteHeader club={club} copy={copy} />
      <script dangerouslySetInnerHTML={{ __html: publicSwBootstrap }} />

      <main
        id="main-content"
        tabIndex={-1}
        className="relative z-[1] flex-1 pb-16 outline-none md:pb-0"
      >
        {children}
      </main>

      <SiteFooter club={club} copy={copy} />
      <FocusOnRouteChange targetId="main-content" />
      <FloatingSearchButton label={copy.search} />
      <AppBottomNav copy={copy} />
    </div>
  );
}
