/**
 * Admin SMS monitor — sync run snapshots.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminSmsSnapshot, AdminSmsSyncRun } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { safeCount } from "./helpers";

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

export async function getAdminSmsSnapshot(client: SupabaseClient): Promise<AdminSmsSnapshot> {
  const [rawCount, parsedCount, ledgerCount, syncRuns] = await Promise.all([
    safeCount(client.from("momo_sms_raw").select("id", { count: "exact", head: true })),
    safeCount(client.from("momo_sms_parsed").select("id", { count: "exact", head: true })),
    safeCount(client.from("momo_ledger_entries").select("id", { count: "exact", head: true })),
    client.from("momo_sms_sync_runs").select("*").order("scan_started_at", { ascending: false }).limit(10),
  ]);
  return {
    metrics: { "SMS captured": rawCount, "SMS parsed": parsedCount, "Ledger entries": ledgerCount },
    syncRuns: !syncRuns.error && Array.isArray(syncRuns.data) ? syncRuns.data.map((row) => mapSmsSyncRun(row as Record<string, unknown>)) : [],
  };
}
