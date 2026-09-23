import { describe, expect, it } from "vitest";
import {
  normalizeAdminFetWalletAdjustmentResult,
  normalizeAdminFetWalletSnapshot,
} from "./fet-wallet";

const overviewRow = {
  user_id: "supporter-1",
  public_user_id: "483912",
  display_name: "Mukamana Aline",
  tier: "imena",
  balance: 450,
  transaction_count: 3,
  last_transaction_at: "2026-07-29T18:00:00.000Z",
  lifetime_earned: 600,
  lifetime_spent: 150,
};

const ledgerRow = {
  id: "ledger-1",
  user_id: "supporter-1",
  public_user_id: "483912",
  display_name: "Mukamana Aline",
  entry_type: "admin_adjustment",
  direction: "credit",
  amount: 250,
  balance_after: 450,
  counterparty_user_id: null,
  counterparty_display_name: null,
  counterparty_public_user_id: null,
  note: "Approved supporter correction.",
  reference_type: "admin_adjustment",
  reference_id: "reference-1",
  created_at: "2026-07-29T18:00:00.000Z",
};

describe("normalizeAdminFetWalletSnapshot", () => {
  it("projects only bounded wallet fields and drops private extras", () => {
    const result = normalizeAdminFetWalletSnapshot({
      overview: [{ ...overviewRow, private_email: "private@example.com" }],
      ledger: [{ ...ledgerRow, metadata: { secret: true } }],
      internal_trace: "private",
    });

    expect(result).toEqual({
      overview: [
        {
          userId: "supporter-1",
          publicUserId: "483912",
          displayName: "Mukamana Aline",
          tier: "imena",
          balance: 450,
          transactionCount: 3,
          lastTransactionAt: "2026-07-29T18:00:00.000Z",
          lifetimeEarned: 600,
          lifetimeSpent: 150,
        },
      ],
      ledger: [
        {
          id: "ledger-1",
          userId: "supporter-1",
          publicUserId: "483912",
          displayName: "Mukamana Aline",
          entryType: "admin_adjustment",
          direction: "credit",
          amount: 250,
          balanceAfter: 450,
          counterpartyUserId: null,
          counterpartyDisplayName: null,
          counterpartyPublicUserId: null,
          note: "Approved supporter correction.",
          referenceType: "admin_adjustment",
          referenceId: "reference-1",
          createdAt: "2026-07-29T18:00:00.000Z",
        },
      ],
    });
    expect(JSON.stringify(result)).not.toContain("private");
    expect(JSON.stringify(result)).not.toContain("metadata");
  });

  it("drops malformed and duplicate records without fabricating identifiers", () => {
    const result = normalizeAdminFetWalletSnapshot({
      overview: [
        overviewRow,
        { ...overviewRow, display_name: "Duplicate" },
        { ...overviewRow, user_id: "", display_name: "Missing id" },
        { ...overviewRow, user_id: "supporter-2", balance: -1 },
      ],
      ledger: [
        ledgerRow,
        { ...ledgerRow, note: "Duplicate" },
        { ...ledgerRow, id: "", created_at: "not-a-date" },
        { ...ledgerRow, id: "ledger-2", entry_type: "private_credit" },
      ],
    });

    expect(result.overview).toHaveLength(1);
    expect(result.ledger).toHaveLength(1);
    expect(result.overview[0]?.userId).toBe("supporter-1");
    expect(result.ledger[0]?.id).toBe("ledger-1");
  });

  it("caps account and ledger windows at their server limits", () => {
    const result = normalizeAdminFetWalletSnapshot({
      overview: Array.from({ length: 80 }, (_, index) => ({
        ...overviewRow,
        user_id: `supporter-${index}`,
      })),
      ledger: Array.from({ length: 140 }, (_, index) => ({
        ...ledgerRow,
        id: `ledger-${index}`,
      })),
    });

    expect(result.overview).toHaveLength(60);
    expect(result.ledger).toHaveLength(120);
  });
});

describe("normalizeAdminFetWalletAdjustmentResult", () => {
  it("normalizes the authoritative RPC result", () => {
    expect(
      normalizeAdminFetWalletAdjustmentResult({
        status: "success",
        amount: -120,
        balance: 330,
        reference_id: "reference-2",
        already_processed: true,
        private_trace: "discarded",
      }),
    ).toEqual({
      status: "success",
      amount: -120,
      balance: 330,
      referenceId: "reference-2",
      alreadyProcessed: true,
    });
  });

  it("rejects zero, missing-reference, and fabricated balance results", () => {
    expect(
      normalizeAdminFetWalletAdjustmentResult({
        status: "success",
        amount: 0,
        balance: 0,
        reference_id: "reference-3",
      }),
    ).toBeNull();
    expect(
      normalizeAdminFetWalletAdjustmentResult({
        status: "success",
        amount: 250,
        balance: 0,
        reference_id: null,
      }),
    ).toBeNull();
  });
});
