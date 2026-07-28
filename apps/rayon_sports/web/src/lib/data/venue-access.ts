import type { SupabaseClient, User } from "@supabase/supabase-js";
import { cache } from "react";
import { getServerSupabase } from "@/lib/supabase/server";
import { safeString, toIdString } from "@/lib/utils";

export type VenueStaffRole = "owner" | "manager" | "staff" | "reviewer";

export interface VenueAccess {
  userId: string;
  clubId: number;
  venueId: string;
  venueName: string;
  venueCity: string;
  role: VenueStaffRole;
  canManageMenu: boolean;
  canOperateOrders: boolean;
  canLaunchPromotions: boolean;
}

export type VenueAccessResult =
  | { status: "ready"; client: SupabaseClient; user: User; access: VenueAccess }
  | { status: "not_configured" }
  | { status: "signed_out" }
  | { status: "forbidden" }
  | { status: "service_error"; correlationId: string };

interface MembershipRow {
  club_id?: unknown;
  venue_id?: unknown;
  role?: unknown;
}

function correlationId() {
  return `venue-${crypto.randomUUID()}`;
}

export function deriveVenueAccess(
  user: User,
  membership: MembershipRow,
  venue: Record<string, unknown>,
): VenueAccess | null {
  const venueId = toIdString(membership.venue_id, "");
  const clubId = Number(membership.club_id);
  const role = safeString(membership.role) as VenueStaffRole;
  if (
    !venueId ||
    !Number.isSafeInteger(clubId) ||
    clubId <= 0 ||
    !["owner", "manager", "staff", "reviewer"].includes(role) ||
    toIdString(venue.id, "") !== venueId ||
    Number(venue.club_id) !== clubId
  ) {
    return null;
  }

  return {
    userId: user.id,
    clubId,
    venueId,
    venueName: safeString(venue.display_name, "Assigned venue"),
    venueCity: safeString(venue.city, ""),
    role,
    canManageMenu: role === "owner" || role === "manager",
    canOperateOrders: role !== "reviewer",
    canLaunchPromotions: role === "owner" || role === "manager",
  };
}

export const resolveVenueAccess = cache(async (): Promise<VenueAccessResult> => {
  const client = await getServerSupabase();
  if (client == null) return { status: "not_configured" };

  const { data: authData, error: authError } = await client.auth.getUser();
  if (authError || authData.user == null) return { status: "signed_out" };

  const { data: memberships, error: membershipError } = await client
    .from("venue_staff_memberships")
    .select("club_id, venue_id, role")
    .eq("user_id", authData.user.id)
    .eq("is_active", true)
    .order("granted_at", { ascending: true })
    .limit(1);

  if (membershipError) {
    const id = correlationId();
    console.error("Venue membership lookup failed", { correlationId: id });
    return { status: "service_error", correlationId: id };
  }
  const membership = Array.isArray(memberships) ? memberships[0] : null;
  if (membership == null) return { status: "forbidden" };

  const venueId = toIdString((membership as MembershipRow).venue_id, "");
  const clubId = Number((membership as MembershipRow).club_id);
  const { data: venue, error: venueError } = await client
    .from("venues")
    .select("id, club_id, display_name, city")
    .eq("id", venueId)
    .eq("club_id", clubId)
    .maybeSingle();

  if (venueError) {
    const id = correlationId();
    console.error("Assigned venue lookup failed", { correlationId: id });
    return { status: "service_error", correlationId: id };
  }
  if (venue == null) return { status: "forbidden" };

  const access = deriveVenueAccess(
    authData.user,
    membership as MembershipRow,
    venue as Record<string, unknown>,
  );
  return access == null
    ? { status: "forbidden" }
    : { status: "ready", client, user: authData.user, access };
});
