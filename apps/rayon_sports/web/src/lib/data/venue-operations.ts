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

export interface VenueTvCode {
  status: string;
  expiresAt: string;
  rotatesAt: string;
  campaignName: string;
}

export interface VenueStaffMember {
  id: string;
  userId: string;
  role: string;
  grantedAt: string;
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
): T[] {
  if (error) throw new Error(`${label}: ${error.message ?? "query failed"}`);
  return Array.isArray(data) ? (data as T[]) : [];
}

export async function getVenueOverview(client: SupabaseClient, access: VenueAccess) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const [campaigns, orders, checkins] = await Promise.all([
    client.from("venue_checkin_campaigns").select("id", { count: "exact", head: true }).eq("club_id", access.clubId).eq("venue_id", access.venueId).eq("status", "approved"),
    client.from("venue_drink_orders").select("id", { count: "exact", head: true }).eq("club_id", access.clubId).eq("venue_id", access.venueId).in("status", ["created", "accepted", "preparing", "ready"]),
    client.from("venue_checkins").select("id", { count: "exact", head: true }).eq("club_id", access.clubId).eq("venue_id", access.venueId).gte("checked_in_at", today.toISOString()),
  ]);
  if (campaigns.error) throw new Error(`Campaigns: ${campaigns.error.message}`);
  if (orders.error) throw new Error(`Orders: ${orders.error.message}`);
  if (checkins.error) throw new Error(`Check-ins: ${checkins.error.message}`);
  return { activeCampaigns: campaigns.count ?? 0, openOrders: orders.count ?? 0, checkinsToday: checkins.count ?? 0 };
}

export type VenueDataResult<T> =
  | { ok: true; data: T }
  | { ok: false; correlationId: string };

export async function captureVenueData<T>(loader: () => Promise<T>, label: string): Promise<VenueDataResult<T>> {
  try {
    return { ok: true, data: await loader() };
  } catch {
    const correlationId = `${label}-${crypto.randomUUID()}`;
    console.error("Venue workflow data failed", { label, correlationId });
    return { ok: false, correlationId };
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
  return requiredRows<Record<string, unknown>>(data, error, "Orders").map((row) => {
    assertVenueScope(row, access);
    return {
      id: String(row.id),
      status: String(row.status),
      totalAmount: Number(row.total_amount) || 0,
      currencyCode: String(row.currency_code || "RWF"),
      paymentStatus: String(row.payment_status || "unknown"),
      ageGateConfirmed: row.age_gate_confirmed === true,
      createdAt: String(row.created_at || ""),
    };
  });
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
  return requiredRows<Record<string, unknown>>(data, error, "Menu").map((row) => {
    assertVenueScope(row, access);
    return {
      id: String(row.id),
      name: String(row.item_name || "Drink"),
      description: String(row.description || ""),
      priceAmount: Number(row.price_amount) || 0,
      currencyCode: String(row.currency_code || "RWF"),
      isActive: row.is_active === true,
      isAlcohol: row.is_alcohol === true,
      sortOrder: Number(row.sort_order) || 0,
    };
  });
}

export async function getVenueCheckins(client: SupabaseClient, access: VenueAccess) {
  const { data, error } = await client
    .from("venue_checkins")
    .select("id, club_id, venue_id, status, location_verification_status, fet_awarded, checked_in_at, review_reason")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .order("checked_in_at", { ascending: false })
    .limit(100);
  return requiredRows<Record<string, unknown>>(data, error, "Check-ins").map((row) => {
    assertVenueScope(row, access);
    return {
      id: String(row.id),
      status: String(row.status),
      locationStatus: String(row.location_verification_status || "not_requested"),
      fetAwarded: Number(row.fet_awarded) || 0,
      checkedInAt: String(row.checked_in_at || ""),
      reviewReason: String(row.review_reason || ""),
    } satisfies VenueCheckin;
  });
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
  return requiredRows<Record<string, unknown>>(data, error, "Campaigns").map((row) => {
    assertVenueScope(row, access);
    return {
      id: String(row.id),
      name: String(row.campaign_name || "Campaign"),
      status: String(row.status),
      startsAt: String(row.starts_at || ""),
      endsAt: String(row.ends_at || ""),
      fetAward: Number(row.fet_award_per_checkin) || 0,
      budget: Number(row.fet_budget) || 0,
      awarded: Number(row.awarded_fet) || 0,
      requireLocation: row.require_location === true,
      isLaunchable:
        String(row.status) === "approved" &&
        Date.parse(String(row.starts_at || "")) <= now &&
        Date.parse(String(row.ends_at || "")) > now &&
        (Number(row.fet_budget) === 0 || Number(row.awarded_fet) < Number(row.fet_budget)),
    } satisfies VenueCampaign;
  });
}

export async function getVenueTvCode(client: SupabaseClient, access: VenueAccess) {
  const { data, error } = await client
    .from("venue_checkin_codes")
    .select("club_id, venue_id, status, expires_at, rotates_at, venue_checkin_campaigns(campaign_name)")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .eq("status", "active")
    .order("expires_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(`TV code: ${error.message}`);
  if (data == null) return null;
  const row = data as unknown as Record<string, unknown>;
  assertVenueScope(row, access);
  const campaign = row.venue_checkin_campaigns as Record<string, unknown> | null;
  return {
    status: String(row.status),
    expiresAt: String(row.expires_at || ""),
    rotatesAt: String(row.rotates_at || ""),
    campaignName: String(campaign?.campaign_name || "Approved campaign"),
  } satisfies VenueTvCode;
}

export async function getVenueStaff(client: SupabaseClient, access: VenueAccess) {
  const { data, error } = await client
    .from("venue_staff_memberships")
    .select("id, club_id, venue_id, user_id, role, granted_at")
    .eq("club_id", access.clubId)
    .eq("venue_id", access.venueId)
    .eq("is_active", true)
    .order("granted_at", { ascending: true });
  return requiredRows<Record<string, unknown>>(data, error, "Staff").map((row) => {
    assertVenueScope(row, access);
    return {
      id: String(row.id),
      userId: String(row.user_id),
      role: String(row.role),
      grantedAt: String(row.granted_at || ""),
    } satisfies VenueStaffMember;
  });
}
