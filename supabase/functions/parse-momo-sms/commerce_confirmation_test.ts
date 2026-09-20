import { confirmRayonReferenceMatch } from "../_shared/payments.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import {
  assertDeepEquals,
  assertEquals,
  FakeAdminClient,
  type TableStore,
} from "./reconciliation_test_support.ts";

for (const kind of ["ticket", "shop"] as const) {
  for (
    const failure of [
      "late_reward",
      "cancelled",
      "missing_result",
      "foreign_result",
    ] as const
  ) {
    Deno.test(`${kind} atomic confirmation preserves outcomes on ${failure}`, async () => {
      const table = kind === "ticket" ? "rs_tickets" : "rs_shop_orders";
      const reference = `RS-${kind.toUpperCase()}-ATOMIC`;
      const row = {
        id: "record-1",
        user_id: "payer-1",
        club_id: 24,
        momo_reference: reference,
        status: "pending",
        amount_paid: 1000,
        total: 1000,
        partner_id: "partner-1",
        rs_matches: { partner_id: "partner-1" },
      };
      const tables: TableStore = {
        [table]: [row],
        pending_transactions: [{
          id: "checkout-1",
          user_id: "payer-1",
          reference,
          recipient_momo: "250788111222",
          amount: 1000,
          provider: "mtn_rwanda",
          status: "pending",
        }],
        african_football_clubs: [{
          id: 24,
          currency_code: "RWF",
          country_iso_code: "RW",
        }],
        partners: [{ id: "partner-1", name: "QA club" }],
      };
      const client = new FakeAdminClient(tables);
      const originalFrom = client.from.bind(client);
      client.from = (name) => {
        const query = originalFrom(name);
        if (name === table && failure === "cancelled") {
          const originalUpdate = query.update.bind(query);
          query.update = (values) => {
            row.status = "cancelled";
            return originalUpdate(values);
          };
        }
        return query;
      };
      let calls = 0;
      client.rpc = async (name, args) => {
        if (name === "rs_apply_membership_points") {
          return {
            data: null,
            error: new Error("Synthetic late reward failure"),
          };
        }
        assertEquals(
          name,
          "confirm_club_commerce_payment",
          "state and rewards use one transaction",
        );
        calls++;
        assertDeepEquals(
          args?.p_record_ids,
          ["record-1"],
          "exact selected records are bound",
        );
        assertEquals(
          args?.p_payee,
          "250788111222",
          "RPC revalidates the receiver",
        );
        if (failure === "late_reward") {
          return {
            data: null,
            error: new Error("Synthetic late reward failure"),
          };
        }
        if (failure === "cancelled") {
          row.status = "cancelled";
          return {
            data: { status: "manual_review", reason: "changed" },
            error: null,
          };
        }
        if (failure === "missing_result") return { data: null, error: null };
        return {
          data: {
            status: "confirmed",
            record_ids: ["foreign"],
            newly_confirmed: true,
            points_awarded: 10,
            referral_activated: false,
            applied_status: "paid",
          },
          error: null,
        };
      };
      let thrown = false;
      let result;
      try {
        result = await confirmRayonReferenceMatch(
          client as unknown as ReturnType<typeof createAdminClient>,
          { reference, user_id: "payer-1" },
          {
            source: "parse-momo-sms",
            timestamp: "2026-09-20T00:00:00Z",
            provider: "mtn_rwanda",
            amount: 1000,
            currency: "RWF",
            country: "RW",
            payeeNumberOrCode: "250788111222",
            transactionId: "SYNTHETIC-COMMERCE",
            parsedSmsId: "parsed-1",
          },
        );
      } catch {
        thrown = true;
      }
      if (failure === "cancelled") {
        assertEquals(
          result?.matchStatus,
          "manual_review",
          "concurrent cancellation requires review",
        );
        assertEquals(row.status, "cancelled", "cancelled target cannot reopen");
      } else {
        assertEquals(
          thrown,
          true,
          "missing or failed atomic outcome must propagate",
        );
        assertEquals(
          row.status,
          "pending",
          "failed transaction cannot leave a confirmed target",
        );
      }
      assertEquals(calls, 1, "one atomic confirmation was attempted");
    });
  }
}
