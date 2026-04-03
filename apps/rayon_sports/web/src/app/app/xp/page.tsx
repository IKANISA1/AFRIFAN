"use client";

import { useEffect, useState } from "react";
import { PortalStateCard } from "@/components/portal/portal-state-card";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { rayonClub } from "@/lib/config";

interface XpEvent {
  id: string;
  eventType: string;
  xpAwarded: number;
  createdAt: string;
}

export default function FanXpPage() {
  const { client, user, membership, refresh } = useFanPortal();
  const [events, setEvents] = useState<XpEvent[]>([]);
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadEvents() {
      const { data } = await activeClient
        .from("cool_events")
        .select("*")
        .eq("user_id", activeUser.id)
        .order("event_at", { ascending: false });

      if (data) {
        setEvents(
          data.map((row) => ({
            id: String(row.id),
            eventType: String(row.event_type ?? "xp_event"),
            xpAwarded: Number(row.xp_awarded ?? 0),
            createdAt: String(row.event_at ?? row.created_at),
          })),
        );
      }
    }

    loadEvents().catch(() => {});
  }, [client, user, membership?.points]);

  async function addCheckInXp() {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    setStatus("Logging web check-in...");

    try {
      await activeClient.rpc("add_fan_points", {
        p_user_id: activeUser.id,
        p_partner_id: rayonClub.numericId.toString(),
        p_points: 50,
        p_reason: "web_check_in",
      });
      await refresh();
      setStatus("50 XP awarded for web check-in.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "XP action failed.");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="XP and badges"
        title="Gamification works in the browser too."
        description="The web app should let active fans keep momentum without forcing every interaction back to mobile."
      />
      <div className="grid gap-5 md:grid-cols-3">
        <PortalStateCard
          label="Current tier"
          value={(membership?.tier ?? "fan").toUpperCase()}
          helper="Tier is driven from the shared membership record."
        />
        <PortalStateCard
          label="Total XP"
          value={String(membership?.points ?? 0)}
          helper="XP is updated from shared supporter events."
        />
        <PortalStateCard
          label="Recent events"
          value={String(events.length)}
          helper="A compact event stream keeps fans aware of recent gains."
        />
      </div>
      <div className="glass-panel rounded-[32px] p-6">
        <button
          type="button"
          onClick={() => addCheckInXp()}
          className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
        >
          Claim daily web check-in
        </button>
        {status ? <p className="mt-4 text-sm text-slate-300">{status}</p> : null}
      </div>
      <div className="glass-panel rounded-[32px] p-6">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          XP event stream
        </p>
        <div className="mt-5 grid gap-3">
          {events.length > 0 ? (
            events.map((event) => (
              <div
                key={event.id}
                className="rounded-[22px] border border-border-soft bg-white/6 p-4 text-sm text-slate-200"
              >
                <p className="font-semibold uppercase tracking-[0.2em] text-club-accent">
                  {event.eventType}
                </p>
                <p className="mt-2">+{event.xpAwarded} XP</p>
                <p className="mt-1 text-slate-400">{event.createdAt}</p>
              </div>
            ))
          ) : (
            <p className="text-sm leading-7 text-slate-300">
              XP history will appear here as supporter actions are recorded.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
