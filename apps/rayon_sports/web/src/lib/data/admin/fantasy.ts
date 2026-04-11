import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminFantasyCompetition,
  AdminFantasyGameweek,
  AdminFantasyGameweekStatus,
  AdminFantasyOperationsSnapshot,
  AdminFantasyPlayer,
  AdminFantasyPlayerPosition,
  FantasyCompetitionMode,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import { requireAdminClubId, safeString, toIdString } from "./helpers";

type BackendCompetitionStatus = "draft" | "active" | "finished";

const defaultScoringRules = {
  points_sub_60: 1,
  points_60_plus: 2,
  assists_all: 3,
  captain_multiplier: 2,
  triple_captain_multiplier: 3,
  penalty_save: 5,
  penalty_miss: -2,
  yellow_card: -1,
  red_card: -3,
  own_goal: -2,
  goals_conceded_per_2: -1,
  saves_per_3: 1,
  goals: { GK_DEF: 6, MID: 5, FWD: 4 },
  clean_sheet: { GK_DEF: 4, MID: 1 },
  defensive_contributions: {
    DEF_threshold: 10,
    MID_FWD_threshold: 12,
    points: 2,
  },
};

const defaultSquadConfig = {
  budget: 1000,
  squad_size: 15,
  starters: 11,
  max_per_club: 3,
  min_def: 3,
  max_def: 5,
  min_mid: 2,
  max_mid: 5,
  min_fwd: 1,
  max_fwd: 3,
};

function mapMode(value: unknown): FantasyCompetitionMode {
  return safeString(value).toLowerCase() === "tournament"
    ? "tournament"
    : "season_long";
}

function mapBackendStatus(value: unknown): BackendCompetitionStatus {
  switch (safeString(value).toLowerCase()) {
    case "active":
      return "active";
    case "finished":
      return "finished";
    default:
      return "draft";
  }
}

function mapPlayerPosition(value: unknown): AdminFantasyPlayerPosition {
  switch (safeString(value).toUpperCase()) {
    case "GK":
      return "GK";
    case "DEF":
      return "DEF";
    case "MID":
      return "MID";
    default:
      return "FWD";
  }
}

function mapGameweekStatus(value: unknown): AdminFantasyGameweekStatus {
  switch (safeString(value).toLowerCase()) {
    case "live":
      return "live";
    case "scoring":
      return "scoring";
    case "finished":
      return "finished";
    default:
      return "upcoming";
  }
}

function mapFantasyCompetition(
  row: Record<string, unknown>,
  enablement: Record<string, unknown> | null,
  clubId: number | null,
  activeEntries: number,
): AdminFantasyCompetition {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId,
    slug: safeString(row.slug),
    name: safeString(row.name, "Fantasy competition"),
    shortName: safeString(row.short_name, safeString(row.name, "Fantasy")),
    season: safeString(row.season, "2026"),
    description: safeString(row.description),
    mode: mapMode(row.competition_type),
    backendStatus: mapBackendStatus(row.status),
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
    isPlayable: enablement?.is_playable === true,
    activeEntries,
    startAt: safeString(row.start_date, new Date().toISOString()),
    endAt: safeString(row.end_date, new Date().toISOString()),
    entryWindowOpensAt: safeString(enablement?.entry_window_opens_at) || null,
    entryWindowClosesAt: safeString(enablement?.entry_window_closes_at) || null,
  };
}

function mapFantasyPlayer(
  player: Record<string, unknown>,
  price: Record<string, unknown>,
): AdminFantasyPlayer {
  return {
    id: toIdString(price.id ?? player.id, crypto.randomUUID()),
    competitionId: safeString(price.competition_id),
    externalId: Number(player.external_id ?? 0),
    name: safeString(player.name, "Player"),
    shortName: safeString(player.short_name, safeString(player.name, "Player")),
    position: mapPlayerPosition(player.position),
    teamId: Number(player.team_id ?? 0),
    teamName: safeString(player.team_name, "Club"),
    teamShort: safeString(player.team_short, "CLB"),
    nationality: safeString(player.nationality) || null,
    photoUrl: safeString(player.photo_url) || null,
    teamLogoUrl: safeString(player.team_logo_url) || null,
    price: Number(price.price ?? 0),
    priceChange: Number(price.price_change ?? 0),
    ownershipPercent: Number(price.ownership_percent ?? 0),
    updatedAt: safeString(price.updated_at, new Date().toISOString()),
  };
}

function mapFantasyGameweek(row: Record<string, unknown>): AdminFantasyGameweek {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    competitionId: safeString(row.competition_id),
    number: Number(row.number ?? 1),
    name: safeString(row.name, "Gameweek"),
    status: mapGameweekStatus(row.status),
    deadlineAt: safeString(row.deadline_at, new Date().toISOString()),
    startAt: safeString(row.start_at, new Date().toISOString()),
    endAt: safeString(row.end_at, new Date().toISOString()),
    isDoubleGameweek: row.is_double_gw === true,
    averageScore:
      typeof row.average_score === "number" ? row.average_score : null,
    highestScore:
      typeof row.highest_score === "number" ? row.highest_score : null,
  };
}

export async function getAdminFantasyCompetitions(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminFantasyCompetition[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFantasyCompetition[]>("fantasy");
  }

  const clubId = requireAdminClubId(access, "load fantasy competitions");
  const [competitionResponse, enablementResponse, entriesResponse] =
    await Promise.all([
      client
        .schema("fantasy")
        .from("competitions")
        .select("*")
        .order("start_date", { ascending: true }),
      client
        .from("fantasy_competition_enablements")
        .select("*")
        .eq("club_id", clubId),
      client
        .schema("fantasy")
        .from("fantasy_entries")
        .select("competition_id"),
    ]);

  if (competitionResponse.error) {
    throw new Error(competitionResponse.error.message);
  }
  if (enablementResponse.error) {
    throw new Error(enablementResponse.error.message);
  }
  if (entriesResponse.error) {
    throw new Error(entriesResponse.error.message);
  }

  const enablementsByCompetitionId = new Map<string, Record<string, unknown>>();
  for (const row of enablementResponse.data ?? []) {
    const competitionId = safeString((row as Record<string, unknown>).competition_id);
    if (competitionId) {
      enablementsByCompetitionId.set(competitionId, row as Record<string, unknown>);
    }
  }

  const entryCounts = new Map<string, number>();
  for (const row of entriesResponse.data ?? []) {
    const competitionId = safeString((row as Record<string, unknown>).competition_id);
    if (!competitionId) {
      continue;
    }
    entryCounts.set(competitionId, (entryCounts.get(competitionId) ?? 0) + 1);
  }

  return (competitionResponse.data ?? []).map((row) =>
    mapFantasyCompetition(
      row as Record<string, unknown>,
      enablementsByCompetitionId.get(
        safeString((row as Record<string, unknown>).id),
      ) ?? null,
      clubId,
      entryCounts.get(safeString((row as Record<string, unknown>).id)) ?? 0,
    ),
  );
}

export async function saveAdminFantasyCompetition(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    slug: string;
    name: string;
    shortName: string;
    season: string;
    description: string;
    mode: FantasyCompetitionMode;
    backendStatus: BackendCompetitionStatus;
    primaryColor: string;
    logoUrl?: string | null;
    countryCode?: string | null;
    provider?: string | null;
    promoTitle?: string | null;
    promoBody?: string | null;
    badgeLabel?: string | null;
    ctaLabel?: string | null;
    heroImageUrl?: string | null;
    sortOrder?: number;
    isVisible?: boolean;
    isFeatured?: boolean;
    isPlayable?: boolean;
    startAt: string;
    endAt: string;
    entryWindowOpensAt?: string | null;
    entryWindowClosesAt?: string | null;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("fantasy", {
      method: "POST",
      body: input,
    });
  }

  const clubId = requireAdminClubId(access, "save fantasy competitions");
  const competitionPayload = {
    slug: safeString(input.slug).toLowerCase(),
    name: safeString(input.name),
    short_name: safeString(input.shortName || input.name),
    competition_type: input.mode,
    season: safeString(input.season),
    description: safeString(input.description),
    logo_url: safeString(input.logoUrl) || null,
    primary_color: safeString(input.primaryColor, "#1A7A4E"),
    country_code: safeString(input.countryCode) || null,
    provider: safeString(input.provider) || null,
    status: input.backendStatus,
    start_date: input.startAt,
    end_date: input.endAt,
  };

  let competitionId = safeString(input.id) || null;
  if (competitionId) {
    const { error } = await client
      .schema("fantasy")
      .from("competitions")
      .update(competitionPayload)
      .eq("id", competitionId);
    if (error) {
      throw new Error(error.message);
    }
  } else {
    const { data, error } = await client
      .schema("fantasy")
      .from("competitions")
      .insert({
        ...competitionPayload,
        scoring_rules: defaultScoringRules,
        squad_config: defaultSquadConfig,
        chip_config: {
          wildcard: true,
          triple_captain: true,
          bench_boost: true,
        },
        transfer_config: {
          free_transfers: 1,
          max_transfers_per_round: input.mode === "tournament" ? 2 : 20,
          max_banked_transfers: 5,
        },
      })
      .select("id")
      .single();
    if (error) {
      throw new Error(error.message);
    }
    competitionId = toIdString(data?.id, crypto.randomUUID());
  }

  const { error: enablementError } = await client
    .from("fantasy_competition_enablements")
    .upsert(
      {
        competition_id: competitionId,
        club_id: clubId,
        promo_title: safeString(input.promoTitle) || null,
        promo_body: safeString(input.promoBody) || null,
        badge_label: safeString(input.badgeLabel) || null,
        cta_label: safeString(input.ctaLabel) || null,
        hero_image_url: safeString(input.heroImageUrl) || null,
        sort_order: Number(input.sortOrder ?? 0),
        is_visible: input.isVisible !== false,
        is_featured: input.isFeatured === true,
        is_playable: input.isPlayable === true,
        entry_window_opens_at: safeString(input.entryWindowOpensAt) || null,
        entry_window_closes_at: safeString(input.entryWindowClosesAt) || null,
      },
      { onConflict: "competition_id,club_id" },
    );

  if (enablementError) {
    throw new Error(enablementError.message);
  }

  return competitionId;
}

export async function deleteAdminFantasyCompetition(
  client: SupabaseClient,
  access: AdminAccess,
  competitionId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("fantasy", {
      method: "DELETE",
      query: { id: competitionId },
    });
    return;
  }

  const clubId = requireAdminClubId(access, "delete fantasy competitions");

  const { error: enablementDeleteError } = await client
    .from("fantasy_competition_enablements")
    .delete()
    .eq("competition_id", competitionId)
    .eq("club_id", clubId);
  if (enablementDeleteError) {
    throw new Error(enablementDeleteError.message);
  }

  const [
    { count: remainingEnablements, error: remainingEnablementsError },
    { count: remainingEntries, error: remainingEntriesError },
  ] = await Promise.all([
    client
      .from("fantasy_competition_enablements")
      .select("id", { count: "exact", head: true })
      .eq("competition_id", competitionId),
    client
      .schema("fantasy")
      .from("fantasy_entries")
      .select("id", { count: "exact", head: true })
      .eq("competition_id", competitionId),
  ]);

  if (remainingEnablementsError) {
    throw new Error(remainingEnablementsError.message);
  }
  if (remainingEntriesError) {
    throw new Error(remainingEntriesError.message);
  }

  if ((remainingEnablements ?? 0) === 0 && (remainingEntries ?? 0) === 0) {
    const { error } = await client
      .schema("fantasy")
      .from("competitions")
      .delete()
      .eq("id", competitionId);
    if (error) {
      throw new Error(error.message);
    }
  }
}

export async function getAdminFantasyOperations(
  client: SupabaseClient,
  access: AdminAccess,
  competitionId: string,
): Promise<AdminFantasyOperationsSnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFantasyOperationsSnapshot>("fantasy-operations", {
      query: { competition_id: competitionId },
    });
  }

  requireAdminClubId(access, "load fantasy operations");
  const trimmedCompetitionId = safeString(competitionId);
  if (!trimmedCompetitionId) {
    return {
      competitionId: "",
      players: [],
      gameweeks: [],
    };
  }

  const [{ data: priceRows, error: priceError }, { data: gameweekRows, error: gameweekError }] =
    await Promise.all([
      client
        .schema("fantasy")
        .from("player_competition_prices")
        .select("*")
        .eq("competition_id", trimmedCompetitionId)
        .order("price", { ascending: false }),
      client
        .schema("fantasy")
        .from("gameweeks")
        .select("*")
        .eq("competition_id", trimmedCompetitionId)
        .order("number", { ascending: true }),
    ]);

  if (priceError) {
    throw new Error(priceError.message);
  }
  if (gameweekError) {
    throw new Error(gameweekError.message);
  }

  const playerIds = (priceRows ?? [])
    .map((row) => Number((row as Record<string, unknown>).player_id ?? 0))
    .filter((value: number) => Number.isFinite(value) && value > 0);

  const playersByExternalId = new Map<number, Record<string, unknown>>();
  if (playerIds.length > 0) {
    const { data: playerRows, error: playerError } = await client
      .schema("fantasy")
      .from("players")
      .select("*")
      .in("external_id", playerIds);
    if (playerError) {
      throw new Error(playerError.message);
    }
    for (const row of playerRows ?? []) {
      const record = row as Record<string, unknown>;
      playersByExternalId.set(Number(record.external_id ?? 0), record);
    }
  }

  return {
    competitionId: trimmedCompetitionId,
    players: (priceRows ?? [])
      .map((row) => row as Record<string, unknown>)
      .map((priceRow) => {
        const player =
          playersByExternalId.get(Number(priceRow.player_id ?? 0)) ?? {};
        return mapFantasyPlayer(player, priceRow);
      })
      .sort((left, right) => {
        const positionCompare = left.position.localeCompare(right.position);
        if (positionCompare != 0) {
          return positionCompare;
        }
        if (left.price != right.price) {
          return right.price - left.price;
        }
        return left.name.localeCompare(right.name);
      }),
    gameweeks: (gameweekRows ?? [])
      .map((row) => mapFantasyGameweek(row as Record<string, unknown>)),
  };
}

export async function saveAdminFantasyPlayer(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    competitionId: string;
    externalId: number;
    name: string;
    shortName: string;
    position: AdminFantasyPlayerPosition;
    teamId: number;
    teamName: string;
    teamShort: string;
    nationality?: string | null;
    photoUrl?: string | null;
    teamLogoUrl?: string | null;
    price: number;
    priceChange?: number;
    ownershipPercent?: number;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("fantasy-players", {
      method: "POST",
      body: input,
    });
  }

  requireAdminClubId(access, "save fantasy players");

  const externalId = Number(input.externalId);
  if (!Number.isFinite(externalId) || externalId <= 0) {
    throw new Error("A valid external player id is required.");
  }

  const competitionId = safeString(input.competitionId);
  if (!competitionId) {
    throw new Error("Competition id is required.");
  }

  const { error: playerError } = await client
    .schema("fantasy")
    .from("players")
    .upsert(
      {
        external_id: externalId,
        name: safeString(input.name, "Player"),
        short_name: safeString(input.shortName, input.name),
        photo_url: safeString(input.photoUrl) || null,
        position: input.position,
        team_id: Number(input.teamId),
        team_name: safeString(input.teamName, "Club"),
        team_short: safeString(input.teamShort, "CLB"),
        team_logo_url: safeString(input.teamLogoUrl) || null,
        nationality: safeString(input.nationality) || null,
        last_synced_at: new Date().toISOString(),
      },
      { onConflict: "external_id" },
    );

  if (playerError) {
    throw new Error(playerError.message);
  }

  const { error: priceError } = await client
    .schema("fantasy")
    .from("player_competition_prices")
    .upsert(
      {
        player_id: externalId,
        competition_id: competitionId,
        price: Number(input.price),
        price_change: Number(input.priceChange ?? 0),
        ownership_percent: Number(input.ownershipPercent ?? 0),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "player_id,competition_id" },
    );

  if (priceError) {
    throw new Error(priceError.message);
  }

  return String(externalId);
}

export async function deleteAdminFantasyPlayer(
  client: SupabaseClient,
  access: AdminAccess,
  competitionId: string,
  externalId: number,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("fantasy-players", {
      method: "DELETE",
      query: {
        id: String(externalId),
        competition_id: competitionId,
      },
    });
    return;
  }

  requireAdminClubId(access, "delete fantasy players");

  const { error } = await client
    .schema("fantasy")
    .from("player_competition_prices")
    .delete()
    .eq("competition_id", competitionId)
    .eq("player_id", externalId);

  if (error) {
    throw new Error(error.message);
  }
}

export async function saveAdminFantasyGameweek(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    competitionId: string;
    number: number;
    name: string;
    status: AdminFantasyGameweekStatus;
    deadlineAt: string;
    startAt: string;
    endAt: string;
    isDoubleGameweek?: boolean;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("fantasy-gameweeks", {
      method: "POST",
      body: input,
    });
  }

  requireAdminClubId(access, "save fantasy gameweeks");
  const payload = {
    competition_id: safeString(input.competitionId),
    number: Number(input.number),
    name: safeString(input.name, "Gameweek"),
    status: input.status,
    deadline_at: input.deadlineAt,
    start_at: input.startAt,
    end_at: input.endAt,
    is_double_gw: input.isDoubleGameweek === true,
  };

  if (safeString(input.id)) {
    const { error } = await client
      .schema("fantasy")
      .from("gameweeks")
      .update(payload)
      .eq("id", safeString(input.id));
    if (error) {
      throw new Error(error.message);
    }
    return safeString(input.id);
  }

  const { data, error } = await client
    .schema("fantasy")
    .from("gameweeks")
    .insert(payload)
    .select("id")
    .single();
  if (error) {
    throw new Error(error.message);
  }
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminFantasyGameweek(
  client: SupabaseClient,
  access: AdminAccess,
  gameweekId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("fantasy-gameweeks", {
      method: "DELETE",
      query: { id: gameweekId },
    });
    return;
  }

  requireAdminClubId(access, "delete fantasy gameweeks");
  const { error } = await client
    .schema("fantasy")
    .from("gameweeks")
    .delete()
    .eq("id", gameweekId);

  if (error) {
    throw new Error(error.message);
  }
}
