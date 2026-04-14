/**
 * Admin SMS monitor — sync run snapshots.
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
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  adminClubIdOrNull,
  hasColumn,
  metadataSnippet,
  safeCount,
} from "./helpers";

function mapSmsSyncRun(row: Record<string, unknown>): AdminSmsSyncRun {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    status: safeString(row.status, "unknown"),
    trigger: safeString(row.trigger, "background"),
    scannedMessages: safeNumber(row.scanned_messages, 0),
    uploadedMessages: safeNumber(row.uploaded_messages, 0),
    startedAt: safeString(row.scan_started_at) || null,
  };
}

function requireAdminWorkspaceAccess(
  access: Pick<AdminAccess, "hasAccess">,
  action: string,
) {
  if (!access.hasAccess) {
    throw new Error(`Admin workspace access is required to ${action}.`);
  }
}

function mapManualReview(row: Record<string, unknown>): AdminSmsManualReview {
  return {
    reviewId: toIdString(row.review_id, crypto.randomUUID()),
    rawSmsId: safeString(row.raw_sms_id) || null,
    parsedSmsId: safeString(row.parsed_sms_id) || null,
    userId: safeString(row.user_id) || null,
    sender: safeString(row.sender, "Unknown sender"),
    txType: safeString(row.tx_type, "unknown"),
    txCategory: safeString(row.tx_category, "uncategorized"),
    cashflowBucket: safeString(row.cashflow_bucket, "unknown"),
    amount: safeNumber(row.amount, 0),
    currency: safeString(row.currency, "RWF"),
    momoTxId: safeString(row.momo_tx_id) || null,
    payerName: safeString(row.payer_name) || null,
    payeeName: safeString(row.payee_name) || null,
    payeeNumberOrCode: safeString(row.payee_number_or_code) || null,
    merchantCode: safeString(row.merchant_code) || null,
    smsReceivedAt: safeString(row.sms_received_at) || null,
    reviewCreatedAt: safeString(row.review_created_at) || null,
    updatedAt: safeString(row.updated_at) || null,
    reviewKind: safeString(row.review_kind, "needs_review"),
    reason: safeString(row.reason, "manual_review"),
    notes: safeString(row.notes) || null,
    smsPreview: safeString(row.sms_preview),
  };
}

function mapPendingIntent(
  row: Record<string, unknown>,
  userNamesById: Map<string, string>,
): AdminPendingPaymentIntent {
  const userId = safeString(row.user_id);
  const targetTable = safeString(row.target_table, "payment_intents");
  const summary = metadataSnippet(row.metadata);

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    userId,
    userName: userNamesById.get(userId) ?? "Supporter",
    expectedAmount: safeNumber(row.expected_amount, 0),
    currency: safeString(row.currency, "RWF"),
    status: safeString(row.status, "pending"),
    targetTable,
    targetRecordId: safeString(row.target_record_id),
    createdAt: safeString(row.created_at, new Date().toISOString()),
    expiresAt: safeString(row.expires_at) || null,
    summaryLabel: `${targetTable.replaceAll("_", " ")} • ${summary}`,
  };
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
  return safeCount(query);
}

export async function getAdminSmsSnapshot(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminSmsSnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSmsSnapshot>("sms");
  }
  const clubId = adminClubIdOrNull(access);
  if (clubId == null) {
    return { metrics: {}, syncRuns: [] };
  }

  const syncRunsHasClubId = await hasColumn(
    client,
    "momo_sms_sync_runs",
    "club_id",
  );
  const [rawCount, parsedCount, ledgerCount, syncRuns] = await Promise.all([
    buildClubScopedCount(client, "momo_sms_raw", clubId),
    buildClubScopedCount(client, "momo_sms_parsed", clubId),
    buildClubScopedCount(client, "momo_ledger_entries", clubId),
    syncRunsHasClubId
      ? client
          .from("momo_sms_sync_runs")
          .select("*")
          .eq("club_id", clubId)
          .order("scan_started_at", { ascending: false })
          .limit(10)
      : client
          .from("momo_sms_sync_runs")
          .select("*")
          .order("scan_started_at", { ascending: false })
          .limit(10),
  ]);
  return {
    metrics: {
      "SMS captured": rawCount,
      "SMS parsed": parsedCount,
      "Ledger entries": ledgerCount,
    },
    syncRuns:
      !syncRuns.error && Array.isArray(syncRuns.data)
        ? syncRuns.data.map((row) =>
            mapSmsSyncRun(row as Record<string, unknown>),
          )
        : [],
  };
}

export async function getAdminSmsManualReviewWorkspace(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminSmsManualReviewWorkspace> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSmsManualReviewWorkspace>("sms-manual-reviews");
  }

  requireAdminWorkspaceAccess(access, "load manual SMS reviews");

  const { data, error } = await client.rpc("get_momo_sms_manual_review_queue", {
    p_limit: 30,
    p_offset: 0,
  });

  if (error) {
    throw new Error(error.message);
  }

  const reviews = Array.isArray(data)
    ? data.map((row) => mapManualReview(row as Record<string, unknown>))
    : [];

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
      "id, user_id, target_table, target_record_id, expected_amount, currency, status, expires_at, created_at, metadata",
    )
    .eq("status", "pending")
    .in("expected_amount", amounts)
    .order("created_at", { ascending: false })
    .limit(150);

  if (intentsError) {
    throw new Error(intentsError.message);
  }

  const userIds = [
    ...new Set(
      (Array.isArray(intents) ? intents : [])
        .map((row) => safeString((row as Record<string, unknown>).user_id))
        .filter(Boolean),
    ),
  ];

  const usersResponse =
    userIds.length > 0
      ? await client.from("users").select("id, full_name").in("id", userIds)
      : { data: [], error: null };

  if (usersResponse.error) {
    throw new Error(usersResponse.error.message);
  }

  const userNamesById = new Map(
    (usersResponse.data ?? []).map((row) => [
      safeString(row.id),
      safeString(row.full_name, "Supporter"),
    ]),
  );

  return {
    reviews,
    pendingIntents: Array.isArray(intents)
      ? intents.map((row) =>
          mapPendingIntent(row as Record<string, unknown>, userNamesById),
        )
      : [],
  };
}

export async function allocateAdminSmsManualReview(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    reviewId: string;
    intentId: string;
    note?: string | null;
  },
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("sms-manual-reviews", {
      method: "POST",
      body: {
        action: "allocate",
        reviewId: input.reviewId,
        intentId: input.intentId,
        note: input.note ?? null,
      },
    });
    return;
  }

  requireAdminWorkspaceAccess(access, "allocate manual SMS reviews");

  const { error } = await client.rpc("allocate_momo_manual_review", {
    p_review_id: input.reviewId,
    p_intent_id: input.intentId,
    p_note: safeString(input.note) || null,
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function rejectAdminSmsManualReview(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    reviewId: string;
    note?: string | null;
  },
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("sms-manual-reviews", {
      method: "POST",
      body: {
        action: "reject",
        reviewId: input.reviewId,
        note: input.note ?? null,
      },
    });
    return;
  }

  requireAdminWorkspaceAccess(access, "reject manual SMS reviews");

  const { error } = await client.rpc("admin_reject_momo_sms_manual_review", {
    p_review_id: input.reviewId,
    p_note: safeString(input.note) || null,
  });

  if (error) {
    throw new Error(error.message);
  }
}
