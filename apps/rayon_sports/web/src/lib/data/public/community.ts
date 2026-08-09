/**
 * Public membership, fan clubs, contributions, standings, squad.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type {
  ContributionGroup,
  FanClubItem,
  MembershipPackage,
  MembershipTierSlug,
  SquadPlayer,
  StandingRow,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { sanitizeMediaUrl } from "./helpers";

// ─── Mappers ─────────────────────────────────────────────

function normalizeMembershipTier(value: string): MembershipTierSlug {
  switch (value.trim().toLowerCase()) {
    case "ingenzi-imanzi":
    case "ingenzi_imanzi":
    case "ingenzi":
    case "imanzi":
      return "ingenzi-imanzi";
    case "inyamibwa":
      return "inyamibwa";
    case "imena":
      return "imena";
    case "bronze":
      return "bronze";
    case "silver":
      return "silver";
    case "gold":
      return "gold";
    default:
      return "imena";
  }
}

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
  const annualPrice = safeNumber(row.annual_price, safeNumber(row.price, 0));

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    tier: normalizeMembershipTier(tierValue),
    title,
    description,
    sortOrder: safeNumber(row.sort_order, 0),
    annualPrice,
    perks:
      benefits.length > 0
        ? benefits
        : description.split(/[.;]/).filter((item) => item.trim().length > 2)
              .length > 0
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
    description: safeString(row.description, "An official supporter chapter."),
    memberCount: safeNumber(row.member_count, 0),
    eventCount: safeNumber(row.event_count, 0),
    rating: safeNumber(row.rating, 0),
    bannerImageUrl: sanitizeMediaUrl(
      row.banner_image_url,
      "/brand-surface.svg",
    ),
  };
}

function mapContributionGroupRow(
  row: Record<string, unknown>,
): ContributionGroup {
  const normalizedType = safeString(row.group_type).toLowerCase();
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Public initiative"),
    description: safeString(
      row.description,
      "Supporters backing a public club initiative.",
    ),
    groupType: normalizedType === "project" ? "project" : "community",
    targetAmount: safeNumber(row.target_amount, 0),
    currentTotal: safeNumber(row.current_total, 0),
    currency: safeString(row.currency),
    memberCount: safeNumber(row.member_count, 0),
    isActive: row.is_closed !== true && row.is_active !== false,
  };
}

function mapStandingRow(
  row: Record<string, unknown>,
  index: number,
  activeClubSlug: string,
): StandingRow {
  const club = safeString(
    row.club_name,
    safeString(row.club, safeString(row.team_name, `Club ${index + 1}`)),
  );
  const form = Array.isArray(row.form)
    ? row.form
        .map((entry) => safeString(entry))
        .filter(Boolean)
        .slice(0, 5)
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
      safeString(row.club_slug) === activeClubSlug ||
      club.toLowerCase().includes(activeClubSlug.replaceAll("_", " ")),
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
      "First-team squad member.",
    imageUrl: sanitizeMediaUrl(row.image_url, "/brand-surface.svg"),
  };
}

// ─── Fetchers ────────────────────────────────────────────

async function loadMembershipPackages(): Promise<MembershipPackage[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  const { data, error } = await client
    .from("membership_tiers")
    .select(
      "id,partner_id,club_id,tier,category_slug,title,name,subtitle," +
        "description,benefits,annual_price,price,is_active,sort_order," +
        "benefit_scope,store_billing_required",
    )
    .eq("club_id", activeClub.numericId)
    .eq("is_active", true)
    .eq("benefit_scope", "physical_membership")
    .eq("store_billing_required", false)
    .order("sort_order", { ascending: true })
    .limit(6);

  if (error) throw error;
  if (!data || data.length === 0) return [];
  return data.map((row) => mapMembershipRow(row));
}

export const getMembershipPackagesStrict = cache(
  async function getMembershipPackagesStrict() {
    return loadMembershipPackages();
  },
);

export const getMembershipPackages = cache(
  async function getMembershipPackages() {
    try {
      return await loadMembershipPackages();
    } catch {
      return [];
    }
  },
);

async function loadFanClubs(): Promise<FanClubItem[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  const { data, error } = await client
    .from("fan_clubs")
    .select(
      "id,partner_id,club_id,name,region,description,member_count," +
        "event_count,rating,banner_emoji,is_active,created_at,updated_at",
    )
    .eq("club_id", activeClub.numericId)
    .eq("is_active", true)
    .order("member_count", { ascending: false })
    .limit(12);

  if (error) throw error;
  if (!data || data.length === 0) {
    return [];
  }

  return data.map((row) => mapFanClubRow(row));
}

export const getFanClubsStrict = cache(async function getFanClubsStrict() {
  return loadFanClubs();
});

export const getFanClubs = cache(async function getFanClubs() {
  try {
    return await loadFanClubs();
  } catch {
    return [];
  }
});

async function loadContributionGroups(): Promise<ContributionGroup[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  const { data, error } = await client
    .from("contribution_groups")
    .select(
      "id,name,description,group_type,target_amount,current_total,currency,member_count,is_closed,is_active,club_id,created_at,updated_at",
    )
    .eq("club_id", activeClub.numericId)
    .eq("is_active", true)
    .order("created_at", { ascending: false })
    .limit(8);

  if (error) throw error;
  if (!data || data.length === 0) {
    return [];
  }

  return data.map((row) => mapContributionGroupRow(row));
}

export const getContributionGroupsStrict = cache(
  async function getContributionGroupsStrict() {
    return loadContributionGroups();
  },
);

export const getContributionGroups = cache(
  async function getContributionGroups() {
    try {
      return await loadContributionGroups();
    } catch {
      return [];
    }
  },
);

async function loadStandings(): Promise<StandingRow[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) {
    return [];
  }

  const { data, error } = await client
    .from("standings")
    .select(
      "position,club_name,club_slug,played,goal_difference,points,form",
    )
    .eq("club_id", activeClub.numericId)
    .order("position", { ascending: true })
    .limit(24);

  if (error) throw error;
  if (!data || data.length === 0) return [];
  return data.map((row, index) => mapStandingRow(row, index, activeClub.slug));
}

export const getStandingsStrict = cache(async function getStandingsStrict() {
  return loadStandings();
});

export const getStandings = cache(async function getStandings(): Promise<
  StandingRow[]
> {
  try {
    return await loadStandings();
  } catch {
    return [];
  }
});

async function loadSquad(): Promise<SquadPlayer[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) {
    return [];
  }

  const { data, error } = await client
    .from("squad_players")
    .select("id,name,position,shirt_number,nationality,bio")
    .eq("club_id", activeClub.numericId)
    .order("shirt_number", { ascending: true })
    .limit(40);

  if (error) throw error;
  if (!data || data.length === 0) return [];
  return data.map((row) => mapSquadRow(row));
}

export const getSquadStrict = cache(async function getSquadStrict() {
  return loadSquad();
});

export const getSquad = cache(async function getSquad(): Promise<
  SquadPlayer[]
> {
  try {
    return await loadSquad();
  } catch {
    return [];
  }
});
