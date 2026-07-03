import type { SupabaseClient } from "@supabase/supabase-js";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import { safeNumber, safeString, toIdString } from "@/lib/utils";

export interface PublicVenueProfile {
  id: string;
  displayName: string;
  slug: string;
  city: string;
  summary: string;
  status: string;
}

export interface VenuePortalSnapshot {
  venueCount: number;
  activeCampaigns: number;
  openOrders: number;
  checkinsToday: number;
  staffCanOperate: boolean;
  safeTvCode: {
    code: string;
    expiresAt: string;
    rewardLabel: string;
  };
}

export interface VenueGovernanceItem {
  id: string;
  label: string;
  detail: string;
  status: string;
  actionLabel: string;
}

export interface VenueGovernanceSnapshot extends VenuePortalSnapshot {
  onboardingQueue: VenueGovernanceItem[];
  staffAssignments: VenueGovernanceItem[];
  campaignControls: VenueGovernanceItem[];
  fetControls: VenueGovernanceItem[];
  auditEvents: VenueGovernanceItem[];
  complianceFlags: VenueGovernanceItem[];
  exportCsv: string;
}

export const emptyVenuePortalSnapshot: VenuePortalSnapshot = {
  venueCount: 0,
  activeCampaigns: 0,
  openOrders: 0,
  checkinsToday: 0,
  staffCanOperate: false,
  safeTvCode: {
    code: "STAFF ONLY",
    expiresAt: "Pending venue approval",
    rewardLabel: "Approved campaigns only",
  },
};

export const emptyVenueGovernanceSnapshot: VenueGovernanceSnapshot = {
  ...emptyVenuePortalSnapshot,
  onboardingQueue: [
    {
      id: "onboarding-review",
      label: "Pending public profile review",
      detail:
        "Confirm venue status, city, radius policy, and approved public copy.",
      status: "Needs club approval",
      actionLabel: "Approve profile",
    },
  ],
  staffAssignments: [
    {
      id: "staff-assignment",
      label: "Assign venue operator",
      detail: "Owner, manager, and staff roles are scoped to one venue.",
      status: "Admin only",
      actionLabel: "Assign staff",
    },
  ],
  campaignControls: [
    {
      id: "campaign-approval",
      label: "Check-in campaign approval",
      detail:
        "Review dates, FET budget, location rules, and max check-ins per supporter.",
      status: "Approval required",
      actionLabel: "Approve campaign",
    },
    {
      id: "campaign-disable",
      label: "Disable campaign",
      detail:
        "Pause rewards immediately when abuse, budget, or compliance review starts.",
      status: "Fails closed",
      actionLabel: "Disable",
    },
  ],
  fetControls: [
    {
      id: "fet-export",
      label: "FET export",
      detail:
        "Export check-in awards, reservations, reversals, and campaign events.",
      status: "Closed-loop only",
      actionLabel: "Download CSV",
    },
    {
      id: "fet-reversal",
      label: "Reversal readiness",
      detail: "Reasoned reversals require approval before ledger adjustment.",
      status: "Approval gated",
      actionLabel: "Prepare reversal",
    },
  ],
  auditEvents: [
    {
      id: "order-audit",
      label: "Order status audit",
      detail:
        "Created, accepted, preparing, ready, served, and cancelled events stay visible.",
      status: "Event trail",
      actionLabel: "View audit",
    },
  ],
  complianceFlags: [
    {
      id: "location-retention",
      label: "Location retention",
      detail:
        "Location is foreground-only and must remain privacy-reviewed before release.",
      status: "Review required",
      actionLabel: "Flag review",
    },
    {
      id: "alcohol-age-gate",
      label: "Alcohol age gate",
      detail:
        "Alcohol items remain blocked unless staff procedure and copy are approved.",
      status: "Blocked",
      actionLabel: "Keep blocked",
    },
  ],
  exportCsv:
    "control,status,owner\nFET export,Closed-loop only,Admin\nReversal readiness,Approval gated,Finance\nCampaign approval,Approval required,Club admin\n",
};

export const fallbackVenueProfiles: PublicVenueProfile[] = [];

function mapVenue(row: Record<string, unknown>): PublicVenueProfile {
  return {
    id: toIdString(row.id, ""),
    displayName: safeString(row.display_name, "Partner venue"),
    slug: safeString(row.slug),
    city: safeString(row.city, "Kigali"),
    summary:
      safeString(row.public_summary) ||
      "Approved partner venue profile will appear after club review.",
    status: safeString(row.status, "pending_review"),
  };
}

async function safeMaybeCount(
  request: PromiseLike<{
    count: number | null;
    error: { message?: string } | null;
  }>,
) {
  const { count, error } = await request;
  return error ? 0 : (count ?? 0);
}

export async function getApprovedPublicVenues(
  client: SupabaseClient | null = getReadOnlySupabase(),
): Promise<PublicVenueProfile[]> {
  if (client == null) {
    return fallbackVenueProfiles;
  }

  const response = await client
    .from("venues")
    .select("id, display_name, slug, city, public_summary, status")
    .eq("approved_public_profile", true)
    .eq("status", "approved")
    .order("display_name", { ascending: true })
    .limit(12);

  if (response.error || !Array.isArray(response.data)) {
    return fallbackVenueProfiles;
  }

  return response.data.map((row) => mapVenue(row as Record<string, unknown>));
}

export async function getVenuePortalSnapshot(
  client: SupabaseClient | null = getReadOnlySupabase(),
): Promise<VenuePortalSnapshot> {
  if (client == null) {
    return emptyVenuePortalSnapshot;
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [venueCount, activeCampaigns, openOrders, checkinsToday] =
    await Promise.all([
      safeMaybeCount(
        client
          .from("venues")
          .select("id", { count: "exact", head: true })
          .in("status", ["pending_review", "approved"]),
      ),
      safeMaybeCount(
        client
          .from("venue_checkin_campaigns")
          .select("id", { count: "exact", head: true })
          .eq("status", "approved"),
      ),
      safeMaybeCount(
        client
          .from("venue_drink_orders")
          .select("id", { count: "exact", head: true })
          .in("status", ["created", "accepted", "preparing", "ready"]),
      ),
      safeMaybeCount(
        client
          .from("venue_checkins")
          .select("id", { count: "exact", head: true })
          .gte("checked_in_at", today.toISOString()),
      ),
    ]);

  return {
    ...emptyVenuePortalSnapshot,
    venueCount: safeNumber(venueCount, 0),
    activeCampaigns: safeNumber(activeCampaigns, 0),
    openOrders: safeNumber(openOrders, 0),
    checkinsToday: safeNumber(checkinsToday, 0),
  };
}

export async function getVenueGovernanceSnapshot(
  client: SupabaseClient | null = getReadOnlySupabase(),
): Promise<VenueGovernanceSnapshot> {
  const portal = await getVenuePortalSnapshot(client);

  return {
    ...emptyVenueGovernanceSnapshot,
    ...portal,
    exportCsv: [
      "metric,value",
      `venues,${portal.venueCount}`,
      `active_campaigns,${portal.activeCampaigns}`,
      `open_orders,${portal.openOrders}`,
      `checkins_today,${portal.checkinsToday}`,
    ].join("\n"),
  };
}
