import {
  getContentBlocks,
  type ContentBlock,
  type PlatformConfigSnapshot,
} from "@/lib/feature-config";

export const HOME_BLOCK_PLACEMENTS = [
  "home_hero",
  "home_top",
  "home_mid",
  "home_bottom",
  "home_footer",
] as const;

const singletonComponents = new Set([
  "hero",
  "hero-block",
  "circles-matchday-block",
  "matchday_hub",
  "fixtures-block",
  "fixtures",
  "membership-standings-block",
  "standings",
  "news-block",
  "news",
  "shop-identity-block",
  "shop",
  "stories-block",
  "stories",
]);

function componentKey(block: ContentBlock) {
  return String(block.content.component || block.block_type || "")
    .trim()
    .toLowerCase();
}

/**
 * Returns the ordered home composition while failing safe against duplicated
 * runtime CMS records. Structural sections are singletons; authored HTML
 * blocks can intentionally appear more than once when their block keys differ.
 */
export function selectHomeBlocks(config: PlatformConfigSnapshot) {
  const seenBlockKeys = new Set<string>();
  const seenSingletonComponents = new Set<string>();

  return HOME_BLOCK_PLACEMENTS.flatMap((placement) =>
    getContentBlocks(config, placement),
  ).filter((block) => {
    const blockKey = block.block_key.trim();
    if (seenBlockKeys.has(blockKey)) {
      return false;
    }
    seenBlockKeys.add(blockKey);

    const component = componentKey(block);
    if (!singletonComponents.has(component)) {
      return true;
    }
    if (seenSingletonComponents.has(component)) {
      return false;
    }
    seenSingletonComponents.add(component);
    return true;
  });
}
