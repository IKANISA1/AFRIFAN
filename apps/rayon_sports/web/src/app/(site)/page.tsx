import { Suspense } from "react";
import { SkeletonCard } from "@/components/skeleton";
import { buildPageMetadata } from "@/lib/metadata";
import { AnimateOnScroll } from "@/components/animate-on-scroll";
import { getClubProfile } from "@/lib/data/public";
import { HeroBlock } from "./_sections/hero-block";
import { StoriesBlock } from "./_sections/stories-block";
import { CirclesAndMatchdayBlock } from "./_sections/circles-matchday-block";
import { FixturesBlock } from "./_sections/fixtures-block";
import { MembershipAndStandingsBlock } from "./_sections/membership-standings-block";
import { NewsBlock } from "./_sections/news-block";
import { ShopAndIdentityBlock } from "./_sections/shop-identity-block";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: `Official ${club.clubName} website`,
    description: `Official ${club.clubName} website for live fixtures, tickets, membership, supporter circles, club news, and matchday coverage.`,
  });
}

function SectionSkeleton({ cols = 3 }: { cols?: number }) {
  return (
    <div className="page-shell">
      <div className={`grid gap-5 ${cols === 2 ? "lg:grid-cols-2" : "lg:grid-cols-3"}`}>
        {Array.from({ length: cols }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    </div>
  );
}

export default function HomePage() {
  return (
    <div className="space-y-16 pb-20 pt-6 sm:pt-8">
      {/* Hero — no scroll animation (already visible on load) */}
      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <HeroBlock />
      </Suspense>
      {/* Stories — inline ring carousel (Instagram-style) */}
      <StoriesBlock />

      {/* Circles + Matchday — fade up on scroll */}
      <AnimateOnScroll animation="fade-up" threshold={0.08}>
        <Suspense fallback={<SectionSkeleton cols={2} />}>
          <CirclesAndMatchdayBlock />
        </Suspense>
      </AnimateOnScroll>

      {/* Fixtures — fade up with slight delay */}
      <AnimateOnScroll animation="fade-up" delay={100} threshold={0.08}>
        <Suspense fallback={<SectionSkeleton />}>
          <FixturesBlock />
        </Suspense>
      </AnimateOnScroll>

      {/* Membership + Standings — scale up for visual variety */}
      <AnimateOnScroll animation="fade-up" threshold={0.08}>
        <Suspense fallback={<SectionSkeleton cols={2} />}>
          <MembershipAndStandingsBlock />
        </Suspense>
      </AnimateOnScroll>

      {/* News — fade up */}
      <AnimateOnScroll animation="fade-up" delay={80} threshold={0.08}>
        <Suspense fallback={<SectionSkeleton />}>
          <NewsBlock />
        </Suspense>
      </AnimateOnScroll>

      {/* Shop + Identity — fade up */}
      <AnimateOnScroll animation="fade-up" threshold={0.08}>
        <Suspense fallback={<SectionSkeleton cols={2} />}>
          <ShopAndIdentityBlock />
        </Suspense>
      </AnimateOnScroll>
    </div>
  );
}
