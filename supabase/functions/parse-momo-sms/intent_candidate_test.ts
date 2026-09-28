import { createClient } from "npm:@supabase/supabase-js@2";
import { assertEquals } from "https://deno.land/std@0.220.1/assert/mod.ts";
import { normalizeParsedSms } from "./ai_parser.ts";
import { reconcileParsedSms } from "./reconciliation.ts";

const raw = {
  id: "raw-candidate",
  user_id: "payer",
  sender: "M-Money",
  sms_body: "Synthetic receipt",
  provider: "mtn_rwanda",
  country_code: "RW",
  sms_received_at: "2026-09-23T00:00:00Z",
  detected_tx_type: "payment",
  detected_amount: 1000,
  detected_tx_id: "candidate-tx",
};
const parsed = normalizeParsedSms({
  parse_status: "parsed",
  tx_direction: "debit",
  tx_type: "payment",
  amount: 1000,
  currency: "RWF",
  payee_number_or_code: "967004",
  momo_tx_id: "candidate-tx",
  confidence: 1,
});
const candidate = {
  id: "eligible",
  user_id: "payer",
  receiving_account_id: "receiver",
  expected_amount: 1000,
  currency: "RWF",
  status: "pending",
  target_table: "membership_payment_orders",
  target_record_id: "paid-order",
  expires_at: "2099-01-01T00:00:00Z",
};

for (
  const scenario of [
    "eligible behind unrelated rows",
    "only unrelated rows",
    "two eligible",
    "no expiry",
  ]
) {
  Deno.test(`intent candidates: ${scenario}`, async () => {
    const unrelated = [
      { ...candidate, id: "expired", expires_at: "2000-01-01T00:00:00Z" },
      { ...candidate, id: "other-merchant", receiving_account_id: "another" },
      { ...candidate, id: "other-currency", currency: "USD" },
    ];
    const rows = scenario === "two eligible"
      ? [candidate, { ...candidate, id: "eligible-2" }]
      : scenario === "no expiry"
      ? [{ ...candidate, expires_at: null }]
      : [
        ...unrelated,
        ...(scenario === "only unrelated rows" ? [] : [candidate]),
      ];
    const previous = globalThis.fetch;
    let allocations = 0, fallbackReads = 0;
    globalThis.fetch = (input, init) => {
      const url = new URL(String(input));
      assertEquals(url.origin, "https://qa.invalid");
      const table = url.pathname.split("/").at(-1);
      const reply = (data: unknown) =>
        Promise.resolve(
          new Response(JSON.stringify(data), {
            headers: { "Content-Type": "application/json" },
          }),
        );
      if (table === "payment_receiver_accounts") {
        return reply([{
          id: "receiver",
          purpose: "subscription",
          is_active: true,
        }]);
      }
      if (table === "payment_intents") {
        // Emulate filtering before the server limit, including ineligible rows
        // that previously hid a valid payment. Real SQL rechecks locked data.
        const filtered = rows.filter((row) => {
          for (
            const field of [
              "user_id",
              "status",
              "expected_amount",
              "currency",
              "receiving_account_id",
            ] as const
          ) {
            const filter = url.searchParams.get(field);
            if (filter && filter !== `eq.${row[field]}`) return false;
          }
          const expiry = url.searchParams.get("or");
          if (
            expiry && row.expires_at !== null &&
            Date.parse(row.expires_at) <= Date.now()
          ) return false;
          return true;
        });
        return reply(
          filtered.slice(
            0,
            Number(url.searchParams.get("limit") ?? rows.length),
          ),
        );
      }
      if (table === "allocate_momo_payment_intent") {
        allocations++;
        assertEquals(JSON.parse(String(init?.body)).p_intent_id, "eligible");
        return reply({
          status: "allocated",
          intent_id: "eligible",
          parsed_sms_id: "parsed-candidate",
          newly_allocated: true,
        });
      }
      if (table === "pending_transactions") fallbackReads++;
      return reply([]);
    };
    try {
      const result = await reconcileParsedSms(
        createClient("https://qa.invalid", "qa", {
          auth: { persistSession: false },
        }),
        raw,
        parsed,
        "parsed-candidate",
        new Date().toISOString(),
      );
      const matched = ["eligible behind unrelated rows", "no expiry"].includes(
        scenario,
      );
      assertEquals(result.matchStatus, matched ? "matched" : "manual_review");
      assertEquals(allocations, matched ? 1 : 0);
      assertEquals(fallbackReads, scenario === "only unrelated rows" ? 1 : 0);
      if (scenario === "two eligible") {
        assertEquals(result.metadata.reason, "ambiguous_intents");
      }
    } finally {
      globalThis.fetch = previous;
    }
  });
}
