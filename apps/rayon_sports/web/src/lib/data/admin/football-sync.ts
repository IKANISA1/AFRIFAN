/**
 * Admin Football Sync - LiveScore web source management and sync health.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

export interface AdminSyncLog {
  id: string;
  syncType: string;
  status: string;
  recordsFetched: number;
  recordsUpserted: number;
  webRequestsUsed: number;
  errorMessage: string | null;
  startedAt: string;
  completedAt: string | null;
  durationMs: number | null;
  metadata: Record<string, unknown>;
}

export interface AdminSyncOverview {
  totalSources: number;
  activeSources: number;
  totalFixtures: number;
  scheduledFixtures: number;
  liveFixtures: number;
  finishedFixtures: number;
  totalTeams: number;
  lastSyncAt: string | null;
  webRequestsToday: number;
  errorsToday: number;
}

export interface AdminLiveScoreCompetitionSource {
  id: string;
  clubId: number | null;
  sourceKey: string;
  displayName: string;
  matchAliases: string[];
  countryAliases: string[];
  externalCompetitionIds: string[];
  sourceUrls: string[];
  priority: number;
  isActive: boolean;
  updatedAt: string;
}

export interface AdminLiveScoreCompetitionSourceInput {
  id?: string | null;
  expectedUpdatedAt?: string | null;
  clubId?: number | null;
  sourceKey: string;
  displayName: string;
  matchAliases: string[];
  countryAliases?: string[];
  externalCompetitionIds?: string[];
  sourceUrls: string[];
  priority?: number;
  isActive: boolean;
}

function stringArray(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((entry) => safeString(entry)).filter(Boolean);
  }
  if (typeof value === "string") {
    return value
      .split(",")
      .map((entry) => entry.trim())
      .filter(Boolean);
  }
  return [];
}

function mapSyncLog(row: Record<string, unknown>): AdminSyncLog {
  const startedAt = safeString(row.started_at, new Date().toISOString());
  const completedAt = row.completed_at ? String(row.completed_at) : null;
  const durationMs = completedAt
    ? new Date(completedAt).getTime() - new Date(startedAt).getTime()
    : null;

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    syncType: safeString(row.sync_type, "livescore_web"),
    status: safeString(row.status, "pending"),
    recordsFetched: safeNumber(row.records_fetched, 0),
    recordsUpserted: safeNumber(row.records_upserted, 0),
    webRequestsUsed: safeNumber(row.api_requests_used, 0),
    errorMessage: row.error_message ? String(row.error_message) : null,
    startedAt,
    completedAt,
    durationMs,
    metadata: (row.metadata as Record<string, unknown>) ?? {},
  };
}

function mapLiveScoreSource(
  row: Record<string, unknown>,
): AdminLiveScoreCompetitionSource {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: row.club_id == null ? null : safeNumber(row.club_id, 0),
    sourceKey: safeString(row.source_key),
    displayName: safeString(row.display_name, "LiveScore source"),
    matchAliases: stringArray(row.match_aliases),
    countryAliases: stringArray(row.country_aliases),
    externalCompetitionIds: stringArray(row.external_competition_ids),
    sourceUrls: stringArray(row.source_urls),
    priority: safeNumber(row.priority, 100),
    isActive: row.is_active !== false,
    updatedAt: safeString(row.updated_at, new Date().toISOString()),
  };
}

export async function getAdminLiveScoreCompetitionSources(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminLiveScoreCompetitionSource[]> {
  void _access;
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminLiveScoreCompetitionSource[]>(
      "livescore-sources",
    );
  }

  const { data, error } = await client
    .from("livescore_competition_sources")
    .select("*")
    .order("priority", { ascending: true })
    .order("display_name", { ascending: true });

  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row) => mapLiveScoreSource(row as Record<string, unknown>))
    : [];
}

export async function getAdminSyncLogs(
  client: SupabaseClient,
  _access: AdminAccess,
  limit: number = 50,
): Promise<AdminSyncLog[]> {
  void _access;
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSyncLog[]>(`football-sync-logs?limit=${limit}`);
  }

  const { data, error } = await client
    .from("football_sync_log")
    .select("*")
    .eq("sync_type", "livescore_web")
    .order("started_at", { ascending: false })
    .limit(limit);

  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row) => mapSyncLog(row as Record<string, unknown>))
    : [];
}

export async function getAdminSyncOverview(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminSyncOverview> {
  void _access;
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSyncOverview>("football-sync-overview");
  }

  const today = new Date(new Date().setHours(0, 0, 0, 0)).toISOString();
  const [sourcesRes, fixturesRes, teamsRes, logsRes] = await Promise.all([
    client
      .from("livescore_competition_sources")
      .select("is_active", { count: "exact" }),
    client
      .schema("football")
      .from("fixtures")
      .select("status", { count: "exact" })
      .eq("external_provider", "livescore"),
    client
      .schema("football")
      .from("teams")
      .select("id", { count: "exact", head: true })
      .eq("external_provider", "livescore"),
    client
      .from("football_sync_log")
      .select("api_requests_used, error_message, started_at")
      .eq("sync_type", "livescore_web")
      .gte("started_at", today)
      .order("started_at", { ascending: false }),
  ]);

  if (sourcesRes.error) throw new Error(sourcesRes.error.message);
  if (fixturesRes.error) throw new Error(fixturesRes.error.message);
  if (teamsRes.error) throw new Error(teamsRes.error.message);
  if (logsRes.error) throw new Error(logsRes.error.message);

  const sources = sourcesRes.data ?? [];
  const fixtures = fixturesRes.data ?? [];
  const logs = logsRes.data ?? [];
  const fixtureStatuses = fixtures.reduce<Record<string, number>>(
    (acc, fixture) => {
      const status = safeString(
        (fixture as Record<string, unknown>).status,
        "unknown",
      );
      acc[status] = (acc[status] ?? 0) + 1;
      return acc;
    },
    {},
  );

  return {
    totalSources: sources.length,
    activeSources: sources.filter(
      (source) => (source as Record<string, unknown>).is_active !== false,
    ).length,
    totalFixtures: fixtures.length,
    scheduledFixtures: fixtureStatuses.scheduled ?? 0,
    liveFixtures: fixtureStatuses.live ?? 0,
    finishedFixtures: fixtureStatuses.finished ?? 0,
    totalTeams: teamsRes.count ?? 0,
    lastSyncAt:
      logs.length > 0
        ? safeString((logs[0] as Record<string, unknown>).started_at)
        : null,
    webRequestsToday: logs.reduce(
      (sum, log) =>
        sum + safeNumber((log as Record<string, unknown>).api_requests_used, 0),
      0,
    ),
    errorsToday: logs.filter((log) =>
      safeString((log as Record<string, unknown>).error_message),
    ).length,
  };
}

export async function saveAdminLiveScoreCompetitionSource(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminLiveScoreCompetitionSourceInput,
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("livescore-sources", {
      method: "POST",
      body: input,
    });
  }

  const requestedClubId = access.isSuperAdmin
    ? (input.clubId ?? null)
    : Number(access.clubId);
  const clubId = Number.isFinite(requestedClubId as number)
    ? requestedClubId
    : null;
  const payload = {
    club_id: clubId,
    source_provider: "livescore",
    source_key: safeString(
      input.sourceKey,
      input.displayName.toLowerCase().replace(/[^a-z0-9]+/g, "-"),
    ),
    display_name: input.displayName.trim(),
    match_aliases: input.matchAliases
      .map((entry) => entry.trim())
      .filter(Boolean),
    country_aliases: (input.countryAliases ?? [])
      .map((entry) => entry.trim())
      .filter(Boolean),
    external_competition_ids: (input.externalCompetitionIds ?? [])
      .map((entry) => entry.trim())
      .filter(Boolean),
    source_urls: input.sourceUrls.map((entry) => entry.trim()).filter(Boolean),
    priority: safeNumber(input.priority, 100),
    is_active: input.isActive,
  };

  if (
    !payload.display_name ||
    payload.match_aliases.length === 0 ||
    payload.source_urls.length === 0
  ) {
    throw new Error(
      "Display name, match aliases, and source URLs are required.",
    );
  }

  if (input.id) {
    return mutateRecordWithVariantsIfUnchanged(
      client,
      "livescore_competition_sources",
      input.id,
      input.expectedUpdatedAt,
      [payload],
    );
  }

  const { data, error } = await client
    .from("livescore_competition_sources")
    .insert(payload)
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminLiveScoreCompetitionSource(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
): Promise<void> {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: boolean }>("livescore-sources", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }

  const clubId = access.isSuperAdmin
    ? null
    : requireAdminClubId(access, "delete LiveScore sources");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "livescore_competition_sources",
    id,
    expectedUpdatedAt,
    clubId == null ? {} : { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_livescore_source",
      source: "admin_football_sync",
    },
  );
}
