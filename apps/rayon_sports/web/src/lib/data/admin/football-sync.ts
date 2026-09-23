/**
 * Admin Football Sync — bounded LiveScore source management and sync health.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const MAX_SOURCE_RECORDS = 500;
const MAX_LOG_RECORDS = 500;
const MAX_LIST_VALUES = 50;
const MAX_SOURCE_URLS = 20;

const syncStatuses = new Set([
  "pending",
  "running",
  "completed",
  "success",
  "completed_with_errors",
  "failed",
  "error",
  "cancelled",
]);

export interface AdminSyncLog {
  id: string;
  syncType: "livescore_web";
  status: string;
  recordsFetched: number;
  recordsUpserted: number;
  webRequestsUsed: number;
  errorMessage: string | null;
  startedAt: string;
  completedAt: string | null;
  durationMs: number | null;
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
  inspectedLogRowsToday: number;
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

export interface AdminFootballSyncSnapshot {
  overview: AdminSyncOverview;
  sources: AdminLiveScoreCompetitionSource[];
  logs: AdminSyncLog[];
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

const emptyOverview: AdminSyncOverview = {
  totalSources: 0,
  activeSources: 0,
  totalFixtures: 0,
  scheduledFixtures: 0,
  liveFixtures: 0,
  finishedFixtures: 0,
  totalTeams: 0,
  lastSyncAt: null,
  webRequestsToday: 0,
  errorsToday: 0,
  inspectedLogRowsToday: 0,
};

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
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

function boundedStringArray(
  value: unknown,
  {
    maximum = MAX_LIST_VALUES,
    itemLength = 160,
  }: { maximum?: number; itemLength?: number } = {},
) {
  const entries =
    typeof value === "string"
      ? value.split(",")
      : Array.isArray(value)
        ? value
        : [];
  const normalized: string[] = [];
  for (const entry of entries.slice(0, maximum)) {
    const text = boundedText(entry, itemLength);
    if (text != null && !normalized.includes(text)) normalized.push(text);
  }
  return normalized;
}

function normalizeLiveScoreUrl(value: unknown) {
  const text = boundedText(value, 2_048);
  if (text == null) return null;
  try {
    const url = new URL(text);
    const host = url.hostname.toLowerCase();
    if (
      url.protocol !== "https:" ||
      url.username !== "" ||
      url.password !== "" ||
      (host !== "livescore.com" && !host.endsWith(".livescore.com"))
    ) {
      return null;
    }
    url.hash = "";
    return url.toString();
  } catch {
    return null;
  }
}

function normalizeSourceUrls(value: unknown) {
  return boundedStringArray(value, {
    maximum: MAX_SOURCE_URLS,
    itemLength: 2_048,
  }).flatMap((entry) => {
    const url = normalizeLiveScoreUrl(entry);
    return url == null ? [] : [url];
  });
}

function mapSyncLog(row: Record<string, unknown>): AdminSyncLog | null {
  const id = boundedText(row.id, 128);
  const syncType = boundedText(row.sync_type ?? row.syncType, 64);
  const status = boundedText(row.status, 64)?.toLowerCase() ?? null;
  const recordsFetched = boundedInteger(
    row.records_fetched ?? row.recordsFetched,
    0,
    1_000_000_000,
  );
  const recordsUpserted = boundedInteger(
    row.records_upserted ?? row.recordsUpserted,
    0,
    1_000_000_000,
  );
  const webRequestsUsed = boundedInteger(
    row.api_requests_used ?? row.webRequestsUsed,
    0,
    1_000_000_000,
  );
  const startedAt = boundedDate(row.started_at ?? row.startedAt);
  const completedValue = row.completed_at ?? row.completedAt;
  const completedAt =
    completedValue == null ? null : boundedDate(completedValue);

  if (
    id == null ||
    syncType !== "livescore_web" ||
    status == null ||
    !syncStatuses.has(status) ||
    recordsFetched == null ||
    recordsUpserted == null ||
    webRequestsUsed == null ||
    startedAt == null ||
    (completedValue != null && completedAt == null)
  ) {
    return null;
  }

  const calculatedDuration =
    completedAt == null
      ? null
      : new Date(completedAt).getTime() - new Date(startedAt).getTime();
  const durationMs =
    calculatedDuration != null &&
    calculatedDuration >= 0 &&
    calculatedDuration <= 7 * 24 * 60 * 60 * 1_000
      ? calculatedDuration
      : null;
  const hasError =
    row.error_message != null || row.errorMessage != null || status === "error";

  return {
    id,
    syncType: "livescore_web",
    status,
    recordsFetched,
    recordsUpserted,
    webRequestsUsed,
    errorMessage: hasError
      ? "Sync reported an operational error. Review authorized server logs."
      : null,
    startedAt,
    completedAt,
    durationMs,
  };
}

function mapLiveScoreSource(
  row: Record<string, unknown>,
): AdminLiveScoreCompetitionSource | null {
  const id = boundedText(row.id, 128);
  const clubValue = row.club_id ?? row.clubId;
  const clubId =
    clubValue == null ? null : boundedInteger(clubValue, 1, 2_147_483_647);
  const sourceKey = boundedText(row.source_key ?? row.sourceKey, 80);
  const displayName = boundedText(row.display_name ?? row.displayName, 160);
  const matchAliases = boundedStringArray(
    row.match_aliases ?? row.matchAliases,
  );
  const countryAliases = boundedStringArray(
    row.country_aliases ?? row.countryAliases,
  );
  const externalCompetitionIds = boundedStringArray(
    row.external_competition_ids ?? row.externalCompetitionIds,
  );
  const sourceUrls = normalizeSourceUrls(row.source_urls ?? row.sourceUrls);
  const priority = boundedInteger(row.priority, 0, 10_000);
  const isActive = row.is_active ?? row.isActive;
  const updatedAt = boundedDate(row.updated_at ?? row.updatedAt);

  if (
    id == null ||
    (clubValue != null && clubId == null) ||
    sourceKey == null ||
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(sourceKey) ||
    displayName == null ||
    matchAliases.length === 0 ||
    sourceUrls.length === 0 ||
    priority == null ||
    typeof isActive !== "boolean" ||
    updatedAt == null
  ) {
    return null;
  }

  return {
    id,
    clubId,
    sourceKey,
    displayName,
    matchAliases,
    countryAliases,
    externalCompetitionIds,
    sourceUrls,
    priority,
    isActive,
    updatedAt,
  };
}

export function normalizeAdminSyncLogs(value: unknown): AdminSyncLog[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, MAX_LOG_RECORDS).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const log = mapSyncLog(entry as Record<string, unknown>);
    return log == null ? [] : [log];
  });
}

export function normalizeAdminLiveScoreCompetitionSources(
  value: unknown,
): AdminLiveScoreCompetitionSource[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, MAX_SOURCE_RECORDS).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const source = mapLiveScoreSource(entry as Record<string, unknown>);
    return source == null ? [] : [source];
  });
}

export function normalizeAdminSyncOverview(value: unknown): AdminSyncOverview {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return emptyOverview;
  }
  const row = value as Record<string, unknown>;
  const normalized = {
    totalSources: boundedInteger(row.totalSources, 0, 1_000_000),
    activeSources: boundedInteger(row.activeSources, 0, 1_000_000),
    totalFixtures: boundedInteger(row.totalFixtures, 0, 1_000_000_000),
    scheduledFixtures: boundedInteger(row.scheduledFixtures, 0, 1_000_000_000),
    liveFixtures: boundedInteger(row.liveFixtures, 0, 1_000_000_000),
    finishedFixtures: boundedInteger(row.finishedFixtures, 0, 1_000_000_000),
    totalTeams: boundedInteger(row.totalTeams, 0, 1_000_000_000),
    lastSyncAt: row.lastSyncAt == null ? null : boundedDate(row.lastSyncAt),
    webRequestsToday: boundedInteger(row.webRequestsToday, 0, 1_000_000_000),
    errorsToday: boundedInteger(row.errorsToday, 0, MAX_LOG_RECORDS),
    inspectedLogRowsToday: boundedInteger(
      row.inspectedLogRowsToday,
      0,
      MAX_LOG_RECORDS,
    ),
  };
  if (
    [
      normalized.totalSources,
      normalized.activeSources,
      normalized.totalFixtures,
      normalized.scheduledFixtures,
      normalized.liveFixtures,
      normalized.finishedFixtures,
      normalized.totalTeams,
      normalized.webRequestsToday,
      normalized.errorsToday,
      normalized.inspectedLogRowsToday,
    ].some((entry) => entry == null) ||
    (row.lastSyncAt != null && normalized.lastSyncAt == null) ||
    (normalized.activeSources ?? 0) > (normalized.totalSources ?? 0)
  ) {
    return emptyOverview;
  }
  return normalized as AdminSyncOverview;
}

export function normalizeAdminFootballSyncSnapshot(
  value: unknown,
): AdminFootballSyncSnapshot {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return { overview: emptyOverview, sources: [], logs: [] };
  }
  const snapshot = value as Record<string, unknown>;
  return {
    overview: normalizeAdminSyncOverview(snapshot.overview),
    sources: normalizeAdminLiveScoreCompetitionSources(snapshot.sources),
    logs: normalizeAdminSyncLogs(snapshot.logs),
  };
}

export async function getAdminLiveScoreCompetitionSources(
  client: SupabaseClient,
  _access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminLiveScoreCompetitionSource[]> {
  void _access;
  if (typeof window !== "undefined") {
    const data = await requestAdminApi<unknown>("livescore-sources", options);
    return normalizeAdminLiveScoreCompetitionSources(data);
  }

  const { data, error } = await client
    .from("livescore_competition_sources")
    .select(
      "id, club_id, source_key, display_name, match_aliases, country_aliases, external_competition_ids, source_urls, priority, is_active, updated_at",
    )
    .order("priority", { ascending: true })
    .order("display_name", { ascending: true })
    .limit(MAX_SOURCE_RECORDS);

  if (error) throw new Error(error.message);
  return normalizeAdminLiveScoreCompetitionSources(data);
}

export async function getAdminSyncLogs(
  client: SupabaseClient,
  _access: AdminAccess,
  limit = 50,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSyncLog[]> {
  void _access;
  const boundedLimit = Math.min(
    MAX_LOG_RECORDS,
    Math.max(1, Number.isFinite(limit) ? Math.floor(limit) : 50),
  );
  if (typeof window !== "undefined") {
    const data = await requestAdminApi<unknown>(
      `football-sync-logs?limit=${boundedLimit}`,
      options,
    );
    return normalizeAdminSyncLogs(data);
  }

  const { data, error } = await client
    .from("football_sync_log")
    .select(
      "id, sync_type, status, records_fetched, records_upserted, api_requests_used, error_message, started_at, completed_at",
    )
    .eq("sync_type", "livescore_web")
    .order("started_at", { ascending: false })
    .limit(boundedLimit);

  if (error) throw new Error(error.message);
  return normalizeAdminSyncLogs(data);
}

export async function getAdminSyncOverview(
  client: SupabaseClient,
  _access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSyncOverview> {
  void _access;
  if (typeof window !== "undefined") {
    const data = await requestAdminApi<unknown>(
      "football-sync-overview",
      options,
    );
    return normalizeAdminSyncOverview(data);
  }

  const today = new Date(new Date().setHours(0, 0, 0, 0)).toISOString();
  const [
    sources,
    activeSources,
    fixtures,
    scheduledFixtures,
    liveFixtures,
    finishedFixtures,
    teams,
    latestLog,
    todayLogs,
  ] = await Promise.all([
    client
      .from("livescore_competition_sources")
      .select("id", { count: "exact", head: true }),
    client
      .from("livescore_competition_sources")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
    client
      .schema("football")
      .from("fixtures")
      .select("id", { count: "exact", head: true })
      .eq("external_provider", "livescore"),
    client
      .schema("football")
      .from("fixtures")
      .select("id", { count: "exact", head: true })
      .eq("external_provider", "livescore")
      .eq("status", "scheduled"),
    client
      .schema("football")
      .from("fixtures")
      .select("id", { count: "exact", head: true })
      .eq("external_provider", "livescore")
      .eq("status", "live"),
    client
      .schema("football")
      .from("fixtures")
      .select("id", { count: "exact", head: true })
      .eq("external_provider", "livescore")
      .eq("status", "finished"),
    client
      .schema("football")
      .from("teams")
      .select("id", { count: "exact", head: true })
      .eq("external_provider", "livescore"),
    client
      .from("football_sync_log")
      .select("started_at")
      .eq("sync_type", "livescore_web")
      .order("started_at", { ascending: false })
      .limit(1),
    client
      .from("football_sync_log")
      .select("api_requests_used, error_message")
      .eq("sync_type", "livescore_web")
      .gte("started_at", today)
      .order("started_at", { ascending: false })
      .limit(MAX_LOG_RECORDS),
  ]);

  const results = [
    sources,
    activeSources,
    fixtures,
    scheduledFixtures,
    liveFixtures,
    finishedFixtures,
    teams,
    latestLog,
    todayLogs,
  ];
  const failed = results.find((result) => result.error != null);
  if (failed?.error) throw new Error(failed.error.message);

  const logRows = Array.isArray(todayLogs.data) ? todayLogs.data : [];
  return normalizeAdminSyncOverview({
    totalSources: sources.count ?? 0,
    activeSources: activeSources.count ?? 0,
    totalFixtures: fixtures.count ?? 0,
    scheduledFixtures: scheduledFixtures.count ?? 0,
    liveFixtures: liveFixtures.count ?? 0,
    finishedFixtures: finishedFixtures.count ?? 0,
    totalTeams: teams.count ?? 0,
    lastSyncAt:
      Array.isArray(latestLog.data) && latestLog.data.length > 0
        ? (latestLog.data[0] as Record<string, unknown>).started_at
        : null,
    webRequestsToday: logRows.reduce((sum, log) => {
      const requests = boundedInteger(
        (log as Record<string, unknown>).api_requests_used,
        0,
        1_000_000_000,
      );
      return sum + (requests ?? 0);
    }, 0),
    errorsToday: logRows.filter(
      (log) => (log as Record<string, unknown>).error_message != null,
    ).length,
    inspectedLogRowsToday: logRows.length,
  });
}

export function normalizeAdminLiveScoreCompetitionSourceInput(
  input: AdminLiveScoreCompetitionSourceInput,
) {
  const displayName = boundedText(input.displayName, 160);
  const derivedKey =
    displayName
      ?.toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "") ?? "";
  const sourceKey = boundedText(input.sourceKey || derivedKey, 80);
  const id = input.id == null ? null : boundedText(input.id, 128);
  const expectedUpdatedAt =
    input.expectedUpdatedAt == null
      ? null
      : boundedDate(input.expectedUpdatedAt);
  const clubId =
    input.clubId == null
      ? null
      : boundedInteger(input.clubId, 1, 2_147_483_647);
  const matchAliases = boundedStringArray(input.matchAliases);
  const countryAliases = boundedStringArray(input.countryAliases ?? []);
  const externalCompetitionIds = boundedStringArray(
    input.externalCompetitionIds ?? [],
  );
  const sourceUrls = normalizeSourceUrls(input.sourceUrls);
  const priority = boundedInteger(input.priority ?? 100, 0, 10_000);

  if (
    displayName == null ||
    sourceKey == null ||
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(sourceKey) ||
    (input.id != null && id == null) ||
    (input.expectedUpdatedAt != null && expectedUpdatedAt == null) ||
    (input.clubId != null && clubId == null) ||
    matchAliases.length === 0 ||
    sourceUrls.length === 0 ||
    priority == null ||
    typeof input.isActive !== "boolean"
  ) {
    throw new Error(
      "Enter a valid display name, source key, match alias, approved LiveScore HTTPS URL, priority, and state.",
    );
  }

  return {
    id,
    expectedUpdatedAt,
    clubId,
    sourceKey,
    displayName,
    matchAliases,
    countryAliases,
    externalCompetitionIds,
    sourceUrls,
    priority,
    isActive: input.isActive,
  };
}

export async function saveAdminLiveScoreCompetitionSource(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminLiveScoreCompetitionSourceInput,
): Promise<string> {
  const normalized = normalizeAdminLiveScoreCompetitionSourceInput(input);
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("livescore-sources", {
      method: "POST",
      body: normalized,
    });
  }

  const requestedClubId = access.isSuperAdmin
    ? normalized.clubId
    : Number(access.clubId);
  const clubId =
    requestedClubId == null
      ? null
      : boundedInteger(requestedClubId, 1, 2_147_483_647);
  if (!access.isSuperAdmin && clubId == null) {
    requireAdminClubId(access, "save LiveScore sources");
  }
  const payload = {
    club_id: clubId,
    source_provider: "livescore",
    source_key: normalized.sourceKey,
    display_name: normalized.displayName,
    match_aliases: normalized.matchAliases,
    country_aliases: normalized.countryAliases,
    external_competition_ids: normalized.externalCompetitionIds,
    source_urls: normalized.sourceUrls,
    priority: normalized.priority,
    is_active: normalized.isActive,
  };

  if (normalized.id) {
    return mutateRecordWithVariantsIfUnchanged(
      client,
      "livescore_competition_sources",
      normalized.id,
      normalized.expectedUpdatedAt,
      [payload],
    );
  }

  const { data, error } = await client
    .from("livescore_competition_sources")
    .insert(payload)
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  const id = boundedText(data?.id, 128);
  if (id == null) throw new Error("LiveScore source save was not confirmed.");
  return id;
}

export async function deleteAdminLiveScoreCompetitionSource(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
): Promise<void> {
  const safeId = boundedText(id, 128);
  const safeUpdatedAt = boundedDate(expectedUpdatedAt);
  if (safeId == null || safeUpdatedAt == null) {
    throw new Error("Refresh the LiveScore source before deleting it.");
  }
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: boolean }>("livescore-sources", {
      method: "DELETE",
      query: { id: safeId, expected_updated_at: safeUpdatedAt },
    });
    return;
  }

  const clubId = access.isSuperAdmin
    ? null
    : requireAdminClubId(access, "delete LiveScore sources");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "livescore_competition_sources",
    safeId,
    safeUpdatedAt,
    clubId == null ? {} : { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_livescore_source",
      source: "admin_football_sync",
    },
  );
}
