/**
 * Admin ticketing — ticket orders and validation.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, TicketOrder } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

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
  userName?: string;
  userPhone?: string;
  matchTitle?: string;
  momoReference?: string;
}

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
  if (!permission.allowed) {
    return permission;
  }

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
  if (orders.length > 100) {
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

interface TicketOrderRow extends Record<string, unknown> {
  id?: unknown;
  match_id?: unknown;
  user_id?: unknown;
  seat_type?: unknown;
  amount_paid?: unknown;
  status?: unknown;
  qr_code?: unknown;
  purchased_at?: unknown;
  created_at?: unknown;
  momo_reference?: unknown;
  profiles?: { full_name?: unknown; phone?: unknown } | null;
  matches?: { home_team?: unknown; away_team?: unknown } | null;
}

export async function getAdminTicketOrders(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminTicketOrder[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminTicketOrder[]>("tickets");
  }
  const clubId = requireAdminClubId(access, "load ticket orders");

  const { data, error } = await client
    .from("tickets")
    .select(`
      *,
      profiles:user_id (full_name, phone),
      matches:match_id (home_team, away_team)
    `)
    .eq("club_id", clubId)
    .order("purchased_at", { ascending: false });

  if (error) throw new Error(error.message);

  return ((data ?? []) as TicketOrderRow[]).map((row) => ({
    id: toIdString(row.id, ""),
    matchId: safeString(row.match_id, ""),
    userId: safeString(row.user_id, ""),
    seatType: safeString(row.seat_type, ""),
    amountPaid: typeof row.amount_paid === "number" ? row.amount_paid : 0,
    status: safeString(row.status, ""),
    qrCode: safeString(row.qr_code, ""),
    purchasedAt: safeString(row.purchased_at) || safeString(row.created_at),
    userName: safeString(row.profiles?.full_name, "Unknown"),
    userPhone: safeString(row.profiles?.phone, "—"),
    matchTitle: `${safeString(row.matches?.home_team, "Home")} vs ${safeString(row.matches?.away_team, "Away")}`,
    momoReference: safeString(row.momo_reference, ""),
  }));
}

export async function updateTicketStatus(
  client: SupabaseClient,
  access: AdminAccess,
  ticketId: string,
  status: string,
) {
  if (!isAdminTicketStatusAction(status)) {
    throw new Error("Unsupported ticket status action.");
  }

  if (typeof window !== "undefined") {
    await requestAdminApi("tickets/status", {
      method: "POST",
      body: { ticketId, status },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "update ticket status");
  const permission = getAdminTicketTargetPermission(access, status);
  if (!permission.allowed) {
    throw new Error(permission.reason ?? "Ticket status change is not permitted.");
  }

  const { error } = await client.rpc("admin_bulk_update_ticket_status", {
    p_ticket_ids: [ticketId],
    p_status: status,
    p_club_id: Number(clubId),
    p_actor_id: access.userId ?? null,
    p_role: access.role,
    p_is_super_admin: access.isSuperAdmin,
  });

  if (error) throw new Error(error.message);
}

export async function bulkUpdateTicketStatus(
  client: SupabaseClient,
  access: AdminAccess,
  ticketIds: readonly string[],
  status: AdminTicketStatusAction,
) {
  const uniqueTicketIds = [...new Set(ticketIds)];
  if (uniqueTicketIds.length === 0 || uniqueTicketIds.length > 100) {
    throw new Error("Select between 1 and 100 ticket records.");
  }

  if (typeof window !== "undefined") {
    await requestAdminApi("tickets/bulk-status", {
      method: "POST",
      body: { ticketIds: uniqueTicketIds, status },
    });
    return;
  }

  const clubId = requireAdminClubId(access, "bulk update ticket status");
  const permission = getAdminTicketTargetPermission(access, status);
  if (!permission.allowed) {
    throw new Error(permission.reason ?? "Ticket status change is not permitted.");
  }
  const { error } = await client.rpc("admin_bulk_update_ticket_status", {
    p_ticket_ids: uniqueTicketIds,
    p_status: status,
    p_club_id: Number(clubId),
    p_actor_id: access.userId ?? null,
    p_role: access.role,
    p_is_super_admin: access.isSuperAdmin,
  });

  if (error) {
    throw new Error(error.message);
  }
}
