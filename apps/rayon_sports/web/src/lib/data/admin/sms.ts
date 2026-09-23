/**
 * Admin SMS monitor — bounded, privacy-safe pipeline and review snapshots.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminPendingPaymentIntent,
  AdminSmsManualReview,
  AdminSmsManualReviewWorkspace,
  AdminSmsSnapshot,
  AdminSmsSyncRun,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import { adminClubIdOrNull, hasColumn } from "./helpers";

export const MAX_ADMIN_SMS_SYNC_RUNS = 50;
export const MAX_ADMIN_SMS_MANUAL_REVIEWS = 30;
export const MAX_ADMIN_SMS_PENDING_INTENTS = 150;
const idPattern = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/;
const syncRunProjection =
  "id,status,trigger,scanned_messages,uploaded_messages,scan_started_at";

export class AdminSmsValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminSmsValidationError";
  }
}

function record(value: unknown, label: string) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new AdminSmsValidationError(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function boundedString(
  value: unknown,
  label: string,
  maxLength: number,
  { allowEmpty = false, nullable = false } = {},
) {
  if (value == null && nullable) return null;
  if (typeof value !== "string") {
    throw new AdminSmsValidationError(`${label} must be text.`);
  }
  const normalized = value.trim();
  if (!normalized && !allowEmpty) {
    throw new AdminSmsValidationError(`${label} is required.`);
  }
  if (normalized.length > maxLength) {
    throw new AdminSmsValidationError(`${label} is too long.`);
  }
  return normalized;
}

function optionalString(value: unknown, label: string, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedString(value, label, maxLength, { nullable: true });
}

function identifier(value: unknown, label: string, nullable = false) {
  if (value == null && nullable) return null;
  const normalized = boundedString(value, label, 128);
  if (normalized == null || !idPattern.test(normalized)) {
    throw new AdminSmsValidationError(`${label} is invalid.`);
  }
  return normalized;
}

function nonNegativeNumber(
  value: unknown,
  label: string,
  { integer = false } = {},
) {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > 1_000_000_000 ||
    (integer && !Number.isInteger(value))
  ) {
    throw new AdminSmsValidationError(`${label} is invalid.`);
  }
  return value;
}

function optionalTimestamp(value: unknown, label: string) {
  if (value == null || value === "") return null;
  const normalized = boundedString(value, label, 64);
  if (normalized == null || Number.isNaN(Date.parse(normalized))) {
    throw new AdminSmsValidationError(`${label} is invalid.`);
  }
  return new Date(normalized).toISOString();
}

function requiredTimestamp(value: unknown, label: string) {
  const normalized = optionalTimestamp(value, label);
  if (normalized == null) {
    throw new AdminSmsValidationError(`${label} is required.`);
  }
  return normalized;
}

function currency(value: unknown) {
  const normalized = boundedString(value, "Currency", 3);
  if (normalized == null || !/^[A-Z]{3}$/.test(normalized.toUpperCase())) {
    throw new AdminSmsValidationError("Currency is invalid.");
  }
  return normalized.toUpperCase();
}

function normalizeSyncRun(value: unknown): AdminSmsSyncRun {
  const run = record(value, "SMS synchronization run");
  return {
    id: identifier(run.id, "Synchronization run id") as string,
    status: boundedString(run.status, "Synchronization status", 40) as string,
    trigger: boundedString(run.trigger, "Synchronization trigger", 80) as string,
    scannedMessages: nonNegativeNumber(
      run.scannedMessages,
      "Scanned message count",
      { integer: true },
    ),
    uploadedMessages: nonNegativeNumber(
      run.uploadedMessages,
      "Uploaded message count",
      { integer: true },
    ),
    startedAt: optionalTimestamp(run.startedAt, "Synchronization start time"),
  };
}

function mapSmsSyncRun(row: Record<string, unknown>) {
  return normalizeSyncRun({
    id: row.id == null ? null : String(row.id),
    status: row.status,
    trigger: row.trigger,
    scannedMessages: row.scanned_messages,
    uploadedMessages: row.uploaded_messages,
    startedAt: row.scan_started_at,
  });
}

function normalizeManualReview(value: unknown): AdminSmsManualReview {
  const review = record(value, "SMS manual review");
  return {
    reviewId: identifier(review.reviewId, "Review id") as string,
    rawSmsId: optionalString(review.rawSmsId, "Raw SMS id", 128),
    parsedSmsId: optionalString(review.parsedSmsId, "Parsed SMS id", 128),
    userId: optionalString(review.userId, "User id", 128),
    sender: boundedString(review.sender, "Sender", 120) as string,
    txType: boundedString(review.txType, "Transaction type", 80) as string,
    txCategory: boundedString(
      review.txCategory,
      "Transaction category",
      80,
    ) as string,
    cashflowBucket: boundedString(
      review.cashflowBucket,
      "Cashflow bucket",
      80,
    ) as string,
    amount: nonNegativeNumber(review.amount, "Review amount"),
    currency: currency(review.currency),
    momoTxId: optionalString(review.momoTxId, "MoMo transaction id", 128),
    payerName: optionalString(review.payerName, "Payer name", 160),
    payeeName: optionalString(review.payeeName, "Payee name", 160),
    payeeNumberOrCode: optionalString(
      review.payeeNumberOrCode,
      "Payee number or code",
      120,
    ),
    merchantCode: optionalString(review.merchantCode, "Merchant code", 120),
    smsReceivedAt: optionalTimestamp(review.smsReceivedAt, "SMS received time"),
    reviewCreatedAt: optionalTimestamp(
      review.reviewCreatedAt,
      "Review creation time",
    ),
    updatedAt: optionalTimestamp(review.updatedAt, "Review update time"),
    reviewKind: boundedString(review.reviewKind, "Review kind", 80) as string,
    reason: boundedString(review.reason, "Review reason", 240) as string,
    notes: optionalString(review.notes, "Review notes", 1_000),
    smsPreview: boundedString(review.smsPreview, "SMS preview", 1_000, {
      allowEmpty: true,
    }) as string,
  };
}

function mapManualReview(row: Record<string, unknown>) {
  return normalizeManualReview({
    reviewId: row.review_id == null ? null : String(row.review_id),
    rawSmsId: row.raw_sms_id == null ? null : String(row.raw_sms_id),
    parsedSmsId:
      row.parsed_sms_id == null ? null : String(row.parsed_sms_id),
    userId: row.user_id == null ? null : String(row.user_id),
    sender: row.sender,
    txType: row.tx_type,
    txCategory: row.tx_category,
    cashflowBucket: row.cashflow_bucket,
    amount: row.amount,
    currency: row.currency,
    momoTxId: row.momo_tx_id,
    payerName: row.payer_name,
    payeeName: row.payee_name,
    payeeNumberOrCode: row.payee_number_or_code,
    merchantCode: row.merchant_code,
    smsReceivedAt: row.sms_received_at,
    reviewCreatedAt: row.review_created_at,
    updatedAt: row.updated_at,
    reviewKind: row.review_kind,
    reason: row.reason,
    notes: row.notes,
    smsPreview: row.sms_preview,
  });
}

function normalizePendingIntent(
  value: unknown,
): AdminPendingPaymentIntent {
  const intent = record(value, "Pending payment intent");
  return {
    id: identifier(intent.id, "Payment intent id") as string,
    userId: identifier(intent.userId, "Payment intent user id") as string,
    userName: boundedString(intent.userName, "Supporter name", 160) as string,
    expectedAmount: nonNegativeNumber(
      intent.expectedAmount,
      "Expected payment amount",
    ),
    currency: currency(intent.currency),
    status: boundedString(intent.status, "Payment intent status", 40) as string,
    targetTable: boundedString(
      intent.targetTable,
      "Payment intent target",
      120,
    ) as string,
    targetRecordId: boundedString(
      intent.targetRecordId,
      "Payment intent target record",
      128,
    ) as string,
    createdAt: requiredTimestamp(
      intent.createdAt,
      "Payment intent creation time",
    ),
    expiresAt: optionalTimestamp(
      intent.expiresAt,
      "Payment intent expiry time",
    ),
    summaryLabel: boundedString(
      intent.summaryLabel,
      "Payment intent summary",
      240,
    ) as string,
  };
}

function mapPendingIntent(
  row: Record<string, unknown>,
  userNamesById: Map<string, string>,
) {
  const userId = identifier(
    row.user_id == null ? null : String(row.user_id),
    "Payment intent user id",
  ) as string;
  const targetTable = boundedString(
    row.target_table,
    "Payment intent target",
    120,
  ) as string;
  return normalizePendingIntent({
    id: row.id == null ? null : String(row.id),
    userId,
    userName: userNamesById.get(userId) ?? "Supporter",
    expectedAmount: row.expected_amount,
    currency: row.currency,
    status: row.status,
    targetTable,
    targetRecordId:
      row.target_record_id == null ? "" : String(row.target_record_id),
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    summaryLabel: targetTable.replaceAll("_", " "),
  });
}

function assertUnique(values: string[], label: string) {
  if (new Set(values).size !== values.length) {
    throw new AdminSmsValidationError(`${label} contains duplicate records.`);
  }
}

export function normalizeAdminSmsSnapshot(value: unknown): AdminSmsSnapshot {
  const snapshot = record(value, "SMS snapshot");
  const metrics = record(snapshot.metrics, "SMS metrics");
  const metricEntries = Object.entries(metrics);
  if (metricEntries.length > 12) {
    throw new AdminSmsValidationError("SMS metrics exceed the safe limit.");
  }
  const normalizedMetrics = Object.fromEntries(
    metricEntries.map(([label, metric]) => [
      boundedString(label, "SMS metric label", 80),
      nonNegativeNumber(metric, "SMS metric", { integer: true }),
    ]),
  );
  if (!Array.isArray(snapshot.syncRuns)) {
    throw new AdminSmsValidationError("SMS synchronization runs must be a list.");
  }
  if (snapshot.syncRuns.length > MAX_ADMIN_SMS_SYNC_RUNS) {
    throw new AdminSmsValidationError(
      "SMS synchronization runs exceed the safe limit.",
    );
  }
  const syncRuns = snapshot.syncRuns.map(normalizeSyncRun);
  assertUnique(
    syncRuns.map((run) => run.id),
    "SMS synchronization runs",
  );
  return { metrics: normalizedMetrics, syncRuns };
}

export function normalizeAdminSmsManualReviewWorkspace(
  value: unknown,
): AdminSmsManualReviewWorkspace {
  const workspace = record(value, "SMS manual review workspace");
  if (
    !Array.isArray(workspace.reviews) ||
    !Array.isArray(workspace.pendingIntents)
  ) {
    throw new AdminSmsValidationError(
      "SMS manual review workspace must contain lists.",
    );
  }
  if (workspace.reviews.length > MAX_ADMIN_SMS_MANUAL_REVIEWS) {
    throw new AdminSmsValidationError(
      "SMS manual reviews exceed the safe limit.",
    );
  }
  if (workspace.pendingIntents.length > MAX_ADMIN_SMS_PENDING_INTENTS) {
    throw new AdminSmsValidationError(
      "Pending payment intents exceed the safe limit.",
    );
  }
  const reviews = workspace.reviews.map(normalizeManualReview);
  const pendingIntents = workspace.pendingIntents.map(normalizePendingIntent);
  assertUnique(
    reviews.map((review) => review.reviewId),
    "SMS manual reviews",
  );
  assertUnique(
    pendingIntents.map((intent) => intent.id),
    "Pending payment intents",
  );
  return { reviews, pendingIntents };
}

async function buildClubScopedCount(
  client: SupabaseClient,
  table: string,
  clubId: number,
) {
  let query = client.from(table).select("id", { count: "exact", head: true });
  if (await hasColumn(client, table, "club_id")) {
    query = query.eq("club_id", clubId);
  }
  const { count, error } = await query;
  if (error) throw new Error(error.message);
  return nonNegativeNumber(count ?? 0, `${table} count`, { integer: true });
}

function requireManualReviewAccess(access: AdminAccess, action: string) {
  if (!access.hasAccess || !access.isSuperAdmin) {
    throw new AdminSmsValidationError(
      `Platform administrator access is required to ${action}.`,
    );
  }
}

export async function getAdminSmsSnapshot(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSmsSnapshot> {
  if (typeof window !== "undefined") {
    return normalizeAdminSmsSnapshot(
      await requestAdminApi<unknown>("sms", { signal: options.signal }),
    );
  }
  const clubId = adminClubIdOrNull(access);
  if (clubId == null) {
    throw new AdminSmsValidationError(
      "An active club is required to load SMS monitoring.",
    );
  }

  const syncRunsHasClubId = await hasColumn(
    client,
    "momo_sms_sync_runs",
    "club_id",
  );
  let syncRunsQuery = client
    .from("momo_sms_sync_runs")
    .select(syncRunProjection);
  if (syncRunsHasClubId) {
    syncRunsQuery = syncRunsQuery.eq("club_id", clubId);
  }
  const [rawCount, parsedCount, ledgerCount, syncRunsResponse] =
    await Promise.all([
      buildClubScopedCount(client, "momo_sms_raw", clubId),
      buildClubScopedCount(client, "momo_sms_parsed", clubId),
      buildClubScopedCount(client, "momo_ledger_entries", clubId),
      syncRunsQuery
        .order("scan_started_at", { ascending: false })
        .limit(MAX_ADMIN_SMS_SYNC_RUNS + 1),
    ]);
  if (syncRunsResponse.error) throw new Error(syncRunsResponse.error.message);
  if (!Array.isArray(syncRunsResponse.data)) {
    throw new AdminSmsValidationError(
      "SMS synchronization response is invalid.",
    );
  }
  if (syncRunsResponse.data.length > MAX_ADMIN_SMS_SYNC_RUNS) {
    throw new AdminSmsValidationError(
      "SMS synchronization runs exceed the safe limit.",
    );
  }
  return normalizeAdminSmsSnapshot({
    metrics: {
      "SMS captured": rawCount,
      "SMS parsed": parsedCount,
      "Ledger entries": ledgerCount,
    },
    syncRuns: syncRunsResponse.data.map((row) =>
      mapSmsSyncRun(row as Record<string, unknown>),
    ),
  });
}

export async function getAdminSmsManualReviewWorkspace(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSmsManualReviewWorkspace> {
  if (typeof window !== "undefined") {
    return normalizeAdminSmsManualReviewWorkspace(
      await requestAdminApi<unknown>("sms-manual-reviews", {
        signal: options.signal,
      }),
    );
  }

  requireManualReviewAccess(access, "load manual SMS reviews");
  const { data, error } = await client.rpc(
    "get_momo_sms_manual_review_queue",
    {
      p_limit: MAX_ADMIN_SMS_MANUAL_REVIEWS + 1,
      p_offset: 0,
    },
  );
  if (error) throw new Error(error.message);
  if (!Array.isArray(data)) {
    throw new AdminSmsValidationError("SMS manual review response is invalid.");
  }
  if (data.length > MAX_ADMIN_SMS_MANUAL_REVIEWS) {
    throw new AdminSmsValidationError(
      "SMS manual reviews exceed the safe limit.",
    );
  }
  const reviews = data.map((row) =>
    mapManualReview(row as Record<string, unknown>),
  );
  const amounts = [
    ...new Set(
      reviews.map((review) => review.amount).filter((value) => value > 0),
    ),
  ];
  if (amounts.length === 0) {
    return { reviews, pendingIntents: [] };
  }

  const { data: intents, error: intentsError } = await client
    .from("payment_intents")
    .select(
      "id,user_id,target_table,target_record_id,expected_amount,currency,status,expires_at,created_at",
    )
    .eq("status", "pending")
    .in("expected_amount", amounts)
    .order("created_at", { ascending: false })
    .limit(MAX_ADMIN_SMS_PENDING_INTENTS + 1);
  if (intentsError) throw new Error(intentsError.message);
  if (!Array.isArray(intents)) {
    throw new AdminSmsValidationError(
      "Pending payment intent response is invalid.",
    );
  }
  if (intents.length > MAX_ADMIN_SMS_PENDING_INTENTS) {
    throw new AdminSmsValidationError(
      "Pending payment intents exceed the safe limit.",
    );
  }

  const userIds = [
    ...new Set(
      intents.map((row) =>
        identifier(
          (row as Record<string, unknown>).user_id == null
            ? null
            : String((row as Record<string, unknown>).user_id),
          "Payment intent user id",
        ) as string,
      ),
    ),
  ];
  const usersResponse =
    userIds.length > 0
      ? await client.from("users").select("id,full_name").in("id", userIds)
      : { data: [], error: null };
  if (usersResponse.error) throw new Error(usersResponse.error.message);
  const userNamesById = new Map(
    (usersResponse.data ?? []).map((row) => [
      identifier(
        (row as Record<string, unknown>).id == null
          ? null
          : String((row as Record<string, unknown>).id),
        "User id",
      ) as string,
      boundedString(
        (row as Record<string, unknown>).full_name,
        "Supporter name",
        160,
      ) as string,
    ]),
  );

  return normalizeAdminSmsManualReviewWorkspace({
    reviews,
    pendingIntents: intents.map((row) =>
      mapPendingIntent(row as Record<string, unknown>, userNamesById),
    ),
  });
}

function normalizeReviewMutationInput(
  value: unknown,
  action: "allocate" | "reject",
) {
  const input = record(value, "SMS review action");
  const allowed =
    action === "allocate"
      ? ["reviewId", "intentId", "note"]
      : ["reviewId", "note"];
  if (Object.keys(input).some((key) => !allowed.includes(key))) {
    throw new AdminSmsValidationError(
      "SMS review action contains unsupported fields.",
    );
  }
  return {
    reviewId: identifier(input.reviewId, "Review id") as string,
    intentId:
      action === "allocate"
        ? (identifier(input.intentId, "Payment intent id") as string)
        : null,
    note: optionalString(input.note, "Review note", 1_000),
  };
}

export async function allocateAdminSmsManualReview(
  client: SupabaseClient,
  access: AdminAccess,
  value: unknown,
) {
  requireManualReviewAccess(access, "allocate manual SMS reviews");
  const input = normalizeReviewMutationInput(value, "allocate");
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("sms-manual-reviews", {
      method: "POST",
      body: {
        action: "allocate",
        reviewId: input.reviewId,
        intentId: input.intentId,
        note: input.note,
      },
    });
    return;
  }
  const { error } = await client.rpc("allocate_momo_manual_review", {
    p_review_id: input.reviewId,
    p_intent_id: input.intentId,
    p_note: input.note,
  });
  if (error) throw new Error(error.message);
}

export async function rejectAdminSmsManualReview(
  client: SupabaseClient,
  access: AdminAccess,
  value: unknown,
) {
  requireManualReviewAccess(access, "reject manual SMS reviews");
  const input = normalizeReviewMutationInput(value, "reject");
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("sms-manual-reviews", {
      method: "POST",
      body: {
        action: "reject",
        reviewId: input.reviewId,
        note: input.note,
      },
    });
    return;
  }
  const { error } = await client.rpc(
    "admin_reject_momo_sms_manual_review",
    {
      p_review_id: input.reviewId,
      p_note: input.note,
    },
  );
  if (error) throw new Error(error.message);
}
