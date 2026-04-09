/**
 * Admin matches — CRUD with legacy column fallback.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { fallbackClubProfile } from "@/lib/content";
import type { AdminAccess, AdminMatchItem } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { hasMissingColumnError } from "./helpers";

function mapMatch(row: Record<string, unknown>): AdminMatchItem {
  const liveEvents = Array.isArray(row.live_events)
    ? row.live_events.map((event, index) => {
        const value =
          typeof event === "object" && event != null
            ? (event as Record<string, unknown>)
            : {};
        return {
          minute: safeString(value.minute, `${index + 1}'`),
          event: safeString(value.event, "Match event"),
          side: safeString(value.side) === "away" ? ("away" as const) : ("home" as const),
        };
      })
    : [];

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId:
      row.club_id == null ? null : safeNumber(row.club_id, fallbackClubProfile.id),
    partnerId: safeString(row.partner_id) || null,
    homeTeam: safeString(row.home_team, fallbackClubProfile.shortName),
    awayTeam: safeString(row.away_team, "Opponent"),
    competition: safeString(row.competition, "League"),
    venue: safeString(row.venue, "Stadium"),
    matchDate: safeString(row.match_date, new Date().toISOString()),
    kickoffTime: safeString(row.kickoff_time, "15:00:00"),
    isOnSale: row.is_on_sale === true,
    generalPrice: safeNumber(row.ticket_general_price, 0),
    vipPrice: safeNumber(row.ticket_vip_price, 0),
    saleStartsAt: safeString(row.sale_starts_at) || null,
    capacity: safeNumber(row.capacity, 0),
    soldCount: safeNumber(row.sold_count, 0),
    imageUrl: safeString(row.image_url) || null,
    matchStatus: safeString(row.match_status, "scheduled"),
    homeScore: safeNumber(row.home_score, 0),
    awayScore: safeNumber(row.away_score, 0),
    liveMinute: row.live_minute == null ? null : safeNumber(row.live_minute, 0),
    matchSummary: safeString(row.match_summary) || null,
    liveStats:
      typeof row.live_stats === "object" && row.live_stats != null
        ? (row.live_stats as Record<string, number | string>)
        : {},
    liveEvents,
    isFeatured: row.is_featured === true,
  };
}

export async function getAdminMatches(client: SupabaseClient, access: AdminAccess) {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminMatchItem[]>("matches");
  }
  let query = client
    .from("matches")
    .select("*")
    .order("match_date", { ascending: true });

  if (access.clubId != null) {
    query = query.eq("club_id", Number(access.clubId));
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) => mapMatch(row as Record<string, unknown>))
    : [];
}

export async function saveAdminMatch(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    partnerId?: string | null;
    homeTeam: string;
    awayTeam: string;
    competition: string;
    venue: string;
    matchDate: string;
    kickoffTime: string;
    saleStartsAt?: string | null;
    isOnSale: boolean;
    generalPrice: number;
    vipPrice: number;
    capacity: number;
    imageUrl?: string;
    matchStatus?: string;
    homeScore?: number;
    awayScore?: number;
    liveMinute?: number | null;
    matchSummary?: string;
    isFeatured?: boolean;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("matches", {
      method: "POST",
      body: input,
    });
  }
  const clubId =
    access.clubId != null
      ? safeNumber(access.clubId, 0)
      : (() => {
          throw new Error("Club context required to save match.");
        })();
  const kickoffTime = safeString(input.kickoffTime, "15:00");
  const matchDate = new Date(`${input.matchDate}T${kickoffTime}:00`);
  const saleStartsAt = input.saleStartsAt
    ? new Date(input.saleStartsAt).toISOString()
    : new Date().toISOString();
  const payload = {
    club_id: clubId,
    partner_id: safeString(input.partnerId, clubId.toString()),
    home_team: input.homeTeam.trim(),
    away_team: input.awayTeam.trim(),
    competition: input.competition.trim(),
    venue: input.venue.trim(),
    match_date: matchDate.toISOString(),
    kickoff_time: `${kickoffTime}:00`,
    sale_starts_at: saleStartsAt,
    is_on_sale: input.isOnSale,
    ticket_general_price: safeNumber(input.generalPrice, 0),
    ticket_vip_price: safeNumber(input.vipPrice, 0),
    capacity: safeNumber(input.capacity, 0),
    image_url: safeString(input.imageUrl) || null,
    match_status: safeString(input.matchStatus, "scheduled"),
    home_score: safeNumber(input.homeScore, 0),
    away_score: safeNumber(input.awayScore, 0),
    live_minute:
      input.liveMinute == null ? null : safeNumber(input.liveMinute, 0),
    match_summary: safeString(input.matchSummary) || null,
    is_featured: input.isFeatured === true,
  };
  const legacyPayload = {
    club_id: payload.club_id,
    partner_id: payload.partner_id,
    home_team: payload.home_team,
    away_team: payload.away_team,
    competition: payload.competition,
    venue: payload.venue,
    match_date: payload.match_date,
    kickoff_time: payload.kickoff_time,
    sale_starts_at: payload.sale_starts_at,
    is_on_sale: payload.is_on_sale,
    ticket_general_price: payload.ticket_general_price,
    ticket_vip_price: payload.ticket_vip_price,
    capacity: payload.capacity,
    image_url: payload.image_url,
  };

  if (input.id) {
    const primary = await client.from("matches").update(payload).eq("id", input.id);
    if (!primary.error) {
      return input.id;
    }
    if (!hasMissingColumnError(primary.error, "match_status")) {
      throw new Error(primary.error.message);
    }
    const fallback = await client
      .from("matches")
      .update(legacyPayload)
      .eq("id", input.id);
    if (fallback.error) {
      throw new Error(fallback.error.message);
    }
    return input.id;
  }

  const primary = await client
    .from("matches")
    .insert(payload)
    .select("id")
    .single();

  if (!primary.error) {
    return toIdString(primary.data?.id, crypto.randomUUID());
  }

  if (!hasMissingColumnError(primary.error, "match_status")) {
    throw new Error(primary.error.message);
  }

  const fallback = await client
    .from("matches")
    .insert(legacyPayload)
    .select("id")
    .single();

  if (fallback.error) {
    throw new Error(fallback.error.message);
  }

  return toIdString(fallback.data?.id, crypto.randomUUID());
}

export async function deleteAdminMatch(
  client: SupabaseClient,
  access: AdminAccess,
  matchId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("matches", {
      method: "DELETE",
      query: { id: matchId },
    });
    return;
  }
  let query = client.from("matches").delete().eq("id", matchId);
  if (access.clubId != null) {
    query = query.eq("club_id", Number(access.clubId));
  }
  const { error } = await query;
  if (error) {
    throw new Error(error.message);
  }
}
