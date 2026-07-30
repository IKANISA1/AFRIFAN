// @vitest-environment node

import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, PlatformFeature } from "@/lib/types";
import {
  MAX_ADMIN_FEATURES,
  getAdminFeatures,
  normalizeAdminFeatureUpdate,
  normalizeAdminFeatures,
  updateAdminFeature,
} from "./features";

const timestamp = "2026-07-30T09:00:00.000Z";
const clubAdminAccess: AdminAccess = {
  hasAccess: true,
  isAuthenticated: true,
  isSuperAdmin: false,
  userId: "club-admin-1",
  role: "club_admin",
  clubId: "24",
  availableClubIds: ["24"],
  canSelectClub: false,
  assignmentCount: 1,
};

const validFeature: PlatformFeature = {
  id: "feature-1",
  clubId: 24,
  scope: "club",
  featureKey: "ticketing",
  displayName: "Ticketing",
  description: "Matchday ticket controls.",
  category: "commerce",
  isEnabled: true,
  visibilityState: "visible",
  updatedAt: timestamp,
  channels: [
    {
      id: "channel-1",
      channel: "mobile",
      isEnabled: true,
      isVisible: true,
      showInNavigation: true,
      showOnHome: false,
      sortOrder: 20,
      routeKey: "/tickets",
      placementKey: "main_nav",
    },
    {
      id: "channel-2",
      channel: "web",
      isEnabled: true,
      isVisible: true,
      showInNavigation: true,
      showOnHome: true,
      sortOrder: 10,
      routeKey: "/tickets",
      placementKey: "home_top",
    },
  ],
  rules: {
    authRequired: true,
    roleRestrictions: ["member", "vip"],
    dependencyRules: { minimum_version: 4 },
    rolloutRules: { percentage: 50 },
    metadata: { owner: "matchday" },
    scheduleStartAt: "2026-08-01T08:00:00.000Z",
    scheduleEndAt: "2026-08-31T20:00:00.000Z",
  },
};

function toRow(feature: PlatformFeature) {
  return {
    id: feature.id,
    feature_key: feature.featureKey,
    display_name: feature.displayName,
    description: feature.description,
    category: feature.category,
    club_id: feature.clubId,
    is_enabled: feature.isEnabled,
    visibility_state: feature.visibilityState,
    updated_at: feature.updatedAt,
    channels: feature.channels.map((channel) => ({
      id: channel.id,
      channel: channel.channel,
      is_enabled: channel.isEnabled,
      is_visible: channel.isVisible,
      show_in_navigation: channel.showInNavigation,
      show_on_home: channel.showOnHome,
      sort_order: channel.sortOrder,
      route_key: channel.routeKey,
      placement_key: channel.placementKey,
    })),
    rules:
      feature.rules == null
        ? null
        : [
            {
              auth_required: feature.rules.authRequired,
              role_restrictions: feature.rules.roleRestrictions,
              dependency_rules: feature.rules.dependencyRules,
              rollout_rules: feature.rules.rolloutRules,
              metadata: feature.rules.metadata,
              schedule_start_at: feature.rules.scheduleStartAt,
              schedule_end_at: feature.rules.scheduleEndAt,
            },
          ],
  };
}

describe("admin feature registry", () => {
  it("accepts strict API records, derives scope, and ignores unowned fields", () => {
    const normalized = normalizeAdminFeatures([
      {
        ...validFeature,
        scope: "global",
        internal_secret: "not-public",
      },
    ]);

    expect(normalized).toEqual([validFeature]);
    expect(JSON.stringify(normalized)).not.toContain("not-public");
  });

  it.each([
    [
      "sensitive metadata",
      [
        {
          ...validFeature,
          rules: {
            ...validFeature.rules!,
            metadata: { access_token: "private" },
          },
        },
      ],
    ],
    [
      "duplicate channel",
      [
        {
          ...validFeature,
          channels: [validFeature.channels[0], validFeature.channels[0]],
        },
      ],
    ],
    [
      "reversed schedule",
      [
        {
          ...validFeature,
          rules: {
            ...validFeature.rules!,
            scheduleStartAt: "2026-09-01T00:00:00.000Z",
            scheduleEndAt: "2026-08-01T00:00:00.000Z",
          },
        },
      ],
    ],
    [
      "duplicate feature key",
      [validFeature, { ...validFeature, id: "feature-2" }],
    ],
  ])("rejects %s instead of returning a partial registry", (_label, value) => {
    expect(() => normalizeAdminFeatures(value)).toThrow();
  });

  it("rejects an oversized registry", () => {
    expect(() =>
      normalizeAdminFeatures(
        Array.from({ length: MAX_ADMIN_FEATURES + 1 }, (_, index) => ({
          ...validFeature,
          id: `feature-${index}`,
          featureKey: `feature_${index}`,
        })),
      ),
    ).toThrow("safe limit");
  });

  it("normalizes mutation input and rejects unknown or unsafe fields", () => {
    expect(
      normalizeAdminFeatureUpdate({
        displayName: "  Ticketing  ",
        description: "",
        isEnabled: false,
        channels: validFeature.channels.map(
          ({ id: _id, ...channel }) => channel,
        ),
        rules: validFeature.rules,
      }),
    ).toMatchObject({
      displayName: "Ticketing",
      description: null,
      isEnabled: false,
    });

    expect(() =>
      normalizeAdminFeatureUpdate({ isEnabled: true, actorId: "private" }),
    ).toThrow();
    expect(() =>
      normalizeAdminFeatureUpdate({
        rules: {
          ...validFeature.rules,
          metadata: { password: "private" },
        },
      }),
    ).toThrow();
  });

  it("resolves a club override over the global record and bounds the query", async () => {
    const globalRow = toRow({
      ...validFeature,
      id: "feature-global",
      clubId: null,
      scope: "global",
      isEnabled: false,
    });
    const clubRow = toRow(validFeature);
    const limit = vi.fn().mockResolvedValue({
      data: [globalRow, clubRow],
      error: null,
    });
    const order = vi.fn(() => ({ limit }));
    const or = vi.fn(() => ({ order }));
    const select = vi.fn(() => ({ or }));
    const from = vi.fn(() => ({ select }));

    await expect(
      getAdminFeatures({ from } as unknown as SupabaseClient, clubAdminAccess),
    ).resolves.toEqual([validFeature]);
    expect(or).toHaveBeenCalledWith("club_id.is.null,club_id.eq.24");
    expect(limit).toHaveBeenCalledWith(MAX_ADMIN_FEATURES + 1);
  });

  it("keeps club moderators read-only before invoking the mutation RPC", async () => {
    const rpc = vi.fn();
    await expect(
      updateAdminFeature(
        { rpc } as unknown as SupabaseClient,
        { ...clubAdminAccess, role: "club_moderator" },
        validFeature.id,
        timestamp,
        { isEnabled: false },
      ),
    ).rejects.toThrow("access is required");
    expect(rpc).not.toHaveBeenCalled();
  });

  it("sends a validated, scoped optimistic mutation to the RPC", async () => {
    const rpc = vi.fn().mockResolvedValue({ error: null });
    await expect(
      updateAdminFeature(
        { rpc } as unknown as SupabaseClient,
        clubAdminAccess,
        validFeature.id,
        timestamp,
        { isEnabled: false },
      ),
    ).resolves.toBeUndefined();
    expect(rpc).toHaveBeenCalledWith(
      "admin_update_platform_feature_if_unchanged",
      expect.objectContaining({
        p_feature_id: validFeature.id,
        p_expected_updated_at: timestamp,
        p_club_id: 24,
        p_updates: { isEnabled: false },
        p_actor_id: "club-admin-1",
      }),
    );
  });
});
