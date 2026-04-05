"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { ArrowRight, Bell, ShieldCheck, Ticket } from "lucide-react";
import { AnimateOnScroll } from "@/components/animate-on-scroll";
import { PullToRefresh } from "@/components/pull-to-refresh";
import { NotificationOptInCard } from "@/components/pwa/notification-opt-in-card";
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
  const router = useRouter();
  const handleRefresh = useCallback(async () => {
    router.refresh();
    // Give server time to re-fetch
    await new Promise((resolve) => setTimeout(resolve, 800));
  }, [router]);

  return (
    <PullToRefresh onRefresh={handleRefresh}>
    <div className="section-grid">
      {/* ── Compact hero — mobile-optimized greeting ── */}
      <section className="glass-panel-elevated relative overflow-hidden rounded-[34px] border border-border-soft p-5 sm:p-8">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(0,56,168,0.18),transparent_40%),radial-gradient(circle_at_bottom_right,rgba(212,160,23,0.12),transparent_35%)]" />
        <div className="relative space-y-4">
          <p className="font-mono text-xs uppercase tracking-[0.32em] text-club-accent">
            Matchday home
          </p>
          <h1 className="font-display text-3xl font-bold uppercase leading-none text-white sm:text-4xl lg:fluid-display">
            Welcome, {supporterName}.
          </h1>
          <p className="max-w-2xl text-sm leading-7 text-slate-200 sm:text-base sm:leading-8">
            Tickets, membership, and live moments — everything lined up for the next whistle.
          </p>
          <div className="flex flex-wrap gap-2 sm:gap-3">
            <Link
              href={ticketHref}
              className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:brightness-110 sm:px-5 sm:py-3"
            >
              Buy tickets <Ticket size={16} />
            </Link>
            <Link
              href={membershipHref}
              className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10 sm:px-5 sm:py-3"
            >
              Upgrade <ShieldCheck size={16} />
            </Link>
          </div>
        </div>
      </section>

      {/* ── Compact stat chips — 3 inline rows instead of tall cards ── */}
      <div className="grid gap-2 sm:grid-cols-3 sm:gap-4">
        <PortalStateCard
          compact
          label="Tier"
          value={tierLabel}
          helper=""
          className="glass-panel-elevated sm:rounded-[28px] sm:p-5"
          badge={
            <span className="rounded-full border border-club-accent/30 bg-club-accent/12 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-[0.18em] text-club-accent">
              Active
            </span>
          }
        />
        <PortalStateCard
          compact
          label="Tickets"
          value={counts.tickets.toString()}
          helper=""
          className="border border-club-primary/30 bg-[linear-gradient(180deg,rgba(0,56,168,0.12),rgba(8,18,42,0.82))]"
        />
        <PortalStateCard
          compact
          label="Orders · Circles"
          value={`${counts.orders} · ${counts.groups}`}
          helper=""
          className="border border-border-soft bg-[linear-gradient(180deg,rgba(212,160,23,0.06),rgba(8,18,42,0.82))]"
        />
      </div>

      {/* ── Featured match spotlight + activity feed ── */}
      <div className="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        {/* Featured match — compact on mobile */}
        {featuredMatch ? (
          <Link
            href={resolvePortalHref(pathname, `/app/tickets`)}
            className="glass-panel card-interactive flex flex-col gap-4 rounded-[30px] border border-border-soft p-5"
          >
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

            {/* Team names — compact inline layout */}
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-club-primary/20 p-1">
                {featuredMatch.homeTeam.toLowerCase().includes("rayon") ? (
                  <Image src="/media/rayon-crest.png" alt="Rayon Sports" width={32} height={32} className="object-contain" />
                ) : (
                  <span className="text-sm font-bold text-white">{featuredMatch.homeTeam.charAt(0)}</span>
                )}
              </div>
              <div className="min-w-0">
                <p className="font-display text-2xl font-bold uppercase leading-none text-white sm:text-3xl">
                  {featuredMatch.homeTeam}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3 -mt-1">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/10 text-sm font-bold text-slate-300">
                {featuredMatch.awayTeam.charAt(0)}
              </div>
              <div className="min-w-0">
                <p className="font-display text-2xl font-bold uppercase leading-none text-white/70 sm:text-3xl">
                  {featuredMatch.awayTeam}
                </p>
              </div>
            </div>

            <p className="text-sm leading-6 text-slate-300">
              {formatDate(featuredMatch.matchDate)} · {featuredMatch.venue}
            </p>

            {/* Ticket prices — inline chips instead of tall grid */}
            <div className="flex flex-wrap gap-2">
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.2em] text-slate-200">
                General {formatCurrency(featuredMatch.generalPrice)}
              </span>
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.2em] text-slate-200">
                VIP {formatCurrency(featuredMatch.vipPrice)}
              </span>
            </div>

            <div className="mt-auto flex items-center gap-2 text-sm font-semibold text-white">
              <Ticket size={16} className="text-club-accent" />
              View tickets
              <ArrowRight size={14} className="text-slate-300" />
            </div>
          </Link>
        ) : null}

        {/* Activity feed — condensed timeline */}
        <AnimateOnScroll animation="fade-up" threshold={0.08}>
        <section className="glass-panel-elevated relative overflow-hidden rounded-[34px] p-5 sm:p-6">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(0,56,168,0.16),transparent_35%),radial-gradient(circle_at_bottom_left,rgba(212,160,23,0.08),transparent_40%)]" />
          <div className="relative space-y-4">
            <div>
              <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
                This week in blue
              </p>
              <h2 className="mt-2 font-display text-2xl font-bold uppercase leading-none text-white sm:text-3xl">
                Before kickoff
              </h2>
            </div>

            <div className="grid gap-3">
              {/* Timeline item — compact */}
              <article className="flex items-start gap-3 rounded-2xl border border-border-soft bg-black/20 p-3 sm:p-4">
                <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-club-accent/15 text-club-accent">
                  <Ticket size={15} />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-white leading-tight">
                    {featuredMatch
                      ? `${featuredMatch.homeTeam} vs ${featuredMatch.awayTeam}`
                      : "Next ticket drop"}
                  </p>
                  <p className="mt-1 text-xs leading-5 text-slate-400">
                    {featuredMatch?.isOnSale
                      ? "Seats open — lock your section."
                      : "Sales not yet open."}
                  </p>
                </div>
              </article>

              <article className="flex items-start gap-3 rounded-2xl border border-border-soft bg-black/20 p-3 sm:p-4">
                <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-club-primary/20 text-blue-200">
                  <Bell size={15} />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-white leading-tight">
                    {liveMatch
                      ? `Live: ${liveMatch.homeTeam} vs ${liveMatch.awayTeam}`
                      : "Get the whistle first"}
                  </p>
                  <p className="mt-1 text-xs leading-5 text-slate-400">
                    {liveMatch
                      ? "Live now — tap to follow."
                      : "Enable alerts for live updates."}
                  </p>
                </div>
              </article>

              <article className="flex items-start gap-3 rounded-2xl border border-border-soft bg-black/20 p-3 sm:p-4">
                <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-200">
                  <ArrowRight size={15} />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-white leading-tight">
                    Membership and chapters
                  </p>
                  <p className="mt-1 text-xs leading-5 text-slate-400">
                    Tier perks, fan clubs, and away-day coordination.
                  </p>
                </div>
              </article>
            </div>

            <div className="flex flex-wrap gap-2">
              <Link
                href={fanClubsHref}
                className="inline-flex min-h-10 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Chapters <ArrowRight size={14} />
              </Link>
              <Link
                href={membershipHref}
                className="inline-flex min-h-10 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Membership <ArrowRight size={14} />
              </Link>
            </div>
          </div>
        </section>
        </AnimateOnScroll>
      </div>

      {/* Notification opt-in */}
      <NotificationOptInCard
        surface="portal"
        path="/app/home"
        title="Matchday alerts"
        description="Kickoff reminders, ticket confirmations, and live score updates."
      />
    </div>
    </PullToRefresh>
  );
}
