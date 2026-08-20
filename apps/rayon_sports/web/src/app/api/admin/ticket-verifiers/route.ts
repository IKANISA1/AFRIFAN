import { NextRequest } from "next/server";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  AdminApiAuthorizationError,
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";
import { AdminMutationConflictError } from "@/lib/data/admin/helpers";
import type { AdminAccess } from "@/lib/types";

export const dynamic = "force-dynamic";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PUBLIC_USER_ID_PATTERN = /^[0-9]{6}$/;
const GATE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{0,31}$/;

function clubIdFor(access: AdminAccess): number {
  const clubId = Number(access.clubId);
  if (!Number.isSafeInteger(clubId) || clubId < 1) {
    throw new AdminApiAuthorizationError("An active club scope is required.");
  }
  return clubId;
}

function requireClubAdmin(access: AdminAccess) {
  const allowed = access.isSuperAdmin ||
    access.role === "super_admin" ||
    access.role === "admin" ||
    access.role === "club_admin";
  if (!allowed || !access.userId) {
    throw new AdminApiAuthorizationError(
      "Club-admin authority is required to manage ticket verifiers.",
    );
  }
}

function uuid(value: unknown, label: string): string {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!UUID_PATTERN.test(normalized)) {
    throw new AdminApiValidationError(`${label} is invalid.`);
  }
  return normalized.toLowerCase();
}

function timestamp(value: unknown, label: string): string {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (
    !normalized ||
    normalized.length > 64 ||
    Number.isNaN(Date.parse(normalized))
  ) {
    throw new AdminApiValidationError(`${label} is invalid.`);
  }
  return new Date(normalized).toISOString();
}

function nestedRecord(value: unknown): Record<string, unknown> {
  const candidate = Array.isArray(value) ? value[0] : value;
  return candidate != null && typeof candidate === "object" &&
      !Array.isArray(candidate)
    ? candidate as Record<string, unknown>
    : {};
}

function safeText(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim()
    ? value.trim()
    : fallback;
}

async function loadWorkspace(client: SupabaseClient, clubId: number) {
  const [organizationResponse, eventResponse, assignmentResponse] = await Promise.all([
    client
      .from("ticket_organizations")
      .select("id, display_name, status")
      .eq("club_id", clubId)
      .order("display_name", { ascending: true })
      .limit(50),
    client
      .from("ticket_events")
      .select(
        "id, organization_id, venue_id, status, entry_opens_at, entry_closes_at, verification_enabled, matches:match_id(home_team, away_team), venues:venue_id(display_name)",
      )
      .eq("club_id", clubId)
      .order("entry_opens_at", { ascending: false })
      .limit(250),
    client
      .from("ticket_verifier_assignments")
      .select(
        "id, organization_id, ticket_event_id, venue_id, user_id, gate_code, starts_at, ends_at, is_active, granted_at, revoked_at, updated_at",
      )
      .eq("club_id", clubId)
      .order("granted_at", { ascending: false })
      .limit(500),
  ]);

  if (organizationResponse.error || eventResponse.error || assignmentResponse.error) {
    throw new Error("Ticket verifier workspace could not be loaded.");
  }

  const organizationRows = (organizationResponse.data ?? []) as Record<string, unknown>[];
  const eventRows = (eventResponse.data ?? []) as Record<string, unknown>[];
  const assignmentRows = (assignmentResponse.data ?? []) as Record<string, unknown>[];
  const userIds = [...new Set(
    assignmentRows
      .map((row) => safeText(row.user_id, ""))
      .filter(Boolean),
  )];
  const profileResponse = userIds.length > 0
    ? await client
      .from("profiles")
      .select("id, public_user_id, display_name, full_name")
      .in("id", userIds)
    : { data: [], error: null };
  if (profileResponse.error) {
    throw new Error("Ticket verifier profiles could not be loaded.");
  }

  const organizations = organizationRows.map((row) => ({
    id: row.id,
    displayName: safeText(row.display_name, "Ticket organization"),
    status: row.status,
  }));
  const organizationById = new Map(
    organizations.map((organization) => [String(organization.id), organization]),
  );
  const events = eventRows.map((row) => {
    const match = nestedRecord(row.matches);
    const venue = nestedRecord(row.venues);
    const homeTeam = safeText(match.home_team, "Home team");
    const awayTeam = safeText(match.away_team, "Away team");
    const organization = organizationById.get(String(row.organization_id));
    return {
      id: row.id,
      organizationId: row.organization_id,
      organizationName: organization?.displayName ?? "Ticket organization",
      venueId: row.venue_id,
      venueName: safeText(venue.display_name, "Venue"),
      matchLabel: `${homeTeam} vs ${awayTeam}`,
      status: row.status,
      entryOpensAt: row.entry_opens_at,
      entryClosesAt: row.entry_closes_at,
      verificationEnabled: row.verification_enabled === true,
    };
  });
  const eventById = new Map(events.map((event) => [String(event.id), event]));
  const profileById = new Map(
    ((profileResponse.data ?? []) as Record<string, unknown>[]).map((profile) => [
      String(profile.id),
      profile,
    ]),
  );
  const assignments = assignmentRows.flatMap((row) => {
    const event = eventById.get(String(row.ticket_event_id));
    const profile = profileById.get(String(row.user_id));
    if (!event || !profile) return [];
    return [{
      id: row.id,
      ticketEventId: row.ticket_event_id,
      organizationId: row.organization_id,
      organizationName: event.organizationName,
      venueId: row.venue_id,
      venueName: event.venueName,
      matchLabel: event.matchLabel,
      userId: row.user_id,
      publicUserId: profile.public_user_id,
      userName: safeText(
        profile.display_name,
        safeText(profile.full_name, "Registered supporter"),
      ),
      gateCode: row.gate_code,
      startsAt: row.starts_at,
      endsAt: row.ends_at,
      isActive: row.is_active === true,
      grantedAt: row.granted_at,
      revokedAt: row.revoked_at,
      updatedAt: row.updated_at,
    }];
  });

  return { organizations, events, assignments };
}

async function findCandidate(
  client: SupabaseClient,
  clubId: number,
  publicUserId: string,
) {
  if (!PUBLIC_USER_ID_PATTERN.test(publicUserId)) {
    throw new AdminApiValidationError(
      "Enter the verifier's 6-digit public user id.",
      "TICKET_VERIFIER_USER_ID_INVALID",
    );
  }
  const { data, error } = await client
    .from("profiles")
    .select("id, public_user_id, display_name, full_name")
    .eq("club_id", clubId)
    .eq("public_user_id", publicUserId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) {
    throw new Error("Verifier candidate lookup failed.");
  }
  if (!data) {
    throw new AdminApiValidationError(
      "No active club profile matched that public user id.",
      "TICKET_VERIFIER_NOT_FOUND",
    );
  }
  return {
    userId: data.id,
    publicUserId: data.public_user_id,
    displayName: safeText(
      data.display_name,
      safeText(data.full_name, "Registered supporter"),
    ),
  };
}

function safeRpcError(message: string | undefined): Error {
  const normalized = message?.toLowerCase() ?? "";
  if (normalized.includes("changed after it was loaded")) {
    return new AdminMutationConflictError();
  }
  if (normalized.includes("already exists")) {
    return new AdminApiValidationError(
      "That verifier already has an active assignment for this event and gate.",
      "TICKET_VERIFIER_DUPLICATE",
    );
  }
  if (normalized.includes("active profile")) {
    return new AdminApiValidationError(
      "The selected user no longer has an active profile in this club.",
      "TICKET_VERIFIER_PROFILE_INACTIVE",
    );
  }
  if (normalized.includes("entry window")) {
    return new AdminApiValidationError(
      "The verifier shift must stay inside the event entry window.",
      "TICKET_VERIFIER_WINDOW_INVALID",
    );
  }
  return new Error("Ticket verifier assignment could not be changed.");
}

export async function GET(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (client, access) => {
      requireClubAdmin(access);
      const clubId = clubIdFor(access);
      const candidateId = request.nextUrl.searchParams.get("public_user_id")?.trim();
      if (candidateId) {
        return findCandidate(client, clubId, candidateId);
      }
      return loadWorkspace(client, clubId);
    },
    {
      featureGuard: { featureKey: "ticketing", mode: "route" },
      operationTimeoutMs: 12_000,
    },
  );
}

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (client, access) => {
      requireClubAdmin(access);
      const clubId = clubIdFor(access);
      const serviceClient = client as unknown as SupabaseClient;
      const body = (await request.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      const action = typeof body.action === "string" ? body.action.trim() : "";
      if (action === "grant") {
        const startsAt = timestamp(body.startsAt, "Shift start");
        const endsAt = timestamp(body.endsAt, "Shift end");
        if (Date.parse(endsAt) <= Date.parse(startsAt)) {
          throw new AdminApiValidationError(
            "Shift end must be after shift start.",
            "TICKET_VERIFIER_WINDOW_INVALID",
          );
        }
        const gateCode = typeof body.gateCode === "string" && body.gateCode.trim()
          ? body.gateCode.trim().toUpperCase()
          : null;
        if (gateCode != null && !GATE_PATTERN.test(gateCode)) {
          throw new AdminApiValidationError(
            "Gate code is invalid.",
            "TICKET_VERIFIER_GATE_INVALID",
          );
        }
        const { data, error } = await serviceClient.rpc(
          "grant_ticket_verifier_assignment",
          {
            p_actor_id: access.userId,
            p_club_id: clubId,
            p_ticket_event_id: uuid(body.ticketEventId, "Ticket event id"),
            p_target_user_id: uuid(body.userId, "Verifier user id"),
            p_gate_code: gateCode,
            p_starts_at: startsAt,
            p_ends_at: endsAt,
          },
        );
        if (error || typeof data !== "string") {
          throw safeRpcError(error?.message);
        }
        return data;
      }

      if (action === "revoke") {
        const { data, error } = await serviceClient.rpc(
          "revoke_ticket_verifier_assignment",
          {
            p_actor_id: access.userId,
            p_club_id: clubId,
            p_assignment_id: uuid(body.assignmentId, "Verifier assignment id"),
            p_expected_updated_at: timestamp(
              body.expectedUpdatedAt,
              "Verifier assignment version",
            ),
          },
        );
        if (error || data !== true) {
          throw safeRpcError(error?.message);
        }
        return { success: true };
      }

      throw new AdminApiValidationError(
        "Choose a supported verifier assignment action.",
        "TICKET_VERIFIER_ACTION_INVALID",
      );
    },
    {
      featureGuard: { featureKey: "ticketing", mode: "action" },
      rateLimitKey: "admin:ticket-verifier-assignment",
      mutationLimit: 30,
      operationTimeoutMs: 12_000,
    },
  );
}
