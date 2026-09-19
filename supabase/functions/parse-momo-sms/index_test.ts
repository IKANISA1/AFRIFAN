import { handleRequest } from "./index.ts";
import { assertEquals } from "./reconciliation_test_support.ts";

const base = "https://qa.invalid";
const raw = {
  id: "raw-1",
  user_id: "user-1",
  sender: "M-Money",
  sms_body: "Synthetic SMS",
  sms_received_at: "2026-09-19T17:00:00Z",
  parse_status: "parsed",
  updated_at: "2026-09-19T17:00:00Z",
};

for (
  const scenario of [
    { name: "posted ledger", ledger: true, expected: 409 },
    {
      name: "matched reconciliation without ledger",
      matched: true,
      expected: 409,
    },
    { name: "failed ledger read", error: "momo_ledger_entries", expected: 500 },
    {
      name: "failed reconciliation read",
      error: "momo_reconciliations",
      expected: 500,
    },
    {
      name: "failed prior-parse read",
      error: "momo_sms_parsed",
      expected: 500,
    },
    { name: "overlapping parse claim", lostClaim: true, expected: 409 },
    { name: "failed parse claim", error: "momo_sms_raw", expected: 500 },
    { name: "ordinary completed retry", ordinaryRetry: true, expected: 200 },
  ]
) {
  Deno.test(`SMS handler preserves evidence on ${scenario.name}`, async () => {
    const originalFetch = globalThis.fetch;
    const values: Record<string, string> = {
      SUPABASE_URL: base,
      SUPABASE_ANON_KEY: "qa-public-key",
      SUPABASE_SERVICE_ROLE_KEY: "qa-service-key",
      SUPABASE_PUBLISHABLE_KEYS: "",
      SUPABASE_SECRET_KEYS: "",
    };
    const saved = Object.fromEntries(
      Object.keys(values).map((k) => [k, Deno.env.get(k)]),
    );
    for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
    const requests: { table: string; method: string }[] = [];
    let claims = 0, aiCalls = 0;
    globalThis.fetch = async (input, init) => {
      const url = new URL(String(input));
      const method = init?.method ?? "GET";
      if (url.origin !== base) {
        aiCalls++;
        throw new Error("Unexpected provider invocation");
      }
      const table = url.pathname.split("/").at(-1)!;
      requests.push({ table, method });
      const json = (data: unknown, status = 200) =>
        new Response(JSON.stringify(data), {
          status,
          headers: { "Content-Type": "application/json" },
        });
      if (url.pathname === "/auth/v1/user") {
        return json({ id: "user-1", app_metadata: { club_id: "24" } });
      }
      if (table === "edge_function_rate_events") {
        return method === "HEAD"
          ? new Response(null, { headers: { "content-range": "*/0" } })
          : json(null, 201);
      }
      if (table === "momo_sms_raw" && method === "GET") return json([raw]);
      if (scenario.error === table) {
        return json({ message: "Synthetic database failure" }, 503);
      }
      if (table === "momo_sms_parsed") return json([{ id: "parsed-1" }]);
      if (table === "momo_ledger_entries") {
        return json(scenario.ledger ? [{ id: "ledger-1" }] : []);
      }
      if (table === "momo_reconciliations") {
        return json(scenario.matched ? [{ id: "match-1" }] : []);
      }
      if (table === "momo_sms_raw" && method === "PATCH") {
        claims++;
        assertEquals(
          url.searchParams.get("user_id"),
          "eq.user-1",
          "claim retains authenticated ownership",
        );
        assertEquals(
          url.searchParams.get("updated_at"),
          "eq." + raw.updated_at,
          "claim retains the read version",
        );
        assertEquals(
          url.searchParams.getAll("parse_status").includes("neq.processing"),
          true,
          "force cannot take over a running parse",
        );
        return json([]);
      }
      throw new Error(`Unexpected request ${method} ${table}`);
    };
    try {
      const response = await handleRequest(
        new Request(base + "/functions/v1/parse-momo-sms", {
          method: "POST",
          headers: {
            Authorization: "Bearer qa-token",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            rawSmsId: raw.id,
            forceReparse: !scenario.ordinaryRetry,
          }),
        }),
      );
      assertEquals(
        response.status,
        scenario.expected,
        "truthful failure/conflict or ordinary idempotent response",
      );
      assertEquals(aiCalls, 0, "no AI reinterpretation before a valid claim");
      assertEquals(
        claims,
        scenario.lostClaim ? 1 : 0,
        "protected evidence never enters processing",
      );
      assertEquals(
        requests.some((r) =>
          ["momo_sms_parsed", "momo_ledger_entries", "momo_reconciliations"]
            .includes(r.table) && r.method !== "GET"
        ),
        false,
        "financial evidence is unchanged",
      );
    } finally {
      globalThis.fetch = originalFetch;
      for (const [key, value] of Object.entries(saved)) {
        if (value === undefined) Deno.env.delete(key);
        else Deno.env.set(key, value);
      }
    }
  });
}
