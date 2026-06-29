/**
 * Admin ticketing — ticket orders and validation.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, TicketOrder } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

export interface AdminTicketOrder extends TicketOrder {
  userName?: string;
  userPhone?: string;
  matchTitle?: string;
  momoReference?: string;
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
  if (typeof window !== "undefined") {
    await requestAdminApi("tickets/status", {
      method: "POST",
      body: { ticketId, status },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "update ticket status");

  const { error } = await client
    .from("tickets")
    .update({ status })
    .eq("id", ticketId)
    .eq("club_id", clubId);

  if (error) throw new Error(error.message);
}
