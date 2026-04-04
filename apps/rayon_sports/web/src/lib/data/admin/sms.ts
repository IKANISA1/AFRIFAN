/**
 * Admin SMS monitor — sync run snapshots.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminSmsSnapshot, AdminSmsSyncRun } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { adminClubIdOrNull, hasColumn, safeCount } from "./helpers";

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

  const syncRunsHasClubId = await hasColumn(client, "momo_sms_sync_runs", "club_id");
  const [rawCount, parsedCount, ledgerCount, syncRuns] = await Promise.all([
    buildClubScopedCount(client, "momo_sms_raw", clubId),
    buildClubScopedCount(client, "momo_sms_parsed", clubId),
    buildClubScopedCount(client, "momo_ledger_entries", clubId),
    (
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
            .limit(10)
    ),
  ]);
  return {
    metrics: { "SMS captured": rawCount, "SMS parsed": parsedCount, "Ledger entries": ledgerCount },
    syncRuns: !syncRuns.error && Array.isArray(syncRuns.data) ? syncRuns.data.map((row) => mapSmsSyncRun(row as Record<string, unknown>)) : [],
  };
}
