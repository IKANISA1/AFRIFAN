"use client";

import { useEffect, useState } from "react";
import { AnimateOnScroll } from "@/components/animate-on-scroll";
import {
  FatDashboard,
  getLevelForFat,
} from "@/components/engagement/fat-dashboard";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { rayonClub } from "@/lib/config";

/* ── Default badge catalogue ── */
const DEFAULT_BADGES = [
  { id: "first-login", name: "First Login", description: "Sign in for the first time", icon: "🔑", fatReward: 10, earned: true, earnedAt: "2026-01-15" },
  { id: "first-ticket", name: "First Ticket", description: "Purchase your first match ticket", icon: "🎫", fatReward: 25, earned: false },
  { id: "5-matches", name: "Five Timer", description: "Attend 5 matches", icon: "🏟️", fatReward: 100, earned: false },
  { id: "predictions-3", name: "Oracle", description: "Make 3 score predictions", icon: "🔮", fatReward: 30, earned: false },
  { id: "motm-voter", name: "Talent Scout", description: "Cast 5 MotM votes", icon: "⭐", fatReward: 25, earned: false },
  { id: "poll-5", name: "Voice of the Stand", description: "Vote in 5 polls", icon: "📢", fatReward: 15, earned: false },
  { id: "exact-prediction", name: "Crystal Ball", description: "Predict an exact score", icon: "💎", fatReward: 50, earned: false },
  { id: "streak-7", name: "Week Warrior", description: "Log in 7 days in a row", icon: "🔥", fatReward: 75, earned: false },
  { id: "membership", name: "Card Holder", description: "Activate membership", icon: "💳", fatReward: 50, earned: false },
  { id: "share-3", name: "Ambassador", description: "Share 3 match links", icon: "🔗", fatReward: 20, earned: false },
  { id: "checkin-10", name: "Regular", description: "10 web check-ins", icon: "📍", fatReward: 40, earned: false },
  { id: "fan-club", name: "Chapter Member", description: "Join a supporter chapter", icon: "🤝", fatReward: 30, earned: false },
];

interface FatEvent {
  id: string;
  eventType: string;
  fatAwarded: number;
  createdAt: string;
}

export default function FanFatPage() {
  const { client, user, membership, refresh } = useFanPortal();
  const [events, setEvents] = useState<FatEvent[]>([]);
  const [status, setStatus] = useState<string | null>(null);
  const [isClaimDisabled, setIsClaimDisabled] = useState(false);

  const totalFat = membership?.points ?? 0;
  const { current, next } = getLevelForFat(totalFat);

  /* Load FAT event history */
  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadEvents() {
      const { data } = await activeClient
        .from("cool_events")
        .select("*")
        .eq("user_id", activeUser.id)
        .order("event_at", { ascending: false })
        .limit(20);

      if (data) {
        setEvents(
          data.map((row) => ({
            id: String(row.id),
            eventType: String(row.event_type ?? "fat_event"),
            fatAwarded: Number(row.xp_awarded ?? 0),
            createdAt: String(row.event_at ?? row.created_at),
          })),
        );
      }
    }

    loadEvents().catch(() => {});
  }, [client, user, membership?.points]);

  /* Daily check-in action */
  async function claimDailyCheckin() {
    if (client == null || user == null || isClaimDisabled) return;
    setIsClaimDisabled(true);
    setStatus("Logging daily check-in…");

    try {
      await client.rpc("add_fan_points", {
        p_user_id: user.id,
        p_partner_id: rayonClub.numericId.toString(),
        p_points: 50,
        p_reason: "web_check_in",
      });
      await refresh();
      setStatus("50 FAT awarded for daily check-in ✓");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Check-in failed.");
      setIsClaimDisabled(false);
    }
  }

  /* Build recent activity from events */
  const recentActivity = events.slice(0, 8).map((e) => ({
    label: e.eventType.replace(/_/g, " "),
    fat: e.fatAwarded,
    date: e.createdAt,
  }));

  /* Build badges with earned state from events */
  const earnedTypes = new Set(events.map((e) => e.eventType));
  const badges = DEFAULT_BADGES.map((badge) => ({
    ...badge,
    earned: badge.earned || earnedTypes.has(badge.id),
  }));

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Fan Achievement Tokens"
        title="Your supporter journey."
      />

      {/* Daily check-in CTA */}
      <div className="glass-panel-elevated rounded-[34px] p-5 sm:p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="font-display text-xl font-bold uppercase leading-none text-white sm:text-2xl">
              Daily check-in
            </p>
            <p className="mt-2 text-sm leading-7 text-slate-300">
              Claim 50 FAT every day you visit the fan portal.
            </p>
          </div>
          <button
            type="button"
            onClick={claimDailyCheckin}
            disabled={isClaimDisabled}
            className="shrink-0 rounded-full bg-club-accent px-6 py-3 text-sm font-semibold text-slate-950 transition hover:brightness-110 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isClaimDisabled ? "Claimed ✓" : "Claim +50 FAT"}
          </button>
        </div>
        {status && (
          <p className="mt-3 rounded-xl bg-white/5 px-4 py-2 text-sm text-slate-300">
            {status}
          </p>
        )}
      </div>

      {/* FAT Dashboard */}
      <AnimateOnScroll animation="fade-up" threshold={0.05}>
        <FatDashboard
          totalFat={totalFat}
          currentLevel={current}
          nextLevel={next}
          badges={badges}
          recentActivity={recentActivity}
        />
      </AnimateOnScroll>
    </div>
  );
}
