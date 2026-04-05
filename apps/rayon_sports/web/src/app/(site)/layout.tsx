import { Suspense } from "react";
import type { ReactNode } from "react";
import { MatchRibbon } from "@/components/match-ribbon";
import { AppBottomNav } from "@/components/app-bottom-nav";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { getClubProfile, getMatches } from "@/lib/data/public";

/* ─────────────────────────────────────────────────────────────
   Async server islands — each fetches its own data so the
   document shell streams immediately (no blocking layout await).
   ───────────────────────────────────────────────────────────── */

async function LiveRibbon() {
  const matches = await getMatches();
  const liveMatch = matches.find((m) => m.matchStatus === "live");
  const nextMatch =
    liveMatch ??
    matches.find(
      (m) => m.matchStatus === "scheduled" || m.matchStatus === "upcoming",
    ) ??
    null;
  return <MatchRibbon match={nextMatch} />;
}

async function HeaderWithClub() {
  const club = await getClubProfile();
  return <SiteHeader club={club} />;
}

/* ─────────────────────────────────────────────────────────────
   Layout — fully synchronous. Suspense boundaries allow
   header + ribbon to stream in as their data resolves while
   still painting the skip-link, main slot, footer, and bottom
   bar immediately.
   ───────────────────────────────────────────────────────────── */

export default function SiteLayout({
  children,
}: {
  children: ReactNode;
}) {
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
    <>
      <a
        href="#main-content"
        className="sr-only fixed left-4 top-4 z-[80] rounded-full bg-white px-4 py-2 text-sm font-semibold text-club-ink shadow-lg focus:not-sr-only"
      >
        Skip to content
      </a>

      <Suspense>
        <LiveRibbon />
      </Suspense>

      <Suspense>
        <HeaderWithClub />
      </Suspense>
      <script dangerouslySetInnerHTML={{ __html: publicSwBootstrap }} />

      <main id="main-content" className="flex-1 pb-16 md:pb-0">
        {children}
      </main>

      <SiteFooter />
      <AppBottomNav surface="site" />
    </>
  );
}
