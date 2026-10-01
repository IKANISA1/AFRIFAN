import { assertEquals, assertFalse } from "jsr:@std/assert";
import { syncFixtures } from "./sync-fixtures.ts";

Deno.test("fixture synchronization keeps governed config linkage and redacts persisted provider failure details", async () => {
  const previousKey = Deno.env.get("API_FOOTBALL_KEY");
  const previousFetch = globalThis.fetch;
  const privateValue =
    "person@example.test +250788123456 https://private.invalid/?token=secret";
  const updates: Record<string, unknown>[] = [];
  const inserts: Record<string, unknown>[] = [];
  Deno.env.set("API_FOOTBALL_KEY", "qa-provider-substitute");
  globalThis.fetch = () =>
    Promise.resolve(new Response(privateValue, { status: 503 }));
  try {
    const config = {
      id: "configuration-1",
      external_league_id: 1,
      season_year: 2026,
      league_name: "League",
    };
    const client = {
      from(table: string) {
        if (table === "football_sync_config") {
          return {
            select() {
              return {
                eq() {
                  return {
                    eq() {
                      return Promise.resolve({ data: [config], error: null });
                    },
                  };
                },
              };
            },
          };
        }
        assertEquals(table, "football_sync_log");
        return {
          insert(row: Record<string, unknown>) {
            inserts.push(row);
            return {
              select() {
                return {
                  single() {
                    return Promise.resolve({ data: { id: "log-1" } });
                  },
                };
              },
            };
          },
          update(row: Record<string, unknown>) {
            updates.push(row);
            return {
              eq(column: string, value: string) {
                assertEquals(column, "id");
                assertEquals(value, "log-1");
                return Promise.resolve({ error: null });
              },
            };
          },
        };
      },
    };
    const results = await syncFixtures(client as never);
    assertEquals(results.length, 1);
    assertEquals(inserts[0], {
      sync_config_id: "configuration-1",
      sync_type: "fixtures",
      status: "started",
    });
    assertEquals(updates.length, 1);
    assertEquals(updates[0].status, "failed");
    assertEquals(updates[0].error_message, "Football synchronization failed.");
    assertFalse(JSON.stringify(updates).includes(privateValue));
    assertEquals(results[0].league, "League");
  } finally {
    globalThis.fetch = previousFetch;
    if (previousKey == null) Deno.env.delete("API_FOOTBALL_KEY");
    else Deno.env.set("API_FOOTBALL_KEY", previousKey);
  }
});
