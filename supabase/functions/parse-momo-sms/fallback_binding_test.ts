import { reconcileParsedSms } from "./reconciliation.ts";
import { normalizeParsedSms, type RawSmsRecord } from "./ai_parser.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { confirmRayonReferenceMatch } from "../_shared/payments.ts";
import {
  assertDeepEquals,
  assertEquals,
  FakeAdminClient,
  type TableStore,
} from "./reconciliation_test_support.ts";

const raw: RawSmsRecord = {
  id: "synthetic-raw",
  user_id: "synthetic-payer",
  sender: "M-Money",
  sms_body: "Synthetic QA payment",
  provider: "mtn_rwanda",
  country_code: "RW",
  sms_received_at: "2026-09-19T20:00:00Z",
  detected_tx_type: "payment",
  detected_amount: 1000,
  detected_tx_id: "SYNTHETIC-TRANSACTION-1",
};
const parsed = normalizeParsedSms({
  parse_status: "parsed",
  confidence: .99,
  tx_direction: "debit",
  tx_type: "payment",
  amount: 1000,
  currency: "RWF",
  momo_tx_id: raw.detected_tx_id,
  payee_number_or_code: "250788111222",
  tx_datetime_iso: raw.sms_received_at,
});
const group = {
  id: "group-1",
  name: "Synthetic community",
  type: "community",
  receiving_momo_code: "250788111222",
  momo_number: null,
  currency: "RWF",
  country: "RW",
  is_active: true,
  is_closed: false,
};

for (const route of ["group", "partner"] as const) {
  for (
    const scenario of [
      "matching",
      "truncated payee",
      "unrelated payee",
      "missing payee",
      "wrong currency",
      "wrong country",
      "inactive",
      ...(route === "partner"
        ? ["wrong provider", "missing provider"]
        : ["closed"]),
    ]
  ) {
    Deno.test(`${route} route evidence: ${scenario}`, async () => {
      const evidence = { ...parsed };
      const rawEvidence = { ...raw };
      const tables: TableStore = {
        groups: route === "group" ? [{ ...group }] : [],
        group_contributions: [],
        group_members: [],
        countries: [{ id: "RW", currency: "RWF" }],
        partner_payment_routes: route === "partner"
          ? [{
            id: "route-1",
            partner_id: "partner-1",
            status: "active",
            country: "RW",
            provider: "mtn_rwanda",
            recipient_code: "250788111222",
          }]
          : [],
      };
      if (scenario === "truncated payee") evidence.payee_number_or_code = "222";
      if (scenario === "unrelated payee") {
        evidence.payee_number_or_code = "250700111222";
      }
      if (scenario === "missing payee") evidence.payee_number_or_code = null;
      if (scenario === "wrong currency") evidence.currency = "USD";
      if (scenario === "wrong country") rawEvidence.country_code = "CD";
      if (scenario === "wrong provider") rawEvidence.provider = "orange";
      if (scenario === "missing provider") rawEvidence.provider = null;
      if (scenario === "closed") tables.groups[0].is_closed = true;
      if (scenario === "inactive") {
        if (route === "group") tables.groups[0].is_active = false;
        else tables.partner_payment_routes[0].status = "inactive";
      }
      const result = await reconcileParsedSms(
        new FakeAdminClient(tables) as unknown as ReturnType<
          typeof createAdminClient
        >,
        rawEvidence,
        evidence,
        "parsed-1",
        "2026-09-19T20:00:00Z",
      );
      assertEquals(
        result.matchStatus,
        scenario === "matching" ? "matched" : "manual_review",
        "only complete matching evidence may allocate",
      );
      assertEquals(
        tables.group_contributions.length,
        scenario === "matching" && route === "group" ? 1 : 0,
        "unbound evidence cannot create contributions",
      );
    });
  }
}

for (
  const scenario of [
    "wrong payee",
    "missing group",
    "wrong currency",
    "inactive group",
  ] as const
) {
  Deno.test(`amount and recency cannot bypass ${scenario}`, async () => {
    const tables: TableStore = {
      groups: scenario === "missing group" ? [] : [{
        ...group,
        receiving_momo_code: scenario === "wrong payee"
          ? "250799555999"
          : group.receiving_momo_code,
        is_active: scenario !== "inactive group",
      }],
      group_contributions: [{
        id: "contribution-1",
        group_id: "group-1",
        user_id: raw.user_id,
        amount: 1000,
        status: "pending",
        created_at: raw.sms_received_at,
        momo_reference: "CHECKOUT-1",
      }],
    };
    const before = structuredClone(tables);
    const result = await reconcileParsedSms(
      new FakeAdminClient(tables) as unknown as ReturnType<
        typeof createAdminClient
      >,
      raw,
      { ...parsed, currency: scenario === "wrong currency" ? "USD" : "RWF" },
      "parsed-1",
      raw.sms_received_at!,
    );
    assertEquals(
      result.matchStatus,
      "manual_review",
      "scoring cannot override missing binding",
    );
    assertDeepEquals(tables, before, "the contribution must remain pending");
  });
}

for (const kind of ["ticket", "shop", "support"] as const) {
  for (
    const scenario of [
      "matching",
      "wrong payee",
      "truncated payee",
      "wrong currency",
      "wrong provider",
      "missing provider",
      "wrong country",
      "missing checkout",
      "failed checkout",
      "missing transaction",
      "missing club",
    ] as const
  ) {
    Deno.test(`${kind} checkout evidence: ${scenario}`, async () => {
      const table = {
        ticket: "rs_tickets",
        shop: "rs_shop_orders",
        support: "rs_initiative_contributions",
      }[kind];
      const reference = `RS-${kind.toUpperCase()}-SYNTHETIC`;
      const row = {
        id: "target-1",
        user_id: raw.user_id,
        club_id: 24,
        momo_reference: reference,
        amount: 1000,
        amount_paid: 1000,
        total: 1000,
        status: "pending",
      };
      const tables: TableStore = {
        [table]: [row],
        users: [],
        pending_transactions: scenario === "missing checkout" ? [] : [{
          id: "checkout-1",
          reference,
          user_id: raw.user_id,
          amount: 1000,
          provider: "mtn_rwanda",
          recipient_momo: "250788111222",
          status: scenario === "failed checkout" ? "failed" : "pending",
        }],
        african_football_clubs: scenario === "missing club"
          ? []
          : [{ id: 24, currency_code: "RWF", country_iso_code: "RW" }],
      };
      const client = new FakeAdminClient(tables);
      const before = structuredClone(tables);
      const result = await confirmRayonReferenceMatch(
        client as unknown as ReturnType<typeof createAdminClient>,
        { reference, user_id: raw.user_id },
        {
          source: "parse-momo-sms",
          timestamp: raw.sms_received_at!,
          parsedSmsId: "parsed-checkout-binding",
          amount: 1000,
          provider: scenario === "missing provider"
            ? null
            : scenario === "wrong provider"
            ? "orange"
            : "mtn_rwanda",
          country: scenario === "wrong country" ? "CD" : "RW",
          currency: scenario === "wrong currency" ? "USD" : "RWF",
          payeeNumberOrCode: scenario === "truncated payee"
            ? "222"
            : scenario === "wrong payee"
            ? "250700111222"
            : "250788111222",
          transactionId: scenario === "missing transaction"
            ? null
            : "SYNTHETIC-TRANSACTION-1",
        },
      );
      assertEquals(
        result.matchStatus,
        scenario === "matching" ? "matched" : "manual_review",
        "checkout binding precedes fulfillment",
      );
      if (scenario !== "matching") {
        assertDeepEquals(
          tables,
          before,
          "unbound evidence cannot change a business target",
        );
        assertEquals(
          client.rpcCalls.length,
          0,
          "unbound evidence cannot award loyalty or referral rewards",
        );
      }
    });
  }
}
