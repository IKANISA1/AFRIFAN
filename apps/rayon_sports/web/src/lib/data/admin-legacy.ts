import type { SupabaseClient, User } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import { fallbackClubProfile } from "@/lib/content";
import type {
  AdminAccess,
  AdminActivityRecord,
  AdminContributionGroup,
  AdminContributionItem,
  AdminContributionSnapshot,
  AdminDashboardMetrics,
  AdminDashboardSnapshot,
  AdminFanClub,
  AdminMatchItem,
  AdminMembershipPackage,
  AdminNewsArticle,
  AdminNotificationContext,
  AdminNotificationRecord,
  AdminRole,
  AdminSmsSnapshot,
  AdminSmsSyncRun,
  AdminShopProduct,
  AdminStandingRow,
  ClubProfile,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";

const newsTableCandidates = ["news_articles", "rs_news_articles"];
const productTableCandidates = ["shop_products", "rs_shop_products"];
const standingsTableCandidates = [
  "standings",
  "league_standings",
  "club_standings",
  "rs_standings",
];
const squadTableCandidates = [
  "squad_players",
  "players",
  "club_players",
  "rs_squad_players",
];
const membershipTable = "membership_packages";
const fanClubTable = "fan_clubs";
const clubTable = "african_football_clubs";
const contributionTable = "contribution_groups";

export const emptyAdminAccess: AdminAccess = {
  hasAccess: false,
  isAuthenticated: false,
  isSuperAdmin: false,
  role: null,
  clubId: null,
  assignmentCount: 0,
};

type AdminAssignmentRow = Record<string, unknown>;
type AdminUserClaims = {
  app_metadata?: Record<string, unknown>;
  user_metadata?: Record<string, unknown>;
} | null;

function normalizeClubId(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value.toString();
  }
  const text = safeString(value);
  if (!text) {
    return null;
  }
  if (text === rayonClub.slug) {
    return rayonClub.numericId.toString();
  }
  const parsed = Number(text);
  if (Number.isFinite(parsed)) {
    return parsed.toString();
  }
  return text;
}

function matchClubScope(
  assignment: AdminAssignmentRow,
  currentClubId: string | null,
) {
  const role = normalizeAdminRole(assignment.role);
  if (role === "super_admin" || role === "admin") {
    return true;
  }
  if (role !== "club_admin" && role !== "club_moderator") {
    return false;
  }
  const assignmentClubId = normalizeClubId(assignment.club_id);
  return currentClubId == null || assignmentClubId === currentClubId;
}

function userClubId(user: AdminUserClaims) {
  return normalizeClubId(
    user?.app_metadata?.club_id ??
      user?.user_metadata?.club_id ??
      user?.user_metadata?.clubId ??
      user?.app_metadata?.clubId,
  );
}

function metadataRole(user: AdminUserClaims) {
  return normalizeAdminRole(
    user?.user_metadata?.role ?? user?.app_metadata?.role ?? null,
  );
}

function metadataSnippet(value: unknown) {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }
  if (typeof value === "object" && value != null) {
    const pairs = Object.entries(value as Record<string, unknown>)
      .slice(0, 2)
      .map(([key, item]) => `${key}: ${String(item)}`);
    return pairs.join(" • ");
  }
  return "Recorded by admin workflow.";
}

async function resolveAccessibleTable(
  client: SupabaseClient,
  candidates: string[],
) {
  for (const table of candidates) {
    const { error } = await client.from(table).select("id").limit(1);
    if (!error) {
      return table;
    }
  }
  return candidates[0];
}

async function resolveNewsTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, newsTableCandidates);
}

async function resolveProductTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, productTableCandidates);
}

async function resolveStandingsTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, standingsTableCandidates);
}

async function resolveSquadTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, squadTableCandidates);
}

async function resolveExistingColumn(
  client: SupabaseClient,
  table: string,
  candidates: string[],
) {
  for (const column of candidates) {
    const { error } = await client.from(table).select(column).limit(1);
    if (!error) {
      return column;
    }
  }

  return candidates[0] ?? null;
}

function hasMissingColumnError(error: unknown, column: string) {
  if (error == null || typeof error !== "object") {
    return false;
  }

  const message = safeString((error as { message?: unknown }).message).toLowerCase();
  return message.includes(column.toLowerCase()) && message.includes("column");
}

async function safeCount(
  request: PromiseLike<{
    count: number | null;
    error: { message?: string } | null;
  }>,
) {
  const { count, error } = await request;
  if (error) {
    return 0;
  }
  return count ?? 0;
}

async function mutateRecordWithVariants(
  client: SupabaseClient,
  table: string,
  id: string | null | undefined,
  payloadVariants: Array<Record<string, unknown>>,
) {
  let lastError: { message?: string } | null = null;

  for (const payload of payloadVariants) {
    if (id) {
      const response = await client.from(table).update(payload).eq("id", id);
      if (!response.error) {
        return id;
      }
      lastError = response.error;
      continue;
    }

    const response = await client
      .from(table)
      .insert(payload)
      .select("id")
      .single();
    if (!response.error) {
      return toIdString(response.data?.id, crypto.randomUUID());
    }
    lastError = response.error;
  }

  throw new Error(lastError?.message ?? "Could not save record.");
}

function mapDashboardActivity(row: Record<string, unknown>): AdminActivityRecord {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.action, "Admin update").replaceAll("_", " "),
    detail: metadataSnippet(row.metadata) || "Club activity recorded.",
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapNewsArticle(row: Record<string, unknown>): AdminNewsArticle {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId:
      row.club_id == null ? null : safeNumber(row.club_id, rayonClub.numericId),
    title: safeString(row.title, "Untitled article"),
    subtitle: safeString(row.subtitle) || null,
    excerpt:
      safeString(row.excerpt) ||
      safeString(row.summary) ||
      safeString(row.body).slice(0, 140),
    body: safeString(row.body, safeString(row.content)),
    category: safeString(row.category, "News"),
    imageUrl:
      safeString(row.image_url) || safeString(row.cover_image_url) || null,
    isPublished: row.is_published === true,
    isFeatured: row.is_featured === true,
    sortOrder: safeNumber(row.sort_order, 0),
    publishedAt: safeString(row.published_at) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapAdminClubProfile(row: Record<string, unknown>): ClubProfile {
  return {
    id: safeNumber(row.id, fallbackClubProfile.id),
    clubName: safeString(row.club_name, fallbackClubProfile.clubName),
    clubSlug: safeString(row.club_slug, fallbackClubProfile.clubSlug),
    shortName: safeString(row.short_name, fallbackClubProfile.shortName),
    nickname: safeString(
      row.nickname_brand_identity,
      fallbackClubProfile.nickname,
    ),
    countryCode: safeString(
      row.country_iso_code,
      fallbackClubProfile.countryCode,
    ),
    league: safeString(row.league, fallbackClubProfile.league),
    region: safeString(row.region, fallbackClubProfile.region),
    currencyCode: safeString(
      row.currency_code,
      fallbackClubProfile.currencyCode,
    ),
    currencySymbol: safeString(
      row.currency_symbol,
      fallbackClubProfile.currencySymbol,
    ),
    defaultLanguage: safeString(
      row.default_language,
      fallbackClubProfile.defaultLanguage,
    ),
    supportedLanguages: Array.isArray(row.supported_languages)
      ? row.supported_languages
          .map((entry) => safeString(entry))
          .filter(Boolean)
      : fallbackClubProfile.supportedLanguages,
    officialContact: safeString(
      row.official_contact,
      fallbackClubProfile.officialContact,
    ),
    facebookUrl: safeString(row.facebook_url) || null,
    xUrl: safeString(row.x_twitter_url) || null,
    instagramUrl: safeString(row.instagram_url) || null,
    tiktokUrl: safeString(row.tiktok_url) || null,
    officialLogoUrl: safeString(row.official_logo_url) || null,
    primaryColorHex: safeString(
      row.primary_color_hex,
      fallbackClubProfile.primaryColorHex,
    ),
    secondaryColorHex: safeString(
      row.secondary_color_hex,
      fallbackClubProfile.secondaryColorHex,
    ),
    accentColorHex: safeString(
      row.accent_color_hex,
      fallbackClubProfile.accentColorHex,
    ),
    featureFlags:
      typeof row.feature_flags === "object" && row.feature_flags != null
        ? (row.feature_flags as Record<string, boolean>)
        : fallbackClubProfile.featureFlags,
  };
}

function mapAdminMembershipPackage(
  row: Record<string, unknown>,
): AdminMembershipPackage {
  const title = safeString(row.title, "Membership tier");
  const description = safeString(
    row.description,
    "Priority access and supporter benefits.",
  );

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    tier:
      safeString(row.tier).toLowerCase() === "platinum"
        ? "platinum"
        : safeString(row.tier).toLowerCase() === "gold"
          ? "gold"
          : safeString(row.tier).toLowerCase() === "bronze"
            ? "bronze"
            : "fan",
    title,
    description,
    sortOrder: safeNumber(row.sort_order, 0),
    annualPrice: safeNumber(row.annual_price, safeNumber(row.price, 0)),
    perks: Array.isArray(row.benefits)
      ? row.benefits.map((entry) => safeString(entry)).filter(Boolean)
      : Array.isArray(row.perks)
        ? row.perks.map((entry) => safeString(entry)).filter(Boolean)
        : description
            .split(/[.;]/)
            .map((item) => item.trim())
            .filter((item) => item.length > 2)
            .slice(0, 4),
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapAdminShopProduct(row: Record<string, unknown>): AdminShopProduct {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Supporter product"),
    subtitle: safeString(row.subtitle, "Official club merchandise"),
    description:
      safeString(row.description) ||
      safeString(row.subtitle) ||
      "Official product listing.",
    category: safeString(row.category, "Merch"),
    price: safeNumber(row.price, 0),
    imageUrl: safeString(row.image_url) || null,
    sizes: Array.isArray(row.sizes)
      ? row.sizes.map((entry) => safeString(entry)).filter(Boolean)
      : ["One Size"],
    isActive: row.is_active !== false,
    collection: safeString(row.collection) || null,
    sortOrder: safeNumber(row.sort_order, 0),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapAdminFanClub(row: Record<string, unknown>): AdminFanClub {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Supporter chapter"),
    region: safeString(row.region, "Official"),
    description: safeString(
      row.description,
      "A Rayon Sports supporter chapter.",
    ),
    memberCount: safeNumber(row.member_count, 0),
    eventCount: safeNumber(row.event_count, 0),
    rating: safeNumber(row.rating, 0),
    bannerImageUrl: safeString(row.banner_image_url) || null,
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapAdminStandingRow(
  row: Record<string, unknown>,
  index: number,
): AdminStandingRow {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    position: safeNumber(row.position, index + 1),
    club: safeString(
      row.club_name,
      safeString(row.club, safeString(row.team_name, `Club ${index + 1}`)),
    ),
    played: safeNumber(row.played, safeNumber(row.matches_played, 0)),
    goalDifference: safeNumber(
      row.goal_difference,
      safeNumber(row.gd, safeNumber(row.goal_diff, 0)),
    ),
    points: safeNumber(row.points, safeNumber(row.pts, 0)),
    form: Array.isArray(row.form)
      ? row.form.map((entry) => safeString(entry)).filter(Boolean).slice(0, 5)
      : [],
    clubSlug: safeString(row.club_slug) || null,
  };
}

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
      row.club_id == null ? null : safeNumber(row.club_id, rayonClub.numericId),
    partnerId: safeString(row.partner_id) || null,
    homeTeam: safeString(row.home_team, rayonClub.shortName),
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

function mapContributionGroup(row: Record<string, unknown>): AdminContributionGroup {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Support circle"),
    description: safeString(row.description, "Supporter funding circle."),
    privacy: safeString(row.privacy) === "public" ? "public" : "private",
    groupType:
      safeString(row.group_type) === "project" ||
      safeString(row.group_type) === "savings" ||
      safeString(row.group_type) === "emergency"
        ? (safeString(row.group_type) as AdminContributionGroup["groupType"])
        : "general",
    targetAmount: safeNumber(row.target_amount, 0),
    currentTotal: safeNumber(row.current_total, 0),
    currency: safeString(row.currency, rayonClub.currencyCode),
    memberCount: safeNumber(row.member_count, 0),
    inviteCode: safeString(row.invite_code) || null,
    isActive: row.is_closed !== true,
    creatorId: safeString(row.creator_id) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    isClosed: row.is_closed === true,
  };
}

function mapContributionItem(row: Record<string, unknown>): AdminContributionItem {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    groupId: safeString(row.group_id),
    userId: safeString(row.user_id),
    amount: safeNumber(row.amount, 0),
    status: safeString(row.status, "pending"),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapNotification(row: Record<string, unknown>): AdminNotificationRecord {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, "Notification"),
    body: safeString(row.body, "No content."),
    audienceType:
      safeString(row.audience_type) === "by_tier"
        ? "by_tier"
        : safeString(row.audience_type) === "by_group"
          ? "by_group"
          : "all_fans",
    audienceTier: safeString(row.audience_tier) || null,
    audienceGroupId: safeString(row.audience_group_id) || null,
    audienceGroupName: safeString(row.audience_group_name) || null,
    deliveryMode:
      safeString(row.delivery_mode) === "schedule" ? "schedule" : "send_now",
    status: safeString(row.status, "scheduled"),
    scheduledAt: safeString(row.scheduled_at) || null,
    sentAt: safeString(row.sent_at) || null,
    requestedRecipientCount: safeNumber(row.requested_recipient_count, 0),
    sentCount: safeNumber(row.sent_count, 0),
    failedCount: safeNumber(row.failed_count, 0),
    createdAt: safeString(row.created_at, new Date().toISOString()),
    lastError: safeString(row.last_error) || null,
  };
}

function mapSmsSyncRun(row: Record<string, unknown>): AdminSmsSyncRun {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    status: safeString(row.status, "unknown"),
    trigger: safeString(row.trigger, "background"),
    scannedMessages: safeNumber(row.scanned_messages, 0),
    uploadedMessages: safeNumber(row.uploaded_messages, 0),
    startedAt: safeString(row.scan_started_at) || null,
  };
}

export function normalizeAdminRole(value: unknown): AdminRole | null {
  const role = safeString(value).toLowerCase();
  switch (role) {
    case "super_admin":
      return "super_admin";
    case "admin":
      return "admin";
    case "rayon_sport":
    case "club_admin":
      return "club_admin";
    case "bank":
    case "club_moderator":
      return "club_moderator";
    case "fan":
      return "fan";
    default:
      return null;
  }
}

export function formatAdminRoleLabel(role: AdminRole | null) {
  return (role ?? "fan").replaceAll("_", " ");
}

export function deriveAdminAccess(
  user: AdminUserClaims,
  assignments: AdminAssignmentRow[],
): AdminAccess {
  if (user == null) {
    return emptyAdminAccess;
  }

  const currentClubId = userClubId(user);
  const matchingAssignments = assignments.filter((assignment) =>
    matchClubScope(assignment, currentClubId),
  );
  const assignmentRole = normalizeAdminRole(matchingAssignments[0]?.role);
  const fallbackRole = metadataRole(user);
  const role = assignmentRole ?? fallbackRole;
  const hasAccess =
    role === "super_admin" ||
    role === "admin" ||
    role === "club_admin" ||
    role === "club_moderator";

  return {
    hasAccess,
    isAuthenticated: user != null,
    isSuperAdmin: role === "super_admin" || role === "admin",
    role,
    clubId: currentClubId,
    assignmentCount: matchingAssignments.length,
  };
}

export async function resolveAdminAccess(
  client: SupabaseClient,
  user: User | null,
) {
  if (user == null) {
    return emptyAdminAccess;
  }

  try {
    const { data, error } = await client
      .from("admin_role_assignments")
      .select("role, club_id, is_active")
      .eq("user_id", user.id)
      .eq("is_active", true);

    if (error) {
      throw error;
    }

    return deriveAdminAccess(
      user,
      Array.isArray(data) ? (data as AdminAssignmentRow[]) : [],
    );
  } catch {
    return deriveAdminAccess(user, []);
  }
}

export async function getAdminDashboardSnapshot(
  client: SupabaseClient,
): Promise<AdminDashboardSnapshot> {
  const now = new Date();
  const startOfDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  ).toISOString();
  const endOfDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
  ).toISOString();
  const newsTable = await resolveNewsTable(client);

  const [totalUsers, activeGroups, transactionsToday, ticketsSold, auditFeed, recentNews] =
    await Promise.all([
      safeCount(client.from("profiles").select("id", { count: "exact", head: true })),
      safeCount(
        client
          .from("contribution_groups")
          .select("id", { count: "exact", head: true })
          .eq("is_closed", false),
      ),
      safeCount(
        client
          .from("contributions")
          .select("id", { count: "exact", head: true })
          .gte("created_at", startOfDay)
          .lt("created_at", endOfDay),
      ),
      safeCount(client.from("tickets").select("id", { count: "exact", head: true })),
      client
        .from("admin_audit_log")
        .select("id, action, metadata, created_at")
        .order("created_at", { ascending: false })
        .limit(4),
      client
        .from(newsTable)
        .select("id, title, created_at")
        .order("created_at", { ascending: false })
        .limit(3),
    ]);

  const activity: AdminActivityRecord[] = [];

  if (!auditFeed.error && Array.isArray(auditFeed.data)) {
    activity.push(
      ...auditFeed.data.map((row) =>
        mapDashboardActivity(row as Record<string, unknown>),
      ),
    );
  }

  if (!recentNews.error && Array.isArray(recentNews.data)) {
    activity.push(
      ...recentNews.data.map((row) => ({
        id: `news-${toIdString((row as Record<string, unknown>).id, crypto.randomUUID())}`,
        title: "CMS update",
        detail: safeString(
          (row as Record<string, unknown>).title,
          "Recent article update.",
        ),
        createdAt: safeString(
          (row as Record<string, unknown>).created_at,
          new Date().toISOString(),
        ),
      })),
    );
  }

  return {
    metrics: {
      totalUsers,
      activeGroups,
      transactionsToday,
      ticketsSold,
    } satisfies AdminDashboardMetrics,
    activity: activity.slice(0, 6),
  };
}

export async function getAdminArticles(client: SupabaseClient) {
  const table = await resolveNewsTable(client);
  const { data, error } = await client
    .from(table)
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) => mapNewsArticle(row as Record<string, unknown>))
    : [];
}

export async function saveAdminArticle(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    title: string;
    subtitle?: string;
    excerpt?: string;
    body: string;
    category?: string;
    imageUrl?: string;
    isPublished?: boolean;
    isFeatured?: boolean;
    sortOrder?: number;
  },
) {
  const table = await resolveNewsTable(client);
  const now = new Date().toISOString();
  const payload = {
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    title: input.title.trim(),
    subtitle: safeString(input.subtitle) || null,
    excerpt: safeString(input.excerpt) || safeString(input.body).slice(0, 140),
    body: input.body.trim(),
    category: safeString(input.category, "News"),
    image_url: safeString(input.imageUrl) || null,
    is_published: input.isPublished === true,
    is_featured: input.isFeatured === true,
    sort_order: safeNumber(input.sortOrder, 0),
    published_at: input.isPublished ? now : null,
  };

  if (input.id) {
    const { error } = await client.from(table).update(payload).eq("id", input.id);
    if (error) {
      throw new Error(error.message);
    }
    return input.id;
  }

  const { data, error } = await client
    .from(table)
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminArticle(
  client: SupabaseClient,
  articleId: string,
) {
  const table = await resolveNewsTable(client);
  const { error } = await client.from(table).delete().eq("id", articleId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminMatches(client: SupabaseClient) {
  const { data, error } = await client
    .from("matches")
    .select("*")
    .order("match_date", { ascending: true });

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
  const kickoffTime = safeString(input.kickoffTime, "15:00");
  const matchDate = new Date(`${input.matchDate}T${kickoffTime}:00`);
  const saleStartsAt = input.saleStartsAt
    ? new Date(input.saleStartsAt).toISOString()
    : new Date().toISOString();
  const payload = {
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    partner_id: safeString(input.partnerId, rayonClub.slug),
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
  matchId: string,
) {
  const { error } = await client.from("matches").delete().eq("id", matchId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminClubProfile(
  client: SupabaseClient,
): Promise<ClubProfile> {
  const { data, error } = await client
    .from(clubTable)
    .select("*")
    .eq("club_slug", rayonClub.slug)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data ? mapAdminClubProfile(data as Record<string, unknown>) : fallbackClubProfile;
}

export async function saveAdminClubProfile(
  client: SupabaseClient,
  input: ClubProfile,
) {
  const payload = {
    club_name: input.clubName.trim(),
    club_slug: rayonClub.slug,
    short_name: input.shortName.trim(),
    nickname_brand_identity: input.nickname.trim(),
    country_iso_code: input.countryCode.trim(),
    league: input.league.trim(),
    region: input.region.trim(),
    currency_code: input.currencyCode.trim(),
    currency_symbol: input.currencySymbol.trim(),
    default_language: input.defaultLanguage.trim(),
    supported_languages: input.supportedLanguages,
    official_contact: input.officialContact.trim(),
    facebook_url: safeString(input.facebookUrl) || null,
    x_twitter_url: safeString(input.xUrl) || null,
    instagram_url: safeString(input.instagramUrl) || null,
    tiktok_url: safeString(input.tiktokUrl) || null,
    official_logo_url: safeString(input.officialLogoUrl) || null,
    primary_color_hex: input.primaryColorHex.trim(),
    secondary_color_hex: input.secondaryColorHex.trim(),
    accent_color_hex: input.accentColorHex.trim(),
    feature_flags: input.featureFlags,
  };
  const payloadWithoutShortName = Object.fromEntries(
    Object.entries(payload).filter(([key]) => key !== "short_name"),
  ) as Record<string, unknown>;

  const existing = await client
    .from(clubTable)
    .select("id")
    .eq("club_slug", rayonClub.slug)
    .maybeSingle();

  if (existing.error) {
    throw new Error(existing.error.message);
  }

  const existingId = existing.data?.id
    ? toIdString(existing.data.id, crypto.randomUUID())
    : null;
  const payloadVariants = existingId
    ? [payload, payloadWithoutShortName]
    : [
        {
          id: rayonClub.numericId,
          ...payload,
        },
        {
          id: rayonClub.numericId,
          ...payloadWithoutShortName,
        },
        payload,
        payloadWithoutShortName,
      ];

  return mutateRecordWithVariants(
    client,
    clubTable,
    existingId,
    payloadVariants,
  );
}

export async function getAdminMembershipPackages(
  client: SupabaseClient,
): Promise<AdminMembershipPackage[]> {
  const scoped = await client
    .from(membershipTable)
    .select("*")
    .eq("club_id", rayonClub.numericId)
    .order("sort_order", { ascending: true });

  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row) =>
      mapAdminMembershipPackage(row as Record<string, unknown>),
    );
  }

  const fallback = await client
    .from(membershipTable)
    .select("*")
    .order("sort_order", { ascending: true });

  if (fallback.error) {
    throw new Error(fallback.error.message);
  }

  if (Array.isArray(fallback.data) && fallback.data.length > 0) {
    return fallback.data.map((row) =>
      mapAdminMembershipPackage(row as Record<string, unknown>),
    );
  }

  return [];
}

export async function saveAdminMembershipPackage(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    tier: AdminMembershipPackage["tier"];
    title: string;
    description: string;
    annualPrice: number;
    sortOrder: number;
    perks: string[];
    isActive: boolean;
  },
) {
  const basePayload = {
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    tier: input.tier,
    title: input.title.trim(),
    description: input.description.trim(),
    sort_order: safeNumber(input.sortOrder, 0),
    is_active: input.isActive,
  };

  return mutateRecordWithVariants(
    client,
    membershipTable,
    input.id,
    [
      {
        ...basePayload,
        annual_price: safeNumber(input.annualPrice, 0),
        price: safeNumber(input.annualPrice, 0),
        benefits: input.perks,
      },
      {
        ...basePayload,
        annual_price: safeNumber(input.annualPrice, 0),
        benefits: input.perks,
      },
      {
        ...basePayload,
        price: safeNumber(input.annualPrice, 0),
        benefits: input.perks,
      },
      {
        ...basePayload,
        annual_price: safeNumber(input.annualPrice, 0),
      },
    ],
  );
}

export async function deleteAdminMembershipPackage(
  client: SupabaseClient,
  packageId: string,
) {
  const { error } = await client
    .from(membershipTable)
    .delete()
    .eq("id", packageId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminProducts(
  client: SupabaseClient,
): Promise<AdminShopProduct[]> {
  const table = await resolveProductTable(client);
  const scoped = await client
    .from(table)
    .select("*")
    .eq("club_id", rayonClub.numericId)
    .order("sort_order", { ascending: true });

  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row) =>
      mapAdminShopProduct(row as Record<string, unknown>),
    );
  }

  const fallback = await client
    .from(table)
    .select("*")
    .order("sort_order", { ascending: true });

  if (fallback.error) {
    throw new Error(fallback.error.message);
  }

  if (Array.isArray(fallback.data) && fallback.data.length > 0) {
    return fallback.data.map((row) =>
      mapAdminShopProduct(row as Record<string, unknown>),
    );
  }

  return [];
}

export async function saveAdminProduct(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    name: string;
    subtitle: string;
    description: string;
    category: string;
    price: number;
    imageUrl?: string;
    sizes: string[];
    isActive: boolean;
    collection?: string;
    sortOrder: number;
  },
) {
  const table = await resolveProductTable(client);
  return mutateRecordWithVariants(client, table, input.id, [
    {
      club_id: safeNumber(access.clubId, rayonClub.numericId),
      name: input.name.trim(),
      subtitle: input.subtitle.trim(),
      description: input.description.trim(),
      category: input.category.trim(),
      price: safeNumber(input.price, 0),
      image_url: safeString(input.imageUrl) || null,
      sizes: input.sizes,
      is_active: input.isActive,
      collection: safeString(input.collection) || null,
      sort_order: safeNumber(input.sortOrder, 0),
    },
  ]);
}

export async function deleteAdminProduct(
  client: SupabaseClient,
  productId: string,
) {
  const table = await resolveProductTable(client);
  const { error } = await client.from(table).delete().eq("id", productId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminFanClubs(
  client: SupabaseClient,
): Promise<AdminFanClub[]> {
  const scoped = await client
    .from(fanClubTable)
    .select("*")
    .eq("club_id", rayonClub.numericId)
    .order("member_count", { ascending: false });

  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row) =>
      mapAdminFanClub(row as Record<string, unknown>),
    );
  }

  const fallback = await client
    .from(fanClubTable)
    .select("*")
    .order("member_count", { ascending: false });

  if (fallback.error) {
    throw new Error(fallback.error.message);
  }

  if (Array.isArray(fallback.data) && fallback.data.length > 0) {
    return fallback.data.map((row) =>
      mapAdminFanClub(row as Record<string, unknown>),
    );
  }

  return [];
}

export async function saveAdminFanClub(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    name: string;
    region: string;
    description: string;
    memberCount: number;
    eventCount: number;
    rating: number;
    bannerImageUrl?: string;
    isActive: boolean;
  },
) {
  return mutateRecordWithVariants(client, fanClubTable, input.id, [
    {
      club_id: safeNumber(access.clubId, rayonClub.numericId),
      name: input.name.trim(),
      region: input.region.trim(),
      description: input.description.trim(),
      member_count: safeNumber(input.memberCount, 0),
      event_count: safeNumber(input.eventCount, 0),
      rating: safeNumber(input.rating, 0),
      banner_image_url: safeString(input.bannerImageUrl) || null,
      is_active: input.isActive,
    },
  ]);
}

export async function deleteAdminFanClub(
  client: SupabaseClient,
  fanClubId: string,
) {
  const { error } = await client.from(fanClubTable).delete().eq("id", fanClubId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminStandings(
  client: SupabaseClient,
): Promise<AdminStandingRow[]> {
  const table = await resolveStandingsTable(client);
  const scoped = await client
    .from(table)
    .select("*")
    .eq("club_id", rayonClub.numericId)
    .order("position", { ascending: true });

  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row, index) =>
      mapAdminStandingRow(row as Record<string, unknown>, index),
    );
  }

  const fallback = await client
    .from(table)
    .select("*")
    .order("position", { ascending: true });

  if (fallback.error) {
    throw new Error(fallback.error.message);
  }

  if (Array.isArray(fallback.data) && fallback.data.length > 0) {
    return fallback.data.map((row, index) =>
      mapAdminStandingRow(row as Record<string, unknown>, index),
    );
  }

  return [];
}

export async function saveAdminStandingRow(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    position: number;
    club: string;
    played: number;
    goalDifference: number;
    points: number;
    form: string[];
    clubSlug?: string | null;
  },
) {
  const table = await resolveStandingsTable(client);
  const clubColumn = await resolveExistingColumn(client, table, [
    "club_name",
    "club",
    "team_name",
  ]);
  const playedColumn = await resolveExistingColumn(client, table, [
    "played",
    "matches_played",
  ]);
  const goalDifferenceColumn = await resolveExistingColumn(client, table, [
    "goal_difference",
    "gd",
    "goal_diff",
  ]);
  const pointsColumn = await resolveExistingColumn(client, table, ["points", "pts"]);
  const clubIdColumn = await resolveExistingColumn(client, table, ["club_id"]);
  const formColumn = await resolveExistingColumn(client, table, ["form"]);
  const slugColumn = await resolveExistingColumn(client, table, ["club_slug"]);

  const payload: Record<string, unknown> = {
    position: safeNumber(input.position, 1),
  };

  if (clubColumn) {
    payload[clubColumn] = input.club.trim();
  }
  if (playedColumn) {
    payload[playedColumn] = safeNumber(input.played, 0);
  }
  if (goalDifferenceColumn) {
    payload[goalDifferenceColumn] = safeNumber(input.goalDifference, 0);
  }
  if (pointsColumn) {
    payload[pointsColumn] = safeNumber(input.points, 0);
  }
  if (clubIdColumn === "club_id") {
    payload.club_id = safeNumber(access.clubId, rayonClub.numericId);
  }
  if (formColumn === "form") {
    payload.form = input.form.slice(0, 5);
  }
  if (slugColumn === "club_slug") {
    payload.club_slug = safeString(input.clubSlug) || null;
  }

  return mutateRecordWithVariants(client, table, input.id, [payload]);
}

export async function deleteAdminStandingRow(
  client: SupabaseClient,
  rowId: string,
) {
  const table = await resolveStandingsTable(client);
  const { error } = await client.from(table).delete().eq("id", rowId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminContributionSnapshot(
  client: SupabaseClient,
): Promise<AdminContributionSnapshot> {
  const [groupsResult, contributionsResult] = await Promise.all([
    client
      .from(contributionTable)
      .select(
        "id, name, description, group_type, privacy, target_amount, current_total, member_count, creator_id, invite_code, is_closed, created_at, currency",
      )
      .eq("club_id", rayonClub.numericId)
      .order("created_at", { ascending: false }),
    client
      .from("contributions")
      .select("id, group_id, user_id, amount, status, created_at")
      .order("created_at", { ascending: false })
      .limit(500),
  ]);

  if (groupsResult.error) {
    throw new Error(groupsResult.error.message);
  }
  if (contributionsResult.error) {
    throw new Error(contributionsResult.error.message);
  }

  const groups = Array.isArray(groupsResult.data)
    ? groupsResult.data.map((row) =>
        mapContributionGroup(row as Record<string, unknown>),
      )
    : [];
  const contributions = Array.isArray(contributionsResult.data)
    ? contributionsResult.data.map((row) =>
        mapContributionItem(row as Record<string, unknown>),
      )
    : [];
  const allowedGroupIds = new Set(groups.map((group) => group.id));
  const scopedContributions = contributions.filter((item) =>
    allowedGroupIds.has(item.groupId),
  );

  const creatorIds = groups
    .map((group) => group.creatorId)
    .filter((value): value is string => Boolean(value));
  const aliases: Record<string, string> = {};

  if (creatorIds.length > 0) {
    const { data } = await client
      .from("profiles")
      .select("id, public_user_id")
      .in("id", creatorIds);

    if (Array.isArray(data)) {
      for (const profile of data) {
        const row = profile as Record<string, unknown>;
        const id = safeString(row.id);
        const alias = safeString(row.public_user_id);
        if (id && alias) {
          aliases[id] = alias;
        }
      }
    }
  }

  const today = new Date();
  const monthlyTotal = scopedContributions.reduce((sum, item) => {
    const createdAt = new Date(item.createdAt);
    if (
      createdAt.getUTCFullYear() !== today.getUTCFullYear() ||
      createdAt.getUTCMonth() !== today.getUTCMonth() ||
      item.status === "failed" ||
      item.status === "reversed"
    ) {
      return sum;
    }
    return sum + item.amount;
  }, 0);

  return {
    groups,
    contributions: scopedContributions,
    aliases,
    monthlyTotal,
  };
}

export function buildContributionExcel(snapshot: AdminContributionSnapshot) {
  // Dynamic import-free approach: build workbook data structure
  const headers = ["Name", "Type", "Total (RWF)", "Target (RWF)", "Contributors", "Status", "Created"];
  const rows = snapshot.groups.map((group) => [
    group.name,
    group.groupType,
    group.currentTotal,
    group.targetAmount,
    group.memberCount,
    group.isClosed ? "Closed" : "Active",
    new Date(group.createdAt).toLocaleDateString("en-RW", {
      year: "numeric",
      month: "short",
      day: "numeric",
    }),
  ]);

  return { headers, rows };
}

export async function downloadContributionExcel(snapshot: AdminContributionSnapshot) {
  const XLSX = await import("xlsx");
  const { headers, rows } = buildContributionExcel(snapshot);
  const data = [headers, ...rows];

  const workbook = XLSX.utils.book_new();
  const worksheet = XLSX.utils.aoa_to_sheet(data);

  // Auto-size columns
  worksheet["!cols"] = headers.map((header, i) => ({
    wch: Math.max(
      header.length,
      ...rows.map((row) => String(row[i] ?? "").length),
      12,
    ),
  }));

  XLSX.utils.book_append_sheet(workbook, worksheet, "Contributions");
  XLSX.writeFile(workbook, `rayon-contributions-${new Date().toISOString().slice(0, 10)}.xlsx`);
}

export async function saveAdminContributionGroup(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    name: string;
    description: string;
    privacy: AdminContributionGroup["privacy"];
    groupType: AdminContributionGroup["groupType"];
    targetAmount: number;
    currentTotal: number;
    currency: string;
    memberCount: number;
    inviteCode?: string | null;
    isClosed: boolean;
  },
) {
  return mutateRecordWithVariants(client, contributionTable, input.id, [
    {
      club_id: safeNumber(access.clubId, rayonClub.numericId),
      name: input.name.trim(),
      description: input.description.trim(),
      privacy: input.privacy,
      group_type: input.groupType,
      target_amount: safeNumber(input.targetAmount, 0),
      current_total: safeNumber(input.currentTotal, 0),
      currency: input.currency.trim() || rayonClub.currencyCode,
      member_count: safeNumber(input.memberCount, 0),
      invite_code: safeString(input.inviteCode) || null,
      is_closed: input.isClosed,
      is_active: input.isClosed !== true,
    },
    {
      club_id: safeNumber(access.clubId, rayonClub.numericId),
      name: input.name.trim(),
      description: input.description.trim(),
      privacy: input.privacy,
      group_type: input.groupType,
      target_amount: safeNumber(input.targetAmount, 0),
      current_total: safeNumber(input.currentTotal, 0),
      currency: input.currency.trim() || rayonClub.currencyCode,
      member_count: safeNumber(input.memberCount, 0),
      invite_code: safeString(input.inviteCode) || null,
      is_closed: input.isClosed,
    },
  ]);
}

export async function deleteAdminContributionGroup(
  client: SupabaseClient,
  groupId: string,
) {
  const { error } = await client
    .from(contributionTable)
    .delete()
    .eq("id", groupId);
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminNotificationContext(
  client: SupabaseClient,
): Promise<AdminNotificationContext> {
  const [groupsResult, historyResult] = await Promise.all([
    client
      .from("contribution_groups")
      .select("id, name")
      .eq("is_closed", false)
      .order("name", { ascending: true })
      .limit(50),
    client
      .from("notifications")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(10),
  ]);

  if (groupsResult.error) {
    throw new Error(groupsResult.error.message);
  }
  if (historyResult.error) {
    throw new Error(historyResult.error.message);
  }

  return {
    groups: Array.isArray(groupsResult.data)
      ? groupsResult.data.map((row) => ({
          id: safeString((row as Record<string, unknown>).id),
          name: safeString((row as Record<string, unknown>).name, "Group"),
        }))
      : [],
    history: Array.isArray(historyResult.data)
      ? historyResult.data.map((row) =>
          mapNotification(row as Record<string, unknown>),
        )
      : [],
  };
}

export async function sendAdminNotification(
  client: SupabaseClient,
  payload: {
    title: string;
    body: string;
    audience: "all_fans" | "by_tier" | "by_group";
    tier?: string | null;
    groupId?: string | null;
    groupName?: string | null;
    deliveryMode: "send_now" | "schedule";
    scheduledAt?: string | null;
    imageUrl?: string | null;
  },
) {
  const response = await client.functions.invoke("admin-send-notification", {
    body: {
      title: payload.title,
      body: payload.body,
      audience: payload.audience,
      tier: payload.tier,
      group_id: payload.groupId,
      group_name: payload.groupName,
      delivery_mode: payload.deliveryMode,
      scheduled_at: payload.scheduledAt,
      image_url: payload.imageUrl,
    },
  });

  const raw = response.data;
  if (raw && typeof raw === "object") {
    const result = raw as { success?: boolean; message?: string; data?: unknown };
    if (result.success === true) {
      return result.data ?? {};
    }
    if (result.message && !result.message.toLowerCase().includes("function")) {
      throw new Error(result.message);
    }
  }
  const user = await client.auth.getUser();
  const legacyInsert = await client
    .from("notifications")
    .insert({
      title: payload.title,
      body: payload.body,
      status: payload.deliveryMode === "schedule" ? "scheduled" : "sent",
      created_by: user.data.user?.id ?? null,
      sent_at: payload.deliveryMode === "send_now" ? new Date().toISOString() : null,
    })
    .select("*")
    .single();

  if (legacyInsert.error) {
    throw new Error(legacyInsert.error.message || "Notification delivery failed.");
  }

  return {
    notification: legacyInsert.data,
    delivery: {
      status: legacyInsert.data?.status ?? "sent",
      sent_count: payload.deliveryMode === "send_now" ? 1 : 0,
      failed_count: 0,
    },
  };
}

export async function getAdminSmsSnapshot(
  client: SupabaseClient,
): Promise<AdminSmsSnapshot> {
  const [rawCount, parsedCount, ledgerCount, syncRuns] = await Promise.all([
    safeCount(client.from("momo_sms_raw").select("id", { count: "exact", head: true })),
    safeCount(client.from("momo_sms_parsed").select("id", { count: "exact", head: true })),
    safeCount(
      client.from("momo_ledger_entries").select("id", { count: "exact", head: true }),
    ),
    client
      .from("momo_sms_sync_runs")
      .select("*")
      .order("scan_started_at", { ascending: false })
      .limit(10),
  ]);

  return {
    metrics: {
      "SMS captured": rawCount,
      "SMS parsed": parsedCount,
      "Ledger entries": ledgerCount,
    },
    syncRuns:
      !syncRuns.error && Array.isArray(syncRuns.data)
        ? syncRuns.data.map((row) => mapSmsSyncRun(row as Record<string, unknown>))
        : [],
  };
}

/* ── Squad CRUD ──────────────────────────────────────────────────── */

export interface AdminSquadPlayer {
  id: string;
  clubId: number | null;
  name: string;
  role: string;
  number: number;
  nationality: string;
  bio: string;
  imageUrl: string | null;
  isActive: boolean;
  createdAt: string;
}

function mapAdminSquadPlayer(row: Record<string, unknown>): AdminSquadPlayer {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
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
    imageUrl: safeString(row.image_url) || safeString(row.photo_url) || null,
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminSquad(
  client: SupabaseClient,
): Promise<AdminSquadPlayer[]> {
  const table = await resolveSquadTable(client);

  const scopedQuery = await client
    .from(table)
    .select("*")
    .eq("club_id", rayonClub.numericId)
    .order("shirt_number", { ascending: true })
    .limit(50);

  if (scopedQuery.data && scopedQuery.data.length > 0) {
    return scopedQuery.data.map((row) =>
      mapAdminSquadPlayer(row as Record<string, unknown>),
    );
  }

  const fallbackQuery = await client
    .from(table)
    .select("*")
    .order("shirt_number", { ascending: true })
    .limit(50);

  if (fallbackQuery.data && fallbackQuery.data.length > 0) {
    return fallbackQuery.data.map((row) =>
      mapAdminSquadPlayer(row as Record<string, unknown>),
    );
  }

  return [];
}

export async function saveAdminSquadPlayer(
  client: SupabaseClient,
  access: AdminAccess,
  player: {
    id: string | null;
    name: string;
    role: string;
    number: number;
    nationality: string;
    bio: string;
    imageUrl: string;
    isActive: boolean;
  },
) {
  const table = await resolveSquadTable(client);
  const payload = {
    club_id: access.clubId ? Number(access.clubId) : rayonClub.numericId,
    name: player.name,
    position: player.role,
    shirt_number: player.number,
    nationality: player.nationality,
    bio: player.bio,
    image_url: player.imageUrl || null,
    is_active: player.isActive,
  };

  if (player.id) {
    const { error } = await client
      .from(table)
      .update(payload)
      .eq("id", player.id);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await client.from(table).insert(payload);
    if (error) throw new Error(error.message);
  }
}

export async function deleteAdminSquadPlayer(
  client: SupabaseClient,
  playerId: string,
) {
  const table = await resolveSquadTable(client);
  const { error } = await client.from(table).delete().eq("id", playerId);
  if (error) throw new Error(error.message);
}
