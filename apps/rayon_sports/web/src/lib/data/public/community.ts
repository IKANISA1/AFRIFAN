/**
 * Public membership, fan clubs, contributions, standings, squad.
 */
import { cache } from "react";
import { rayonClub } from "@/lib/config";
import {
  fallbackContributionGroups,
  fallbackFanClubs,
  fallbackMembershipPackages,
  fallbackSquad,
  fallbackStandings,
} from "@/lib/content";
import { getAdminSupabase } from "@/lib/supabase/admin";
import type {
  ContributionGroup,
  FanClubItem,
  MembershipPackage,
  SquadPlayer,
  StandingRow,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import {
  resolveAccessibleTable,
  sanitizeMediaUrl,
  squadTableCandidates,
  standingsTableCandidates,
} from "./helpers";

// ─── Mappers ─────────────────────────────────────────────

function mapMembershipRow(row: Record<string, unknown>): MembershipPackage {
  const title = safeString(row.title, "Membership tier");
  const description = safeString(
    row.description,
    "Priority access and supporter benefits across club channels.",
  );
  const tierValue = safeString(row.tier).toLowerCase();
  const benefits = Array.isArray(row.benefits)
    ? row.benefits
        .map((item) => safeString(item))
        .filter(Boolean)
        .slice(0, 4)
    : [];
  const fallbackTier =
    fallbackMembershipPackages.find((entry) => entry.tier === tierValue) ??
    fallbackMembershipPackages.find(
      (entry) => entry.title.toLowerCase() === title.toLowerCase(),
    ) ??
    null;
  const annualPrice = safeNumber(
    row.annual_price,
    safeNumber(row.price, fallbackTier?.annualPrice ?? 0),
  );

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    tier:
      tierValue == "gold"
        ? "gold"
        : tierValue == "platinum"
          ? "platinum"
          : tierValue == "bronze"
            ? "bronze"
            : "fan",
    title,
    description,
    sortOrder: safeNumber(row.sort_order, 0),
    annualPrice,
    perks:
      benefits.length > 0
        ? benefits
        : description.split(/[.;]/).filter((item) => item.trim().length > 2).length > 0
        ? description
            .split(/[.;]/)
            .map((item) => item.trim())
            .filter((item) => item.length > 2)
            .slice(0, 4)
        : ["Priority access", "Supporter identity", "Club communications"],
  };
}

function mapFanClubRow(row: Record<string, unknown>): FanClubItem {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Supporter chapter"),
    region: safeString(row.region, "Official"),
    description: safeString(
      row.description,
      "A Rayon Sports supporter chapter.",
    ),
    memberCount: safeNumber(row.member_count, 0),
    eventCount: safeNumber(row.event_count, 0),
    rating: safeNumber(row.rating, 0),
    bannerImageUrl: sanitizeMediaUrl(row.banner_image_url, "/media/stadium-hero.jpg"),
  };
}

function mapContributionGroupRow(row: Record<string, unknown>): ContributionGroup {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Support circle"),
    description: safeString(
      row.description,
      "Supporters pooling funds around club activity.",
    ),
    privacy: safeString(row.privacy) == "public" ? "public" : "private",
    groupType:
      safeString(row.group_type) == "project" ||
      safeString(row.group_type) == "savings" ||
      safeString(row.group_type) == "emergency"
        ? (safeString(row.group_type) as ContributionGroup["groupType"])
        : "general",
    targetAmount: safeNumber(row.target_amount, 0),
    currentTotal: safeNumber(row.current_total, 0),
    currency: safeString(row.currency, "RWF"),
    memberCount: safeNumber(row.member_count, 0),
    inviteCode: safeString(row.invite_code) || null,
    isActive: row.is_closed !== true && row.is_active !== false,
  };
}

function mapStandingRow(row: Record<string, unknown>, index: number): StandingRow {
  const club = safeString(
    row.club_name,
    safeString(row.club, safeString(row.team_name, `Club ${index + 1}`)),
  );
  const form = Array.isArray(row.form)
    ? row.form.map((entry) => safeString(entry)).filter(Boolean).slice(0, 5)
    : [];

  return {
    position: safeNumber(row.position, index + 1),
    club,
    played: safeNumber(row.played, safeNumber(row.matches_played, 0)),
    goalDifference: safeNumber(
      row.goal_difference,
      safeNumber(row.gd, safeNumber(row.goal_diff, 0)),
    ),
    points: safeNumber(row.points, safeNumber(row.pts, 0)),
    form,
    highlight:
      safeString(row.club_slug) === rayonClub.slug ||
      club.toLowerCase().includes("rayon"),
  };
}

function mapSquadRow(row: Record<string, unknown>): SquadPlayer {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Squad player"),
    role:
      safeString(row.role) ||
      safeString(row.position) ||
      safeString(row.primary_position, "Player"),
    number: safeNumber(row.number, safeNumber(row.shirt_number, 0)),
    nationality: safeString(row.nationality, "Rwanda"),
    bio:
      safeString(row.bio) ||
      safeString(row.description) ||
      safeString(row.player_summary) ||
      "Rayon Sports first-team squad member.",
  };
}

// ─── Fetchers ────────────────────────────────────────────

export const getMembershipPackages = cache(async function getMembershipPackages() {
  const client = getAdminSupabase();
  if (client == null) return fallbackMembershipPackages;

  try {
    const scoped = await client
      .from("membership_packages")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(6);

    if (scoped.data && scoped.data.length > 0) {
      return scoped.data.map((row) => mapMembershipRow(row));
    }

    const fallbackQuery = await client
      .from("membership_packages")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(6);

    if (!fallbackQuery.data || fallbackQuery.data.length == 0) {
      return fallbackMembershipPackages;
    }

    return fallbackQuery.data.map((row) => mapMembershipRow(row));
  } catch {
    return fallbackMembershipPackages;
  }
});

export const getFanClubs = cache(async function getFanClubs() {
  const client = getAdminSupabase();
  if (client == null) return fallbackFanClubs;

  try {
    const scoped = await client
      .from("fan_clubs")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("member_count", { ascending: false })
      .limit(12);

    if (scoped.data && scoped.data.length > 0) {
      return scoped.data.map((row) => mapFanClubRow(row));
    }

    const fallbackQuery = await client
      .from("fan_clubs")
      .select("*")
      .order("member_count", { ascending: false })
      .limit(12);

    if (!fallbackQuery.data || fallbackQuery.data.length == 0) {
      return fallbackFanClubs;
    }

    return fallbackQuery.data.map((row) => mapFanClubRow(row));
  } catch {
    return fallbackFanClubs;
  }
});

export const getContributionGroups = cache(async function getContributionGroups() {
  const client = getAdminSupabase();
  if (client == null) return fallbackContributionGroups;

  try {
    const scoped = await client
      .from("contribution_groups")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .eq("is_active", true)
      .order("created_at", { ascending: false })
      .limit(8);

    if (scoped.data && scoped.data.length > 0) {
      return scoped.data.map((row) => mapContributionGroupRow(row));
    }

    const fallbackQuery = await client
      .from("contribution_groups")
      .select("*")
      .eq("is_closed", false)
      .order("created_at", { ascending: false })
      .limit(8);

    if (!fallbackQuery.data || fallbackQuery.data.length == 0) {
      return fallbackContributionGroups;
    }

    return fallbackQuery.data.map((row) => mapContributionGroupRow(row));
  } catch {
    return fallbackContributionGroups;
  }
});

export const getStandings = cache(async function getStandings(): Promise<StandingRow[]> {
  const client = getAdminSupabase();
  if (client == null) {
    return fallbackStandings;
  }

  try {
    const table = await resolveAccessibleTable(client, standingsTableCandidates);
    const scopedQuery = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("position", { ascending: true })
      .limit(20);

    if (scopedQuery.data && scopedQuery.data.length >= 6) {
      return scopedQuery.data.map((row, index) => mapStandingRow(row, index));
    }

    const fallbackQuery = await client
      .from(table)
      .select("*")
      .order("position", { ascending: true })
      .limit(20);

    if (fallbackQuery.data && fallbackQuery.data.length > 0) {
      return fallbackQuery.data.map((row, index) => mapStandingRow(row, index));
    }
  } catch {}

  return fallbackStandings;
});

export const getSquad = cache(async function getSquad(): Promise<SquadPlayer[]> {
  const client = getAdminSupabase();
  if (client == null) {
    return fallbackSquad;
  }

  try {
    const table = await resolveAccessibleTable(client, squadTableCandidates);
    const scopedQuery = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("shirt_number", { ascending: true })
      .limit(30);

    if (scopedQuery.data && scopedQuery.data.length > 0) {
      return scopedQuery.data.map((row) => mapSquadRow(row));
    }

    const fallbackQuery = await client
      .from(table)
      .select("*")
      .order("shirt_number", { ascending: true })
      .limit(30);

    if (fallbackQuery.data && fallbackQuery.data.length > 0) {
      return fallbackQuery.data.map((row) => mapSquadRow(row));
    }
  } catch {}

  return fallbackSquad;
});
