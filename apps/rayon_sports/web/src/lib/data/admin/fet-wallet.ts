import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminFetWalletAdjustmentResult,
  AdminAccess,
  AdminFetWalletLedgerRow,
  AdminFetWalletOverviewRow,
  AdminFetWalletSnapshot,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

const MAX_WALLET_ACCOUNTS = 60;
const MAX_WALLET_LEDGER_ROWS = 120;
const MAX_WALLET_ADJUSTMENT = 1_000_000;
const walletEntryTypes = new Set([
  "earn",
  "transfer_in",
  "transfer_out",
  "redeem",
  "admin_adjustment",
  "opening_balance",
]);

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function optionalText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength);
}

function boundedInteger(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    value >= minimum &&
    value <= maximum
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function mapOverviewRow(
  row: Record<string, unknown>,
): AdminFetWalletOverviewRow | null {
  const userId = boundedText(row.user_id ?? row.userId, 128);
  const publicUserIdValue = row.public_user_id ?? row.publicUserId;
  const publicUserId = optionalText(publicUserIdValue, 64);
  const displayName = boundedText(row.display_name ?? row.displayName, 160);
  const tier = boundedText(row.tier, 40);
  const balance = boundedInteger(row.balance, 0, 1_000_000_000);
  const transactionCount = boundedInteger(
    row.transaction_count ?? row.transactionCount,
    0,
    1_000_000_000,
  );
  const lastTransactionValue = row.last_transaction_at ?? row.lastTransactionAt;
  const lastTransactionAt =
    lastTransactionValue == null ? null : boundedDate(lastTransactionValue);
  const lifetimeEarned = boundedInteger(
    row.lifetime_earned ?? row.lifetimeEarned,
    0,
    1_000_000_000,
  );
  const lifetimeSpent = boundedInteger(
    row.lifetime_spent ?? row.lifetimeSpent,
    0,
    1_000_000_000,
  );

  if (
    userId == null ||
    (publicUserIdValue != null &&
      publicUserIdValue !== "" &&
      publicUserId == null) ||
    displayName == null ||
    tier == null ||
    balance == null ||
    transactionCount == null ||
    (lastTransactionValue != null && lastTransactionAt == null) ||
    lifetimeEarned == null ||
    lifetimeSpent == null
  ) {
    return null;
  }

  return {
    userId,
    publicUserId,
    displayName,
    tier,
    balance,
    transactionCount,
    lastTransactionAt,
    lifetimeEarned,
    lifetimeSpent,
  };
}

function mapLedgerRow(
  row: Record<string, unknown>,
): AdminFetWalletLedgerRow | null {
  const id = boundedText(row.id, 128);
  const userId = boundedText(row.user_id ?? row.userId, 128);
  const publicUserIdValue = row.public_user_id ?? row.publicUserId;
  const publicUserId = optionalText(publicUserIdValue, 64);
  const displayName = boundedText(row.display_name ?? row.displayName, 160);
  const entryType = boundedText(row.entry_type ?? row.entryType, 32);
  const direction = boundedText(row.direction, 16);
  const amount = boundedInteger(row.amount, 1, 1_000_000_000);
  const balanceAfter = boundedInteger(
    row.balance_after ?? row.balanceAfter,
    0,
    1_000_000_000,
  );
  const counterpartyUserIdValue =
    row.counterparty_user_id ?? row.counterpartyUserId;
  const counterpartyUserId = optionalText(counterpartyUserIdValue, 128);
  const counterpartyDisplayNameValue =
    row.counterparty_display_name ?? row.counterpartyDisplayName;
  const counterpartyDisplayName = optionalText(
    counterpartyDisplayNameValue,
    160,
  );
  const counterpartyPublicUserIdValue =
    row.counterparty_public_user_id ?? row.counterpartyPublicUserId;
  const counterpartyPublicUserId = optionalText(
    counterpartyPublicUserIdValue,
    64,
  );
  const noteValue = row.note;
  const note = optionalText(noteValue, 1_000);
  const referenceTypeValue = row.reference_type ?? row.referenceType;
  const referenceType = optionalText(referenceTypeValue, 80);
  const referenceIdValue = row.reference_id ?? row.referenceId;
  const referenceId = optionalText(referenceIdValue, 160);
  const createdAt = boundedDate(row.created_at ?? row.createdAt);

  if (
    id == null ||
    userId == null ||
    (publicUserIdValue != null &&
      publicUserIdValue !== "" &&
      publicUserId == null) ||
    displayName == null ||
    entryType == null ||
    !walletEntryTypes.has(entryType) ||
    (direction !== "credit" && direction !== "debit") ||
    amount == null ||
    balanceAfter == null ||
    (counterpartyUserIdValue != null &&
      counterpartyUserIdValue !== "" &&
      counterpartyUserId == null) ||
    (counterpartyDisplayNameValue != null &&
      counterpartyDisplayNameValue !== "" &&
      counterpartyDisplayName == null) ||
    (counterpartyPublicUserIdValue != null &&
      counterpartyPublicUserIdValue !== "" &&
      counterpartyPublicUserId == null) ||
    (noteValue != null && noteValue !== "" && note == null) ||
    (referenceTypeValue != null &&
      referenceTypeValue !== "" &&
      referenceType == null) ||
    (referenceIdValue != null &&
      referenceIdValue !== "" &&
      referenceId == null) ||
    createdAt == null
  ) {
    return null;
  }

  return {
    id,
    userId,
    publicUserId,
    displayName,
    entryType,
    direction,
    amount,
    balanceAfter,
    counterpartyUserId,
    counterpartyDisplayName,
    counterpartyPublicUserId,
    note,
    referenceType,
    referenceId,
    createdAt,
  };
}

export function normalizeAdminFetWalletSnapshot(
  value: unknown,
): AdminFetWalletSnapshot {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return { overview: [], ledger: [] };
  }
  const source = value as Record<string, unknown>;
  const overview: AdminFetWalletOverviewRow[] = [];
  const ledger: AdminFetWalletLedgerRow[] = [];
  const seenUsers = new Set<string>();
  const seenEntries = new Set<string>();

  if (Array.isArray(source.overview)) {
    for (const entry of source.overview.slice(0, MAX_WALLET_ACCOUNTS)) {
      if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
        continue;
      }
      const row = mapOverviewRow(entry as Record<string, unknown>);
      if (row != null && !seenUsers.has(row.userId)) {
        overview.push(row);
        seenUsers.add(row.userId);
      }
    }
  }

  if (Array.isArray(source.ledger)) {
    for (const entry of source.ledger.slice(0, MAX_WALLET_LEDGER_ROWS)) {
      if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
        continue;
      }
      const row = mapLedgerRow(entry as Record<string, unknown>);
      if (row != null && !seenEntries.has(row.id)) {
        ledger.push(row);
        seenEntries.add(row.id);
      }
    }
  }

  return { overview, ledger };
}

export function normalizeAdminFetWalletAdjustmentResult(
  value: unknown,
): AdminFetWalletAdjustmentResult | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const source = value as Record<string, unknown>;
  const amount = boundedInteger(
    source.amount,
    -MAX_WALLET_ADJUSTMENT,
    MAX_WALLET_ADJUSTMENT,
  );
  const balance = boundedInteger(source.balance, 0, 1_000_000_000);
  const referenceId = boundedText(
    source.reference_id ?? source.referenceId,
    160,
  );
  const alreadyProcessedValue =
    source.already_processed ?? source.alreadyProcessed;
  if (
    source.status !== "success" ||
    amount == null ||
    amount === 0 ||
    balance == null ||
    referenceId == null ||
    (alreadyProcessedValue != null &&
      typeof alreadyProcessedValue !== "boolean")
  ) {
    return null;
  }
  return {
    status: "success",
    amount,
    balance,
    referenceId,
    alreadyProcessed:
      typeof alreadyProcessedValue === "boolean"
        ? alreadyProcessedValue
        : undefined,
  };
}

export async function getAdminFetWalletSnapshot(
  client: SupabaseClient,
  access: AdminAccess,
  options: {
    search?: string | null;
    userId?: string | null;
    signal?: AbortSignal;
  } = {},
): Promise<AdminFetWalletSnapshot> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("gamification-wallet", {
      query: {
        search: options.search ?? undefined,
        user_id: options.userId ?? undefined,
      },
      signal: options.signal,
    });
    return normalizeAdminFetWalletSnapshot(result);
  }

  const clubId = requireAdminClubId(access, "load points operations");
  const search = optionalText(options.search, 160);
  const userId = optionalText(options.userId, 128);
  if (
    (options.search != null && options.search !== "" && search == null) ||
    (options.userId != null && options.userId !== "" && userId == null)
  ) {
    throw new Error("Wallet search input is invalid.");
  }

  const [overviewResponse, ledgerResponse] = await Promise.all([
    client.rpc("fet_admin_get_wallet_overview", {
      p_club_id: clubId,
      p_search: search,
      p_limit: MAX_WALLET_ACCOUNTS,
      p_offset: 0,
    }),
    client.rpc("fet_admin_get_wallet_ledger", {
      p_club_id: clubId,
      p_search: search,
      p_user_id: userId,
      p_limit: MAX_WALLET_LEDGER_ROWS,
      p_offset: 0,
    }),
  ]);

  if (overviewResponse.error) {
    throw new Error(overviewResponse.error.message);
  }
  if (ledgerResponse.error) {
    throw new Error(ledgerResponse.error.message);
  }

  return normalizeAdminFetWalletSnapshot({
    overview: overviewResponse.data,
    ledger: ledgerResponse.data,
  });
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
    const result = await requestAdminApi<unknown>("gamification-wallet", {
      method: "POST",
      body: input,
    });
    const normalized = normalizeAdminFetWalletAdjustmentResult(result);
    if (normalized == null) {
      throw new Error("Wallet adjustment returned an invalid result.");
    }
    return normalized;
  }

  const clubId = requireAdminClubId(access, "adjust points balances");
  const userId = boundedText(input.userId, 128);
  const amount = boundedInteger(
    input.amount,
    -MAX_WALLET_ADJUSTMENT,
    MAX_WALLET_ADJUSTMENT,
  );
  const reason = boundedText(input.reason, 500);
  const idempotencyKey = optionalText(input.idempotencyKey, 200);
  if (
    userId == null ||
    amount == null ||
    amount === 0 ||
    reason == null ||
    (input.idempotencyKey != null &&
      input.idempotencyKey !== "" &&
      idempotencyKey == null)
  ) {
    throw new Error("Wallet adjustment input is invalid.");
  }
  const { data, error } = await client.rpc("fet_admin_adjust_balance", {
    p_user_id: userId,
    p_amount: amount,
    p_reason: reason,
    p_idempotency_key: idempotencyKey,
    p_club_id: clubId,
  });

  if (error) {
    throw new Error(error.message);
  }

  const normalized = normalizeAdminFetWalletAdjustmentResult(data);
  if (normalized == null) {
    throw new Error("Wallet adjustment returned an invalid result.");
  }
  return normalized;
}
