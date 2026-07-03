"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Clock, Monitor, Trophy, Users } from "lucide-react";
import {
  buildTvDisplayViewModel,
  createGameRuntimeClient,
  type GameTvSessionState,
} from "@/lib/game-runtime";
import { getBrowserSupabase } from "@/lib/supabase/browser";

const TV_DISPLAY_POLL_INTERVAL_MS = 5000;

type TvRealtimeChannel = {
  on(
    event: "postgres_changes",
    config: {
      event: "*";
      schema: "africlub_game";
      table: string;
      filter: string;
    },
    callback: () => void,
  ): TvRealtimeChannel;
  subscribe(callback?: (status: string) => void): TvRealtimeChannel;
  unsubscribe?: () => Promise<unknown> | unknown;
};

type TvRealtimeClient = {
  channel(name: string): TvRealtimeChannel;
  removeChannel?: (channel: TvRealtimeChannel) => Promise<unknown> | unknown;
};

type TvDisplayClientProps = {
  initialState: GameTvSessionState;
  sessionId: string | null;
  venueCheckin?: {
    code: string;
    venueName?: string | null;
    expiresAt?: string | null;
    rewardLabel?: string | null;
  } | null;
};

export function TvDisplayClient({
  initialState,
  sessionId,
  venueCheckin = null,
}: TvDisplayClientProps) {
  const client = useMemo(() => createGameRuntimeClient({}), []);
  const [state, setState] = useState(initialState);
  const [status, setStatus] = useState<"demo" | "loading" | "live" | "error">(
    sessionId ? "loading" : "demo",
  );

  const refreshState = useCallback(
    async (activeSessionId: string, isActive: () => boolean) => {
      try {
        const nextState = await client.getTvState(activeSessionId);
        if (!isActive()) return;
        setState(nextState);
        setStatus("live");
      } catch {
        if (!isActive()) return;
        setStatus("error");
      }
    },
    [client],
  );

  useEffect(() => {
    if (!sessionId) {
      return;
    }

    let active = true;
    const activeSessionId = sessionId;

    const initialRefresh = window.setTimeout(() => {
      refreshState(activeSessionId, () => active).catch(() => {});
    }, 0);
    const interval = window.setInterval(
      () => {
        refreshState(activeSessionId, () => active).catch(() => {});
      },
      TV_DISPLAY_POLL_INTERVAL_MS,
    );

    return () => {
      active = false;
      window.clearTimeout(initialRefresh);
      window.clearInterval(interval);
    };
  }, [refreshState, sessionId]);

  useEffect(() => {
    if (!sessionId) {
      return;
    }

    const supabase = getBrowserSupabase() as TvRealtimeClient | null;
    if (supabase == null) {
      return;
    }

    let active = true;
    const activeSessionId = sessionId;
    const refreshFromRealtime = () => {
      refreshState(activeSessionId, () => active).catch(() => {});
    };
    const channel = supabase
      .channel(`africlub_game_session:${activeSessionId}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "africlub_game",
          table: "game_sessions",
          filter: `id=eq.${activeSessionId}`,
        },
        refreshFromRealtime,
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "africlub_game",
          table: "session_questions",
          filter: `session_id=eq.${activeSessionId}`,
        },
        refreshFromRealtime,
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "africlub_game",
          table: "answer_claims",
          filter: `session_id=eq.${activeSessionId}`,
        },
        refreshFromRealtime,
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "africlub_game",
          table: "session_players",
          filter: `session_id=eq.${activeSessionId}`,
        },
        refreshFromRealtime,
      );

    channel.subscribe((subscriptionStatus) => {
      if (subscriptionStatus === "SUBSCRIBED") {
        refreshFromRealtime();
      }
    });

    return () => {
      active = false;
      if (supabase.removeChannel) {
        supabase.removeChannel(channel);
      } else {
        channel.unsubscribe?.();
      }
    };
  }, [refreshState, sessionId]);

  const displayState = sessionId ? state : initialState;
  const displayStatus = sessionId ? status : "demo";
  const display = buildTvDisplayViewModel(displayState);
  const statusLabel =
    displayStatus === "live"
      ? "Live session"
      : displayStatus === "loading"
        ? "Syncing"
        : displayStatus === "error"
          ? "Connection paused"
          : "Demo mode";

  return (
    <main className="min-h-screen bg-[#07111f] text-white">
      <section className="mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-8 lg:px-10">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-white/10 pb-5">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.18em] text-cyan-200">
              AfriClub Game
            </p>
            <h1 className="mt-2 text-3xl font-semibold md:text-5xl">
              {display.headline}
            </h1>
          </div>
          <div className="flex items-center gap-3 rounded-md bg-white/10 px-4 py-3 text-sm font-semibold">
            <Monitor className="h-5 w-5 text-cyan-200" aria-hidden="true" />
            {statusLabel}
          </div>
        </header>

        {venueCheckin ? (
          <section className="mt-6 grid gap-4 rounded-lg border border-cyan-200/20 bg-cyan-200/10 p-5 md:grid-cols-[1fr_auto] md:items-center">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.18em] text-cyan-200">
                Venue check-in
              </p>
              <h2 className="mt-2 text-2xl font-semibold md:text-4xl">
                {venueCheckin.venueName ?? "Approved venue"}
              </h2>
              <p className="mt-2 text-sm text-slate-300">
                {venueCheckin.rewardLabel ?? "Open the supporter app to check in."}
              </p>
            </div>
            <div className="rounded-md bg-white px-6 py-5 text-center text-slate-950">
              <p className="text-xs font-bold uppercase tracking-[0.18em]">
                Code
              </p>
              <p className="mt-2 font-mono text-4xl font-black tracking-[0.18em]">
                {venueCheckin.code}
              </p>
              <p className="mt-2 text-xs font-semibold uppercase tracking-[0.14em] text-slate-600">
                {venueCheckin.expiresAt ?? "Rotates soon"}
              </p>
            </div>
          </section>
        ) : null}

        <div className="grid flex-1 gap-6 py-8 lg:grid-cols-[1fr_320px]">
          <section className="flex min-h-[520px] flex-col justify-between rounded-lg border border-white/10 bg-white/[0.06] p-6 shadow-2xl shadow-black/30">
            <div className="flex items-center justify-between gap-4">
              <div className="rounded-md bg-cyan-300 px-4 py-2 text-sm font-bold text-slate-950">
                {display.questionLabel}
              </div>
              <div className="flex items-center gap-2 rounded-md bg-emerald-300 px-4 py-2 text-sm font-bold text-slate-950">
                <Clock className="h-4 w-4" aria-hidden="true" />
                {displayState.currentQuestion?.timeLimitSeconds ?? 0}s
              </div>
            </div>

            <div className="mx-auto max-w-4xl text-center">
              <p className="text-lg font-semibold uppercase tracking-[0.14em] text-cyan-200">
                {display.category}
              </p>
              <h2 className="mt-5 text-4xl font-semibold leading-tight md:text-6xl">
                {display.prompt}
              </h2>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              {display.options.length === 0 ? (
                <div className="rounded-md border border-white/10 bg-slate-950/60 px-5 py-5 text-2xl font-semibold md:col-span-2">
                  Waiting for question
                </div>
              ) : (
                display.options.map((answer, index) => (
                  <div
                    key={answer.key}
                    className="rounded-md border border-white/10 bg-slate-950/60 px-5 py-5 text-2xl font-semibold"
                  >
                    {String.fromCharCode(65 + index)}. {answer.label}
                  </div>
                ))
              )}
            </div>
          </section>

          <aside className="grid content-start gap-4">
            <div className="rounded-lg border border-white/10 bg-white/[0.06] p-5">
              <div className="flex items-center gap-3 text-cyan-200">
                <Users className="h-5 w-5" aria-hidden="true" />
                <p className="font-semibold uppercase tracking-[0.14em]">
                  Live teams
                </p>
              </div>
              <div className="mt-5 space-y-4">
                {display.leaderboard.length === 0 ? (
                  <div className="rounded-md bg-slate-950/60 px-4 py-3 font-semibold">
                    Waiting for scores
                  </div>
                ) : (
                  display.leaderboard.map((team) => (
                    <div
                      key={team.rank}
                      className="flex items-center justify-between rounded-md bg-slate-950/60 px-4 py-3"
                    >
                      <span className="font-semibold">{team.teamName}</span>
                      <span className="text-xl font-bold">{team.score}</span>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="rounded-lg border border-white/10 bg-white/[0.06] p-5">
              <div className="flex items-center gap-3 text-amber-200">
                <Trophy className="h-5 w-5" aria-hidden="true" />
                <p className="font-semibold uppercase tracking-[0.14em]">
                  First correct claim
                </p>
              </div>
              <p className="mt-5 text-3xl font-bold">{display.claimLabel}</p>
              <p className="mt-2 text-sm text-slate-300">
                Correct answers stay hidden until the claim or reveal state.
              </p>
            </div>
          </aside>
        </div>
      </section>
    </main>
  );
}
