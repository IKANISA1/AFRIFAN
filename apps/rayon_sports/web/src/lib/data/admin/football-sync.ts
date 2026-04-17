/**
 * Admin Football Sync — data layer for the API-Football sync dashboard.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";

/* ---------- Types ---------- */

export interface AdminSyncConfig {
  id: string;
  leagueId: number;
  leagueName: string;
  leagueCountry: string;
  season: number;
  competitionId: string | null;
  seasonId: string | null;
  isActive: boolean;
  lastSyncAt: string | null;
  syncIntervalMinutes: number;
  createdAt: string;
}

export interface AdminSyncLog {
  id: string;
  syncType: string;
  status: string;
  recordsProcessed: number;
  apiCallsUsed: number;
  errorMessage: string | null;
  startedAt: string;
  completedAt: string | null;
  durationMs: number | null;
  metadata: Record<string, unknown>;
}

export interface AdminSyncOverview {
  totalLeagues: number;
  activeLeagues: number;
  totalFixtures: number;
  scheduledFixtures: number;
  finishedFixtures: number;
  totalTeams: number;
  lastSyncAt: string | null;
  apiCallsToday: number;
  apiCallsLimit: number;
}

/* ---------- Mappers ---------- */

function mapSyncConfig(row: Record<string, unknown>): AdminSyncConfig {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    leagueId: safeNumber(row.league_id, 0),
    leagueName: safeString(row.league_name, "League"),
    leagueCountry: safeString(row.league_country),
    season: safeNumber(row.season, 2025),
    competitionId: row.competition_id ? String(row.competition_id) : null,
    seasonId: row.season_id ? String(row.season_id) : null,
    isActive: row.is_active !== false,
    lastSyncAt: row.last_sync_at ? String(row.last_sync_at) : null,
    syncIntervalMinutes: safeNumber(row.sync_interval_minutes, 360),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapSyncLog(row: Record<string, unknown>): AdminSyncLog {
  const startedAt = safeString(row.started_at, new Date().toISOString());
  const completedAt = row.completed_at ? String(row.completed_at) : null;
  let durationMs: number | null = null;
  if (startedAt && completedAt) {
    durationMs = new Date(completedAt).getTime() - new Date(startedAt).getTime();
  }

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    syncType: safeString(row.sync_type, "unknown"),
    status: safeString(row.status, "pending"),
    recordsProcessed: safeNumber(row.records_processed, 0),
    apiCallsUsed: safeNumber(row.api_calls_used, 0),
    errorMessage: row.error_message ? String(row.error_message) : null,
    startedAt,
    completedAt,
    durationMs,
    metadata: (row.metadata as Record<string, unknown>) ?? {},
  };
}

/* ---------- Queries ---------- */

export async function getAdminSyncConfigs(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminSyncConfig[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSyncConfig[]>("football-sync-configs");
  }

  const { data, error } = await client
    .from("football_sync_config")
    .select("*")
    .order("league_name", { ascending: true });

  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((r) => mapSyncConfig(r as Record<string, unknown>))
    : [];
}

export async function getAdminSyncLogs(
  client: SupabaseClient,
  _access: AdminAccess,
  limit: number = 50,
): Promise<AdminSyncLog[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSyncLog[]>(`football-sync-logs?limit=${limit}`);
  }

  const { data, error } = await client
    .from("football_sync_log")
    .select("*")
    .order("started_at", { ascending: false })
    .limit(limit);

  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((r) => mapSyncLog(r as Record<string, unknown>))
    : [];
}

export async function getAdminSyncOverview(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminSyncOverview> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSyncOverview>("football-sync-overview");
  }

  // Parallel counts
  const [configRes, fixturesRes, teamsRes, logsRes] = await Promise.all([
    client.from("football_sync_config").select("is_active", { count: "exact" }),
    client.from("football_fixtures_catalog").select("status", { count: "exact" }),
    client.from("football_teams_catalog").select("id", { count: "exact", head: true }),
    client
      .from("football_sync_log")
      .select("api_calls_used, started_at")
      .gte("started_at", new Date(new Date().setHours(0, 0, 0, 0)).toISOString())
      .order("started_at", { ascending: false }),
  ]);

  const configs = configRes.data ?? [];
  const fixtures = fixturesRes.data ?? [];
  const totalTeams = teamsRes.count ?? 0;
  const todayLogs = logsRes.data ?? [];

  const activeLeagues = configs.filter((c) => (c as Record<string, unknown>).is_active !== false).length;

  const fixtureStatuses = fixtures.reduce<Record<string, number>>((acc, f) => {
    const status = String((f as Record<string, unknown>).status ?? "unknown");
    acc[status] = (acc[status] ?? 0) + 1;
    return acc;
  }, {});

  const apiCallsToday = todayLogs.reduce((sum, log) => {
    return sum + safeNumber((log as Record<string, unknown>).api_calls_used, 0);
  }, 0);

  const lastSync = todayLogs.length > 0
    ? String((todayLogs[0] as Record<string, unknown>).started_at ?? "")
    : null;

  return {
    totalLeagues: configs.length,
    activeLeagues,
    totalFixtures: fixtures.length,
    scheduledFixtures: fixtureStatuses["scheduled"] ?? 0,
    finishedFixtures: fixtureStatuses["finished"] ?? 0,
    totalTeams,
    lastSyncAt: lastSync,
    apiCallsToday,
    apiCallsLimit: 100, // Free tier
  };
}

/* ---------- Actions ---------- */

export async function triggerSyncCommand(
  client: SupabaseClient,
  _access: AdminAccess,
  command: string,
): Promise<{ message: string; data?: unknown }> {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ message: string; data?: unknown }>("football-sync-trigger", {
      method: "POST",
      body: { command },
    });
  }

  const { data, error } = await client.functions.invoke("football-sync", {
    body: { command },
  });

  if (error) throw new Error(error.message);
  return { message: `Sync command '${command}' triggered`, data };
}

export async function triggerMultiplierGeneration(
  client: SupabaseClient,
  _access: AdminAccess,
  fixtureId?: string,
): Promise<{ message: string; data?: unknown }> {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ message: string; data?: unknown }>("football-multipliers", {
      method: "POST",
      body: { command: fixtureId ? "generate" : "generate-all", fixture_id: fixtureId },
    });
  }

  const { data, error } = await client.functions.invoke("generate-multipliers", {
    body: {
      command: fixtureId ? "generate" : "generate-all",
      fixture_id: fixtureId,
    },
  });

  if (error) throw new Error(error.message);
  return { message: "Multiplier generation triggered", data };
}
