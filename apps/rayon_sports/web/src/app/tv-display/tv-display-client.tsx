"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Clock, Monitor, Trophy, Users } from "lucide-react";
import {
  buildTvDisplayViewModel,
  createGameRuntimeClient,
  GameRuntimeRequestError,
  type GameTvSessionState,
} from "@/lib/game-runtime";
import { getBrowserSupabase } from "@/lib/supabase/browser";

const TV_DISPLAY_POLL_INTERVAL_MS = 5000;
const TV_DISPLAY_REQUEST_TIMEOUT_MS = 8000;

export type TvDisplayStatus =
  | "demo"
  | "loading"
  | "live"
  | "syncing"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "disabled"
  | "conflict"
  | "security_timeout";

const statusContent: Record<
  TvDisplayStatus,
  { label: string; detail: string }
> = {
  demo: {
    label: "Demo mode",
    detail: "Sample matchday content is shown. No live session is connected.",
  },
  loading: {
    label: "Connecting",
    detail: "Waiting for the first safe session update.",
  },
  live: {
    label: "Live session",
    detail: "The display is current and continues to refresh.",
  },
  syncing: {
    label: "Updating",
    detail: "The last confirmed round stays visible while the next update loads.",
  },
  empty: {
    label: "Waiting room",
    detail: "The host has not opened a question or published scores yet.",
  },
  error: {
    label: "Connection paused",
    detail: "The last confirmed display is retained. Ask the host to retry.",
  },
  offline: {
    label: "Offline",
    detail: "The last confirmed display is retained until this screen reconnects.",
  },
  permission_denied: {
    label: "Display access denied",
    detail: "Ask the host to verify this screen or issue a new display link.",
  },
  disabled: {
    label: "Session closed",
    detail: "This round is no longer accepting updates. Ask the host to start another.",
  },
  conflict: {
    label: "Session changed",
    detail: "The host changed this round. The display will reload current state.",
  },
  security_timeout: {
    label: "Update timed out",
    detail: "No change is assumed. The last confirmed display remains visible.",
  },
};

const recoveryStatuses = new Set<TvDisplayStatus>([
  "error",
  "offline",
  "permission_denied",
  "conflict",
  "security_timeout",
]);

export function resolveTvDisplayStatus(
  state: GameTvSessionState,
): TvDisplayStatus {
  if (state.phase === "closed") return "disabled";
  if (state.currentQuestion == null && state.leaderboard.length === 0) {
    return "empty";
  }
  return "live";
}

export function resolveTvDisplayFailure(error: unknown): TvDisplayStatus {
  if (error instanceof GameRuntimeRequestError) {
    return error.kind;
  }
  return "error";
}

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
  const client = useMemo(
    () =>
      createGameRuntimeClient({
        timeoutMs: TV_DISPLAY_REQUEST_TIMEOUT_MS,
      }),
    [],
  );
  const [state, setState] = useState(initialState);
  const [status, setStatus] = useState<TvDisplayStatus>(
    sessionId ? "loading" : "demo",
  );
  const hasConfirmedState = useRef(false);

  const refreshState = useCallback(
    async (activeSessionId: string, isActive: () => boolean) => {
      if (typeof navigator !== "undefined" && !navigator.onLine) {
        if (isActive()) setStatus("offline");
        return;
      }

      if (isActive()) {
        setStatus(hasConfirmedState.current ? "syncing" : "loading");
      }

      try {
        const nextState = await client.getTvState(activeSessionId);
        if (!isActive()) return;
        setState(nextState);
        hasConfirmedState.current = true;
        setStatus(resolveTvDisplayStatus(nextState));
      } catch (error) {
        if (!isActive()) return;
        setStatus(resolveTvDisplayFailure(error));
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
    const isActive = () => active;
    const refresh = () => {
      refreshState(activeSessionId, isActive).catch(() => {});
    };
    const handleOffline = () => {
      if (active) setStatus("offline");
    };

    const initialRefresh = window.setTimeout(refresh, 0);
    const interval = window.setInterval(
      refresh,
      TV_DISPLAY_POLL_INTERVAL_MS,
    );
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", refresh);

    return () => {
      active = false;
      window.clearTimeout(initialRefresh);
      window.clearInterval(interval);
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", refresh);
    };
  }, [refreshState, sessionId]);

  useEffect(() => {
    if (
      !sessionId ||
      !Number.isSafeInteger(state.clubId) ||
      state.clubId <= 0
    ) {
      return;
    }

    const supabase = getBrowserSupabase() as TvRealtimeClient | null;
    if (supabase == null) {
      return;
    }

    let active = true;
    const activeSessionId = sessionId;
    const activeClubId = state.clubId;
    const refreshFromRealtime = () => {
      refreshState(activeSessionId, () => active).catch(() => {});
    };
    const channel = supabase
      .channel(`${activeClubId}:game_session:${activeSessionId}`)
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
  }, [refreshState, sessionId, state.clubId]);

  const displayState = sessionId ? state : initialState;
  const displayStatus = sessionId ? status : "demo";
  const display = buildTvDisplayViewModel(displayState);
  const statusMessage = statusContent[displayStatus];

  return (
    <main
      className="tv-display min-h-screen"
      data-tv-display-status={displayStatus}
    >
      <section className="mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-8 lg:px-10">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-[var(--tv-border)] pb-5">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--tv-accent)]">
              AfriClub Game
            </p>
            <h1 className="mt-2 text-3xl font-semibold md:text-5xl">
              {display.headline}
            </h1>
          </div>
          <div
            className="flex max-w-md items-start gap-3 rounded-lg border border-[var(--tv-border)] bg-[var(--tv-panel-strong)] px-4 py-3"
            role="status"
            aria-live="polite"
            data-tv-status={displayStatus}
          >
            <Monitor
              className="mt-0.5 h-5 w-5 shrink-0 text-[var(--tv-accent)]"
              aria-hidden="true"
            />
            <div>
              <p className="text-sm font-bold">{statusMessage.label}</p>
              <p className="mt-1 text-xs leading-5 text-[var(--tv-copy-muted)]">
                {statusMessage.detail}
              </p>
            </div>
          </div>
        </header>

        {recoveryStatuses.has(displayStatus) ? (
          <aside
            className="mt-5 rounded-lg border border-[var(--tv-status-border)] bg-[var(--tv-status-surface)] px-5 py-4"
            role={
              displayStatus === "permission_denied" ? "alert" : "status"
            }
          >
            <p className="font-semibold">{statusMessage.label}</p>
            <p className="mt-1 text-sm leading-6 text-[var(--tv-copy-muted)]">
              {statusMessage.detail}
            </p>
          </aside>
        ) : null}

        {venueCheckin ? (
          <section className="mt-6 grid gap-4 rounded-lg border border-[var(--tv-accent-border)] bg-[var(--tv-accent-surface)] p-5 md:grid-cols-[1fr_auto] md:items-center">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--tv-accent)]">
                Venue check-in
              </p>
              <h2 className="mt-2 text-2xl font-semibold md:text-4xl">
                {venueCheckin.venueName ?? "Approved venue"}
              </h2>
              <p className="mt-2 text-sm text-[var(--tv-copy-muted)]">
                {venueCheckin.rewardLabel ??
                  "Open the supporter app to check in."}
              </p>
            </div>
            <div className="rounded-md bg-[var(--tv-code-surface)] px-6 py-5 text-center text-[var(--tv-code-ink)]">
              <p className="text-xs font-bold uppercase tracking-[0.18em]">
                Code
              </p>
              <p className="mt-2 font-mono text-4xl font-black tracking-[0.18em]">
                {venueCheckin.code}
              </p>
              <p className="mt-2 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--tv-code-muted)]">
                {venueCheckin.expiresAt ?? "Rotates soon"}
              </p>
            </div>
          </section>
        ) : null}

        <div className="grid flex-1 gap-6 py-8 lg:grid-cols-[1fr_320px]">
          <section className="flex min-h-[520px] flex-col justify-between rounded-lg border border-[var(--tv-border)] bg-[var(--tv-panel)] p-6 shadow-2xl shadow-black/30">
            <div className="flex items-center justify-between gap-4">
              <div className="rounded-md bg-[var(--tv-accent-fill)] px-4 py-2 text-sm font-bold text-[var(--tv-accent-ink)]">
                {display.questionLabel}
              </div>
              <div className="flex items-center gap-2 rounded-md bg-[var(--tv-success-fill)] px-4 py-2 text-sm font-bold text-[var(--tv-success-ink)]">
                <Clock className="h-4 w-4" aria-hidden="true" />
                {displayState.currentQuestion?.timeLimitSeconds ?? 0}s
              </div>
            </div>

            <div className="mx-auto max-w-4xl text-center">
              <p className="text-lg font-semibold uppercase tracking-[0.14em] text-[var(--tv-accent)]">
                {display.category}
              </p>
              <h2 className="mt-5 text-4xl font-semibold leading-tight md:text-6xl">
                {display.prompt}
              </h2>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              {display.options.length === 0 ? (
                <div className="rounded-md border border-[var(--tv-border)] bg-[var(--tv-option-surface)] px-5 py-5 text-2xl font-semibold md:col-span-2">
                  Waiting for question
                </div>
              ) : (
                display.options.map((answer, index) => (
                  <div
                    key={answer.key}
                    className="rounded-md border border-[var(--tv-border)] bg-[var(--tv-option-surface)] px-5 py-5 text-2xl font-semibold"
                  >
                    {String.fromCharCode(65 + index)}. {answer.label}
                  </div>
                ))
              )}
            </div>
          </section>

          <aside className="grid content-start gap-4">
            <div className="rounded-lg border border-[var(--tv-border)] bg-[var(--tv-panel)] p-5">
              <div className="flex items-center gap-3 text-[var(--tv-accent)]">
                <Users className="h-5 w-5" aria-hidden="true" />
                <p className="font-semibold uppercase tracking-[0.14em]">
                  Live teams
                </p>
              </div>
              <div className="mt-5 space-y-4">
                {display.leaderboard.length === 0 ? (
                  <div className="rounded-md bg-[var(--tv-option-surface)] px-4 py-3 font-semibold">
                    Waiting for scores
                  </div>
                ) : (
                  display.leaderboard.map((team) => (
                    <div
                      key={team.rank}
                      className="flex items-center justify-between rounded-md bg-[var(--tv-option-surface)] px-4 py-3"
                    >
                      <span className="font-semibold">{team.teamName}</span>
                      <span className="text-xl font-bold">{team.score}</span>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="rounded-lg border border-[var(--tv-border)] bg-[var(--tv-panel)] p-5">
              <div className="flex items-center gap-3 text-[var(--tv-warning)]">
                <Trophy className="h-5 w-5" aria-hidden="true" />
                <p className="font-semibold uppercase tracking-[0.14em]">
                  First correct claim
                </p>
              </div>
              <p className="mt-5 text-3xl font-bold">{display.claimLabel}</p>
              <p className="mt-2 text-sm text-[var(--tv-copy-muted)]">
                Correct answers stay hidden until the claim or reveal state.
              </p>
            </div>
          </aside>
        </div>
      </section>
    </main>
  );
}
