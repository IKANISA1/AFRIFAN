"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackMatches } from "@/lib/content";
import { rayonClub } from "@/lib/config";
import type { MatchItem } from "@/lib/types";

export default function LiveMatchPage() {
  const params = useParams<{ matchId: string }>();
  const { client } = useFanPortal();
  const [match, setMatch] = useState<MatchItem | null>(
    fallbackMatches.find((entry) => entry.id === params.matchId) ?? null,
  );

  useEffect(() => {
    if (client == null || params.matchId == null) return;
    const activeClient = client;

    async function loadMatch() {
      const { data } = await activeClient
        .from("matches")
        .select("*")
        .eq("club_id", rayonClub.numericId)
        .eq("id", params.matchId)
        .maybeSingle();

      if (data) {
        setMatch({
          id: String(data.id),
          homeTeam: String(data.home_team),
          awayTeam: String(data.away_team),
          competition: String(data.competition ?? "League"),
          venue: String(data.venue ?? "Stadium"),
          matchDate: String(data.match_date),
          kickoffTime: String(data.kickoff_time ?? ""),
          isOnSale: Boolean(data.is_on_sale),
          generalPrice: Number(data.ticket_general_price ?? 0),
          vipPrice: Number(data.ticket_vip_price ?? 0),
          imageUrl: data.image_url ? String(data.image_url) : null,
          matchStatus: String(data.match_status ?? "scheduled"),
          homeScore: Number(data.home_score ?? 0),
          awayScore: Number(data.away_score ?? 0),
          liveMinute:
            data.live_minute == null ? null : Number(data.live_minute ?? 0),
          matchSummary: data.match_summary ? String(data.match_summary) : null,
          liveEvents: Array.isArray(data.live_events)
            ? data.live_events.map((event: unknown, index: number) => {
                const entry =
                  typeof event == "object" && event != null
                    ? (event as Record<string, unknown>)
                    : null;

                return {
                  minute:
                    typeof entry?.minute == "string"
                      ? entry.minute
                      : `${index + 1}'`,
                  event:
                    typeof entry?.event == "string"
                      ? entry.event
                      : "Match event",
                  side: entry?.side == "away" ? "away" : "home",
                };
              })
            : [],
          liveStats:
            typeof data.live_stats == "object" && data.live_stats != null
              ? (data.live_stats as Record<string, number | string>)
              : {},
          isFeatured: Boolean(data.is_featured),
        });
      }
    }

    loadMatch().catch(() => {});
  }, [client, params.matchId]);

  if (match == null) {
    return (
      <div className="section-grid">
        <SectionHeading
          eyebrow="Live center"
          title="Match context unavailable."
          description="This match was not found in the current live feed."
        />
      </div>
    );
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Live center"
        title={`${match.homeTeam} ${match.homeScore} — ${match.awayScore} ${match.awayTeam}`}
        description={match.matchSummary ?? "Realtime match context for supporters."}
      />
      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <div className="glass-panel rounded-[32px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
            {match.matchStatus} {match.liveMinute ? `• ${match.liveMinute}'` : ""}
          </p>
          <div className="mt-4 grid gap-4 sm:grid-cols-3">
            {Object.entries(match.liveStats).map(([key, value]) => (
              <div key={key} className="rounded-[22px] bg-white/6 p-4">
                <p className="text-xs uppercase tracking-[0.2em] text-slate-400">
                  {key}
                </p>
                <p className="mt-2 font-display text-3xl font-bold uppercase">
                  {value}
                </p>
              </div>
            ))}
          </div>
        </div>
        <div className="glass-panel rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">
            Match events
          </p>
          <div className="mt-5 grid gap-3">
            {match.liveEvents.length > 0 ? (
              match.liveEvents.map((event) => (
                <div
                  key={`${event.minute}-${event.event}`}
                  className="rounded-[22px] border border-border-soft bg-white/6 p-4 text-sm text-slate-200"
                >
                  <p className="font-semibold uppercase tracking-[0.2em] text-club-accent">
                    {event.minute} • {event.side}
                  </p>
                  <p className="mt-2">{event.event}</p>
                </div>
              ))
            ) : (
              <p className="text-sm leading-7 text-slate-300">
                Live events will appear here once the admin feed starts
                publishing moments from the match.
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
