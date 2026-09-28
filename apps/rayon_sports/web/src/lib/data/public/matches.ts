/**
 * Public matches data.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type { MatchItem } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { sanitizeMediaUrl } from "./helpers";
import { loadGikundiroPublicSource, mapGikundiroFixtures } from "./gikundiro-source";

function mapMatchRow(
  row: Record<string, unknown>,
  activeClubShortName: string,
): MatchItem {
  const liveEvents = Array.isArray(row.live_events)
    ? row.live_events
        .map((event, index) => {
          if (typeof event != "object" || event == null) {
            return {
              minute: `${index + 1}'`,
              event: "Match event",
              side: "home" as const,
            };
          }
          return {
            minute: safeString(
              (event as Record<string, unknown>).minute,
              `${index + 1}'`,
            ),
            event: safeString(
              (event as Record<string, unknown>).event,
              "Live event",
            ),
            side:
              safeString((event as Record<string, unknown>).side) == "away"
                ? ("away" as const)
                : ("home" as const),
          };
        })
        .slice(0, 6)
    : [];

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    homeTeam: safeString(row.home_team, activeClubShortName),
    awayTeam: safeString(row.away_team, "Opponent"),
    competition: safeString(row.competition, "League"),
    venue: safeString(row.venue, "Venue TBC"),
    matchDate: safeString(row.match_date, new Date().toISOString()),
    kickoffTime: safeString(row.kickoff_time) || null,
    isOnSale: Boolean(row.is_on_sale),
    generalPrice: safeNumber(row.ticket_general_price, 0),
    vipPrice: safeNumber(row.ticket_vip_price, 0),
    imageUrl: sanitizeMediaUrl(row.image_url, "/brand-surface.svg"),
    matchStatus: safeString(row.match_status, "scheduled"),
    homeScore: safeNumber(row.home_score, 0),
    awayScore: safeNumber(row.away_score, 0),
    liveMinute: row.live_minute == null ? null : safeNumber(row.live_minute, 0),
    matchSummary: safeString(row.match_summary) || null,
    liveEvents,
    liveStats:
      typeof row.live_stats == "object" && row.live_stats != null
        ? (row.live_stats as Record<string, number | string>)
        : {},
    isFeatured: Boolean(row.is_featured),
  };
}

async function loadMatches() {
  const activeClub = await getActiveClubReference();
  if (activeClub.numericId === 24) {
    const source = await loadGikundiroPublicSource();
    if (source) return mapGikundiroFixtures(source.fixtures);
  }
  const client = getReadOnlySupabase();
  if (client == null) return [];

  const { data, error } = await client
    .from("unified_matches")
    .select("*")
    .eq("club_id", activeClub.numericId)
    .order("match_date", { ascending: true })
    .limit(20);

  if (error) {
    throw error;
  }
  if (!data || data.length == 0) return [];
  return data.map((row) => mapMatchRow(row, activeClub.shortName));
}

async function loadMatchById(matchId: string) {
  const activeClub = await getActiveClubReference();
  if (activeClub.numericId === 24 && matchId.startsWith("gikundiro-")) {
    const source = await loadGikundiroPublicSource();
    return mapGikundiroFixtures(source?.fixtures).find((match) => match.id === matchId) ?? null;
  }
  const client = getReadOnlySupabase();
  if (client == null) return null;

  const { data, error } = await client
    .from("unified_matches")
    .select("*")
    .eq("club_id", activeClub.numericId)
    .eq("id", matchId)
    .maybeSingle();

  if (error) {
    throw error;
  }
  if (data == null) return null;
  return mapMatchRow(data, activeClub.shortName);
}

export const getMatchesStrict = cache(async function getMatchesStrict() {
  return loadMatches();
});

export const getMatches = cache(async function getMatches() {
  try {
    return await loadMatches();
  } catch {
    return [];
  }
});

export const getMatchById = cache(async function getMatchById(matchId: string) {
  try {
    return await loadMatchById(matchId);
  } catch {
    return null;
  }
});

export const getMatchByIdStrict = cache(
  async function getMatchByIdStrict(matchId: string) {
    return loadMatchById(matchId);
  },
);
