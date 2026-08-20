import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PUBLIC_USER_ID_PATTERN = /^[0-9]{6}$/;
const GATE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{0,31}$/;

export type AdminTicketOrganization = {
  id: string;
  displayName: string;
  status: "draft" | "active" | "suspended" | "archived";
};

export type AdminTicketVerifierEvent = {
  id: string;
  organizationId: string;
  organizationName: string;
  venueId: string;
  venueName: string;
  matchLabel: string;
  status: "draft" | "active" | "paused" | "completed" | "cancelled";
  entryOpensAt: string;
  entryClosesAt: string;
  verificationEnabled: boolean;
};

export type AdminTicketVerifierAssignment = {
  id: string;
  ticketEventId: string;
  organizationId: string;
  organizationName: string;
  venueId: string;
  venueName: string;
  matchLabel: string;
  userId: string;
  publicUserId: string;
  userName: string;
  gateCode: string | null;
  startsAt: string;
  endsAt: string;
  isActive: boolean;
  grantedAt: string;
  revokedAt: string | null;
  updatedAt: string;
};

export type AdminTicketVerifierCandidate = {
  userId: string;
  publicUserId: string;
  displayName: string;
};

export type AdminTicketVerifierWorkspace = {
  organizations: AdminTicketOrganization[];
  events: AdminTicketVerifierEvent[];
  assignments: AdminTicketVerifierAssignment[];
};

export class AdminTicketVerifierValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminTicketVerifierValidationError";
  }
}

function record(value: unknown, label: string): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new AdminTicketVerifierValidationError(`${label} is invalid.`);
  }
  return value as Record<string, unknown>;
}

function text(value: unknown, label: string, maximum = 255): string {
  if (typeof value !== "string") {
    throw new AdminTicketVerifierValidationError(`${label} is invalid.`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maximum) {
    throw new AdminTicketVerifierValidationError(`${label} is invalid.`);
  }
  return normalized;
}

function uuid(value: unknown, label: string): string {
  const normalized = text(value, label, 36);
  if (!UUID_PATTERN.test(normalized)) {
    throw new AdminTicketVerifierValidationError(`${label} is invalid.`);
  }
  return normalized.toLowerCase();
}

function timestamp(value: unknown, label: string): string {
  const normalized = text(value, label, 64);
  if (Number.isNaN(Date.parse(normalized))) {
    throw new AdminTicketVerifierValidationError(`${label} is invalid.`);
  }
  return new Date(normalized).toISOString();
}

function nullableTimestamp(value: unknown, label: string): string | null {
  return value == null || value === "" ? null : timestamp(value, label);
}

function enumValue<T extends string>(
  value: unknown,
  allowed: ReadonlySet<T>,
  label: string,
): T {
  const normalized = text(value, label, 32) as T;
  if (!allowed.has(normalized)) {
    throw new AdminTicketVerifierValidationError(`${label} is invalid.`);
  }
  return normalized;
}

const organizationStatuses = new Set<AdminTicketOrganization["status"]>([
  "draft",
  "active",
  "suspended",
  "archived",
]);
const eventStatuses = new Set<AdminTicketVerifierEvent["status"]>([
  "draft",
  "active",
  "paused",
  "completed",
  "cancelled",
]);

function normalizeOrganization(value: unknown): AdminTicketOrganization {
  const source = record(value, "Ticket organization");
  return {
    id: uuid(source.id, "Ticket organization id"),
    displayName: text(source.displayName, "Ticket organization name", 120),
    status: enumValue(source.status, organizationStatuses, "Organization status"),
  };
}

function normalizeEvent(value: unknown): AdminTicketVerifierEvent {
  const source = record(value, "Ticket event");
  return {
    id: uuid(source.id, "Ticket event id"),
    organizationId: uuid(source.organizationId, "Ticket organization id"),
    organizationName: text(source.organizationName, "Ticket organization name", 120),
    venueId: uuid(source.venueId, "Venue id"),
    venueName: text(source.venueName, "Venue name", 160),
    matchLabel: text(source.matchLabel, "Match label", 260),
    status: enumValue(source.status, eventStatuses, "Ticket event status"),
    entryOpensAt: timestamp(source.entryOpensAt, "Entry opens at"),
    entryClosesAt: timestamp(source.entryClosesAt, "Entry closes at"),
    verificationEnabled: source.verificationEnabled === true,
  };
}

function normalizeAssignment(value: unknown): AdminTicketVerifierAssignment {
  const source = record(value, "Verifier assignment");
  const gateCode = source.gateCode == null || source.gateCode === ""
    ? null
    : text(source.gateCode, "Gate code", 32).toUpperCase();
  if (gateCode != null && !GATE_PATTERN.test(gateCode)) {
    throw new AdminTicketVerifierValidationError("Gate code is invalid.");
  }
  const publicUserId = text(source.publicUserId, "Public user id", 6);
  if (!PUBLIC_USER_ID_PATTERN.test(publicUserId)) {
    throw new AdminTicketVerifierValidationError("Public user id is invalid.");
  }
  return {
    id: uuid(source.id, "Verifier assignment id"),
    ticketEventId: uuid(source.ticketEventId, "Ticket event id"),
    organizationId: uuid(source.organizationId, "Ticket organization id"),
    organizationName: text(source.organizationName, "Ticket organization name", 120),
    venueId: uuid(source.venueId, "Venue id"),
    venueName: text(source.venueName, "Venue name", 160),
    matchLabel: text(source.matchLabel, "Match label", 260),
    userId: uuid(source.userId, "Verifier user id"),
    publicUserId,
    userName: text(source.userName, "Verifier name", 160),
    gateCode,
    startsAt: timestamp(source.startsAt, "Shift starts at"),
    endsAt: timestamp(source.endsAt, "Shift ends at"),
    isActive: source.isActive === true,
    grantedAt: timestamp(source.grantedAt, "Granted at"),
    revokedAt: nullableTimestamp(source.revokedAt, "Revoked at"),
    updatedAt: timestamp(source.updatedAt, "Assignment version"),
  };
}

export function normalizeAdminTicketVerifierWorkspace(
  value: unknown,
): AdminTicketVerifierWorkspace {
  const source = record(value, "Ticket verifier workspace");
  if (
    !Array.isArray(source.organizations) ||
    !Array.isArray(source.events) ||
    !Array.isArray(source.assignments) ||
    source.organizations.length > 50 ||
    source.events.length > 250 ||
    source.assignments.length > 500
  ) {
    throw new AdminTicketVerifierValidationError(
      "Ticket verifier workspace exceeds its safe bounds.",
    );
  }
  const workspace = {
    organizations: source.organizations.map(normalizeOrganization),
    events: source.events.map(normalizeEvent),
    assignments: source.assignments.map(normalizeAssignment),
  };
  for (const [label, ids] of [
    ["organizations", workspace.organizations.map((item) => item.id)],
    ["events", workspace.events.map((item) => item.id)],
    ["assignments", workspace.assignments.map((item) => item.id)],
  ] as const) {
    if (new Set(ids).size !== ids.length) {
      throw new AdminTicketVerifierValidationError(
        `Ticket verifier ${label} contain duplicate records.`,
      );
    }
  }
  return workspace;
}

export function normalizeAdminTicketVerifierCandidate(
  value: unknown,
): AdminTicketVerifierCandidate {
  const source = record(value, "Verifier candidate");
  const publicUserId = text(source.publicUserId, "Public user id", 6);
  if (!PUBLIC_USER_ID_PATTERN.test(publicUserId)) {
    throw new AdminTicketVerifierValidationError("Public user id is invalid.");
  }
  return {
    userId: uuid(source.userId, "Verifier user id"),
    publicUserId,
    displayName: text(source.displayName, "Verifier display name", 160),
  };
}

function requireClubAdmin(
  access: Pick<AdminAccess, "hasAccess" | "isSuperAdmin" | "role" | "clubId">,
) {
  const allowed = access.hasAccess && access.clubId != null && (
    access.isSuperAdmin ||
    access.role === "super_admin" ||
    access.role === "admin" ||
    access.role === "club_admin"
  );
  if (!allowed) {
    throw new AdminTicketVerifierValidationError(
      "Club-admin authority is required to manage ticket verifiers.",
    );
  }
}

export async function getAdminTicketVerifierWorkspace(
  _client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
) {
  requireClubAdmin(access);
  return normalizeAdminTicketVerifierWorkspace(
    await requestAdminApi<unknown>("ticket-verifiers", {
      signal: options.signal,
    }),
  );
}

export async function findAdminTicketVerifierCandidate(
  _client: SupabaseClient,
  access: AdminAccess,
  publicUserId: string,
) {
  requireClubAdmin(access);
  const normalized = publicUserId.trim();
  if (!PUBLIC_USER_ID_PATTERN.test(normalized)) {
    throw new AdminTicketVerifierValidationError(
      "Enter the verifier's 6-digit public user id.",
    );
  }
  return normalizeAdminTicketVerifierCandidate(
    await requestAdminApi<unknown>("ticket-verifiers", {
      query: { public_user_id: normalized },
    }),
  );
}

export async function grantAdminTicketVerifierAssignment(
  _client: SupabaseClient,
  access: AdminAccess,
  input: {
    ticketEventId: string;
    userId: string;
    gateCode?: string | null;
    startsAt: string;
    endsAt: string;
  },
) {
  requireClubAdmin(access);
  const gateCode = input.gateCode?.trim().toUpperCase() || null;
  if (gateCode != null && !GATE_PATTERN.test(gateCode)) {
    throw new AdminTicketVerifierValidationError(
      "Gate codes may use A-Z, 0-9, underscores, and hyphens.",
    );
  }
  const startsAt = timestamp(input.startsAt, "Shift starts at");
  const endsAt = timestamp(input.endsAt, "Shift ends at");
  if (Date.parse(endsAt) <= Date.parse(startsAt)) {
    throw new AdminTicketVerifierValidationError(
      "Shift end must be after shift start.",
    );
  }
  return await requestAdminApi<string>("ticket-verifiers", {
    method: "POST",
    body: {
      action: "grant",
      ticketEventId: uuid(input.ticketEventId, "Ticket event id"),
      userId: uuid(input.userId, "Verifier user id"),
      gateCode,
      startsAt,
      endsAt,
    },
  });
}

export async function revokeAdminTicketVerifierAssignment(
  _client: SupabaseClient,
  access: AdminAccess,
  assignment: Pick<AdminTicketVerifierAssignment, "id" | "updatedAt">,
) {
  requireClubAdmin(access);
  await requestAdminApi<{ success: true }>("ticket-verifiers", {
    method: "POST",
    body: {
      action: "revoke",
      assignmentId: uuid(assignment.id, "Verifier assignment id"),
      expectedUpdatedAt: timestamp(
        assignment.updatedAt,
        "Verifier assignment version",
      ),
    },
  });
}
