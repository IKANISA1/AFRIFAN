import type { SupabaseClient } from "@supabase/supabase-js";
import type { VenueAccess } from "./venue-access";
import { safeString, toIdString } from "@/lib/utils";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const GATE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{0,31}$/;

export interface TicketVerifierAssignment {
  id: string;
  ticketEventId: string;
  gateCode: string | null;
  startsAt: string;
  endsAt: string;
}

function assignmentFromRow(
  row: Record<string, unknown>,
  access: VenueAccess,
): TicketVerifierAssignment | null {
  const id = toIdString(row.id, "");
  const ticketEventId = toIdString(row.ticket_event_id, "");
  const userId = toIdString(row.user_id, "");
  const venueId = toIdString(row.venue_id, "");
  const clubId = Number(row.club_id);
  const startsAt = safeString(row.starts_at);
  const endsAt = safeString(row.ends_at);
  const rawGate = safeString(row.gate_code).toUpperCase();
  const gateCode = rawGate.length > 0 ? rawGate : null;
  if (
    !UUID_PATTERN.test(id) ||
    !UUID_PATTERN.test(ticketEventId) ||
    userId !== access.userId ||
    venueId !== access.venueId ||
    clubId !== access.clubId ||
    !Number.isFinite(Date.parse(startsAt)) ||
    !Number.isFinite(Date.parse(endsAt)) ||
    (gateCode != null && !GATE_PATTERN.test(gateCode))
  ) {
    return null;
  }
  return { id, ticketEventId, gateCode, startsAt, endsAt };
}

export async function getActiveTicketVerifierAssignments(
  client: SupabaseClient,
  access: VenueAccess,
  now = new Date(),
): Promise<TicketVerifierAssignment[]> {
  const timestamp = now.toISOString();
  const { data, error } = await client
    .from("ticket_verifier_assignments")
    .select(
      "id, club_id, venue_id, user_id, ticket_event_id, gate_code, starts_at, ends_at",
    )
    .eq("user_id", access.userId)
    .eq("venue_id", access.venueId)
    .eq("is_active", true)
    .lte("starts_at", timestamp)
    .gt("ends_at", timestamp)
    .order("starts_at", { ascending: true })
    .limit(50);
  if (error)
    throw new Error("Ticket verifier assignments could not be loaded.");
  return (Array.isArray(data) ? data : [])
    .map((row) => assignmentFromRow(row as Record<string, unknown>, access))
    .filter((row): row is TicketVerifierAssignment => row != null);
}

export function uniqueAssignedGateCodes(
  assignments: TicketVerifierAssignment[],
): Array<string | null> {
  const values = assignments.map((assignment) => assignment.gateCode);
  return Array.from(new Set(values));
}
