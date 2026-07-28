import { buildPageMetadata } from "@/lib/metadata";
import { getClubProfile } from "@/lib/data/public";
import { HeroBlock } from "./_sections/hero-block";
import { GroupsAndMatchdayBlock } from "./_sections/circles-matchday-block";
import { FixturesBlock } from "./_sections/fixtures-block";
import { MembershipAndStandingsBlock } from "./_sections/membership-standings-block";
import { NewsBlock } from "./_sections/news-block";
import { ShopAndIdentityBlock } from "./_sections/shop-identity-block";
import { StoriesBlock } from "./_sections/stories-block";
import {
  getPlatformConfig,
  type ContentBlock,
  type PlatformConfigSnapshot,
} from "@/lib/feature-config";
import { selectHomeBlocks } from "@/lib/home-block-selection";
import { FeatureGate } from "@/components/feature-gate";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: `Official ${club.clubName} website`,
    description: `Official ${club.clubName} website for live fixtures, tickets, membership, supporter circles, club news, and matchday coverage.`,
  });
}

export default async function HomePage() {
  const config = await getPlatformConfig();
  const allBlocks = selectHomeBlocks(config);

  return (
    <div className="flex flex-col gap-24 pb-32 pt-0 lg:gap-48">
      {allBlocks.map((block) => (
        <BlockRenderer key={block.block_key} block={block} config={config} />
      ))}
    </div>
  );
}

function BlockRenderer({
  block,
  config,
}: {
  block: ContentBlock;
  config: PlatformConfigSnapshot;
}) {
  const content = _renderBlockContent(block);

  if (block.feature_key) {
    return (
      <FeatureGate config={config} featureKey={block.feature_key}>
        {content}
      </FeatureGate>
    );
  }

  return content;
}

function _renderBlockContent(block: ContentBlock) {
  const component = String(block.content.component || block.block_type || "");

  switch (component) {
    case "hero":
    case "hero-block":
      return <HeroBlock />;
    case "circles-matchday-block":
    case "matchday_hub":
      return <GroupsAndMatchdayBlock />;
    case "fixtures-block":
    case "fixtures":
      return <FixturesBlock />;
    case "membership-standings-block":
    case "standings":
      return <MembershipAndStandingsBlock />;
    case "news-block":
    case "news":
      return <NewsBlock />;
    case "shop-identity-block":
    case "shop":
      return <ShopAndIdentityBlock />;
    case "stories-block":
    case "stories":
      return <StoriesBlock />;
    case "html":
      return (
        <section className="page-shell">
          {block.title && (
            <h2 className="text-3xl font-bold mb-8 uppercase tracking-tighter text-white">
              {block.title}
            </h2>
          )}
          <div
            className="prose prose-invert max-w-none"
            dangerouslySetInnerHTML={{
              __html: String(block.content.html || ""),
            }}
          />
        </section>
      );
    default:
      // Fallback for sections not explicitly mapped
      return null;
  }
}
