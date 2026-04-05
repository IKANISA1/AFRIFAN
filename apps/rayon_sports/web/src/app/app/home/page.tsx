"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { ArrowRight, Bell, ShieldCheck, Ticket } from "lucide-react";
import { NotificationOptInCard } from "@/components/pwa/notification-opt-in-card";
import { PageHero } from "@/components/page-hero";
import { PortalStateCard } from "@/components/portal/portal-state-card";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackMatches } from "@/lib/content";
import { resolvePortalHref } from "@/lib/host-routing";
import { rayonClub } from "@/lib/config";
import type { MatchItem } from "@/lib/types";
import {
  formatCurrency,
  formatDate,
  formatMatchStatusLabel,
  isLiveMatch,
  isUpcomingMatch,
} from "@/lib/utils";

export default function FanPortalDashboardPage() {
  const pathname = usePathname();
  const { client, user, profile, membership } = useFanPortal();
  const [counts, setCounts] = useState({
    tickets: 0,
    orders: 0,
    groups: 0,
  });
  const [matches, setMatches] = useState<MatchItem[]>(fallbackMatches);

  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadCounts() {
      const [tickets, orders, groups, matchRows] = await Promise.all([
        activeClient.from("tickets").select("id").eq("user_id", activeUser.id),
        activeClient
          .from("shop_orders")
          .select("id")
          .eq("user_id", activeUser.id),
        activeClient
          .from("group_members")
          .select("id")
          .eq("user_id", activeUser.id),
        activeClient
          .from("matches")
          .select("*")
          .eq("club_id", rayonClub.numericId)
          .order("match_date", { ascending: true }),
      ]);

      setCounts({
        tickets: tickets.data?.length ?? 0,
        orders: orders.data?.length ?? 0,
        groups: groups.data?.length ?? 0,
      });

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
    }

    loadCounts().catch(() => {});
  }, [client, user]);

  const featuredMatch =
    matches.find((match) => match.isFeatured) ??
    matches.find((match) => match.isOnSale) ??
    matches.find((match) => isUpcomingMatch(match.matchStatus)) ??
    matches[0];
  const liveMatch = matches.find((match) => isLiveMatch(match.matchStatus));
  const openSales = matches.filter((match) => match.isOnSale).length;
  const tierLabel = (membership?.tier ?? "fan").toUpperCase();
  const supporterName = profile?.displayName ?? "Gikundiro supporter";
  const ticketHref = resolvePortalHref(pathname, "/app/tickets");
  const membershipHref = resolvePortalHref(pathname, "/app/membership");
  const fanClubsHref = resolvePortalHref(pathname, "/app/fan-clubs");

  return (
    <div className="section-grid">
      <PageHero
        eyebrow="Matchday home"
        title={`Welcome, ${supporterName}.`}
        description="Tickets, membership, and live moments — everything lined up for the next whistle."
        actions={
          <>
            <Link
              href={ticketHref}
              className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
            >
              Buy tickets <Ticket size={18} />
            </Link>
            <Link
              href={membershipHref}
              className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-5 py-3 font-semibold text-white transition hover:bg-white/10"
            >
              Upgrade membership <ShieldCheck size={18} />
            </Link>
          </>
        }
        stats={[
          { label: "Tier", value: tierLabel },
          { label: "Tickets owned", value: counts.tickets.toString() },
          { label: "Sales open", value: openSales.toString() },
        ]}
        media={
          featuredMatch ? (
            <article className="rounded-[28px] border border-border-soft bg-black/20 p-5">
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-club-accent/30 bg-club-accent/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-club-accent">
                  {featuredMatch.competition}
                </span>
                <span className="rounded-full border border-border-soft px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  {formatMatchStatusLabel(featuredMatch.matchStatus)}
                </span>
                {featuredMatch.isOnSale ? (
                  <span className="rounded-full border border-emerald-400/30 bg-emerald-500/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-emerald-200">
                    On sale
                  </span>
                ) : null}
              </div>
              <h2 className="mt-5 font-display text-4xl font-bold uppercase leading-none text-white">
                {featuredMatch.homeTeam} vs {featuredMatch.awayTeam}
              </h2>
              <p className="mt-3 text-sm leading-6 text-slate-300">
                {formatDate(featuredMatch.matchDate)} at {featuredMatch.venue}
              </p>
              <p className="mt-4 text-sm leading-7 text-slate-200">
                {featuredMatch.matchSummary ??
                  "Supporters are building momentum around the next big fixture."}
              </p>
              <div className="mt-5 grid gap-3 sm:grid-cols-2">
                <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
                  <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
                    General
                  </p>
                  <p className="mt-2 font-display text-3xl font-bold uppercase text-white">
                    {formatCurrency(featuredMatch.generalPrice)}
                  </p>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
                  <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
                    VIP
                  </p>
                  <p className="mt-2 font-display text-3xl font-bold uppercase text-white">
                    {formatCurrency(featuredMatch.vipPrice)}
                  </p>
                </div>
              </div>
            </article>
          ) : null
        }
      />

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-6">
          <div className="grid gap-5 md:grid-cols-3">
            <PortalStateCard
              label="Membership"
              value={tierLabel}
              className="glass-panel-elevated"
              badge={
                <span className="rounded-full border border-club-accent/30 bg-club-accent/12 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-club-accent">
                  Active
                </span>
              }
              helper={`${profile?.publicUserId ?? "Pending"} · ${membership?.chapter ?? "Main stand"}`}
            />
            <PortalStateCard
              label="Tickets"
              value={counts.tickets.toString()}
              className="border border-club-primary/30 bg-[linear-gradient(180deg,rgba(0,56,168,0.18),rgba(8,18,42,0.82))]"
              helper="Owned across all fixtures."
            />
            <PortalStateCard
              label="Orders · Circles"
              value={`${counts.orders} · ${counts.groups}`}
              className="border border-border-soft bg-[linear-gradient(180deg,rgba(212,160,23,0.08),rgba(8,18,42,0.82))]"
              helper="Shop orders and supporter groups."
            />
          </div>

          <NotificationOptInCard
            surface="portal"
            path="/app/home"
            title="Matchday alerts"
            description="Kickoff reminders, ticket confirmations, and live score updates."
          />
        </div>

        <section className="glass-panel-elevated relative overflow-hidden rounded-[34px] p-6">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(0,56,168,0.16),transparent_35%),radial-gradient(circle_at_bottom_left,rgba(212,160,23,0.08),transparent_40%)]" />
          <div className="relative space-y-5">
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                This week in blue
              </p>
              <h2 className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
                Before kickoff
              </h2>
            </div>

            <div className="grid gap-4">
              <article className="rounded-[24px] border border-border-soft bg-black/20 p-4">
                <div className="flex items-start gap-3">
                  <div className="mt-1 rounded-full bg-club-accent/15 p-2 text-club-accent">
                    <Ticket size={18} />
                  </div>
                  <div>
                    <p className="text-[11px] uppercase tracking-[0.24em] text-slate-300">
                      Ticket window
                    </p>
                    <p className="mt-2 text-lg font-semibold text-white">
                      {featuredMatch
                        ? `${featuredMatch.homeTeam} vs ${featuredMatch.awayTeam}`
                        : "Next ticket drop"}
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      {featuredMatch?.isOnSale
                        ? "Seats open — lock your section."
                        : "Sales not yet open."}
                    </p>
                  </div>
                </div>
              </article>

              <article className="rounded-[24px] border border-border-soft bg-black/20 p-4">
                <div className="flex items-start gap-3">
                  <div className="mt-1 rounded-full bg-club-primary/20 p-2 text-blue-200">
                    <Bell size={18} />
                  </div>
                  <div>
                    <p className="text-[11px] uppercase tracking-[0.24em] text-slate-300">
                      Match alerts
                    </p>
                    <p className="mt-2 text-lg font-semibold text-white">
                      {liveMatch
                        ? `Live now: ${liveMatch.homeTeam} vs ${liveMatch.awayTeam}`
                        : "Get the whistle before everyone else"}
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      {liveMatch
                        ? "Live now — tap to follow."
                        : "Enable alerts for live updates."}
                    </p>
                  </div>
                </div>
              </article>

              <article className="rounded-[24px] border border-border-soft bg-black/20 p-4">
                <div className="flex items-start gap-3">
                  <div className="mt-1 rounded-full bg-emerald-500/15 p-2 text-emerald-200">
                    <ArrowRight size={18} />
                  </div>
                  <div>
                    <p className="text-[11px] uppercase tracking-[0.24em] text-slate-300">
                      Supporter moves
                    </p>
                    <p className="mt-2 text-lg font-semibold text-white">
                      Membership and chapters
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      Tier perks, fan clubs, and away-day coordination.
                    </p>
                  </div>
                </div>
              </article>
            </div>

            <div className="flex flex-wrap gap-3">
              <Link
                href={fanClubsHref}
                className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Explore chapters <ArrowRight size={16} />
              </Link>
              <Link
                href={membershipHref}
                className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Review membership <ArrowRight size={16} />
              </Link>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
