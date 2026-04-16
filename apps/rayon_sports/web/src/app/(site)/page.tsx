import { buildPageMetadata } from "@/lib/metadata";
import { getClubProfile } from "@/lib/data/public";
import { HeroBlock } from "./_sections/hero-block";
import { GroupsAndMatchdayBlock } from "./_sections/Groups-matchday-block";
import { FixturesBlock } from "./_sections/fixtures-block";
import { MembershipAndStandingsBlock } from "./_sections/membership-standings-block";
import { NewsBlock } from "./_sections/news-block";
import { ShopAndIdentityBlock } from "./_sections/shop-identity-block";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: `Official ${club.clubName} website`,
    description: `Official ${club.clubName} website for live fixtures, tickets, membership, supporter Groups, club news, and matchday coverage.`,
  });
}

export default function HomePage() {
  return (
    <div className="flex flex-col gap-24 pb-32 pt-0 lg:gap-48">
      <HeroBlock />
      <div className="flex flex-col gap-24 lg:gap-48">
        <GroupsAndMatchdayBlock />
        <FixturesBlock />
        <MembershipAndStandingsBlock />
        <NewsBlock />
        <ShopAndIdentityBlock />
      </div>
    </div>
  );
}
