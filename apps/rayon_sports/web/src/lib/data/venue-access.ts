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
  canVerifyTickets?: boolean;
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

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const VENUE_ACCESS_TIMEOUT_MS = 12_000;

function boundedText(value: unknown, maxLength: number) {
  const normalized = safeString(value);
  return normalized.length > 0 && normalized.length <= maxLength
    ? normalized
    : null;
}

async function withVenueAccessTimeout<T>(operation: PromiseLike<T>) {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Promise.resolve(operation),
      new Promise<never>((_resolve, reject) => {
        timeoutId = setTimeout(
          () => reject(new Error("Venue authorization timed out")),
          VENUE_ACCESS_TIMEOUT_MS,
        );
      }),
    ]);
  } finally {
    if (timeoutId != null) clearTimeout(timeoutId);
  }
}

export function deriveVenueAccess(
  user: User,
  membership: MembershipRow,
  venue: Record<string, unknown>,
): VenueAccess | null {
  const venueId = toIdString(membership.venue_id, "");
  const clubId = Number(membership.club_id);
  const role = safeString(membership.role) as VenueStaffRole;
  const userId = toIdString(user.id, "");
  const venueName = boundedText(venue.display_name, 120);
  const venueCity = boundedText(venue.city, 80) ?? "";
  if (
    !UUID_PATTERN.test(userId) ||
    !UUID_PATTERN.test(venueId) ||
    !Number.isSafeInteger(clubId) ||
    clubId <= 0 ||
    !["owner", "manager", "staff", "reviewer"].includes(role) ||
    toIdString(venue.id, "") !== venueId ||
    Number(venue.club_id) !== clubId ||
    venueName == null
  ) {
    return null;
  }

  return {
    userId,
    clubId,
    venueId,
    venueName,
    venueCity,
    role,
    canManageMenu: role === "owner" || role === "manager",
    canOperateOrders: role !== "reviewer",
    canLaunchPromotions: role === "owner" || role === "manager",
  };
}

export const resolveVenueAccess = cache(
  async (): Promise<VenueAccessResult> => {
    const client = await getServerSupabase();
    if (client == null) return { status: "not_configured" };

    let authResult;
    try {
      authResult = await withVenueAccessTimeout(client.auth.getUser());
    } catch {
      const id = correlationId();
      console.error("Venue authentication lookup failed", {
        correlationId: id,
      });
      return { status: "service_error", correlationId: id };
    }
    const { data: authData, error: authError } = authResult;
    if (authError) {
      const id = correlationId();
      console.error("Venue authentication lookup failed", {
        correlationId: id,
      });
      return { status: "service_error", correlationId: id };
    }
    if (authData.user == null) return { status: "signed_out" };

    let membershipResult;
    try {
      membershipResult = await withVenueAccessTimeout(
        client
          .from("venue_staff_memberships")
          .select("club_id, venue_id, role")
          .eq("user_id", authData.user.id)
          .eq("is_active", true)
          .order("granted_at", { ascending: true })
          .limit(1),
      );
    } catch {
      const id = correlationId();
      console.error("Venue membership lookup failed", { correlationId: id });
      return { status: "service_error", correlationId: id };
    }
    const { data: memberships, error: membershipError } = membershipResult;

    if (membershipError) {
      const id = correlationId();
      console.error("Venue membership lookup failed", { correlationId: id });
      return { status: "service_error", correlationId: id };
    }
    const membership = Array.isArray(memberships) ? memberships[0] : null;
    if (membership == null) return { status: "forbidden" };

    const venueId = toIdString((membership as MembershipRow).venue_id, "");
    const clubId = Number((membership as MembershipRow).club_id);
    let venueResult;
    try {
      venueResult = await withVenueAccessTimeout(
        client
          .from("venues")
          .select("id, club_id, display_name, city")
          .eq("id", venueId)
          .eq("club_id", clubId)
          .maybeSingle(),
      );
    } catch {
      const id = correlationId();
      console.error("Assigned venue lookup failed", { correlationId: id });
      return { status: "service_error", correlationId: id };
    }
    const { data: venue, error: venueError } = venueResult;

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
  },
);
