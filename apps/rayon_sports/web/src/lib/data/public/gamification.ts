import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { siteConfig } from "@/lib/config";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type {
  FanEngagementLeaderboardEntry,
  FanEngagementTokenItem,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";

type SupabaseRpcResult = Promise<{ data: unknown; error: unknown }>;

function invokeUntypedRpc(
  client: NonNullable<ReturnType<typeof getReadOnlySupabase>>,
  fn: string,
  args?: Record<string, unknown>,
): SupabaseRpcResult {
  return (
    client.rpc as unknown as (
      this: typeof client,
      fn: string,
      args?: Record<string, unknown>,
    ) => SupabaseRpcResult
  ).call(client, fn, args);
}

function mapTemplateScope(value: unknown): FanEngagementTokenItem["templateScope"] {
  return safeString(value).toLowerCase() === "club_specific"
    ? "club_specific"
    : "generic";
}

function mapToken(
  row: Record<string, unknown>,
): FanEngagementTokenItem {
  const fallbackCode = safeString(row.code, "fet-item").toUpperCase();

  return {
    id: toIdString(row.id, fallbackCode),
    clubId: safeNumber(row.club_id, 0),
    code: fallbackCode,
    templateScope: mapTemplateScope(row.template_scope),
    category: safeString(row.category, "General"),
    itemName: safeString(row.item_name, "Fan engagement reward"),
    fetValue: safeNumber(row.fet_value, 0),
    triggerCondition: safeString(
      row.trigger_condition,
      "Defined by club operations.",
    ),
    activationTiming: safeString(row.activation_timing, "Always on"),
    description: safeString(row.description),
    badgeName: safeString(row.badge_name) || null,
    implementationNotes: safeString(row.implementation_notes) || null,
    sortOrder: safeNumber(row.sort_order, 0),
    isActive: row.is_active !== false,
  };
}

function mapLeaderboardRow(
  row: Record<string, unknown>,
  index: number,
): FanEngagementLeaderboardEntry {
  const fallbackUserId = `supporter-${index + 1}`;

  return {
    rank: safeNumber(row.rank, index + 1),
    userId: toIdString(row.user_id, fallbackUserId),
    supporterAlias: safeString(row.supporter_alias, "000000"),
    displayName: safeString(row.display_name, "Supporter"),
    totalFet: safeNumber(row.total_fet, 0),
    tier: safeString(row.tier, "imena"),
    isCurrentUser: row.is_current_user === true,
  };
}

function buildClubCandidates(activeClubId: number) {
  const candidates = [activeClubId, siteConfig.defaultClubId].filter((value) =>
    Number.isFinite(value) && value > 0,
  );
  return [...new Set(candidates)];
}

export const getFanEngagementTokens = cache(
  async function getFanEngagementTokens(
    limit = 12,
  ): Promise<FanEngagementTokenItem[]> {
    try {
      return await loadFanEngagementTokens(limit, false);
    } catch {
      return [];
    }
  },
);

async function loadFanEngagementTokens(
  limit: number,
  strict: boolean,
): Promise<FanEngagementTokenItem[]> {
  const client = getReadOnlySupabase();
  if (client == null) return [];

  const activeClub = await getActiveClubReference();
  let lastError: unknown;
  for (const clubId of buildClubCandidates(activeClub.numericId)) {
    const { data, error } = await invokeUntypedRpc(client, "fet_get_catalog", {
      p_club_id: clubId,
      p_include_inactive: false,
    });
    if (error) {
      lastError = error;
      continue;
    }
    if (!Array.isArray(data) || data.length === 0) return [];

    const rows = data as Array<Record<string, unknown>>;
    const mapped = rows
      .filter((row) => !strict || isCompletePublicTokenRow(row))
      .map((row) => mapToken(row))
      .filter((item) => item.isActive)
      .slice(0, Math.max(0, limit));
    return mapped;
  }
  if (lastError) throw lastError;
  return [];
}

function isCompletePublicTokenRow(row: Record<string, unknown>) {
  const value = Number(row.fet_value);
  return (
    toIdString(row.id, "").trim().length > 0 &&
    safeString(row.code).trim().length > 0 &&
    safeString(row.category).trim().length > 0 &&
    safeString(row.item_name).trim().length > 0 &&
    Number.isFinite(value) &&
    value >= 0 &&
    safeString(row.trigger_condition).trim().length > 0 &&
    safeString(row.activation_timing).trim().length > 0 &&
    safeString(row.description).trim().length > 0 &&
    row.is_active !== false
  );
}

export const getFanEngagementTokensStrict = cache(
  async function getFanEngagementTokensStrict(
    limit = 12,
  ): Promise<FanEngagementTokenItem[]> {
    return loadFanEngagementTokens(limit, true);
  },
);

export const getFanEngagementLeaderboard = cache(
  async function getFanEngagementLeaderboard(
    limit = 10,
  ): Promise<FanEngagementLeaderboardEntry[]> {
    try {
      return await loadFanEngagementLeaderboard(limit, false);
    } catch {
      return [];
    }
  },
);

function isSafePublicAlias(value: string) {
  return (
    /^[A-Za-z0-9_-]{2,32}$/.test(value) &&
    !/^\d{7,}$/.test(value)
  );
}

function isCompletePublicLeaderboardRow(row: Record<string, unknown>) {
  const rank = Number(row.rank);
  const totalFet = Number(row.total_fet);
  return (
    Number.isInteger(rank) &&
    rank > 0 &&
    Number.isFinite(totalFet) &&
    totalFet >= 0 &&
    isSafePublicAlias(safeString(row.supporter_alias).trim()) &&
    safeString(row.tier).trim().length > 0
  );
}

async function loadFanEngagementLeaderboard(
  limit: number,
  strict: boolean,
): Promise<FanEngagementLeaderboardEntry[]> {
  const client = getReadOnlySupabase();
  if (client == null) return [];

  const activeClub = await getActiveClubReference();
  let lastError: unknown;
  for (const clubId of buildClubCandidates(activeClub.numericId)) {
    const { data, error } = await invokeUntypedRpc(
      client,
      "fet_get_leaderboard",
      {
        p_club_id: clubId,
        p_limit: Math.max(0, limit),
      },
    );
    if (error) {
      lastError = error;
      continue;
    }
    if (!Array.isArray(data) || data.length === 0) return [];

    return (data as Array<Record<string, unknown>>)
      .filter((row) => !strict || isCompletePublicLeaderboardRow(row))
      .map((row, index) => mapLeaderboardRow(row, index))
      .slice(0, Math.max(0, limit));
  }
  if (lastError) throw lastError;
  return [];
}

export const getFanEngagementLeaderboardStrict = cache(
  async function getFanEngagementLeaderboardStrict(
    limit = 10,
  ): Promise<FanEngagementLeaderboardEntry[]> {
    return loadFanEngagementLeaderboard(limit, true);
  },
);
