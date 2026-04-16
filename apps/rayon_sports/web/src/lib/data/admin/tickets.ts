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

  return (data ?? []).map((row: any) => ({
    id: toIdString(row.id, ""),
    matchId: row.match_id,
    userId: row.user_id,
    seatType: row.seat_type,
    amountPaid: row.amount_paid,
    status: row.status,
    qrCode: row.qr_code,
    purchasedAt: safeString(row.purchased_at, row.created_at),
    userName: safeString(row.profiles?.full_name, "Unknown"),
    userPhone: safeString(row.profiles?.phone, "—"),
    matchTitle: `${row.matches?.home_team} vs ${row.matches?.away_team}`,
    momoReference: row.momo_reference,
  }));
}

export async function updateTicketStatus(
  client: SupabaseClient,
  access: AdminAccess,
  ticketId: string,
  status: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("tickets/status", {
      method: "POST",
      body: { ticketId, status },
    });
  }
  const clubId = requireAdminClubId(access, "update ticket status");

  const { error } = await client
    .from("tickets")
    .update({ status })
    .eq("id", ticketId)
    .eq("club_id", clubId);

  if (error) throw new Error(error.message);
}
