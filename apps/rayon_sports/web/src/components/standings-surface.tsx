"use client";

import { TeamCard } from "@/components/team-card";

import Link from "next/link";
import {
  type PointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  ArrowRight,
  BarChart3,
  CalendarDays,
  RefreshCw,
  Trophy,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const STANDINGS_TIMEOUT_MS = 8_000;

export type PublicStanding = {
  position: number;
  club: string;
  played: number;
  goalDifference: number;
  points: number;
  form: string[];
  highlight: boolean;
};

type StandingsInteraction = "idle" | "focused" | "pressed" | "selected";

type StandingsSurfaceProps = {
  locale: string;
  clubName: string;
  copy: {
    eyebrow: string;
    title: string;
    description: string;
    fixtureHub: string;
    recentResults: string;
    positionInRace: string;
    highlightedClub: string;
    summaryPoints: readonly string[];
    clubsShown: string;
    clubPosition: string;
    points: string;
    position: string;
    club: string;
    played: string;
    goalDifference: string;
    form: string;
    recentScorelines: string;
    upcomingMatches: string;
  };
};

type StandingsStateCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  selected: string;
  win: string;
  draw: string;
  loss: string;
};

const stateCopy: Record<"en", StandingsStateCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading league table",
        detail: "Waiting for the first confirmed public standings record.",
      },
      ready: {
        label: "League table confirmed",
        detail: "These positions come from the latest confirmed public table.",
      },
      empty: {
        label: "No standings listed",
        detail: "No confirmed public league positions are available yet.",
      },
      error: {
        label: "League table unavailable",
        detail: "Confirmed positions remain visible. Retry when service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed positions remain visible until the connection returns.",
      },
      permission_denied: {
        label: "Standings access denied",
        detail: "The public league table is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing league table",
        detail: "Confirmed positions remain visible while the table updates.",
      },
      conflict: {
        label: "League table changed",
        detail: "Refresh to load the current confirmed positions.",
      },
      security_timeout: {
        label: "Standings request timed out",
        detail: "No change is assumed. Confirmed positions remain visible.",
      },
    },
    refresh: "Refresh standings",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while standings are loading.",
    selected: "Selected club",
    win: "Win",
    draw: "Draw",
    loss: "Loss",
  },
};

function finiteNonNegative(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

export function normalizeStandings(value: unknown): PublicStanding[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const rows: PublicStanding[] = [];
  for (const entry of value) {
    if (typeof entry !== "object" || entry == null) continue;
    const row = entry as Record<string, unknown>;
    const position = row.position;
    const club = typeof row.club === "string" ? row.club.trim() : "";
    const key = `${position}|${club.toLowerCase()}`;
    if (
      !Number.isInteger(position) ||
      (position as number) <= 0 ||
      !club ||
      !finiteNonNegative(row.played) ||
      typeof row.goalDifference !== "number" ||
      !Number.isFinite(row.goalDifference) ||
      !finiteNonNegative(row.points) ||
      seen.has(key)
    ) {
      continue;
    }
    seen.add(key);
    rows.push({
      position: position as number,
      club,
      played: row.played as number,
      goalDifference: row.goalDifference as number,
      points: row.points as number,
      form: Array.isArray(row.form)
        ? row.form
            .filter(
              (entry): entry is string =>
                typeof entry === "string" &&
                ["W", "D", "L"].includes(entry.toUpperCase()),
            )
            .map((entry) => entry.toUpperCase())
            .slice(0, 5)
        : [],
      highlight: row.highlight === true,
    });
    if (rows.length === 24) break;
  }
  return rows.sort((a, b) => a.position - b.position);
}

export function resolveStandingsStateCopy(_locale: string) {
  const language = "en";
  return stateCopy[language as keyof typeof stateCopy] ?? stateCopy.en;
}

export function StandingsSurface({
  locale,
  clubName,
  copy,
}: StandingsSurfaceProps) {
  const localized = useMemo(
    () => resolveStandingsStateCopy(locale),
    [locale],
  );
  const [rows, setRows] = useState<PublicStanding[]>([]);
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] =
    useState<StandingsInteraction>("idle");
  const hasConfirmedRows = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadStandings = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedRows.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, STANDINGS_TIMEOUT_MS);
    try {
      const response = await fetch("/api/public-content?resource=standings", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (isMounted.current) {
          setStatus(resolveFixturesFailureStatus(response.status));
        }
        return;
      }
      const items =
        typeof payload === "object" && payload !== null && "items" in payload
          ? (payload as { items: unknown }).items
          : null;
      if (!Array.isArray(items)) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const nextRows = normalizeStandings(items);
      if (!isMounted.current) return;
      setRows(nextRows);
      setSelectedKey((current) => {
        const highlighted =
          nextRows.find((row) => row.highlight) ?? nextRows[0] ?? null;
        return nextRows.some((row) => `${row.position}|${row.club}` === current)
          ? current
          : highlighted
            ? `${highlighted.position}|${highlighted.club}`
            : null;
      });
      hasConfirmedRows.current = nextRows.length > 0;
      setStatus(nextRows.length === 0 ? "empty" : "ready");
    } catch {
      if (!isMounted.current || (controller.signal.aborted && !timedOut)) return;
      if (typeof navigator !== "undefined" && !navigator.onLine) {
        setStatus("offline");
      } else if (timedOut) {
        setStatus("security_timeout");
      } else {
        setStatus("error");
      }
    } finally {
      window.clearTimeout(timeout);
      if (activeRequest.current === controller) activeRequest.current = null;
    }
  }, []);

  useEffect(() => {
    isMounted.current = true;
    void loadStandings();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadStandings();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadStandings]);

  const selected =
    rows.find((row) => `${row.position}|${row.club}` === selectedKey) ??
    rows.find((row) => row.highlight) ??
    rows[0] ??
    null;
  const clubRow =
    rows.find((row) => row.highlight) ??
    rows.find((row) =>
      row.club.toLowerCase().includes(clubName.trim().toLowerCase()),
    ) ??
    null;
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = localized.status[status];

  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) return;
    setInteraction("pressed");
  };

  return (
    <section
      className="standings-surface"
      data-standings-status={status}
      data-standings-interaction={interaction}
      data-standings-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="standings-hero">
          <div>
            <p className="standings-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title}</h1>
            <p className="standings-description">{copy.description}</p>
          </div>
          <aside
            className="standings-status"
            data-standings-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <BarChart3 aria-hidden="true" />
            )}
            <div>
              <p>{message.label}</p>
              <span>{message.detail}</span>
            </div>
          </aside>
          <div className="standings-actions">
            <Link
              href="/fixtures"
              className="standings-action standings-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <CalendarDays aria-hidden="true" /> {copy.fixtureHub}
            </Link>
            <Link
              href="/results"
              className="standings-action standings-action-secondary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <Trophy aria-hidden="true" /> {copy.recentResults}
            </Link>
            <button
              type="button"
              className="standings-action standings-action-secondary"
              disabled={isBusy}
              aria-describedby={
                isBusy ? "standings-refresh-disabled" : undefined
              }
              onClick={() => void loadStandings()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? localized.retry : localized.refresh}
            </button>
            <span id="standings-refresh-disabled" className="sr-only">
              {localized.refreshDisabled}
            </span>
          </div>
          <dl className="standings-stats">
            <div>
              <dt>{copy.clubsShown}</dt>
              <dd>{rows.length}</dd>
            </div>
            <div>
              <dt>{copy.clubPosition}</dt>
              <dd>{clubRow ? `#${clubRow.position}` : "—"}</dd>
            </div>
            <div>
              <dt>{copy.points}</dt>
              <dd>{clubRow?.points ?? "—"}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="standings-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="standings-content" aria-busy={isBusy}>
          {selected ? (
            <>
              <article className="standings-featured">
                <p className="standings-eyebrow">{localized.selected}</p>
                <div className="standings-featured-rank">
                  <strong>#{selected.position}</strong>
                  <div>
                    <h2><TeamCard name={selected.club} /></h2>
                    <p>{copy.positionInRace}</p>
                  </div>
                </div>
                <dl className="standings-featured-stats">
                  <div>
                    <dt>{copy.played}</dt>
                    <dd>{selected.played}</dd>
                  </div>
                  <div>
                    <dt>{copy.goalDifference}</dt>
                    <dd>
                      {selected.goalDifference > 0
                        ? `+${selected.goalDifference}`
                        : selected.goalDifference}
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.points}</dt>
                    <dd>{selected.points}</dd>
                  </div>
                </dl>
                <div className="standings-form" role="group" aria-label={copy.form}>
                  {selected.form.map((entry, index) => (
                    <span
                      key={`${entry}-${index}`}
                      data-result={entry}
                      title={
                        entry === "W"
                          ? localized.win
                          : entry === "D"
                            ? localized.draw
                            : localized.loss
                      }
                    >
                      {entry}
                    </span>
                  ))}
                </div>
                <Link
                  href="/results"
                  className="standings-action standings-action-primary"
                >
                  {copy.recentScorelines} <ArrowRight aria-hidden="true" />
                </Link>
              </article>

              <div className="standings-list" role="group" aria-label={copy.title}>
                {rows.map((row) => {
                  const key = `${row.position}|${row.club}`;
                  return (
                    <button
                      type="button"
                      key={key}
                      className="standings-card"
                      aria-pressed={
                        key === `${selected.position}|${selected.club}`
                      }
                      onClick={() => {
                        setSelectedKey(key);
                        setInteraction("selected");
                      }}
                      onFocus={() => setInteraction("focused")}
                      onBlur={() =>
                        setInteraction((current) =>
                          current === "focused" ? "idle" : current,
                        )
                      }
                      onPointerDown={pressControl}
                      onPointerUp={() => setInteraction("selected")}
                      onPointerCancel={() => setInteraction("idle")}
                    >
                      <b>#{row.position}</b>
                      <span>
                        <TeamCard name={row.club} />
                        <small>
                          {copy.played}: {row.played} · {copy.goalDifference}:{" "}
                          {row.goalDifference > 0
                            ? `+${row.goalDifference}`
                            : row.goalDifference}
                        </small>
                      </span>
                      <em>
                        {row.points} {copy.points}
                      </em>
                    </button>
                  );
                })}
              </div>
            </>
          ) : status === "loading" ? (
            <div
              className="standings-skeleton"
              role="group"
              aria-label={message.label}
              aria-busy="true"
            >
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="standings-empty">
              <Trophy aria-hidden="true" />
              <h2>{localized.status.empty.label}</h2>
              <p>{localized.status.empty.detail}</p>
            </div>
          )}
        </section>

        <aside className="standings-supporting">
          <p className="standings-eyebrow">{copy.eyebrow}</p>
          <h2>{copy.highlightedClub}</h2>
          <ul>
            {copy.summaryPoints.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
          <Link
            href="/fixtures"
            className="standings-action standings-action-secondary"
          >
            {copy.upcomingMatches} <ArrowRight aria-hidden="true" />
          </Link>
        </aside>
      </div>
    </section>
  );
}
