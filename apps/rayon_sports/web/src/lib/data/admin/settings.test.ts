// @vitest-environment node

import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  normalizeAdminClubProfile,
  saveAdminClubProfile,
  type AdminClubProfileInput,
} from "./settings";

const updatedAt = "2026-07-30T09:00:00.000Z";
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

const profileInput: AdminClubProfileInput = {
  id: 24,
  clubName: "Rayon Sports FC",
  clubSlug: "rayon-sports",
  shortName: "Rayon",
  nickname: "Gikundiro",
  countryCode: "RW",
  league: "Rwanda Premier League",
  region: "Kigali",
  currencyCode: "RWF",
  currencySymbol: "FRw",
  defaultLanguage: "en",
  supportedLanguages: ["en"],
  officialContact: "+250 700 000 000",
  facebookUrl: "https://facebook.com/rayonsports",
  xUrl: null,
  instagramUrl: null,
  tiktokUrl: null,
  officialLogoUrl: "https://cdn.example.com/rayon.png",
  primaryColorHex: "0038a8",
  secondaryColorHex: "#0e2b55",
  accentColorHex: "#FC0",
  featureFlags: {
    chat: true,
    fan_clubs: false,
  },
  expectedUpdatedAt: updatedAt,
};

function createMutationClient() {
  const payloads: Record<string, unknown>[] = [];
  const versionChecks: unknown[] = [];
  const mutationQuery = {
    eq(column: string, value: unknown) {
      if (column === "updated_at") versionChecks.push(value);
      return mutationQuery;
    },
    select() {
      return mutationQuery;
    },
    maybeSingle() {
      return Promise.resolve({ data: { id: 24 }, error: null });
    },
  };
  const client = {
    from(table: string) {
      expect(table).toBe("african_football_clubs");
      return {
        select(columns: string) {
          expect(columns).toBe("id, club_slug");
          return {
            eq(column: string, value: unknown) {
              expect(column).toBe("id");
              expect(value).toBe(24);
              return {
                maybeSingle() {
                  return Promise.resolve({
                    data: { id: 24, club_slug: "rayon-sports" },
                    error: null,
                  });
                },
              };
            },
          };
        },
        update(payload: Record<string, unknown>) {
          payloads.push(payload);
          return mutationQuery;
        },
      };
    },
  } as unknown as SupabaseClient;
  return { client, payloads, versionChecks };
}

describe("admin club settings", () => {
  it("projects only strict profile fields without fallback or private values", () => {
    const normalized = normalizeAdminClubProfile({
      id: 24,
      club_name: "Rayon Sports FC",
      club_slug: "rayon-sports",
      nickname_brand_identity: "Gikundiro",
      country_iso_code: "rw",
      league: "Rwanda Premier League",
      region: "Kigali",
      currency_code: "rwf",
      currency_symbol: "FRw",
      default_language: "en",
      supported_languages: ["en"],
      official_contact: "+250 700 000 000",
      facebook_url: "https://facebook.com/rayonsports",
      x_twitter_url: null,
      instagram_url: null,
      tiktok_url: null,
      official_logo_url: "https://cdn.example.com/rayon.png",
      primary_color_hex: "#0038a8",
      secondary_color_hex: "#0e2b55",
      accent_color_hex: "#fc0",
      feature_flags: { chat: true, fan_clubs: false },
      updated_at: updatedAt,
      market_research_note: "not-public",
      momo_ussd_template: "not-public",
    });

    expect(normalized).toEqual({
      id: 24,
      clubName: "Rayon Sports FC",
      clubSlug: "rayon-sports",
      shortName: "Gikundiro",
      nickname: "Gikundiro",
      countryCode: "RW",
      league: "Rwanda Premier League",
      region: "Kigali",
      currencyCode: "RWF",
      currencySymbol: "FRw",
      defaultLanguage: "en",
      supportedLanguages: ["en"],
      officialContact: "+250 700 000 000",
      facebookUrl: "https://facebook.com/rayonsports",
      xUrl: null,
      instagramUrl: null,
      tiktokUrl: null,
      officialLogoUrl: "https://cdn.example.com/rayon.png",
      primaryColorHex: "#0038A8",
      secondaryColorHex: "#0E2B55",
      accentColorHex: "#FFCC00",
      featureFlags: { chat: true, fan_clubs: false },
      updatedAt,
    });
    expect(JSON.stringify(normalized)).not.toContain("not-public");
  });

  it.each([
    ["missing profile", null],
    [
      "untrusted URL",
      {
        ...profileInput,
        updatedAt,
        facebookUrl: "http://example.com/rayon",
      },
    ],
    [
      "invalid feature flag",
      {
        ...profileInput,
        updatedAt,
        featureFlags: { "bad flag": true },
      },
    ],
    [
      "missing record version",
      {
        ...profileInput,
        updatedAt: "",
      },
    ],
  ])("rejects %s instead of fabricating settings", (_label, value) => {
    expect(normalizeAdminClubProfile(value)).toBeNull();
  });

  it("normalizes values and enforces optimistic concurrency on save", async () => {
    const { client, payloads, versionChecks } = createMutationClient();

    await expect(
      saveAdminClubProfile(client, clubAdminAccess, profileInput),
    ).resolves.toBe("24");

    expect(payloads[0]).toMatchObject({
      club_name: "Rayon Sports FC",
      club_slug: "rayon-sports",
      primary_color_hex: "#0038A8",
      secondary_color_hex: "#0E2B55",
      accent_color_hex: "#FFCC00",
      feature_flags: {
        chat: true,
        fan_clubs: false,
      },
    });
    expect(versionChecks).toEqual([updatedAt]);
  });

  it("rejects cross-club writes before querying storage", async () => {
    const from = vi.fn();
    await expect(
      saveAdminClubProfile(
        { from } as unknown as SupabaseClient,
        clubAdminAccess,
        { ...profileInput, id: 48 },
      ),
    ).rejects.toThrow("active scope");
    expect(from).not.toHaveBeenCalled();
  });

  it("keeps club moderators read-only", async () => {
    await expect(
      saveAdminClubProfile(
        {} as SupabaseClient,
        { ...clubAdminAccess, role: "club_moderator" },
        profileInput,
      ),
    ).rejects.toThrow("Club admin access is required");
  });

  it("rejects malformed profile values before querying storage", async () => {
    const from = vi.fn();
    await expect(
      saveAdminClubProfile(
        { from } as unknown as SupabaseClient,
        clubAdminAccess,
        {
          ...profileInput,
          primaryColorHex: "not-a-color",
        },
      ),
    ).rejects.toThrow("correct invalid values");
    expect(from).not.toHaveBeenCalled();
  });
});
