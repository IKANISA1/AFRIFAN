import { handleRequest } from "./index.ts";
import { assertEquals } from "./reconciliation_test_support.ts";

for (
  const scenario of [
    { name: "expired pre-parse worker", claim: "claimed", expected: 200 },
    { name: "live worker", claim: "busy", expected: 409 },
    {
      name: "interrupted persisted interpretation",
      claim: "review_required",
      expected: 409,
    },
    {
      name: "late worker result",
      claim: "claimed",
      lostPersist: true,
      expected: 500,
    },
    {
      name: "late worker completion",
      claim: "claimed",
      lostFinish: true,
      expected: 500,
    },
  ]
) {
  Deno.test(`SMS lease recovery fences ${scenario.name}`, async () => {
    const savedFetch = globalThis.fetch;
    const values = {
      SUPABASE_URL: "https://qa.invalid",
      SUPABASE_ANON_KEY: "qa-public-key",
      SUPABASE_SERVICE_ROLE_KEY: "qa-service-key",
      SUPABASE_PUBLISHABLE_KEYS: "",
      SUPABASE_SECRET_KEYS: "",
      OPENAI_API_KEY: "qa-provider-substitute",
    };
    const saved = Object.fromEntries(
      Object.keys(values).map((k) => [k, Deno.env.get(k)]),
    );
    for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
    const requests: string[] = [];
    let aiCalls = 0, persisted = 0, completed = 0;
    const json = (data: unknown, status = 200) =>
      new Response(JSON.stringify(data), {
        status,
        headers: { "Content-Type": "application/json" },
      });
    globalThis.fetch = async (input, init) => {
      const url = new URL(String(input)), method = init?.method ?? "GET";
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      const table = url.pathname.split("/").at(-1)!;
      requests.push(`${method} ${table}`);
      if (url.origin === "https://api.openai.com") {
        aiCalls++;
        return json({
          output: [{
            content: [{
              type: "output_text",
              text: JSON.stringify({
                parse_status: "needs_review",
                amount: 1000,
                currency: "RWF",
              }),
            }],
          }],
        });
      }
      if (url.origin !== "https://qa.invalid") {
        throw new Error("External requests disabled");
      }
      if (url.pathname === "/auth/v1/user") return json({ id: "user-1" });
      if (table === "edge_function_rate_events") {
        return method === "HEAD"
          ? new Response(null, { headers: { "content-range": "*/0" } })
          : json(null, 201);
      }
      if (table === "momo_sms_raw" && method === "GET") {
        return json([{
          id: "raw-1",
          user_id: "user-1",
          sender: "M-Money",
          sms_body: "Synthetic SMS",
          parse_status: "processing",
          updated_at: "2026-09-19T17:00:00Z",
        }]);
      }
      if (table === "momo_sms_parsed" && method === "GET") return json([]);
      if (table === "claim_momo_sms_parse") {
        assertEquals(
          body.p_user_id,
          "user-1",
          "claim binds authenticated owner",
        );
        assertEquals(body.p_raw_sms_id, "raw-1", "claim binds source SMS");
        assertEquals(
          body.p_expected_updated_at,
          "2026-09-19T17:00:00Z",
          "claim retains observed source version",
        );
        return json({ status: scenario.claim, token: "lease-1" });
      }
      if (table === "persist_momo_sms_parse") {
        persisted++;
        assertEquals(
          body.p_token,
          "lease-1",
          "AI result requires the original lease",
        );
        assertEquals(
          body.p_payload.parse_status,
          "needs_review",
          "actual normalized interpretation is persisted",
        );
        return scenario.lostPersist
          ? json({ message: "MOMO_PARSE_LEASE_LOST" }, 409)
          : json({ id: "parsed-1" });
      }
      if (table === "finish_momo_sms_parse") {
        assertEquals(
          body.p_token,
          "lease-1",
          "completion and failure cleanup are fenced",
        );
        if (body.p_success) completed++;
        return json(!scenario.lostFinish && !scenario.lostPersist);
      }
      if (table === "momo_parse_attempts") {
        return method === "GET" ? json([]) : json({ id: "attempt-1" });
      }
      if (
        ["momo_reconciliations", "operational_health_events"].includes(table)
      ) return json(null, 201);
      throw new Error(`Unexpected request ${method} ${table}`);
    };
    try {
      const result = await handleRequest(
        new Request("https://qa.invalid/functions/v1/parse-momo-sms", {
          method: "POST",
          headers: {
            Authorization: "Bearer qa-token",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ rawSmsId: "raw-1", provider: "openai" }),
        }),
      );
      assertEquals(
        result.status,
        scenario.expected,
        "busy/stale work cannot report success",
      );
      assertEquals(
        aiCalls,
        scenario.claim === "claimed" ? 1 : 0,
        "AI is reached only by the claim owner",
      );
      assertEquals(
        persisted,
        aiCalls,
        "parsed evidence is saved only through the lease RPC",
      );
      assertEquals(
        completed,
        aiCalls && !scenario.lostPersist ? 1 : 0,
        "no completion after a rejected interpretation",
      );
      assertEquals(
        requests.includes("PATCH momo_sms_raw"),
        false,
        "late worker cannot overwrite another attempt's state",
      );
      assertEquals(
        requests.includes("POST momo_sms_parsed"),
        false,
        "interpretation writes cannot bypass fencing",
      );
    } finally {
      globalThis.fetch = savedFetch;
      for (const [k, v] of Object.entries(saved)) {
        if (v === undefined) Deno.env.delete(k);
        else Deno.env.set(k, v);
      }
    }
  });
}
