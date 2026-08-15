import type { SupabaseClient } from "@supabase/supabase-js";
import type { VenueAccess } from "@/lib/data/venue-access";

export interface VenueOrder {
  id: string;
  status: string;
  totalAmount: number;
  currencyCode: string;
  paymentStatus: string;
  ageGateConfirmed: boolean;
  createdAt: string;
}

export interface VenueMenuItem {
  id: string;
  name: string;
  description: string;
  priceAmount: number;
  currencyCode: string;
  isActive: boolean;
  isAlcohol: boolean;
  sortOrder: number;
}

export interface VenueCheckin {
  id: string;
  status: string;
  locationStatus: string;
  fetAwarded: number;
  checkedInAt: string;
  reviewReason: string;
}

export interface VenueCampaign {
  id: string;
  name: string;
  status: string;
  startsAt: string;
  endsAt: string;
  fetAward: number;
  budget: number;
  awarded: number;
  requireLocation: boolean;
  isLaunchable: boolean;
}

export interface VenueStaffMember {
  id: string;
  role: string;
  grantedAt: string;
  isCurrentUser: boolean;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_CURRENCY_PATTERN = /^[A-Z]{3}$/;
const VENUE_DATA_TIMEOUT_MS = 12_000;

const orderStatuses = new Set(["created", "accepted", "preparing", "ready"]);
const paymentStatuses = new Set(["pending", "paid", "failed", "refunded"]);
const checkinStatuses = new Set(["pending", "approved", "rejected", "review"]);
const locationStatuses = new Set([
  "not_requested",
  "pending",
  "verified",
  "rejected",
  "unavailable",
]);
const campaignStatuses = new Set([
  "draft",
  "pending_approval",
  "approved",
  "active",
  "paused",
  "ended",
  "cancelled",
]);
const staffRoles = new Set(["owner", "manager", "staff", "reviewer"]);

export class VenueDataContractError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "VenueDataContractError";
  }
}

function strictId(value: unknown, label: string) {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new VenueDataContractError(`${label} identifier is invalid`);
  }
  return value;
}

function strictText(
  value: unknown,
  label: string,
  maxLength: number,
  { optional = false }: { optional?: boolean } = {},
) {
  if (optional && (value == null || value === "")) return "";
  if (typeof value !== "string") {
    throw new VenueDataContractError(`${label} is invalid`);
  }
  const normalized = value.trim();
  if ((!optional && normalized.length === 0) || normalized.length > maxLength) {
    throw new VenueDataContractError(`${label} is invalid`);
  }
  return normalized;
}

function strictEnum(value: unknown, label: string, allowed: Set<string>) {
  const normalized = strictText(value, label, 40).toLowerCase();
  if (!allowed.has(normalized)) {
    throw new VenueDataContractError(`${label} is invalid`);
  }
  return normalized;
}

function strictInteger(
  value: unknown,
  label: string,
  { min = 0, max = Number.MAX_SAFE_INTEGER }: { min?: number; max?: number } = {},
) {
  const normalized = Number(value);
  if (
    !Number.isSafeInteger(normalized) ||
    normalized < min ||
    normalized > max
  ) {
    throw new VenueDataContractError(`${label} is invalid`);
  }
  return normalized;
}

function strictTimestamp(
  value: unknown,
  label: string,
  { optional = false }: { optional?: boolean } = {},
) {
  if (optional && (value == null || value === "")) return "";
  const normalized = strictText(value, label, 64);
  if (!Number.isFinite(Date.parse(normalized))) {
    throw new VenueDataContractError(`${label} is invalid`);
  }
  return normalized;
}

function strictCurrency(value: unknown) {
  const normalized = strictText(value, "Currency", 3).toUpperCase();
  if (!ISO_CURRENCY_PATTERN.test(normalized)) {
    throw new VenueDataContractError("Currency is invalid");
  }
  return normalized;
}

function strictBoolean(value: unknown, label: string) {
  if (typeof value !== "boolean") {
    throw new VenueDataContractError(`${label} is invalid`);
  }
  return value;
}

function assertUniqueIds(rows: Array<{ id: string }>, label: string) {
  if (new Set(rows.map((row) => row.id)).size !== rows.length) {
    throw new VenueDataContractError(`${label} contains duplicate records`);
  }
}

export function assertVenueScope(row: Record<string, unknown>, access: VenueAccess) {
  if (String(row.venue_id) !== access.venueId || Number(row.club_id) !== access.clubId) {
    throw new Error("Venue scope mismatch");
  }
}

function requiredRows<T>(
  data: unknown,
  error: { message?: string } | null,
  label: string,
  maxRows: number,
): T[] {
  if (error) throw new Error(`${label} query failed`);
  if (!Array.isArray(data) || data.length > maxRows) {
    throw new VenueDataContractError(`${label} response is invalid`);
  }
  return data as T[];
}

export async function getVenueOverview(client: SupabaseClient, access: VenueAccess) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const [campaigns, orders, checkins] = await Promise.all([
    client.from("venue_checkin_campaigns").select("id", { count: "exact", head: true }).eq("club_id", access.clubId).eq("venue_id", access.venueId).eq("status", "approved"),
    client.from("venue_drink_orders").select("id", { count: "exact", head: true }).eq("club_id", access.clubId).eq("venue_id", access.venueId).in("status", ["created", "accepted", "preparing", "ready"]),
    client.from("venue_checkins").select("id", { count: "exact", head: true }).eq("club_id", access.clubId).eq("venue_id", access.venueId).gte("checked_in_at", today.toISOString()),
  ]);
  if (campaigns.error) throw new Error("Campaigns query failed");
  if (orders.error) throw new Error("Orders query failed");
  if (checkins.error) throw new Error("Check-ins query failed");
  return {
    activeCampaigns: strictInteger(campaigns.count, "Campaign count", {
      max: 10_000,
    }),
    openOrders: strictInteger(orders.count, "Order count", { max: 10_000 }),
    checkinsToday: strictInteger(checkins.count, "Check-in count", {
      max: 1_000_000,
    }),
  };
}

export type VenueDataResult<T> =
  | { ok: true; data: T }
  | { ok: false; correlationId: string };

export async function captureVenueData<T>(loader: () => Promise<T>, label: string): Promise<VenueDataResult<T>> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    const data = await Promise.race([
      loader(),
      new Promise<never>((_resolve, reject) => {
        timeoutId = setTimeout(
          () => reject(new Error("Venue operation timed out")),
          VENUE_DATA_TIMEOUT_MS,
        );
      }),
    ]);
    return { ok: true, data };
  } catch {
    const correlationId = `${label}-${crypto.randomUUID()}`;
    console.error("Venue workflow data failed", { label, correlationId });
    return { ok: false, correlationId };
  } finally {
    if (timeoutId != null) clearTimeout(timeoutId);
  }
}

export async function getVenueOrders(
  client: SupabaseClient,
  access: VenueAccess,
): Promise<VenueOrder[]> {
  const { data, error } = await client
    .from("venue_drink_orders")
    .select("id, club_id, venue_id, status, total_amount, currency_code, payment_status, age_gate_confirmed, created_at")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .in("status", ["created", "accepted", "preparing", "ready"])
    .order("created_at", { ascending: true })
    .limit(100);
  const orders = requiredRows<Record<string, unknown>>(
    data,
    error,
    "Orders",
    100,
  ).map((row) => {
    assertVenueScope(row, access);
    return {
      id: strictId(row.id, "Order"),
      status: strictEnum(row.status, "Order status", orderStatuses),
      totalAmount: strictInteger(row.total_amount, "Order total", {
        max: 100_000_000,
      }),
      currencyCode: strictCurrency(row.currency_code),
      paymentStatus: strictEnum(
        row.payment_status,
        "Payment status",
        paymentStatuses,
      ),
      ageGateConfirmed: strictBoolean(row.age_gate_confirmed, "Age gate"),
      createdAt: strictTimestamp(row.created_at, "Order creation time"),
    };
  });
  assertUniqueIds(orders, "Orders");
  return orders;
}

export async function getVenueMenu(
  client: SupabaseClient,
  access: VenueAccess,
): Promise<VenueMenuItem[]> {
  const { data, error } = await client
    .from("venue_drink_items")
    .select("id, club_id, venue_id, item_name, description, price_amount, currency_code, is_active, is_alcohol, sort_order")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .order("sort_order", { ascending: true })
    .limit(50);
  const items = requiredRows<Record<string, unknown>>(
    data,
    error,
    "Menu",
    50,
  ).map((row) => {
    assertVenueScope(row, access);
    return {
      id: strictId(row.id, "Menu item"),
      name: strictText(row.item_name, "Menu item name", 80),
      description: strictText(row.description, "Menu item description", 240, {
        optional: true,
      }),
      priceAmount: strictInteger(row.price_amount, "Menu item price", {
        max: 10_000_000,
      }),
      currencyCode: strictCurrency(row.currency_code),
      isActive: strictBoolean(row.is_active, "Menu item active state"),
      isAlcohol: strictBoolean(row.is_alcohol, "Menu item alcohol state"),
      sortOrder: strictInteger(row.sort_order, "Menu item sort order", {
        max: 100,
      }),
    };
  });
  assertUniqueIds(items, "Menu");
  if (items.filter((item) => item.isActive).length > 10) {
    throw new VenueDataContractError("Menu exceeds the active-item limit");
  }
  return items;
}

export async function getVenueCheckins(client: SupabaseClient, access: VenueAccess) {
  const { data, error } = await client
    .from("venue_checkins")
    .select("id, club_id, venue_id, status, location_verification_status, fet_awarded, checked_in_at, review_reason")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .order("checked_in_at", { ascending: false })
    .limit(100);
  const checkins = requiredRows<Record<string, unknown>>(
    data,
    error,
    "Check-ins",
    100,
  ).map((row) => {
    assertVenueScope(row, access);
    return {
      id: strictId(row.id, "Check-in"),
      status: strictEnum(row.status, "Check-in status", checkinStatuses),
      locationStatus: strictEnum(
        row.location_verification_status,
        "Location status",
        locationStatuses,
      ),
      fetAwarded: strictInteger(row.fet_awarded, "FET award", {
        max: 1_000_000,
      }),
      checkedInAt: strictTimestamp(row.checked_in_at, "Check-in time"),
      reviewReason: strictText(row.review_reason, "Review reason", 240, {
        optional: true,
      }),
    } satisfies VenueCheckin;
  });
  assertUniqueIds(checkins, "Check-ins");
  return checkins;
}

export async function getVenueCampaigns(client: SupabaseClient, access: VenueAccess) {
  const { data, error } = await client
    .from("venue_checkin_campaigns")
    .select("id, club_id, venue_id, campaign_name, status, starts_at, ends_at, fet_award_per_checkin, fet_budget, awarded_fet, require_location")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .order("starts_at", { ascending: false })
    .limit(50);
  const now = Date.now();
  const campaigns = requiredRows<Record<string, unknown>>(
    data,
    error,
    "Campaigns",
    50,
  ).map((row) => {
    assertVenueScope(row, access);
    const status = strictEnum(
      row.status,
      "Campaign status",
      campaignStatuses,
    );
    const startsAt = strictTimestamp(row.starts_at, "Campaign start");
    const endsAt = strictTimestamp(row.ends_at, "Campaign end");
    const budget = strictInteger(row.fet_budget, "Campaign budget", {
      max: 1_000_000_000,
    });
    const awarded = strictInteger(row.awarded_fet, "Campaign awarded FET", {
      max: 1_000_000_000,
    });
    if (Date.parse(startsAt) >= Date.parse(endsAt) || awarded > budget) {
      throw new VenueDataContractError("Campaign lifecycle is invalid");
    }
    return {
      id: strictId(row.id, "Campaign"),
      name: strictText(row.campaign_name, "Campaign name", 120),
      status,
      startsAt,
      endsAt,
      fetAward: strictInteger(row.fet_award_per_checkin, "Campaign FET award", {
        max: 1_000_000,
      }),
      budget,
      awarded,
      requireLocation: strictBoolean(
        row.require_location,
        "Campaign location state",
      ),
      isLaunchable:
        status === "approved" &&
        Date.parse(startsAt) <= now &&
        Date.parse(endsAt) > now &&
        (budget === 0 || awarded < budget),
    } satisfies VenueCampaign;
  });
  assertUniqueIds(campaigns, "Campaigns");
  return campaigns;
}

export async function getVenueStaff(client: SupabaseClient, access: VenueAccess) {
  const { data, error } = await client
    .from("venue_staff_memberships")
    .select("id, club_id, venue_id, user_id, role, granted_at")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .eq("is_active", true)
    .order("granted_at", { ascending: true })
    .limit(100);
  const staff = requiredRows<Record<string, unknown>>(
    data,
    error,
    "Staff",
    100,
  ).map((row) => {
    assertVenueScope(row, access);
    const userId = strictId(row.user_id, "Staff user");
    return {
      id: strictId(row.id, "Staff assignment"),
      role: strictEnum(row.role, "Staff role", staffRoles),
      grantedAt: strictTimestamp(row.granted_at, "Staff assignment time"),
      isCurrentUser: userId === access.userId,
    } satisfies VenueStaffMember;
  });
  assertUniqueIds(staff, "Staff");
  return staff;
}
