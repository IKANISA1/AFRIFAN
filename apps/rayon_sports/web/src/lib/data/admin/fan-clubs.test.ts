// @vitest-environment node

import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { saveAdminFanClub } from "./fan-clubs";

describe("saveAdminFanClub", () => {
  it("resolves the club football partner before creating a fan club", async () => {
    const client = {
      from(table: string) {
        if (table === "african_football_clubs") {
          return {
            select(columns: string) {
              expect(columns).toBe("club_name, club_slug");
              return {
                eq(column: string, value: unknown) {
                  expect(column).toBe("id");
                  expect(value).toBe(24);
                  return {
                    maybeSingle() {
                      return Promise.resolve({
                        data: {
                          club_name: "Rayon Sports FC",
                          club_slug: "rayon-sports",
                        },
                        error: null,
                      });
                    },
                  };
                },
              };
            },
          };
        }

        if (table === "partners") {
          return {
            select(columns: string) {
              expect(columns).toBe("id");
              return {
                eq(column: string, value: unknown) {
                  if (column === "category") {
                    expect(value).toBe("football");
                    return {
                      eq(innerColumn: string, innerValue: unknown) {
                        expect(innerColumn).toBe("slug");
                        expect(innerValue).toBe("rayon-sports");
                        return {
                          maybeSingle() {
                            return Promise.resolve({
                              data: { id: "partner-1" },
                              error: null,
                            });
                          },
                        };
                      },
                    };
                  }

                  throw new Error(`Unexpected partners filter: ${column}`);
                },
              };
            },
          };
        }

        if (table === "fan_clubs") {
          return {
            insert(payload: Record<string, unknown>) {
              expect(payload).toMatchObject({
                partner_id: "partner-1",
                club_id: 24,
                name: "Kigali North",
                region: "Kigali",
                description: "North FanClubs",
                member_count: 42,
                event_count: 3,
                rating: 4.5,
                banner_image_url: "https://example.com/chapter.jpg",
                is_active: true,
              });
              return {
                select(columns: string) {
                  expect(columns).toBe("id");
                  return {
                    single() {
                      return Promise.resolve({
                        data: { id: "fan-club-1" },
                        error: null,
                      });
                    },
                  };
                },
              };
            },
          };
        }

        throw new Error(`Unexpected table lookup: ${table}`);
      },
    } as unknown as SupabaseClient;

    await expect(
      saveAdminFanClub(
        client,
        { clubId: "24" } as unknown as AdminAccess,
        {
          name: "Kigali North",
          region: "Kigali",
          description: "North FanClubs",
          memberCount: 42,
          eventCount: 3,
          rating: 4.5,
          bannerImageUrl: "https://example.com/chapter.jpg",
          isActive: true,
        },
      ),
    ).resolves.toBe("fan-club-1");
  });
});
