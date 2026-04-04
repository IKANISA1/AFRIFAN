import { Suspense } from "react";
import { SkeletonCard } from "@/components/skeleton";
import { buildPageMetadata } from "@/lib/metadata";
import { HeroBlock } from "./_sections/hero-block";
import { CirclesAndMatchdayBlock } from "./_sections/circles-matchday-block";
import { FixturesBlock } from "./_sections/fixtures-block";
import { MembershipAndStandingsBlock } from "./_sections/membership-standings-block";
import { NewsBlock } from "./_sections/news-block";
import { ShopAndIdentityBlock } from "./_sections/shop-identity-block";

export const metadata = buildPageMetadata({
  title: "Official Rayon Sports website",
  description:
    "Official Rayon Sports website for live fixtures, tickets, membership, supporter circles, club news, and matchday coverage.",
});

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
      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <HeroBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <CirclesAndMatchdayBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton />}>
        <FixturesBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <MembershipAndStandingsBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton />}>
        <NewsBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <ShopAndIdentityBlock />
      </Suspense>
    </div>
  );
}
