import { assertEquals } from "jsr:@std/assert";
import { createFootballSyncHandler } from "./index.ts";
import { HttpError, requireGlobalAdminCaller } from "../_shared/auth.ts";

for (const role of ["club_admin", "club_moderator", "supporter"]) {
  Deno.test(`actual football synchronization denies ${role} before service or provider work`, async () => {
    const handler = createFootballSyncHandler({
      requireCronSecret: () => {
        throw new HttpError(401, "Not cron");
      },
      requireGlobalAdminCaller: (request) =>
        requireGlobalAdminCaller(request, {
          createUserClient: () => ({
            auth: {
              getUser: async () => ({
                data: {
                  user: { id: "actor-1", app_metadata: { role, club_id: 7 } },
                },
                error: null,
              }),
            },
          }),
          createAdminClient: () => ({
            from: () => ({
              select: () => ({
                eq: () => ({
                  eq: async () => ({
                    data: [{ role, club_id: 7, is_active: true }],
                    error: null,
                  }),
                }),
              }),
            }),
          }),
        }),
      createAdminClient: () => {
        throw new Error("global service work must not begin");
      },
    });
    const response = await handler(
      new Request("https://example.test/football-sync", {
        method: "POST",
        headers: {
          authorization: "Bearer staff-token",
          "content-type": "application/json",
        },
        body: JSON.stringify({ command: "full-sync" }),
      }),
    );
    assertEquals(response.status, 403);
  });
}
