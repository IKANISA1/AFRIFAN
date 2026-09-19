import { createClient } from "npm:@supabase/supabase-js@2";
import { normalizeParsedSms } from "./ai_parser.ts";
import { reconcileParsedSms } from "./reconciliation.ts";
import { assertEquals } from "./reconciliation_test_support.ts";

const raw = {
  id: "raw-1",
  user_id: "user-1",
  sender: "M-Money",
  sms_body: "Synthetic payment",
  provider: "mtn_rwanda",
  country_code: "RW",
  sms_received_at: "2026-09-19T17:00:00Z",
  detected_tx_type: "payment",
  detected_amount: 1000,
  detected_tx_id: "transaction-1",
};
const parsed = normalizeParsedSms({
  parse_status: "parsed",
  confidence: 0.99,
  tx_direction: "debit",
  tx_type: "payment",
  amount: 1000,
  currency: "RWF",
  payee_number_or_code: "250788111222",
  momo_tx_id: "transaction-1",
});

for (
  const scenario of [
    "matching",
    "wrong currency",
    "wrong receiver",
    "foreign owner",
    "wrong amount",
    "credit",
    "unknown direction",
    "inactive receiver",
    "missing receiver",
    "expired",
    "invalid expiry",
    "ambiguous",
    "receiver read error",
    "intent read error",
    "write error",
    "lost claim",
    "legacy read error",
    "fractional amount",
    "unsafe amount",
  ]
) {
  Deno.test(`generic payment intent: ${scenario}`, async () => {
    const intent = {
      id: "intent-1",
      user_id: "user-1",
      receiving_account_id: "receiver-1",
      target_table: "initiative_contributions",
      target_record_id: "contribution-1",
      expected_amount: 1000,
      currency: "RWF",
      status: "pending",
      expires_at: new Date(Date.now() + 60000).toISOString(),
      updated_at: "2026-09-19T17:00:00Z",
    };
    const receiver = {
      id: "receiver-1",
      purpose: "club_shop",
      is_active: true,
    };
    const evidence = { ...parsed };
    if (scenario === "wrong currency") evidence.currency = "USD";
    if (scenario === "wrong receiver") {
      intent.receiving_account_id = "receiver-2";
    }
    if (scenario === "foreign owner") intent.user_id = "user-2";
    if (scenario === "wrong amount") intent.expected_amount = 500;
    if (scenario === "credit") evidence.tx_direction = "credit";
    if (scenario === "unknown direction") evidence.tx_direction = "unknown";
    if (scenario === "inactive receiver") receiver.is_active = false;
    if (scenario === "expired") intent.expires_at = "2000-01-01T00:00:00Z";
    if (scenario === "invalid expiry") intent.expires_at = "invalid";
    if (scenario === "fractional amount") evidence.amount = 1.5;
    if (scenario === "unsafe amount") {
      evidence.amount = Number.MAX_SAFE_INTEGER + 1;
    }
    const original = globalThis.fetch;
    let writes = 0, unexpected = 0;
    globalThis.fetch = (input, init) => {
      const url = new URL(String(input)), method = init?.method ?? "GET";
      const table = url.pathname.split("/").at(-1);
      const reply = (data: unknown, status = 200) =>
        Promise.resolve(
          new Response(JSON.stringify(data), {
            status,
            headers: { "Content-Type": "application/json" },
          }),
        );
      assertEquals(url.origin, "https://qa.invalid", "isolated client");
      if (table === "payment_receiver_accounts") {
        assertEquals(
          url.searchParams.get("payee_number_or_code"),
          "eq.250788111222",
          "exact receiver lookup",
        );
        if (scenario === "receiver read error") {
          return reply({ message: "receiver read failed" }, 400);
        }
        return reply(scenario === "missing receiver" ? [] : [receiver]);
      }
      if (table === "payment_intents" && method === "GET") {
        assertEquals(
          url.searchParams.get("user_id"),
          "eq.user-1",
          "schema owner field",
        );
        assertEquals(
          url.searchParams.get("status"),
          "eq.pending",
          "pending only",
        );
        assertEquals(
          url.searchParams.get("expected_amount"),
          "eq.1000",
          "exact amount",
        );
        assertEquals(
          url.searchParams.get("select")!.includes("intent_type"),
          false,
          "no nonexistent column",
        );
        if (scenario === "intent read error") {
          return reply({ message: "intent read failed" }, 400);
        }
        if (scenario === "legacy read error") return reply([]);
        return reply(
          scenario === "ambiguous"
            ? [intent, { ...intent, id: "intent-2" }]
            : [intent],
        );
      }
      if (table === "payment_intents" && method === "PATCH") {
        writes++;
        assertEquals(
          JSON.parse(String(init?.body)).status,
          "fulfilled",
          "declared database status",
        );
        assertEquals(
          url.searchParams.get("status"),
          "eq.pending",
          "cannot reopen terminal intent",
        );
        assertEquals(
          url.searchParams.get("user_id"),
          "eq.user-1",
          "claim retains owner",
        );
        assertEquals(
          url.searchParams.get("updated_at"),
          "eq." + intent.updated_at,
          "claim retains version",
        );
        if (scenario === "write error") {
          return reply({ message: "write failed" }, 400);
        }
        return reply(scenario === "lost claim" ? [] : [{ id: intent.id }]);
      }
      if (
        table === "pending_transactions" && scenario === "legacy read error"
      ) return reply({ message: "legacy read failed" }, 400);
      unexpected++;
      return reply({ message: "Unexpected fallback request" }, 400);
    };
    try {
      const client = createClient("https://qa.invalid", "qa-key", {
        auth: { persistSession: false },
      });
      let result, error;
      try {
        result = await reconcileParsedSms(
          client,
          raw,
          evidence,
          "parsed-1",
          new Date().toISOString(),
        );
      } catch (caught) {
        error = caught;
      }
      assertEquals(
        !!error,
        scenario.endsWith("error"),
        "database failure is propagated",
      );
      if (!error) {
        assertEquals(
          result?.matchStatus,
          scenario === "matching" ? "matched" : "manual_review",
          "truthful match outcome",
        );
        if (scenario === "matching") {
          assertEquals(
            result?.matchType,
            "intent_initiative_contributions",
            "schema target kind",
          );
        }
      }
      assertEquals(
        writes,
        ["matching", "write error", "lost claim"].includes(scenario) ? 1 : 0,
        "mismatched evidence cannot mutate intent",
      );
      assertEquals(
        unexpected,
        0,
        "no unsafe fallback after read or intent failure",
      );
    } finally {
      globalThis.fetch = original;
    }
  });
}
