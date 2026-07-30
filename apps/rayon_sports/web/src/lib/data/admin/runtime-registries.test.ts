// @vitest-environment node

import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminRuntimeRegistrySnapshot } from "@/lib/types";
import {
  MAX_RUNTIME_RECORDS_PER_COLLECTION,
  normalizeAdminRuntimeRegistrySnapshot,
  saveAdminPlatformRoute,
} from "./runtime-registries";

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

const base = {
  clubId: 24,
  scope: "club" as const,
  isActive: true,
  metadata: { owner: "platform" },
  createdAt: timestamp,
  updatedAt: timestamp,
};

const snapshot: AdminRuntimeRegistrySnapshot = {
  routes: [
    {
      ...base,
      id: "route-1",
      routeKey: "tickets.detail",
      pathPattern: "/tickets/:matchId",
      surface: "web",
      featureKey: "ticketing",
      label: "Ticket detail",
      authRequired: true,
      requiredRoles: ["member"],
      presentation: "screen",
      showInNavigation: false,
      showOnHome: false,
      sortOrder: 10,
    },
  ],
  optionSets: [
    {
      ...base,
      id: "option-set-1",
      optionSetKey: "ticket_payment_method",
      label: "Ticket payment method",
      description: "Allowed payment methods.",
      valueType: "text",
      surface: "both",
    },
  ],
  optionValues: [
    {
      id: "option-value-1",
      optionSetId: "option-set-1",
      optionKey: "mobile_money",
      label: "Mobile money",
      value: "momo",
      sortOrder: 1,
      isDefault: true,
      isActive: true,
      metadata: { owner: "commerce" },
      createdAt: timestamp,
      updatedAt: timestamp,
    },
  ],
  runtimeCopy: [
    {
      ...base,
      id: "copy-1",
      copyKey: "tickets.checkout.title",
      surface: "both",
      locale: "en",
      textValue: "Complete your ticket purchase",
      description: "Checkout heading.",
    },
  ],
  navigation: [
    {
      ...base,
      id: "navigation-1",
      navKey: "tickets",
      label: "Tickets",
      href: "/tickets",
      navGroup: "primary",
      surface: "web",
      featureKey: "ticketing",
      sortOrder: 10,
    },
  ],
  search: [
    {
      ...base,
      id: "search-1",
      searchKey: "tickets",
      title: "Tickets",
      description: "Browse match tickets.",
      href: "/tickets",
      category: "Page",
      metaLabel: "Matchday",
      surface: "web",
      featureKey: "ticketing",
      sortOrder: 10,
    },
  ],
  venueControls: [
    {
      ...base,
      id: "venue-control-1",
      controlKey: "orders.review",
      label: "Order review",
      detail: "Review pending venue orders.",
      statusLabel: "review_required",
      actionLabel: "Review",
      controlGroup: "orders",
      venueId: "venue-1",
      sortOrder: 10,
    },
  ],
};

describe("admin runtime registry normalization", () => {
  it("accepts strict bounded records and derives every scope from club id", () => {
    const normalized = normalizeAdminRuntimeRegistrySnapshot({
      ...snapshot,
      routes: [
        {
          ...snapshot.routes[0],
          scope: "global",
          private_owner_email: "not-public@example.com",
        },
      ],
    });

    expect(normalized).toEqual(snapshot);
    expect(JSON.stringify(normalized)).not.toContain("not-public");
  });

  it.each([
    [
      "an invalid surface",
      {
        ...snapshot,
        routes: [{ ...snapshot.routes[0], surface: "consumer" }],
      },
    ],
    [
      "sensitive metadata",
      {
        ...snapshot,
        navigation: [
          {
            ...snapshot.navigation[0],
            metadata: { access_token: "private" },
          },
        ],
      },
    ],
    [
      "a non-relative navigation target",
      {
        ...snapshot,
        navigation: [
          { ...snapshot.navigation[0], href: "https://untrusted.example" },
        ],
      },
    ],
    [
      "duplicate scoped keys",
      {
        ...snapshot,
        runtimeCopy: [
          snapshot.runtimeCopy[0],
          { ...snapshot.runtimeCopy[0], id: "copy-2" },
        ],
      },
    ],
  ])("rejects %s instead of returning a partial registry", (_label, value) => {
    expect(() => normalizeAdminRuntimeRegistrySnapshot(value)).toThrow();
  });

  it("rejects an oversized collection", () => {
    expect(() =>
      normalizeAdminRuntimeRegistrySnapshot({
        ...snapshot,
        routes: Array.from(
          { length: MAX_RUNTIME_RECORDS_PER_COLLECTION + 1 },
          (_, index) => ({
            ...snapshot.routes[0],
            id: `route-${index}`,
            routeKey: `route_${index}`,
          }),
        ),
      }),
    ).toThrow("safe limit");
  });
});

describe("admin runtime registry writes", () => {
  it("keeps club moderators read-only before querying storage", async () => {
    const from = vi.fn();
    await expect(
      saveAdminPlatformRoute(
        { from } as unknown as SupabaseClient,
        { ...clubAdminAccess, role: "club_moderator" },
        snapshot.routes[0],
      ),
    ).rejects.toThrow("write access is required");
    expect(from).not.toHaveBeenCalled();
  });

  it("prevents club admins from writing global registry records", async () => {
    const from = vi.fn();
    await expect(
      saveAdminPlatformRoute(
        { from } as unknown as SupabaseClient,
        clubAdminAccess,
        { ...snapshot.routes[0], scope: "global" },
      ),
    ).rejects.toThrow("Platform admin access is required");
    expect(from).not.toHaveBeenCalled();
  });

  it("rejects sensitive metadata before a runtime write", async () => {
    const from = vi.fn();
    await expect(
      saveAdminPlatformRoute(
        { from } as unknown as SupabaseClient,
        clubAdminAccess,
        {
          ...snapshot.routes[0],
          metadata: { password: "private" },
        },
      ),
    ).rejects.toThrow("without sensitive keys");
    expect(from).not.toHaveBeenCalled();
  });
});
