import { headers } from "next/headers";
import { isControlledVenueEvidenceAllowed } from "@/lib/controlled-venue-evidence";
import type { VenueAccess } from "@/lib/data/venue-access";

export const controlledVenueAccess: VenueAccess = {
  userId: "11111111-1111-4111-8111-111111111111",
  clubId: 24,
  venueId: "22222222-2222-4222-8222-222222222222",
  venueName: "Amahoro Matchday Bar",
  venueCity: "Kigali",
  role: "manager",
  canManageMenu: true,
  canOperateOrders: true,
  canLaunchPromotions: true,
  canVerifyTickets: true,
};

export async function isControlledVenueEvidenceRequest() {
  const requestHeaders = await headers();
  return isControlledVenueEvidenceAllowed({
    previewEnabled: process.env.AFRICLUB_ALLOW_HTTP_PREVIEW,
    venueEvidenceEnabled: process.env.AFRICLUB_CONTROLLED_VENUE_EVIDENCE,
    host: requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
  });
}

export type VenueEvidenceSearchParams = Promise<
  Record<string, string | string[] | undefined>
>;

export async function controlledVenueEvidenceState(
  searchParams: VenueEvidenceSearchParams,
) {
  if (!(await isControlledVenueEvidenceRequest())) return null;
  const value = (await searchParams).evidence;
  return typeof value === "string" ? value : "ready";
}
