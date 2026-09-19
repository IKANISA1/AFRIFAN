import { describe, expect, it } from "vitest";
import type {
  ContentBlock,
  PlatformConfigSnapshot,
} from "@/lib/feature-config";
import { selectHomeBlocks } from "@/lib/home-block-selection";

function configWithBlocks(
  contentBlocks: ContentBlock[],
): PlatformConfigSnapshot {
  return {
    features: [],
    content_blocks: contentBlocks,
    route_registry: [],
    option_sets: [],
    runtime_copy: [],
    site_navigation: [],
    site_search: [],
    config_version: "test",
    channel: "web",
    club_id: 24,
  };
}

function block(
  blockKey: string,
  placementKey: string,
  component: string,
): ContentBlock {
  return {
    block_key: blockKey,
    block_type: component,
    placement_key: placementKey,
    title: blockKey,
    subtitle: null,
    content: { component },
    target_channel: "web",
    feature_key: null,
    sort_order: 1,
    is_active: true,
    metadata: {},
  };
}

describe("selectHomeBlocks", () => {
  it("keeps one structural component when CMS records are duplicated", () => {
    const config = configWithBlocks([
      block("hero-primary", "home_hero", "hero-block"),
      block("hero-duplicate", "home_top", "hero-block"),
    ]);

    expect(selectHomeBlocks(config).map((block) => block.block_key)).toEqual([
      "hero-primary",
    ]);
  });

  it("allows distinct authored HTML blocks across home placements", () => {
    const config = configWithBlocks([
      block("campaign-one", "home_mid", "html"),
      block("campaign-two", "home_bottom", "html"),
    ]);

    expect(selectHomeBlocks(config).map((block) => block.block_key)).toEqual([
      "campaign-one",
      "campaign-two",
    ]);
  });
});
