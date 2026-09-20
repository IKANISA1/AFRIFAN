import { createClient } from "npm:@supabase/supabase-js@2";
import {
  confirmGroupContribution,
  ensureGroupContributionByPayeeRoute,
  findGroupContributionCandidate,
} from "./group_reconciler.ts";
import { normalizeParsedSms, type RawSmsRecord } from "./ai_parser.ts";
import {
  assertEquals,
  FakeAdminClient,
  type TableStore,
} from "./reconciliation_test_support.ts";
import { createAdminClient } from "../_shared/supabase.ts";

const binding = { userId: "payer-1", groupId: "group-1", amount: 1000 };
for (
  const scenario of [
    "new confirmation",
    "same payment retry",
    "different payment",
    "cancelled",
    "deleted",
    "owner changed",
    "amount changed",
    "group changed",
    "write error",
    "read error",
  ]
) {
  Deno.test(`group confirmation transport: ${scenario}`, async () => {
    const original = globalThis.fetch;
    const current = {
      id: "contribution-1",
      user_id: binding.userId,
      group_id: binding.groupId,
      amount: binding.amount,
      status: "confirmed",
      momo_reference: "TX-ONE",
    };
    if (scenario === "different payment") current.momo_reference = "TX-OTHER";
    if (scenario === "cancelled") current.status = "cancelled";
    if (scenario === "owner changed") current.user_id = "payer-2";
    if (scenario === "amount changed") current.amount = 2000;
    if (scenario === "group changed") current.group_id = "group-2";
    let writes = 0;
    globalThis.fetch = (input, init) => {
      const url = new URL(String(input)), method = init?.method ?? "GET";
      assertEquals(url.origin, "https://qa.invalid", "isolated transport");
      const reply = (data: unknown, status = 200) =>
        Promise.resolve(
          new Response(JSON.stringify(data), {
            status,
            headers: { "Content-Type": "application/json" },
          }),
        );
      if (method === "PATCH") {
        writes++;
        assertEquals(
          url.searchParams.get("status"),
          "eq.pending",
          "claim cannot reopen terminal rows",
        );
        assertEquals(
          url.searchParams.get("user_id"),
          "eq.payer-1",
          "claim retains payer",
        );
        assertEquals(
          url.searchParams.get("group_id"),
          "eq.group-1",
          "claim retains group",
        );
        assertEquals(
          url.searchParams.get("amount"),
          "eq.1000",
          "claim retains amount",
        );
        if (scenario === "write error") {
          return reply({ message: "synthetic write failure" }, 500);
        }
        return reply(scenario === "new confirmation" ? current : null);
      }
      if (scenario === "read error") {
        return reply({ message: "synthetic read failure" }, 500);
      }
      return reply(scenario === "deleted" ? [] : [current]);
    };
    try {
      let rejected = false;
      try {
        await confirmGroupContribution(
          createClient("https://qa.invalid", "synthetic-test-key"),
          "contribution-1",
          "TX-ONE",
          binding,
        );
      } catch {
        rejected = true;
      }
      assertEquals(
        rejected,
        !["new confirmation", "same payment retry"].includes(scenario),
        "only the exact persisted payment may succeed",
      );
      assertEquals(writes, 1, "one conditional write");
    } finally {
      globalThis.fetch = original;
    }
  });
}

const raw: RawSmsRecord = {
  id: "raw-1",
  user_id: "payer-1",
  sender: "M-Money",
  sms_body: "Synthetic payment",
  provider: "mtn_rwanda",
  country_code: "RW",
  sms_received_at: "2026-09-19T23:00:00Z",
  detected_tx_type: "payment",
  detected_amount: 1000,
  detected_tx_id: "TX-NEW",
};
const parsed = normalizeParsedSms({
  parse_status: "parsed",
  confidence: .99,
  tx_direction: "debit",
  tx_type: "payment",
  amount: 1000,
  currency: "RWF",
  momo_tx_id: "TX-NEW",
  payee_number_or_code: "250788111222",
});
const group = {
  id: "group-1",
  name: "Synthetic group",
  type: "community",
  country: "RW",
  currency: "RWF",
  receiving_momo_code: "250788111222",
  momo_number: null,
  receiving_momo_route_type: "phone",
  is_active: true,
  is_closed: false,
};
for (const route of ["scored candidate", "direct payee"] as const) {
  Deno.test(`a new group payment cannot reuse a confirmed equal-amount row: ${route}`, async () => {
    const old = {
      id: "old-contribution",
      group_id: group.id,
      user_id: raw.user_id,
      amount: 1000,
      status: "confirmed",
      momo_reference: "TX-OLD",
      created_at: raw.sms_received_at,
    };
    const tables: TableStore = {
      groups: [{ ...group }],
      group_contributions: [old],
    };
    const client = new FakeAdminClient(tables) as unknown as ReturnType<
      typeof createAdminClient
    >;
    if (route === "scored candidate") {
      const result = await findGroupContributionCandidate(client, raw, parsed);
      assertEquals(
        result.candidate,
        null,
        "old confirmed payment is not a candidate",
      );
    } else {
      const result = await ensureGroupContributionByPayeeRoute(
        client,
        raw,
        parsed,
        group,
        raw.sms_received_at!,
      );
      assertEquals(
        result.id === old.id,
        false,
        "the distinct payment gets a separate contribution",
      );
      assertEquals(
        tables.group_contributions.length,
        2,
        "both distinct payments are represented",
      );
      assertEquals(
        old.momo_reference,
        "TX-OLD",
        "old payment reference stays intact",
      );
    }
  });
}
