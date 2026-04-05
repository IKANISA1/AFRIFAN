"use client";

import { useEffect, useState } from "react";
import { ArrowRight, ShieldCheck, Ticket } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackMatches } from "@/lib/content";
import { resolvePortalHref } from "@/lib/host-routing";
import { rayonClub } from "@/lib/config";
import type { MatchItem, TicketOrder } from "@/lib/types";
import {
  formatCurrency,
  formatDateTime,
  formatMatchStatusLabel,
  isLiveMatch,
} from "@/lib/utils";
import { usePathname } from "next/navigation";

export default function FanTicketsPage() {
  const pathname = usePathname();
  const { client, user } = useFanPortal();
  const [matches, setMatches] = useState<MatchItem[]>(fallbackMatches);
  const [tickets, setTickets] = useState<TicketOrder[]>([]);
  const [status, setStatus] = useState<string | null>(null);
  const [selectedMatchId, setSelectedMatchId] = useState(fallbackMatches[0]?.id ?? "");
  const [selectedSeatType, setSelectedSeatType] = useState<"general" | "vip">("general");
  const [quantity, setQuantity] = useState(1);

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

  useEffect(() => {
    if (!matches.some((match) => match.id === selectedMatchId) && matches[0]) {
      setSelectedMatchId(matches[0].id);
    }
  }, [matches, selectedMatchId]);

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

  const selectedMatch =
    matches.find((match) => match.id === selectedMatchId) ?? matches[0];
  const seatPrice =
    selectedSeatType === "vip"
      ? selectedMatch?.vipPrice ?? 0
      : selectedMatch?.generalPrice ?? 0;
  const totalPrice = seatPrice * quantity;
  const liveMatches = matches.filter((match) => isLiveMatch(match.matchStatus)).length;
  const onSaleMatches = matches.filter((match) => match.isOnSale).length;
  const membershipHref = resolvePortalHref(pathname, "/app/membership");
  const matchById = new Map(matches.map((match) => [match.id, match]));

  return (
    <div className="section-grid">
      <PageHero
        eyebrow="Matchday tickets"
        title="Lock in your place before the blue wave hits the gates."
        description="Pick the fixture, choose your section, and get your seat locked before the gates open."
        stats={[
          { label: "Sales open", value: onSaleMatches.toString() },
          { label: "Live matches", value: liveMatches.toString() },
          { label: "Tickets owned", value: tickets.length.toString() },
        ]}
        actions={
          <>
            <a
              href="#ticket-builder"
              className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
            >
              Start checkout <Ticket size={18} />
            </a>
            <a
              href="#ticket-history"
              className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-5 py-3 font-semibold text-white transition hover:bg-white/10"
            >
              See my tickets <ArrowRight size={18} />
            </a>
          </>
        }
        media={
          selectedMatch ? (
            <article className="rounded-[28px] border border-border-soft bg-black/20 p-5">
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-club-accent/30 bg-club-accent/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-club-accent">
                  {selectedMatch.competition}
                </span>
                <span className="rounded-full border border-border-soft px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  {formatMatchStatusLabel(selectedMatch.matchStatus)}
                </span>
                {selectedMatch.isOnSale ? (
                  <span className="rounded-full border border-emerald-400/30 bg-emerald-500/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-emerald-200">
                    Open now
                  </span>
                ) : null}
              </div>
              <h2 className="mt-5 font-display text-4xl font-bold uppercase leading-none text-white">
                {selectedMatch.homeTeam} vs {selectedMatch.awayTeam}
              </h2>
              <p className="mt-3 text-sm leading-6 text-slate-300">
                {formatDateTime(selectedMatch.matchDate)} at {selectedMatch.venue}
              </p>
                {selectedMatch.matchSummary ?? null}
              <div className="mt-5 grid gap-3 sm:grid-cols-2">
                <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
                  <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
                    General
                  </p>
                  <p className="mt-2 font-display text-3xl font-bold uppercase text-white">
                    {formatCurrency(selectedMatch.generalPrice)}
                  </p>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
                  <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
                    VIP
                  </p>
                  <p className="mt-2 font-display text-3xl font-bold uppercase text-white">
                    {formatCurrency(selectedMatch.vipPrice)}
                  </p>
                </div>
              </div>
            </article>
          ) : null
        }
      />

      <div className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <form
          id="ticket-builder"
          action={purchaseTicket}
          className="glass-panel-elevated grid gap-5 rounded-[34px] p-6"
        >
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Checkout
            </p>
            <h2 className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
              Select your match.
            </h2>
          </div>

          <label className="grid gap-2 text-sm">
            Match
            <select
              name="matchId"
              className="dashboard-input"
              value={selectedMatchId}
              onChange={(event) => setSelectedMatchId(event.target.value)}
            >
              {matches.map((match) => (
                <option key={match.id} value={match.id}>
                  {match.homeTeam} vs {match.awayTeam}
                </option>
              ))}
            </select>
          </label>

          <div className="grid gap-4 sm:grid-cols-2">
            {(["general", "vip"] as const).map((seatType) => {
              const active = selectedSeatType === seatType;
              const seatTypeLabel = seatType.toUpperCase();
              const price =
                seatType === "vip"
                  ? selectedMatch?.vipPrice ?? 0
                  : selectedMatch?.generalPrice ?? 0;

              return (
                <label
                  key={seatType}
                  className={`rounded-[24px] border px-4 py-4 transition ${
                    active
                      ? "border-club-primary-light bg-club-primary/18"
                      : "border-border-soft bg-white/5 hover:bg-white/8"
                  }`}
                >
                  <input
                    type="radio"
                    name="seatType"
                    value={seatType}
                    checked={active}
                    onChange={() => setSelectedSeatType(seatType)}
                    className="sr-only"
                  />
                  <p className="text-[11px] uppercase tracking-[0.24em] text-slate-300">
                    {seatTypeLabel}
                  </p>
                  <p className="mt-3 font-display text-3xl font-bold uppercase text-white">
                    {formatCurrency(price)}
                  </p>
                </label>
              );
            })}
          </div>

          <label className="grid gap-2 text-sm">
            Quantity
            <input
              name="quantity"
              type="number"
              min="1"
              max="6"
              value={quantity}
              onChange={(event) =>
                setQuantity(Math.max(1, Math.min(6, Number(event.target.value) || 1)))
              }
              className="dashboard-input"
            />
          </label>

          <div className="rounded-[28px] border border-border-soft bg-black/20 p-5">
            <div className="flex items-center justify-between gap-4 border-b border-border-soft pb-4">
              <div>
                <p className="text-[11px] uppercase tracking-[0.22em] text-slate-300">
                  Selected match
                </p>
                <p className="mt-2 text-lg font-semibold text-white">
                  {selectedMatch
                    ? `${selectedMatch.homeTeam} vs ${selectedMatch.awayTeam}`
                    : "Choose a fixture"}
                </p>
              </div>
              <span className="rounded-full border border-border-soft px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                {selectedSeatType}
              </span>
            </div>
            <div className="mt-4 grid gap-3 text-sm text-slate-300">
              <div className="flex items-center justify-between gap-3">
                <span>Seat price</span>
                <span>{formatCurrency(seatPrice)}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>Quantity</span>
                <span>{quantity}</span>
              </div>
              <div className="flex items-center justify-between gap-3 border-t border-border-soft pt-3 text-base font-semibold text-white">
                <span>Total</span>
                <span>{formatCurrency(totalPrice)}</span>
              </div>
            </div>
          </div>

          <button
            type="submit"
            className="rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            Reserve ticket
          </button>

          {status ? (
            <p className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3 text-sm text-slate-200">
              {status}
            </p>
          ) : null}
        </form>

        <div className="grid gap-5">
          {matches.slice(0, 3).map((match) => (
            <article
              key={match.id}
              className="glass-panel card-interactive relative overflow-hidden rounded-[30px] p-5"
            >
              <div className="absolute inset-x-0 top-0 h-1 bg-[linear-gradient(90deg,rgba(212,160,23,0.85),rgba(0,56,168,0.7))]" />
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-club-accent/30 bg-club-accent/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-club-accent">
                  {match.competition}
                </span>
                <span className="rounded-full border border-border-soft px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  {formatMatchStatusLabel(match.matchStatus)}
                </span>
                {match.isOnSale ? (
                  <span className="rounded-full border border-emerald-400/30 bg-emerald-500/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-emerald-200">
                    Ticket sale
                  </span>
                ) : null}
              </div>
              <div className="mt-5 flex items-start justify-between gap-4">
                <div>
                  <p className="font-display text-3xl font-bold uppercase leading-none">
                    {match.homeTeam} vs {match.awayTeam}
                  </p>
                  <p className="mt-2 text-sm text-slate-300">
                    {formatDateTime(match.matchDate)} • {match.venue}
                  </p>
                  {match.matchSummary ?? null}
                </div>
                <div className="min-w-[140px] rounded-[22px] border border-border-soft bg-white/5 p-4 text-right">
                  <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
                    General
                  </p>
                  <p className="mt-2 font-display text-3xl font-bold uppercase text-white">
                    {formatCurrency(match.generalPrice)}
                  </p>
                  <p className="mt-3 text-[11px] uppercase tracking-[0.2em] text-slate-300">
                    VIP {formatCurrency(match.vipPrice)}
                  </p>
                </div>
              </div>
            </article>
          ))}

          <div id="ticket-history" className="glass-panel rounded-[30px] p-5">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                  Ticket history
                </p>
                <p className="mt-3 font-display text-3xl font-bold uppercase leading-none">
                  My tickets
                </p>
              </div>
              <a
                href={membershipHref}
                className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Membership perks <ShieldCheck size={16} />
              </a>
            </div>

            <p className="mt-4 text-sm leading-7 text-slate-300">
              Tickets stay tied to your supporter identity.
            </p>

            <div className="mt-5 grid gap-3">
              {tickets.length > 0 ? (
                tickets.map((ticket) => {
                  const relatedMatch = matchById.get(ticket.matchId);

                  return (
                    <div
                      key={ticket.id}
                      className="rounded-[22px] border border-border-soft bg-white/6 p-4 text-sm text-slate-200"
                    >
                      <div className="flex flex-wrap items-center justify-between gap-3">
                        <p className="font-semibold uppercase tracking-[0.2em] text-club-accent">
                          {ticket.seatType} • {ticket.status}
                        </p>
                        <span className="rounded-full border border-border-soft px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300">
                          {formatCurrency(ticket.amountPaid)}
                        </span>
                      </div>
                      <p className="mt-3 text-base font-semibold text-white">
                        {relatedMatch
                          ? `${relatedMatch.homeTeam} vs ${relatedMatch.awayTeam}`
                          : "Matchday ticket"}
                      </p>
                      <p className="mt-1 text-slate-300">
                        {relatedMatch
                          ? `${formatDateTime(relatedMatch.matchDate)} • ${relatedMatch.venue}`
                          : formatDateTime(ticket.purchasedAt)}
                      </p>
                      <p className="mt-3 text-slate-300">{ticket.qrCode}</p>
                    </div>
                  );
                })
              ) : (
                <p className="rounded-[22px] border border-dashed border-border-soft bg-white/4 px-5 py-6 text-sm leading-7 text-slate-300">
                  No tickets yet. Start with the match selector above.
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
