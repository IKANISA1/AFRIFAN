import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { createDispatchScheduledNotificationsHandler } from "./index.ts";
import { HttpError } from "../_shared/auth.ts";
const op = "99002900-0000-4000-8000-000000000001";
function request(body: unknown = {}) {
  return new Request("https://qa.invalid/scheduled", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}
Deno.test("scheduled notification actual cron rejects before service job access", async () => {
  let privileged = 0;
  const handler = createDispatchScheduledNotificationsHandler({
    requireCronSecret: () => {
      throw new HttpError(403, "Cron authority required");
    },
    createAdminClient: () => {
      privileged++;
      throw new Error("No job reads without cron authority");
    },
  });
  assertEquals((await handler(request())).status, 403);
  assertEquals(privileged, 0);
});
Deno.test("scheduled notification actual cron lists original commands and never rewrites notifications directly", async () => {
  let dispatched = 0;
  const handler = createDispatchScheduledNotificationsHandler({
    requireCronSecret: () => {},
    enforceRateLimit: async () => {},
    createAdminClient: () => ({
      rpc: async (name: string, args: unknown) => {
        assertEquals(name, "list_due_admin_notification_commands");
        assertEquals(args, { p_limit: 2 });
        return { data: [{ operation_id: op }], error: null };
      },
      from: () => {
        throw new Error("No raw notification writes");
      },
    } as never),
    dispatchCommand: async (_, original) => {
      dispatched++;
      assertEquals(original, op);
      return { delivery: { status: "unknown" } } as never;
    },
  });
  const response = await handler(request({ limit: 2 }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).data, {
    processed: 1,
    sent: 0,
    partial: 0,
    failed: 0,
    unknown: 1,
    processing: 0,
    fetched: 1,
  });
  assertEquals(dispatched, 1);
});
Deno.test("scheduled notification uncertain worker result is retained as unknown without raw retry writes", async () => {
  let attempts = 0;
  const handler = createDispatchScheduledNotificationsHandler({
    requireCronSecret: () => {},
    enforceRateLimit: async () => {},
    createAdminClient: () => ({
      rpc: async () => ({ data: [{ operation_id: op }], error: null }),
      from: () => {
        throw new Error("No false failed update");
      },
    } as never),
    dispatchCommand: async () => {
      attempts++;
      throw new Error("lost completion response");
    },
  });
  const response = await handler(request());
  assertEquals(response.status, 200);
  assertEquals((await response.json()).data.unknown, 1);
  assertEquals(attempts, 1);
});
