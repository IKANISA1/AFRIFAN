import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

export interface AdminVenueOverview {
  venueCount: number;
  activeCampaigns: number;
  openOrders: number;
  checkinsToday: number;
}

export class AdminVenueValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminVenueValidationError";
  }
}

function record(value: unknown) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new AdminVenueValidationError("Venue overview must be an object.");
  }
  return value as Record<string, unknown>;
}

function count(value: unknown, label: string) {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < 0 ||
    value > 1_000_000_000
  ) {
    throw new AdminVenueValidationError(`${label} is invalid.`);
  }
  return value;
}

export function normalizeAdminVenueOverview(
  value: unknown,
): AdminVenueOverview {
  const overview = record(value);
  return {
    venueCount: count(overview.venueCount, "Venue count"),
    activeCampaigns: count(
      overview.activeCampaigns,
      "Active campaign count",
    ),
    openOrders: count(overview.openOrders, "Open order count"),
    checkinsToday: count(overview.checkinsToday, "Check-in count"),
  };
}

async function strictCount(
  request: PromiseLike<{
    count: number | null;
    error: { message?: string } | null;
  }>,
  label: string,
) {
  const { count: result, error } = await request;
  if (error) throw new Error(error.message);
  return count(result ?? 0, label);
}

export async function getAdminVenueOverview(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminVenueOverview> {
  if (typeof window !== "undefined") {
    return normalizeAdminVenueOverview(
      await requestAdminApi<unknown>("venues-overview", {
        signal: options.signal,
      }),
    );
  }
  const clubId = requireAdminClubId(access, "load venue oversight");
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const [venueCount, activeCampaigns, openOrders, checkinsToday] =
    await Promise.all([
      strictCount(
        client
          .from("venues")
          .select("id", { count: "exact", head: true })
          .eq("club_id", clubId)
          .in("status", ["pending_review", "approved"]),
        "Venue count",
      ),
      strictCount(
        client
          .from("venue_checkin_campaigns")
          .select("id", { count: "exact", head: true })
          .eq("club_id", clubId)
          .eq("status", "approved"),
        "Active campaign count",
      ),
      strictCount(
        client
          .from("venue_drink_orders")
          .select("id", { count: "exact", head: true })
          .eq("club_id", clubId)
          .in("status", ["created", "accepted", "preparing", "ready"]),
        "Open order count",
      ),
      strictCount(
        client
          .from("venue_checkins")
          .select("id", { count: "exact", head: true })
          .eq("club_id", clubId)
          .gte("checked_in_at", startOfToday.toISOString()),
        "Check-in count",
      ),
    ]);
  return normalizeAdminVenueOverview({
    venueCount,
    activeCampaigns,
    openOrders,
    checkinsToday,
  });
}
