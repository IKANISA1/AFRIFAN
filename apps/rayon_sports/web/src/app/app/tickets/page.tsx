"use client";

import { useEffect, useState } from "react";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackMatches } from "@/lib/content";
import { rayonClub } from "@/lib/config";
import type { MatchItem, TicketOrder } from "@/lib/types";
import { formatCurrency, formatDateTime } from "@/lib/utils";

export default function FanTicketsPage() {
  const { client, user } = useFanPortal();
  const [matches, setMatches] = useState<MatchItem[]>(fallbackMatches);
  const [tickets, setTickets] = useState<TicketOrder[]>([]);
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadData() {
      const [matchRows, ticketRows] = await Promise.all([
        activeClient
          .from("matches")
          .select("*")
          .eq("club_id", rayonClub.numericId)
          .order("match_date", { ascending: true }),
        activeClient
          .from("tickets")
          .select("*")
          .eq("user_id", activeUser.id)
          .order("purchased_at", { ascending: false }),
      ]);

      if (matchRows.data && matchRows.data.length > 0) {
        setMatches(
          matchRows.data.map((row) => ({
            id: String(row.id),
            homeTeam: String(row.home_team),
            awayTeam: String(row.away_team),
            competition: String(row.competition ?? "League"),
            venue: String(row.venue ?? "Stadium"),
            matchDate: String(row.match_date),
            kickoffTime: String(row.kickoff_time ?? ""),
            isOnSale: Boolean(row.is_on_sale),
            generalPrice: Number(row.ticket_general_price ?? 0),
            vipPrice: Number(row.ticket_vip_price ?? 0),
            imageUrl: row.image_url ? String(row.image_url) : null,
            matchStatus: String(row.match_status ?? "scheduled"),
            homeScore: Number(row.home_score ?? 0),
            awayScore: Number(row.away_score ?? 0),
            liveMinute:
              row.live_minute == null ? null : Number(row.live_minute ?? 0),
            matchSummary: row.match_summary ? String(row.match_summary) : null,
            liveEvents: [],
            liveStats: {},
            isFeatured: Boolean(row.is_featured),
          })),
        );
      }

      if (ticketRows.data) {
        setTickets(
          ticketRows.data.map((row) => ({
            id: String(row.id),
            matchId: String(row.match_id),
            userId: String(row.user_id),
            seatType: String(row.seat_type ?? "general"),
            amountPaid: Number(row.amount_paid ?? 0),
            status: String(row.status ?? "active"),
            qrCode: row.qr_code ? String(row.qr_code) : null,
            purchasedAt: String(row.purchased_at ?? row.created_at),
          })),
        );
      }
    }

    loadData().catch(() => {});
  }, [client, user]);

  async function purchaseTicket(formData: FormData) {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    setStatus("Creating ticket order...");

    try {
      const matchId = String(formData.get("matchId") ?? "");
      const seatType = String(formData.get("seatType") ?? "general");
      const quantity = Number(formData.get("quantity") ?? "1");
      const match = matches.find((entry) => entry.id === matchId);
      const amountPerSeat =
        seatType === "vip" ? match?.vipPrice ?? 0 : match?.generalPrice ?? 0;

      await activeClient.from("tickets").insert(
        Array.from({ length: quantity }).map((_, index) => ({
          match_id: matchId,
          user_id: activeUser.id,
          club_id: rayonClub.numericId,
          seat_type: seatType,
          amount_paid: amountPerSeat,
          qr_code: `WEB-${Date.now()}-${index}`,
          momo_reference: `WEB-TICKET-${Date.now()}`,
          status: "active",
          purchased_at: new Date().toISOString(),
        })),
      );

      const { data } = await activeClient
        .from("tickets")
        .select("*")
        .eq("user_id", activeUser.id)
        .order("purchased_at", { ascending: false });

      if (data) {
        setTickets(
          data.map((row) => ({
            id: String(row.id),
            matchId: String(row.match_id),
            userId: String(row.user_id),
            seatType: String(row.seat_type ?? "general"),
            amountPaid: Number(row.amount_paid ?? 0),
            status: String(row.status ?? "active"),
            qrCode: row.qr_code ? String(row.qr_code) : null,
            purchasedAt: String(row.purchased_at ?? row.created_at),
          })),
        );
      }

      setStatus("Ticket purchase recorded.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Purchase failed.");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Tickets"
        title="Purchase and manage match tickets in the portal."
        description="The web build uses the same ticket records as the app while making the purchase step readable and form-friendly in browser."
      />
      <div className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <form action={purchaseTicket} className="glass-panel grid gap-5 rounded-[32px] p-6">
          <label className="grid gap-2 text-sm">
            Match
            <select
              name="matchId"
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
              defaultValue={matches[0]?.id}
            >
              {matches.map((match) => (
                <option key={match.id} value={match.id}>
                  {match.homeTeam} vs {match.awayTeam}
                </option>
              ))}
            </select>
          </label>
          <div className="grid gap-5 md:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Seat type
              <select
                name="seatType"
                className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
                defaultValue="general"
              >
                <option value="general">General</option>
                <option value="vip">VIP</option>
              </select>
            </label>
            <label className="grid gap-2 text-sm">
              Quantity
              <input
                name="quantity"
                type="number"
                min="1"
                max="6"
                defaultValue="1"
                className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
              />
            </label>
          </div>
          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            Confirm ticket purchase
          </button>
          {status ? <p className="text-sm text-slate-300">{status}</p> : null}
        </form>

        <div className="grid gap-5">
          {matches.slice(0, 3).map((match) => (
            <article key={match.id} className="glass-panel rounded-[30px] p-5">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="font-display text-3xl font-bold uppercase leading-none">
                    {match.homeTeam} vs {match.awayTeam}
                  </p>
                  <p className="mt-2 text-sm text-slate-300">
                    {formatDateTime(match.matchDate)} • {match.venue}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-display text-3xl font-bold uppercase">
                    {formatCurrency(match.generalPrice)}
                  </p>
                  <p className="text-xs uppercase tracking-[0.24em] text-slate-400">
                    general
                  </p>
                </div>
              </div>
            </article>
          ))}

          <div className="glass-panel rounded-[30px] p-5">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              My tickets
            </p>
            <div className="mt-5 grid gap-3">
              {tickets.length > 0 ? (
                tickets.map((ticket) => (
                  <div
                    key={ticket.id}
                    className="rounded-[22px] border border-border-soft bg-white/6 p-4 text-sm text-slate-200"
                  >
                    <p className="font-semibold uppercase tracking-[0.2em] text-club-accent">
                      {ticket.seatType} • {ticket.status}
                    </p>
                    <p className="mt-2">{formatCurrency(ticket.amountPaid)}</p>
                    <p className="mt-1 text-slate-400">{ticket.qrCode}</p>
                  </div>
                ))
              ) : (
                <p className="text-sm leading-7 text-slate-300">
                  Ticket history will appear here after your first portal
                  purchase.
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
