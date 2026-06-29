// @vitest-environment node

import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { saveAdminClubProfile } from "./settings";

describe("saveAdminClubProfile", () => {
  it("normalizes team colors before persisting club settings", async () => {
    const client = {
      from(table: string) {
        expect(table).toBe("african_football_clubs");
        return {
          select(columns: string) {
            expect(columns).toBe("id");
            return {
              eq(column: string, value: unknown) {
                expect(column).toBe("id");
                expect(value).toBe(24);
                return {
                  maybeSingle() {
                    return Promise.resolve({
                      data: { id: 24 },
                      error: null,
                    });
                  },
                };
              },
            };
          },
          update(payload: Record<string, unknown>) {
            expect(payload).toMatchObject({
              club_name: "Rayon Sports FC",
              club_slug: "rayon-sports",
              primary_color_hex: "#0038A8",
              secondary_color_hex: "#0E2B55",
              accent_color_hex: "#FFCC00",
            });
            const query = {
              eq(column: string, value: unknown) {
                expect(column).toBe("id");
                expect(value === 24 || value === "24").toBe(true);
                return value === "24"
                  ? Promise.resolve({ error: null })
                  : query;
              },
            };
            return {
              eq: query.eq,
            };
          },
        };
      },
    } as unknown as SupabaseClient;

    await expect(
      saveAdminClubProfile(
        client,
        { clubId: "24" } as unknown as AdminAccess,
        {
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
          defaultLanguage: "rw",
          supportedLanguages: ["rw", "en", "fr"],
          officialContact: "+250 700 000 000",
          facebookUrl: null,
          xUrl: null,
          instagramUrl: null,
          tiktokUrl: null,
          officialLogoUrl: null,
          primaryColorHex: "0038a8",
          secondaryColorHex: "#0e2b55",
          accentColorHex: "#FC0",
          featureFlags: {
            chat: true,
            fan_clubs: true,
            shop: true,
            sms_ledger: true,
            ticketing: true,
          },
        },
      ),
    ).resolves.toBe("24");
  });

  it("rejects malformed team color values", async () => {
    await expect(
      saveAdminClubProfile(
        {} as unknown as SupabaseClient,
        { clubId: "24" } as unknown as AdminAccess,
        {
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
          defaultLanguage: "rw",
          supportedLanguages: ["rw", "en", "fr"],
          officialContact: "+250 700 000 000",
          facebookUrl: null,
          xUrl: null,
          instagramUrl: null,
          tiktokUrl: null,
          officialLogoUrl: null,
          primaryColorHex: "not-a-color",
          secondaryColorHex: "#0E2B55",
          accentColorHex: "#F7B500",
          featureFlags: {
            chat: true,
            fan_clubs: true,
            shop: true,
            sms_ledger: true,
            ticketing: true,
          },
        },
      ),
    ).rejects.toThrow("Primary team color must be a valid hex value");
  });
});
