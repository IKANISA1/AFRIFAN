import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type {
  FantasyBracketMatch,
  FantasyCompetition,
  FantasyCompetitionMode,
  FantasyCompetitionStatus,
  FantasyLeaderboardEntry,
} from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { getConfigValue } from "./cms";

function coerceBoolean(value: unknown, fallback = false) {
  if (typeof value === "boolean") {
    return value;
  }
  const normalized = safeString(value).toLowerCase();
  if (!normalized) {
    return fallback;
  }
  return normalized === "true" || normalized === "1" || normalized === "yes";
}

function mapMode(value: unknown): FantasyCompetitionMode {
  return safeString(value).toLowerCase() === "tournament"
    ? "tournament"
    : "season_long";
}

function mapStatus(value: unknown): FantasyCompetitionStatus {
  switch (safeString(value).toLowerCase()) {
    case "active":
    case "live":
    case "playable":
      return "playable";
    case "finished":
    case "archived":
      return "archived";
    case "draft":
    case "preview":
      return "preview";
    default:
      return "planned";
  }
}

function mapCompetition(
  row: Record<string, unknown>,
  enablement?: Record<string, unknown>,
): FantasyCompetition {
  const status = mapStatus(row.status);
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    slug: safeString(row.slug),
    name: safeString(row.name, "Fantasy competition"),
    shortName: safeString(row.short_name, safeString(row.name, "Fantasy")),
    season: safeString(row.season, "2026"),
    description: safeString(
      row.description,
      "Official fantasy football with live scoring, captaincy, transfers, and club-level leaderboards.",
    ),
    mode: mapMode(row.competition_mode ?? row.competition_type),
    status,
    primaryColor: safeString(row.primary_color, "#1A7A4E"),
    logoUrl: safeString(row.logo_url) || null,
    countryCode: safeString(row.country_code) || null,
    provider: safeString(row.provider) || null,
    promoTitle: safeString(enablement?.promo_title) || null,
    promoBody: safeString(enablement?.promo_body) || null,
    badgeLabel: safeString(enablement?.badge_label) || null,
    ctaLabel: safeString(enablement?.cta_label) || null,
    heroImageUrl: safeString(enablement?.hero_image_url) || null,
    sortOrder: Number(enablement?.sort_order ?? 0),
    isVisible: enablement == null ? true : enablement.is_visible !== false,
    isFeatured: enablement?.is_featured === true,
    isPlayable: enablement?.is_playable === true || status === "playable",
    startAt: safeString(row.start_at) || null,
    endAt: safeString(row.end_at) || null,
    entryWindowOpensAt: safeString(enablement?.entry_window_opens_at) || null,
    entryWindowClosesAt: safeString(enablement?.entry_window_closes_at) || null,
  };
}

type SupabaseRpcResult = Promise<{ data: unknown; error: unknown }>;

function invokeUntypedRpc(
  client: NonNullable<ReturnType<typeof getReadOnlySupabase>>,
  fn: string,
  args?: Record<string, unknown>,
): SupabaseRpcResult {
  const rpc = client.rpc as unknown as (
    fn: string,
    args?: Record<string, unknown>,
  ) => SupabaseRpcResult;
  return rpc(fn, args);
}

async function isFantasyWebEnabled() {
  const [featureEnabled, webEnabled] = await Promise.all([
    getConfigValue("feature_fantasy_enabled", "true"),
    getConfigValue("feature_fantasy_web_enabled", "true"),
  ]);

  return coerceBoolean(featureEnabled, true) && coerceBoolean(webEnabled, true);
}

export const getFantasyCompetitions = cache(async function getFantasyCompetitions() {
  const enabled = await isFantasyWebEnabled();
  if (!enabled) {
    return [] as FantasyCompetition[];
  }

  const client = getReadOnlySupabase();
  if (client == null) {
    return [] as FantasyCompetition[];
  }

  try {
    const activeClub = await getActiveClubReference();
    const [{ data: competitionRows }, { data: enablementRows }] = await Promise.all([
      client.from("fantasy_competitions").select("*").order("start_at", {
        ascending: true,
      }),
      client
        .from("fantasy_competition_enablements")
        .select("*")
        .eq("club_id", activeClub.numericId)
        .order("sort_order", { ascending: true }),
    ]);

    if (!Array.isArray(competitionRows) || competitionRows.length === 0) {
      return [] as FantasyCompetition[];
    }

    const enablementsByCompetitionId = new Map<string, Record<string, unknown>>();
    for (const row of enablementRows ?? []) {
      const competitionId = safeString(
        (row as Record<string, unknown>).competition_id,
      );
      if (competitionId) {
        enablementsByCompetitionId.set(
          competitionId,
          row as Record<string, unknown>,
        );
      }
    }

    return competitionRows
      .map((row) =>
        mapCompetition(
          row as Record<string, unknown>,
          enablementsByCompetitionId.get(
            safeString((row as Record<string, unknown>).id),
          ),
        ),
      )
      .filter((competition) => competition.isVisible)
      .sort((left, right) => {
        if (left.isFeatured !== right.isFeatured) {
          return left.isFeatured ? -1 : 1;
        }
        if (left.sortOrder !== right.sortOrder) {
          return left.sortOrder - right.sortOrder;
        }
        return left.name.localeCompare(right.name);
      });
  } catch {
    return [] as FantasyCompetition[];
  }
});

export const getFeaturedFantasyCompetition = cache(
  async function getFeaturedFantasyCompetition() {
    const competitions = await getFantasyCompetitions();
    return (
      competitions.find((competition) => competition.isFeatured) ??
      competitions[0] ??
      null
    );
  },
);

export const getFantasyCompetitionBySlug = cache(
  async function getFantasyCompetitionBySlug(slug: string) {
    const competitions = await getFantasyCompetitions();
    return competitions.find((competition) => competition.slug === slug) ?? null;
  },
);

export const getFantasyLeaderboard = cache(
  async function getFantasyLeaderboard(
    competitionSlug: string,
    limit = 20,
  ): Promise<FantasyLeaderboardEntry[]> {
    const enabled = await isFantasyWebEnabled();
    if (!enabled || !competitionSlug.trim()) {
      return [];
    }

    const client = getReadOnlySupabase();
    if (client == null) {
      return [];
    }

    try {
      const { data } = await invokeUntypedRpc(client, "fantasy_get_leaderboard", {
        p_competition_slug: competitionSlug,
        p_limit: limit,
      });

      if (!Array.isArray(data) || data.length === 0) {
        return [];
      }

      return (data as Array<Record<string, unknown>>).map((row, index) => {
        const item = row as Record<string, unknown>;
        return {
          rank: Number(item.overall_rank ?? index + 1),
          teamName: safeString(item.team_name, `Manager ${index + 1}`),
          managerName: safeString(item.manager_name, "Manager"),
          points: Number(item.total_points ?? 0),
          isCurrentUser: item.is_current_user === true,
        } satisfies FantasyLeaderboardEntry;
      });
    } catch {
      return [];
    }
  },
);

export const getFantasyBracket = cache(
  async function getFantasyBracket(
    competitionSlug: string,
  ): Promise<FantasyBracketMatch[]> {
    const enabled = await isFantasyWebEnabled();
    if (!enabled || !competitionSlug.trim()) {
      return [];
    }

    const client = getReadOnlySupabase();
    if (client == null) {
      return [];
    }

    try {
      const competition = await getFantasyCompetitionBySlug(competitionSlug);
      if (competition == null) {
        return [];
      }

      const { data } = await invokeUntypedRpc(
        client,
        "fantasy_get_competition_bracket",
        {
          p_competition_id: competition.id,
        },
      );

      if (!Array.isArray(data) || data.length === 0) {
        return [];
      }

      return (data as Array<Record<string, unknown>>).map((row) => ({
        stage: safeString(row.stage, "Groups"),
        stageOrder: Number(row.stage_order ?? 99),
        label: safeString(row.label, "Fixture"),
        homeTeamName: safeString(row.home_team_name, "TBD"),
        awayTeamName: safeString(row.away_team_name, "TBD"),
        homeGoals:
          typeof row.home_goals === "number" ? row.home_goals : null,
        awayGoals:
          typeof row.away_goals === "number" ? row.away_goals : null,
        statusShort: safeString(row.status_short) || null,
        kickoffAt: safeString(row.kickoff_at) || null,
      }));
    } catch {
      return [];
    }
  },
);
