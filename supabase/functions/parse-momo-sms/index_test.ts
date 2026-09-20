import { handleRequest } from "./index.ts";
import { assertEquals } from "./reconciliation_test_support.ts";

for (const failedTable of ["momo_parse_attempts", "momo_sms_raw"]) {
  Deno.test(`SMS completion does not report success when ${failedTable} persistence fails`, async () => {
    const originalFetch = globalThis.fetch;
    const values: Record<string, string> = {
      SUPABASE_URL: "https://qa.invalid",
      SUPABASE_ANON_KEY: "qa-public-key",
      SUPABASE_SERVICE_ROLE_KEY: "qa-service-key",
      SUPABASE_PUBLISHABLE_KEYS: "",
      SUPABASE_SECRET_KEYS: "",
      OPENAI_API_KEY: "qa-provider-substitute",
    };
    const saved = Object.fromEntries(
      Object.keys(values).map((key) => [key, Deno.env.get(key)]),
    );
    for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
    let failures = 0;
    const rawStates: string[] = [];
    const json = (data: unknown, status = 200) =>
      new Response(JSON.stringify(data), {
        status,
        headers: { "Content-Type": "application/json" },
      });
    globalThis.fetch = async (input, init) => {
      const url = new URL(String(input));
      const method = init?.method ?? "GET";
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      if (url.origin === "https://api.openai.com") {
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
        throw new Error("Unexpected external request");
      }
      const table = url.pathname.split("/").at(-1)!;
      if (url.pathname === "/auth/v1/user") return json({ id: "user-1" });
      if (table === "edge_function_rate_events") {
        return method === "HEAD"
          ? new Response(null, { headers: { "content-range": "*/0" } })
          : json(null, 201);
      }
      if (table === "momo_sms_raw") {
        if (method === "GET") return json([{ ...raw, parse_status: "failed" }]);
        rawStates.push(body.parse_status);
        if (failedTable === table && body.parse_status === "parsed") {
          failures++;
          return json({ message: "Completion unavailable" }, 503);
        }
        return json({ id: raw.id });
      }
      if (table === "momo_sms_parsed") {
        return method === "GET" ? json([]) : json({ id: "parsed-1" });
      }
      if (table === "momo_parse_attempts") {
        if (method === "GET") return json([]);
        if (failedTable === table && body.status === "success") {
          failures++;
          return json({ message: "Completion unavailable" }, 503);
        }
        return json({ id: "attempt-1" });
      }
      if (
        ["momo_reconciliations", "operational_health_events"].includes(table)
      ) return json(null, 201);
      throw new Error(`Unexpected request ${method} ${table}`);
    };
    try {
      const response = await handleRequest(
        new Request("https://qa.invalid/functions/v1/parse-momo-sms", {
          method: "POST",
          headers: {
            Authorization: "Bearer qa-token",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ rawSmsId: "raw-1", provider: "openai" }),
        }),
      );
      assertEquals(failures, 1, "the final persistence failure was reached");
      assertEquals(
        response.status,
        500,
        "an uncommitted completion is not a successful parse",
      );
      assertEquals(
        rawStates.at(-1),
        "failed",
        "ordinary retry remains available",
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
    {
      name: "committed allocation recovery",
      ordinaryRetry: true,
      recovery: true,
      ledger: true,
      matched: true,
      expected: 200,
    },
    {
      name: "committed commerce recovery",
      ordinaryRetry: true,
      recovery: true,
      commerce: true,
      ledger: true,
      matched: true,
      expected: 200,
    },
    {
      name: "unverifiable commerce recovery",
      ordinaryRetry: true,
      recovery: true,
      commerce: true,
      ledger: true,
      matched: true,
      recoveryError: true,
      expected: 500,
    },
    {
      name: "foreign commerce recovery receipt",
      ordinaryRetry: true,
      recovery: true,
      commerce: true,
      foreignReceipt: true,
      ledger: true,
      matched: true,
      expected: 409,
    },
    {
      name: "unverifiable allocation recovery",
      ordinaryRetry: true,
      recovery: true,
      ledger: true,
      matched: true,
      recoveryError: true,
      expected: 500,
    },
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
    let claims = 0, aiCalls = 0, recoveries = 0;
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
      if (table === "momo_sms_raw" && method === "GET") {
        return json([{
          ...raw,
          parse_status: scenario.recovery ? "failed" : raw.parse_status,
        }]);
      }
      if (table === "confirm_club_commerce_payment") {
        recoveries++;
        const args = JSON.parse(String(init?.body));
        assertEquals(
          args.p_parsed_sms_id,
          "parsed-1",
          "commerce recovery binds original evidence",
        );
        assertEquals(
          args.p_user_id,
          "user-1",
          "commerce recovery binds authenticated owner",
        );
        return scenario.recoveryError
          ? json({ message: "commerce receipt unavailable" }, 503)
          : json({
            status: "confirmed",
            parsed_sms_id: "parsed-1",
            record_ids: ["record-1"],
            newly_confirmed: false,
          });
      }
      if (table === "allocate_momo_payment_intent") {
        recoveries++;
        const args = JSON.parse(String(init?.body));
        assertEquals(
          args.p_parsed_sms_id,
          "parsed-1",
          "recovery reuses the committed parse",
        );
        assertEquals(
          args.p_intent_id,
          "intent-1",
          "recovery reuses the committed intent",
        );
        return scenario.recoveryError
          ? json({ message: "committed allocation unavailable" }, 503)
          : json({
            status: "allocated",
            intent_id: "intent-1",
            parsed_sms_id: "parsed-1",
            newly_allocated: false,
          });
      }
      if (scenario.error === table) {
        return json({ message: "Synthetic database failure" }, 503);
      }
      if (table === "momo_sms_parsed") return json([{ id: "parsed-1" }]);
      if (table === "momo_ledger_entries") {
        return json(scenario.ledger ? [{ id: "ledger-1" }] : []);
      }
      if (table === "momo_reconciliations") {
        return json(
          scenario.matched
            ? [{
              id: "match-1",
              metadata: scenario.recovery
                ? scenario.commerce
                  ? {
                    commerce_persisted: true,
                    commerce_request: {
                      p_parsed_sms_id: "parsed-1",
                      p_user_id: scenario.foreignReceipt
                        ? "foreign-user"
                        : "user-1",
                      p_record_ids: ["record-1"],
                    },
                  }
                  : { allocation_persisted: true, intent_id: "intent-1" }
                : {},
            }]
            : [],
        );
      }
      if (table === "momo_sms_raw" && method === "PATCH") {
        if (scenario.recovery) {
          assertEquals(
            JSON.parse(String(init?.body)).parse_status,
            "parsed",
            "recovery restores parser completion",
          );
          assertEquals(
            url.searchParams.get("updated_at"),
            "eq." + raw.updated_at,
            "recovery retains source version",
          );
          return json({ id: raw.id });
        }
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
        recoveries,
        scenario.recovery && !scenario.foreignReceipt ? 1 : 0,
        "only committed allocation recovery reaches the idempotent RPC",
      );
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
