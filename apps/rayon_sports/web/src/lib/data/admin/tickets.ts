/**
 * Admin ticketing — bounded, scope-safe ticket operations.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, TicketOrder } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  AdminMutationConflictError,
  requireAdminClubId,
  requireExpectedUpdatedAt,
} from "./helpers";

export const MAX_ADMIN_TICKET_ORDERS = 500;
const MAX_ADMIN_TICKET_MUTATION = 100;
const idPattern = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/;
const ticketProjection = `
  id,
  match_id,
  user_id,
  seat_type,
  amount_paid,
  status,
  purchased_at,
  created_at,
  updated_at,
  momo_reference,
  profiles:user_id (full_name, phone),
  matches:match_id (home_team, away_team)
`;

export type AdminTicketStatus =
  | "pending"
  | "valid"
  | "used"
  | "cancelled"
  | "voided"
  | "refunded";

export type AdminTicketStatusAction = Extract<
  AdminTicketStatus,
  "valid" | "used" | "cancelled"
>;

export interface AdminTicketOrder extends TicketOrder {
  updatedAt: string;
  userName?: string;
  userPhone?: string;
  matchTitle?: string;
  momoReference?: string;
}

export class AdminTicketValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminTicketValidationError";
  }
}

const ticketStatuses = new Set<AdminTicketStatus>([
  "pending",
  "valid",
  "used",
  "cancelled",
  "voided",
  "refunded",
]);

const ticketStatusTransitions: Record<
  AdminTicketStatus,
  readonly AdminTicketStatusAction[]
> = {
  pending: ["valid", "cancelled"],
  valid: ["used", "cancelled"],
  used: [],
  cancelled: [],
  voided: [],
  refunded: [],
};

function record(value: unknown, label: string) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new AdminTicketValidationError(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function boundedString(
  value: unknown,
  label: string,
  maxLength: number,
  { allowEmpty = false, nullable = false } = {},
) {
  if (value == null && nullable) return null;
  if (typeof value !== "string") {
    throw new AdminTicketValidationError(`${label} must be text.`);
  }
  const normalized = value.trim();
  if (!normalized && !allowEmpty) {
    throw new AdminTicketValidationError(`${label} is required.`);
  }
  if (normalized.length > maxLength) {
    throw new AdminTicketValidationError(`${label} is too long.`);
  }
  return normalized;
}

function optionalString(value: unknown, label: string, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedString(value, label, maxLength, { nullable: true });
}

function identifier(value: unknown, label: string) {
  const normalized = boundedString(value, label, 128);
  if (normalized == null || !idPattern.test(normalized)) {
    throw new AdminTicketValidationError(`${label} is invalid.`);
  }
  return normalized;
}

function amount(value: unknown) {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > 1_000_000_000
  ) {
    throw new AdminTicketValidationError("Ticket payment amount is invalid.");
  }
  return value;
}

function timestamp(value: unknown, label: string) {
  const normalized = boundedString(value, label, 64);
  if (normalized == null || Number.isNaN(Date.parse(normalized))) {
    throw new AdminTicketValidationError(`${label} is invalid.`);
  }
  return new Date(normalized).toISOString();
}

function loadedVersion(value: unknown) {
  const normalized = requireExpectedUpdatedAt(
    typeof value === "string" ? value : null,
  );
  return timestamp(normalized, "Ticket loaded version");
}

function status(value: unknown): AdminTicketStatus {
  const normalized = boundedString(value, "Ticket status", 24) as string;
  if (!ticketStatuses.has(normalized as AdminTicketStatus)) {
    throw new AdminTicketValidationError("Ticket status is invalid.");
  }
  return normalized as AdminTicketStatus;
}

function normalizeTicketOrder(value: unknown): AdminTicketOrder {
  const order = record(value, "Ticket order");
  return {
    id: identifier(order.id, "Ticket id"),
    matchId: identifier(order.matchId, "Match id"),
    userId: identifier(order.userId, "Supporter id"),
    seatType: boundedString(order.seatType, "Ticket type", 80) as string,
    amountPaid: amount(order.amountPaid),
    status: status(order.status),
    qrCode: null,
    purchasedAt: timestamp(order.purchasedAt, "Ticket purchase time"),
    updatedAt: loadedVersion(order.updatedAt),
    userName: boundedString(order.userName, "Supporter name", 160) as string,
    userPhone:
      optionalString(order.userPhone, "Supporter phone", 40) ?? "Not available",
    matchTitle: boundedString(order.matchTitle, "Match title", 240) as string,
    momoReference:
      optionalString(order.momoReference, "Payment reference", 160) ?? "",
  };
}

function mapTicketOrder(row: Record<string, unknown>) {
  const profile = record(row.profiles, "Ticket supporter");
  const match = record(row.matches, "Ticket match");
  const homeTeam = boundedString(match.home_team, "Home team", 120) as string;
  const awayTeam = boundedString(match.away_team, "Away team", 120) as string;
  return normalizeTicketOrder({
    id: row.id == null ? null : String(row.id),
    matchId: row.match_id == null ? null : String(row.match_id),
    userId: row.user_id == null ? null : String(row.user_id),
    seatType: row.seat_type,
    amountPaid: row.amount_paid,
    status: row.status,
    purchasedAt: row.purchased_at ?? row.created_at,
    updatedAt: row.updated_at,
    userName: profile.full_name,
    userPhone: profile.phone,
    matchTitle: `${homeTeam} vs ${awayTeam}`,
    momoReference: row.momo_reference,
  });
}

export function normalizeAdminTicketOrders(value: unknown) {
  if (!Array.isArray(value)) {
    throw new AdminTicketValidationError("Ticket orders must be a list.");
  }
  if (value.length > MAX_ADMIN_TICKET_ORDERS) {
    throw new AdminTicketValidationError("Ticket orders exceed the safe limit.");
  }
  const orders = value.map(normalizeTicketOrder);
  if (new Set(orders.map((order) => order.id)).size !== orders.length) {
    throw new AdminTicketValidationError(
      "Ticket orders contain duplicate records.",
    );
  }
  return orders;
}

export function isAdminTicketStatusAction(
  value: string,
): value is AdminTicketStatusAction {
  return value === "valid" || value === "used" || value === "cancelled";
}

export function canAdminTransitionTicketStatus(
  access: Pick<AdminAccess, "hasAccess" | "isSuperAdmin" | "role">,
  currentStatus: string,
  nextStatus: AdminTicketStatusAction,
) {
  const permission = getAdminTicketTargetPermission(access, nextStatus);
  if (!permission.allowed) return permission;
  const normalizedCurrent = currentStatus.toLowerCase() as AdminTicketStatus;
  const allowedTargets = ticketStatusTransitions[normalizedCurrent] ?? [];
  if (!allowedTargets.includes(nextStatus)) {
    return {
      allowed: false,
      reason: `A ${normalizedCurrent || "unknown"} ticket cannot move to ${nextStatus}.`,
    };
  }
  return { allowed: true, reason: null };
}

export function getAdminTicketTargetPermission(
  access: Pick<AdminAccess, "hasAccess" | "isSuperAdmin" | "role">,
  nextStatus: AdminTicketStatusAction,
) {
  if (!access.hasAccess) {
    return { allowed: false, reason: "Admin access is required." };
  }
  const roleCanOperate =
    access.isSuperAdmin ||
    access.role === "super_admin" ||
    access.role === "admin" ||
    access.role === "club_admin" ||
    access.role === "club_moderator";
  if (!roleCanOperate) {
    return {
      allowed: false,
      reason: "Your role cannot operate ticket status changes.",
    };
  }
  if (
    nextStatus === "cancelled" &&
    !access.isSuperAdmin &&
    access.role !== "super_admin" &&
    access.role !== "admin" &&
    access.role !== "club_admin"
  ) {
    return {
      allowed: false,
      reason: "Ticket cancellation requires club-admin authority.",
    };
  }
  return { allowed: true, reason: null };
}

export function getAdminTicketBulkEligibility(
  access: Pick<AdminAccess, "hasAccess" | "isSuperAdmin" | "role">,
  orders: readonly Pick<AdminTicketOrder, "status">[],
  nextStatus: AdminTicketStatusAction,
) {
  if (orders.length > MAX_ADMIN_TICKET_MUTATION) {
    return {
      allowed: false,
      blocked: orders.length,
      total: orders.length,
    };
  }
  const blocked = orders.filter(
    (order) =>
      !canAdminTransitionTicketStatus(access, order.status, nextStatus).allowed,
  ).length;
  return {
    allowed: orders.length > 0 && blocked === 0,
    blocked,
    total: orders.length,
  };
}

export async function getAdminTicketOrders(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminTicketOrder[]> {
  if (typeof window !== "undefined") {
    return normalizeAdminTicketOrders(
      await requestAdminApi<unknown>("tickets", { signal: options.signal }),
    );
  }
  const clubId = requireAdminClubId(access, "load ticket orders");
  const { data, error } = await client
    .from("tickets")
    .select(ticketProjection)
    .eq("club_id", clubId)
    .order("purchased_at", { ascending: false })
    .limit(MAX_ADMIN_TICKET_ORDERS + 1);
  if (error) throw new Error(error.message);
  if (!Array.isArray(data)) {
    throw new AdminTicketValidationError("Ticket order response is invalid.");
  }
  if (data.length > MAX_ADMIN_TICKET_ORDERS) {
    throw new AdminTicketValidationError("Ticket orders exceed the safe limit.");
  }
  return data.map((row) => mapTicketOrder(row as Record<string, unknown>));
}

export type AdminTicketVersion = Readonly<
  Pick<AdminTicketOrder, "id" | "updatedAt">
>;

export function normalizeAdminTicketVersions(
  tickets: readonly AdminTicketVersion[],
) {
  if (
    !Array.isArray(tickets) ||
    tickets.length === 0 ||
    tickets.length > MAX_ADMIN_TICKET_MUTATION
  ) {
    throw new AdminTicketValidationError(
      "Select between 1 and 100 ticket records.",
    );
  }
  const versions = tickets.map((value) => {
    const ticket = record(value, "Ticket selection");
    return {
      id: identifier(ticket.id, "Ticket id"),
      expectedUpdatedAt: loadedVersion(ticket.updatedAt),
    };
  });
  if (new Set(versions.map((ticket) => ticket.id)).size !== versions.length) {
    throw new AdminTicketValidationError(
      "Ticket selection contains duplicate records.",
    );
  }
  return versions;
}

export async function updateTicketStatus(
  client: SupabaseClient,
  access: AdminAccess,
  ticket: AdminTicketVersion,
  nextStatus: string,
) {
  if (!isAdminTicketStatusAction(nextStatus)) {
    throw new AdminTicketValidationError(
      "Unsupported ticket status action.",
    );
  }
  const [version] = normalizeAdminTicketVersions([ticket]);
  const permission = getAdminTicketTargetPermission(access, nextStatus);
  if (!permission.allowed) {
    throw new AdminTicketValidationError(
      permission.reason ?? "Ticket status change is not permitted.",
    );
  }
  if (typeof window !== "undefined") {
    await requestAdminApi("tickets/status", {
      method: "POST",
      body: {
        ticketId: version.id,
        expectedUpdatedAt: version.expectedUpdatedAt,
        status: nextStatus,
      },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "update ticket status");
  const { error } = await client.rpc(
    "admin_bulk_update_ticket_status_if_unchanged",
    {
      p_ticket_ids: [version.id],
      p_expected_updated_ats: [version.expectedUpdatedAt],
      p_status: nextStatus,
      p_club_id: Number(clubId),
      p_actor_id: access.userId ?? null,
      p_role: access.role,
      p_is_super_admin: access.isSuperAdmin,
    },
  );
  if (error) {
    if (/changed after .* loaded|loaded version|stale/i.test(error.message)) {
      throw new AdminMutationConflictError(error.message);
    }
    throw new Error(error.message);
  }
}

export async function bulkUpdateTicketStatus(
  client: SupabaseClient,
  access: AdminAccess,
  tickets: readonly AdminTicketVersion[],
  nextStatus: AdminTicketStatusAction,
) {
  if (!isAdminTicketStatusAction(nextStatus)) {
    throw new AdminTicketValidationError(
      "Unsupported ticket status action.",
    );
  }
  const versions = normalizeAdminTicketVersions(tickets);
  const permission = getAdminTicketTargetPermission(access, nextStatus);
  if (!permission.allowed) {
    throw new AdminTicketValidationError(
      permission.reason ?? "Ticket status change is not permitted.",
    );
  }
  if (typeof window !== "undefined") {
    await requestAdminApi("tickets/bulk-status", {
      method: "POST",
      body: {
        tickets: versions.map(({ id, expectedUpdatedAt }) => ({
          id,
          expectedUpdatedAt,
        })),
        status: nextStatus,
      },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "bulk update ticket status");
  const { error } = await client.rpc(
    "admin_bulk_update_ticket_status_if_unchanged",
    {
      p_ticket_ids: versions.map(({ id }) => id),
      p_expected_updated_ats: versions.map(
        ({ expectedUpdatedAt }) => expectedUpdatedAt,
      ),
      p_status: nextStatus,
      p_club_id: Number(clubId),
      p_actor_id: access.userId ?? null,
      p_role: access.role,
      p_is_super_admin: access.isSuperAdmin,
    },
  );
  if (error) {
    if (/changed after .* loaded|loaded version|stale/i.test(error.message)) {
      throw new AdminMutationConflictError(error.message);
    }
    throw new Error(error.message);
  }
}
