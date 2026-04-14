import { buildPageMetadata } from "@/lib/metadata";
import { getClubProfile } from "@/lib/data/public";
import { HeroBlock } from "./_sections/hero-block";
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

export default function HomePage() {
  return (
    <div className="space-y-16 pb-20 pt-6 sm:pt-8">
      <HeroBlock />
      <CirclesAndMatchdayBlock />
      <FixturesBlock />
      <MembershipAndStandingsBlock />
      <NewsBlock />
      <ShopAndIdentityBlock />
    </div>
  );
}
