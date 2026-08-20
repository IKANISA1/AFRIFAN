import { describe, expect, it } from "vitest";

import {
  canRenderFeature,
  canUseFeature,
  getContentBlocks,
  getFeatureAccess,
  getFeatureKeyForPath,
  getNavFeatures,
  getRuntimeCopy,
  isRouteAvailable,
  type PlatformConfigSnapshot,
} from "./feature-config";

const config: PlatformConfigSnapshot = {
  channel: "web",
  club_id: 7,
  config_version: "2026-04-16T18:00:00Z",
  features: [
    {
      feature_key: "news",
      display_name: "News",
      is_enabled: true,
      visibility_state: "visible",
      channel: {
        is_enabled: true,
        is_visible: true,
        show_in_navigation: true,
        show_on_home: true,
        sort_order: 2,
        route_key: "/news",
        placement_key: "home_feed",
      },
      rules: {
        auth_required: false,
        role_restrictions: [],
        dependency_rules: {},
        rollout_rules: {},
        is_within_schedule: true,
      },
    },
    {
      feature_key: "shop",
      display_name: "Shop",
      is_enabled: true,
      visibility_state: "hidden",
      channel: {
        is_enabled: true,
        is_visible: false,
        show_in_navigation: true,
        show_on_home: true,
        sort_order: 3,
        route_key: "/shop",
        placement_key: "home_store",
      },
      rules: {
        auth_required: false,
        role_restrictions: [],
        dependency_rules: {},
        rollout_rules: {},
        is_within_schedule: true,
      },
    },
    {
      feature_key: "tickets",
      display_name: "Tickets",
      is_enabled: true,
      visibility_state: "maintenance",
      channel: {
        is_enabled: true,
        is_visible: true,
        show_in_navigation: true,
        show_on_home: true,
        sort_order: 1,
        route_key: "/tickets",
        placement_key: "home_primary",
      },
      rules: {
        auth_required: false,
        role_restrictions: [],
        dependency_rules: {},
        rollout_rules: {},
        is_within_schedule: true,
      },
    },
    {
      feature_key: "venue_app",
      display_name: "Venue App",
      is_enabled: true,
      visibility_state: "visible",
      channel: {
        is_enabled: true,
        is_visible: true,
        show_in_navigation: true,
        show_on_home: false,
        sort_order: 5,
        route_key: "/venues",
        placement_key: null,
      },
      rules: {
        auth_required: false,
        role_restrictions: [],
        dependency_rules: {},
        rollout_rules: {},
        is_within_schedule: true,
      },
    },
    {
      feature_key: "fan_clubs",
      display_name: "Fan Clubs",
      is_enabled: true,
      visibility_state: "visible",
      channel: {
        is_enabled: true,
        is_visible: true,
        show_in_navigation: false,
        show_on_home: false,
        sort_order: 4,
        route_key: "/fan-clubs",
        placement_key: null,
      },
      rules: {
        auth_required: true,
        role_restrictions: [],
        dependency_rules: {},
        rollout_rules: {},
        is_within_schedule: true,
      },
    },
  ],
  content_blocks: [
    {
      block_key: "hero",
      block_type: "banner",
      title: "Hero",
      subtitle: null,
      content: {},
      target_channel: "web",
      placement_key: "home_top",
      feature_key: null,
      is_active: true,
      sort_order: 1,
      metadata: {},
    },
    {
      block_key: "news-promo",
      block_type: "card",
      title: "News promo",
      subtitle: null,
      content: {},
      target_channel: "web",
      placement_key: "home_top",
      feature_key: "news",
      is_active: true,
      sort_order: 2,
      metadata: {},
    },
    {
      block_key: "shop-promo",
      block_type: "card",
      title: "Shop promo",
      subtitle: null,
      content: {},
      target_channel: "web",
      placement_key: "home_top",
      feature_key: "shop",
      is_active: true,
      sort_order: 3,
      metadata: {},
    },
  ],
  route_registry: [],
  option_sets: [],
  runtime_copy: [],
  site_navigation: [],
  site_search: [],
  venue_governance_controls: [],
};

describe("feature-config", () => {
  it("distinguishes hidden, maintenance, and auth-gated states", () => {
    const hidden = getFeatureAccess(config, "shop");
    const maintenance = getFeatureAccess(config, "tickets");
    const signedOut = getFeatureAccess(config, "fan_clubs");
    const signedIn = getFeatureAccess(config, "fan_clubs", {
      isAuthenticated: true,
    });

    expect(hidden.isVisible).toBe(false);
    expect(hidden.isOperational).toBe(true);
    expect(canRenderFeature(config, "shop")).toBe(false);
    expect(canUseFeature(config, "shop")).toBe(true);

    expect(maintenance.isVisible).toBe(true);
    expect(maintenance.isOperational).toBe(false);
    expect(maintenance.reason).toBe("maintenance");

    expect(signedOut.isAvailable).toBe(false);
    expect(signedOut.reason).toBe("auth_required");
    expect(signedIn.isAvailable).toBe(true);
  });

  it("derives navigation and content blocks from the same feature state", () => {
    const navKeys = getNavFeatures(config).map(
      (feature) => feature.feature_key,
    );
    const blockKeys = getContentBlocks(config, "home_top").map(
      (block) => block.block_key,
    );

    expect(navKeys).toEqual(["news", "venue_app"]);
    expect(blockKeys).toEqual(["hero", "news-promo"]);
  });

  it("uses exact, language, then deterministic English runtime-copy fallback", () => {
    const copyConfig: PlatformConfigSnapshot = {
      ...config,
      runtime_copy: [
        {
          copy_key: "home.feed.degraded",
          surface: "web",
          locale: "rw",
          text_value: "Amakuru ntabonetse.",
          description: null,
          metadata: {},
        },
        {
          copy_key: "home.feed.degraded",
          surface: "web",
          locale: "fr",
          text_value: "Les informations sont indisponibles.",
          description: null,
          metadata: {},
        },
        {
          copy_key: "home.feed.degraded",
          surface: "web",
          locale: "en",
          text_value: "Club data is unavailable.",
          description: null,
          metadata: {},
        },
        {
          copy_key: "home.feed.degraded",
          surface: "web",
          locale: "fr-rw",
          text_value: "Les informations locales sont indisponibles.",
          description: null,
          metadata: {},
        },
      ],
    };

    expect(getRuntimeCopy(copyConfig, "home.feed.degraded", "FR_rw")).toBe(
      "Les informations locales sont indisponibles.",
    );
    expect(getRuntimeCopy(copyConfig, "home.feed.degraded", "fr-BE")).toBe(
      "Les informations sont indisponibles.",
    );
    expect(getRuntimeCopy(copyConfig, "home.feed.degraded", "de")).toBe(
      "Club data is unavailable.",
    );
  });

  it("does not fall through to unrelated runtime-copy locales", () => {
    const copyConfig: PlatformConfigSnapshot = {
      ...config,
      runtime_copy: [
        {
          copy_key: "home.feed.degraded",
          surface: "web",
          locale: "rw",
          text_value: "Amakuru ntabonetse.",
          description: null,
          metadata: {},
        },
      ],
    };

    expect(getRuntimeCopy(copyConfig, "home.feed.degraded", "fr")).toBeNull();
  });

  it("blocks disabled routes while leaving unrelated routes alone", () => {
    expect(getFeatureKeyForPath(config, "/news/123")).toBe("news");
    expect(getFeatureKeyForPath(config, "/shop/cart")).toBe("shop");
    expect(getFeatureKeyForPath(config, "/venues/rayon-lounge")).toBe(
      "venue_app",
    );
    expect(isRouteAvailable(config, "/news/123")).toBe(true);
    expect(isRouteAvailable(config, "/shop/cart")).toBe(false);
    expect(isRouteAvailable(config, "/tickets/checkout")).toBe(false);
    expect(isRouteAvailable(config, "/venues/rayon-lounge")).toBe(true);
    expect(isRouteAvailable(config, "/contact")).toBe(true);
  });
});
