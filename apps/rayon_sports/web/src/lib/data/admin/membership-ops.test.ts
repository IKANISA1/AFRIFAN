// @vitest-environment node

import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  getAdminMembershipApplications,
  reviewMembershipApplication,
} from "./membership-ops";

describe("getAdminMembershipApplications", () => {
  it("loads applications and hydrates profile data without embedded joins", async () => {
    const applicationRows = [
      {
        id: "application-1",
        user_id: "user-1",
        club_id: 24,
        tier: "gold",
        status: "pending",
        payment_status: "paid",
        application_date: "2026-04-16T22:00:00.000Z",
        updated_at: "2026-07-24T20:00:00.000Z",
        review_date: null,
        reviewer_id: null,
        notes: null,
      },
    ];

    const profileRows = [
      {
        id: "user-1",
        full_name: "UAT Admin",
        phone: "+250788123456",
      },
    ];

    const client = {
      from(table: string) {
        if (table === "membership_applications") {
          return {
            select(columns: string) {
              expect(columns).toBe("*");
              return {
                eq(column: string, value: unknown) {
                  expect(column).toBe("club_id");
                  expect(value).toBe(24);
                  return {
                    order(orderColumn: string, options: { ascending: boolean }) {
                      expect(orderColumn).toBe("application_date");
                      expect(options).toEqual({ ascending: false });
                      return Promise.resolve({
                        data: applicationRows,
                        error: null,
                      });
                    },
                  };
                },
              };
            },
          };
        }

        if (table === "profiles") {
          return {
            select(columns: string) {
              expect(columns).toBe("id, full_name, phone");
              return {
                in(column: string, values: string[]) {
                  expect(column).toBe("id");
                  expect(values).toEqual(["user-1"]);
                  return Promise.resolve({
                    data: profileRows,
                    error: null,
                  });
                },
              };
            },
          };
        }

        if (table === "users") {
          return {
            select(columns: string) {
              expect(columns).toBe("id, full_name, phone");
              return {
                in(column: string, values: string[]) {
                  expect(column).toBe("id");
                  expect(values).toEqual(["user-1"]);
                  return Promise.resolve({
                    data: [],
                    error: null,
                  });
                },
              };
            },
          };
        }

        throw new Error(`Unexpected table lookup: ${table}`);
      },
    } as unknown as SupabaseClient;

    await expect(
      getAdminMembershipApplications(client, {
        clubId: "24",
      } as unknown as AdminAccess),
    ).resolves.toEqual([
      {
        id: "application-1",
        userId: "user-1",
        clubId: 24,
        tier: "gold",
        status: "pending",
        paymentStatus: "paid",
        applicationDate: "2026-04-16T22:00:00.000Z",
        reviewDate: null,
        reviewerId: null,
        notes: null,
        userName: "UAT Admin",
        userPhone: "+250788123456",
        updatedAt: "2026-07-24T20:00:00.000Z",
      },
    ]);
  });

  it("falls back to users when profile rows are unavailable", async () => {
    const applicationRows = [
      {
        id: "application-2",
        user_id: "user-2",
        club_id: 24,
        tier: "imena",
        status: "pending",
        payment_status: "paid",
        application_date: "2026-04-16T23:00:00.000Z",
        updated_at: "2026-07-24T20:05:00.000Z",
        review_date: null,
        reviewer_id: null,
        notes: null,
      },
    ];

    const userRows = [
      {
        id: "user-2",
        full_name: "Fallback User",
        phone: "+250788654321",
      },
    ];

    const client = {
      from(table: string) {
        if (table === "membership_applications") {
          return {
            select(columns: string) {
              expect(columns).toBe("*");
              return {
                eq(column: string, value: unknown) {
                  expect(column).toBe("club_id");
                  expect(value).toBe(24);
                  return {
                    order(orderColumn: string, options: { ascending: boolean }) {
                      expect(orderColumn).toBe("application_date");
                      expect(options).toEqual({ ascending: false });
                      return Promise.resolve({
                        data: applicationRows,
                        error: null,
                      });
                    },
                  };
                },
              };
            },
          };
        }

        if (table === "profiles") {
          return {
            select(columns: string) {
              expect(columns).toBe("id, full_name, phone");
              return {
                in(column: string, values: string[]) {
                  expect(column).toBe("id");
                  expect(values).toEqual(["user-2"]);
                  return Promise.resolve({
                    data: [],
                    error: null,
                  });
                },
              };
            },
          };
        }

        if (table === "users") {
          return {
            select(columns: string) {
              expect(columns).toBe("id, full_name, phone");
              return {
                in(column: string, values: string[]) {
                  expect(column).toBe("id");
                  expect(values).toEqual(["user-2"]);
                  return Promise.resolve({
                    data: userRows,
                    error: null,
                  });
                },
              };
            },
          };
        }

        throw new Error(`Unexpected table lookup: ${table}`);
      },
    } as unknown as SupabaseClient;

    await expect(
      getAdminMembershipApplications(client, {
        clubId: "24",
      } as unknown as AdminAccess),
    ).resolves.toEqual([
      {
        id: "application-2",
        userId: "user-2",
        clubId: 24,
        tier: "imena",
        status: "pending",
        paymentStatus: "paid",
        applicationDate: "2026-04-16T23:00:00.000Z",
        reviewDate: null,
        reviewerId: null,
        notes: null,
        userName: "Fallback User",
        userPhone: "+250788654321",
        updatedAt: "2026-07-24T20:05:00.000Z",
      },
    ]);
  });
});

describe("reviewMembershipApplication", () => {
  it("resolves the club partner before calling the atomic review RPC", async () => {
    const client = {
      from(table: string) {
        if (table === "membership_applications") {
          return {
            select(columns: string) {
              expect(columns).toBe("*");
              return {
                eq(column: string, value: unknown) {
                  expect(column).toBe("id");
                  expect(value).toBe("application-1");
                  return {
                    single() {
                      return Promise.resolve({
                        data: {
                          id: "application-1",
                          user_id: "user-1",
                          tier: "gold",
                          payment_status: "paid",
                          metadata: { chapter: "Central" },
                        },
                        error: null,
                      });
                    },
                  };
                },
              };
            },
            update(payload: Record<string, unknown>) {
              expect(payload.status).toBe("approved");
              expect(payload.notes).toBe("Looks good");
              expect(payload.reviewer_id).toBe("admin-1");
              return {
                eq(column: string, value: unknown) {
                  expect(column).toBe("id");
                  expect(value).toBe("application-1");
                  return Promise.resolve({ error: null });
                },
              };
            },
          };
        }

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

        if (table === "fan_memberships") {
          return {
            update(payload: Record<string, unknown>) {
              expect(payload).toMatchObject({
                tier: "gold",
                status: "active",
                club_id: 24,
                chapter: "Central",
              });
              return {
                eq(column: string, value: unknown) {
                  expect(column).toBe("user_id");
                  expect(value).toBe("user-1");
                  return {
                    eq(innerColumn: string, innerValue: unknown) {
                      expect(innerColumn).toBe("partner_id");
                      expect(innerValue).toBe("partner-1");
                      return {
                        select(columns: string) {
                          expect(columns).toBe("id");
                          return {
                            maybeSingle() {
                              return Promise.resolve({
                                data: { id: "membership-1" },
                                error: null,
                              });
                            },
                          };
                        },
                      };
                    },
                  };
                },
              };
            },
          };
        }

        throw new Error(`Unexpected table lookup: ${table}`);
      },
      rpc(fn: string, payload: Record<string, unknown>) {
        expect(fn).toBe(
          "admin_review_membership_application_if_unchanged",
        );
        expect(payload).toEqual({
          p_application_id: "application-1",
          p_expected_updated_at: "2026-07-24T20:00:00.000Z",
          p_decision: "approved",
          p_notes: "Looks good",
          p_club_id: 24,
          p_partner_id: "partner-1",
          p_actor_id: "admin-1",
        });
        return Promise.resolve({
          data: { id: "application-1" },
          error: null,
        });
      },
    } as unknown as SupabaseClient;

    await expect(
      reviewMembershipApplication(
        client,
        {
          clubId: "24",
          userId: "admin-1",
        } as unknown as AdminAccess,
        "application-1",
        "2026-07-24T20:00:00.000Z",
        "approved",
        "Looks good",
      ),
    ).resolves.toBeUndefined();
  });
});
