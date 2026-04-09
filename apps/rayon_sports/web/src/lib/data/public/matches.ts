/**
 * Public matches data.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { fallbackMatches } from "@/lib/content";
import { getAdminSupabase } from "@/lib/supabase/admin";
import type { MatchItem } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { sanitizeMediaUrl } from "./helpers";

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
    venue: safeString(row.venue, "Club Stadium"),
    matchDate: safeString(row.match_date, new Date().toISOString()),
    kickoffTime: safeString(row.kickoff_time) || null,
    isOnSale: Boolean(row.is_on_sale),
    generalPrice: safeNumber(row.ticket_general_price, 0),
    vipPrice: safeNumber(row.ticket_vip_price, 0),
    imageUrl: sanitizeMediaUrl(row.image_url, "/media/stadium-hero.jpg"),
    matchStatus: safeString(row.match_status, "scheduled"),
    homeScore: safeNumber(row.home_score, 0),
    awayScore: safeNumber(row.away_score, 0),
    liveMinute:
      row.live_minute == null ? null : safeNumber(row.live_minute, 0),
    matchSummary: safeString(row.match_summary) || null,
    liveEvents,
    liveStats:
      typeof row.live_stats == "object" && row.live_stats != null
        ? (row.live_stats as Record<string, number | string>)
        : {},
    isFeatured: Boolean(row.is_featured),
  };
}

export const getMatches = cache(async function getMatches() {
  const client = getAdminSupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return fallbackMatches;

  try {
    const { data } = await client
      .from("matches")
      .select("*")
      .eq("club_id", activeClub.numericId)
      .order("match_date", { ascending: true })
      .limit(12);

    if (!data || data.length == 0) return fallbackMatches;
    return data.map((row) => mapMatchRow(row, activeClub.shortName));
  } catch {
    return fallbackMatches;
  }
});

export const getMatchById = cache(async function getMatchById(matchId: string) {
  const matches = await getMatches();
  return matches.find((match) => match.id === matchId) ?? null;
});
