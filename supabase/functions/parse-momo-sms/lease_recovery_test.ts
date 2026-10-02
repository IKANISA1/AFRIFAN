import { handleRequest } from "./index.ts";
import { assertEquals as compare } from "./reconciliation_test_support.ts";
const assertEquals = (
  actual: unknown,
  expected: unknown,
  message = "Expected contract value",
) => compare(actual, expected, message);
const eventId = "99964000-0000-4000-8000-000000000001",
  secret = btoa("a".repeat(32));
for (
  const failure of [
    "lost committed response",
    "uncommitted SQL transaction",
  ] as const
) {
  Deno.test(`actual Supabase worker retries ${failure} with the same durable event`, async () => {
    const values = {
      SUPABASE_URL: "https://qa.invalid",
      SUPABASE_SERVICE_ROLE_KEY: "qa-service-key",
      SUPABASE_SECRET_KEYS: "",
      TRUSTED_SMS_INGRESS_ENABLED: "true",
      SMS_PROCESSOR_SECRET: secret,
    };
    const saved = Object.fromEntries(
      Object.keys(values).map((k) => [k, Deno.env.get(k)]),
    );
    for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
    const originalFetch = globalThis.fetch;
    let attempts = 0, posted = 0;
    const json = (data: unknown, status = 200) =>
      new Response(JSON.stringify(data), {
        status,
        headers: { "content-type": "application/json" },
      });
    globalThis.fetch = async (input, init) => {
      const url = new URL(String(input));
      assertEquals(url.origin, "https://qa.invalid");
      const body = JSON.parse(String(init?.body));
      const rpc = url.pathname.split("/").at(-1);
      if (rpc === "get_trusted_sms_gateway_event") {
        assertEquals(body.p_event_id, eventId);
        return json({
          gateway_id: "99964000-0000-4000-8000-000000000020",
          club_id: 9996401,
        });
      }
      if (rpc === "consume_edge_rate_limit") {
        return json([{ allowed: true, retry_after_seconds: 0 }]);
      }
      if (rpc === "process_trusted_sms_gateway_evidence") {
        assertEquals(body.p_event_id, eventId);
        assertEquals(Object.keys(body).join(), "p_event_id");
        attempts++;
        if (attempts === 1) {
          if (failure === "lost committed response") posted++;
          return json({ message: "private transaction failure" }, 500);
        }
        const replay = posted > 0;
        if (!replay) posted++;
        return json({ event_id: eventId, status: "confirmed", replay });
      }
      throw new Error(`Unexpected Auth/provider/table call: ${url.pathname}`);
    };
    const request = () =>
      new Request("https://qa.invalid/functions/v1/parse-momo-sms", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-sms-processor-secret": secret,
        },
        body: JSON.stringify({ eventId }),
      });
    try {
      const first = await handleRequest(request());
      assertEquals(first.status, 500);
      assertEquals(
        JSON.stringify(await first.json()).includes(
          "private transaction failure",
        ),
        false,
      );
      const second = await handleRequest(request());
      assertEquals(second.status, 200);
      const receipt = await second.json();
      assertEquals(receipt.eventId, eventId);
      assertEquals(receipt.replay, failure === "lost committed response");
      assertEquals(posted, 1);
      assertEquals(attempts, 2);
    } finally {
      globalThis.fetch = originalFetch;
      for (const [k, v] of Object.entries(saved)) {
        v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
      }
    }
  });
}
