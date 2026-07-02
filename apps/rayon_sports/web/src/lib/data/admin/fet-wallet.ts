import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminFetWalletAdjustmentResult,
  AdminAccess,
  AdminFetWalletLedgerRow,
  AdminFetWalletOverviewRow,
  AdminFetWalletSnapshot,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  requireAdminClubId,
  safeNumber,
  safeString,
  toIdString,
} from "./helpers";

function mapOverviewRow(
  row: Record<string, unknown>,
): AdminFetWalletOverviewRow {
  return {
    userId: safeString(row.user_id),
    publicUserId: safeString(row.public_user_id) || null,
    displayName: safeString(row.display_name, "Supporter"),
    tier: safeString(row.tier, "imena"),
    balance: safeNumber(row.balance, 0),
    transactionCount: safeNumber(row.transaction_count, 0),
    lastTransactionAt: safeString(row.last_transaction_at) || null,
    lifetimeEarned: safeNumber(row.lifetime_earned, 0),
    lifetimeSpent: safeNumber(row.lifetime_spent, 0),
  };
}

function mapLedgerRow(row: Record<string, unknown>): AdminFetWalletLedgerRow {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    userId: safeString(row.user_id),
    publicUserId: safeString(row.public_user_id) || null,
    displayName: safeString(row.display_name, "Supporter"),
    entryType: safeString(row.entry_type, "earn"),
    direction:
      safeString(row.direction, "credit") === "debit" ? "debit" : "credit",
    amount: safeNumber(row.amount, 0),
    balanceAfter: safeNumber(row.balance_after, 0),
    counterpartyUserId: safeString(row.counterparty_user_id) || null,
    counterpartyDisplayName: safeString(row.counterparty_display_name) || null,
    counterpartyPublicUserId:
      safeString(row.counterparty_public_user_id) || null,
    note: safeString(row.note) || null,
    referenceType: safeString(row.reference_type) || null,
    referenceId: safeString(row.reference_id) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminFetWalletSnapshot(
  client: SupabaseClient,
  access: AdminAccess,
  options: {
    search?: string | null;
    userId?: string | null;
  } = {},
): Promise<AdminFetWalletSnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFetWalletSnapshot>("gamification-wallet", {
      query: {
        search: options.search ?? undefined,
        user_id: options.userId ?? undefined,
      },
    });
  }

  const clubId = requireAdminClubId(access, "load points operations");
  const search = safeString(options.search) || null;
  const userId = safeString(options.userId) || null;

  const [overviewResponse, ledgerResponse] = await Promise.all([
    client.rpc("fet_admin_get_wallet_overview", {
      p_club_id: clubId,
      p_search: search,
      p_limit: 60,
      p_offset: 0,
    }),
    client.rpc("fet_admin_get_wallet_ledger", {
      p_club_id: clubId,
      p_search: search,
      p_user_id: userId,
      p_limit: 120,
      p_offset: 0,
    }),
  ]);

  if (overviewResponse.error) {
    throw new Error(overviewResponse.error.message);
  }
  if (ledgerResponse.error) {
    throw new Error(ledgerResponse.error.message);
  }

  return {
    overview: Array.isArray(overviewResponse.data)
      ? overviewResponse.data.map((row) =>
          mapOverviewRow(row as Record<string, unknown>),
        )
      : [],
    ledger: Array.isArray(ledgerResponse.data)
      ? ledgerResponse.data.map((row) =>
          mapLedgerRow(row as Record<string, unknown>),
        )
      : [],
  };
}

export async function adjustAdminFetWalletBalance(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    userId: string;
    amount: number;
    reason: string;
    idempotencyKey?: string | null;
  },
): Promise<AdminFetWalletAdjustmentResult> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFetWalletAdjustmentResult>(
      "gamification-wallet",
      {
        method: "POST",
        body: input,
      },
    );
  }

  const clubId = requireAdminClubId(access, "adjust points balances");
  const { error } = await client.rpc("fet_admin_adjust_balance", {
    p_user_id: input.userId,
    p_amount: Math.trunc(input.amount),
    p_reason: safeString(input.reason),
    p_idempotency_key: safeString(input.idempotencyKey) || null,
    p_club_id: clubId,
  });

  if (error) {
    throw new Error(error.message);
  }

  return {
    status: "success",
    amount: Math.trunc(input.amount),
    balance: 0,
    referenceId: null,
  };
}
