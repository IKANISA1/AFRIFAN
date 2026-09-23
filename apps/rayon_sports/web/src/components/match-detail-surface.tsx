"use client";

import { FixtureTeams } from "@/components/team-card";

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
  ArrowLeft,
  CalendarDays,
  MapPin,
  RefreshCw,
  ShieldCheck,
  Ticket,
  WifiOff,
} from "lucide-react";

const MATCH_DETAIL_REQUEST_TIMEOUT_MS = 8_000;

export type MatchDetailStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

type MatchDetailMode = "fixture" | "ticket";
type MatchDetailInteraction = "idle" | "focused" | "pressed" | "selected";
type MatchDetailPanel = "overview" | "access";

export type PublicMatchDetail = {
  id: string;
  homeTeam: string;
  awayTeam: string;
  competition: string;
  venue: string;
  matchDate: string;
  kickoffTime: string | null;
  isOnSale: boolean;
  generalPrice: number;
  vipPrice: number;
  matchStatus: string;
  homeScore: number;
  awayScore: number;
  liveMinute: number | null;
  matchSummary: string | null;
};

type MatchDetailCopy = {
  backLabel: string;
  eyebrow: string;
  description: string;
  continueInFanApp: string;
  membership: string;
};

type MatchDetailSurfaceProps = {
  matchId: string;
  mode: MatchDetailMode;
  locale: string;
  currencyCode: string;
  copy: MatchDetailCopy;
};

type StateCopy = {
  status: Record<MatchDetailStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  overview: string;
  access: string;
  kickoff: string;
  venue: string;
  general: string;
  vip: string;
  onSale: string;
  unavailable: string;
  noDetail: string;
  noDetailBody: string;
  fixtureDetail: string;
  ticketDetail: string;
  viewFixture: string;
  viewTickets: string;
  confirmedOnly: string;
};

const stateCopy: Record<"en", StateCopy> = {
  en: {
    status: {
      loading: { label: "Loading match details", detail: "Waiting for the first confirmed match record." },
      ready: { label: "Match details confirmed", detail: "This information comes from the latest confirmed public record." },
      empty: { label: "Match not found", detail: "No confirmed public record matches this fixture." },
      error: { label: "Match details unavailable", detail: "Confirmed details remain visible. Retry when the service recovers." },
      offline: { label: "You are offline", detail: "Confirmed details remain visible until the connection returns." },
      permission_denied: { label: "Match access denied", detail: "This public match record is not available to this visitor." },
      syncing: { label: "Refreshing match details", detail: "Confirmed details remain visible while the record updates." },
      conflict: { label: "Match details changed", detail: "Refresh to load the current confirmed record." },
      security_timeout: { label: "Match request timed out", detail: "No change is assumed. Confirmed details remain visible." },
    },
    refresh: "Refresh details",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while match details are loading.",
    overview: "Overview",
    access: "Access",
    kickoff: "Kickoff",
    venue: "Venue",
    general: "General admission",
    vip: "VIP access",
    onSale: "On sale",
    unavailable: "Not currently on sale",
    noDetail: "No confirmed match detail is available.",
    noDetailBody: "Return to the match list or try again later.",
    fixtureDetail: "Fixture detail",
    ticketDetail: "Ticket detail",
    viewFixture: "View fixture detail",
    viewTickets: "View ticket access",
    confirmedOnly: "Lineups, live events, and operational notes appear only after the club confirms them.",
  },
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function boundedText(value: unknown, maximum: number) {
  return typeof value === "string" &&
    value.trim() !== "" &&
    value.length <= maximum
    ? value.trim()
    : null;
}

export function normalizeMatchDetail(value: unknown): PublicMatchDetail | null {
  if (!isRecord(value)) return null;
  const id = boundedText(value.id, 200);
  const homeTeam = boundedText(value.homeTeam, 160);
  const awayTeam = boundedText(value.awayTeam, 160);
  const competition = boundedText(value.competition, 160);
  const venue = boundedText(value.venue, 240);
  const matchDate = boundedText(value.matchDate, 80);
  if (
    !id ||
    !homeTeam ||
    !awayTeam ||
    !competition ||
    !venue ||
    !matchDate ||
    Number.isNaN(Date.parse(matchDate)) ||
    typeof value.isOnSale !== "boolean" ||
    typeof value.generalPrice !== "number" ||
    !Number.isFinite(value.generalPrice) ||
    value.generalPrice < 0 ||
    typeof value.vipPrice !== "number" ||
    !Number.isFinite(value.vipPrice) ||
    value.vipPrice < 0 ||
    typeof value.matchStatus !== "string" ||
    typeof value.homeScore !== "number" ||
    typeof value.awayScore !== "number"
  ) {
    return null;
  }
  return {
    id,
    homeTeam,
    awayTeam,
    competition,
    venue,
    matchDate,
    kickoffTime:
      value.kickoffTime == null ? null : boundedText(value.kickoffTime, 40),
    isOnSale: value.isOnSale,
    generalPrice: value.generalPrice,
    vipPrice: value.vipPrice,
    matchStatus: value.matchStatus.slice(0, 80),
    homeScore: value.homeScore,
    awayScore: value.awayScore,
    liveMinute:
      typeof value.liveMinute === "number" && Number.isFinite(value.liveMinute)
        ? value.liveMinute
        : null,
    matchSummary:
      value.matchSummary == null ? null : boundedText(value.matchSummary, 2_000),
  };
}

export function resolveMatchDetailFailureStatus(
  status: number,
): MatchDetailStatus {
  if (status === 401 || status === 403) return "permission_denied";
  if (status === 409) return "conflict";
  if (status === 408 || status === 504) return "security_timeout";
  return "error";
}

export function resolveMatchDetailStateCopy(_locale: string): StateCopy {
  const language = "en";
  return stateCopy[language as keyof typeof stateCopy] ?? stateCopy.en;
}

function formatMoney(value: number, locale: string, currencyCode: string) {
  return new Intl.NumberFormat("en", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 0,
  }).format(value);
}

function formatMatchDate(value: string, _locale: string) {
  return new Intl.DateTimeFormat("en", {
    dateStyle: "full",
    timeStyle: "short",
  }).format(new Date(value));
}

export function MatchDetailSurface({
  matchId,
  mode,
  locale,
  currencyCode,
  copy,
}: MatchDetailSurfaceProps) {
  const localized = useMemo(
    () => resolveMatchDetailStateCopy(locale),
    [locale],
  );
  const [match, setMatch] = useState<PublicMatchDetail | null>(null);
  const [status, setStatus] = useState<MatchDetailStatus>("loading");
  const [interaction, setInteraction] =
    useState<MatchDetailInteraction>("idle");
  const [panel, setPanel] = useState<MatchDetailPanel>(
    mode === "ticket" ? "access" : "overview",
  );
  const hasConfirmedMatch = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadMatch = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedMatch.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, MATCH_DETAIL_REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(
        `/api/public-content?resource=fixture-detail&matchId=${encodeURIComponent(matchId)}`,
        {
          cache: "no-store",
          headers: { Accept: "application/json" },
          signal: controller.signal,
        },
      );
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (isMounted.current) {
          setStatus(resolveMatchDetailFailureStatus(response.status));
        }
        return;
      }
      if (!isRecord(payload) || !("item" in payload)) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const nextMatch = normalizeMatchDetail(payload.item);
      if (!isMounted.current) return;
      setMatch(nextMatch);
      hasConfirmedMatch.current = nextMatch != null;
      setStatus(nextMatch == null ? "empty" : "ready");
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
  }, [matchId]);

  useEffect(() => {
    isMounted.current = true;
    void loadMatch();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadMatch();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadMatch]);

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
  const choosePanel = (nextPanel: MatchDetailPanel) => {
    setPanel(nextPanel);
    setInteraction("selected");
  };
  const isPlayed =
    match != null &&
    ["live", "finished", "full_time", "result"].includes(
      match.matchStatus.toLowerCase(),
    );

  return (
    <article
      className="match-detail-surface"
      data-match-status={status}
      data-match-interaction={interaction}
      data-match-panel={panel}
      data-match-refresh-disabled={isBusy ? "true" : "false"}
      data-match-mode={mode}
    >
      <div className="page-shell section-grid pb-20 pt-8">
        <nav className="match-detail-nav" aria-label={copy.backLabel}>
          <Link
            href={mode === "ticket" ? "/tickets" : "/fixtures"}
            className="match-detail-action match-detail-action-secondary"
            onFocus={() => setInteraction("focused")}
            onBlur={() => setInteraction("idle")}
            onPointerDown={pressControl}
            onPointerUp={() => setInteraction("idle")}
            onPointerCancel={() => setInteraction("idle")}
          >
            <ArrowLeft aria-hidden="true" />
            {copy.backLabel}
          </Link>
          <button
            type="button"
            className="match-detail-action match-detail-action-secondary"
            disabled={isBusy}
            aria-describedby={isBusy ? "match-refresh-disabled-reason" : undefined}
            onClick={() => void loadMatch()}
            onFocus={() => setInteraction("focused")}
            onBlur={() => setInteraction("idle")}
            onPointerDown={pressControl}
            onPointerUp={() => setInteraction("idle")}
            onPointerCancel={() => setInteraction("idle")}
          >
            <RefreshCw aria-hidden="true" />
            {isRecovery ? localized.retry : localized.refresh}
          </button>
          <span id="match-refresh-disabled-reason" className="sr-only">
            {localized.refreshDisabled}
          </span>
        </nav>

        <aside
          className="match-detail-status"
          data-match-status={status}
          role={status === "permission_denied" ? "alert" : "status"}
          aria-live="polite"
        >
          {status === "offline" ? (
            <WifiOff aria-hidden="true" />
          ) : (
            <ShieldCheck aria-hidden="true" />
          )}
          <div>
            <p className="match-detail-status-label">{message.label}</p>
            <p className="match-detail-status-copy">{message.detail}</p>
          </div>
        </aside>

        {isRecovery ? (
          <aside className="match-detail-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        {match ? (
          <>
            <header className="match-detail-hero" aria-busy={isBusy}>
              <p className="match-detail-eyebrow">
                {copy.eyebrow} · {match.competition}
              </p>
              <h1><FixtureTeams homeTeam={match.homeTeam} awayTeam={match.awayTeam} /></h1>
              <p className="match-detail-score">
                {isPlayed ? `${match.homeScore} — ${match.awayScore}` : "VS"}
              </p>
              <div className="match-detail-facts">
                <p><CalendarDays aria-hidden="true" /> {formatMatchDate(match.matchDate, locale)}</p>
                <p><MapPin aria-hidden="true" /> {match.venue}</p>
              </div>
            </header>

            <div className="match-detail-tabs" role="group" aria-label={copy.description}>
              <button
                type="button"
                aria-pressed={panel === "overview"}
                onClick={() => choosePanel("overview")}
                onFocus={() => setInteraction("focused")}
                onPointerDown={pressControl}
                onPointerUp={() => setInteraction("idle")}
              >
                {localized.overview}
              </button>
              <button
                type="button"
                aria-pressed={panel === "access"}
                onClick={() => choosePanel("access")}
                onFocus={() => setInteraction("focused")}
                onPointerDown={pressControl}
                onPointerUp={() => setInteraction("idle")}
              >
                {localized.access}
              </button>
            </div>

            {panel === "overview" ? (
              <section className="match-detail-panel" aria-label={localized.overview}>
                <p className="match-detail-panel-kicker">{localized.fixtureDetail}</p>
                <h2>{match.competition}</h2>
                <p>{match.matchSummary ?? copy.description}</p>
                <dl className="match-detail-data">
                  <div><dt>{localized.kickoff}</dt><dd>{match.kickoffTime ?? formatMatchDate(match.matchDate, locale)}</dd></div>
                  <div><dt>{localized.venue}</dt><dd>{match.venue}</dd></div>
                </dl>
                <p className="match-detail-confirmed-only">{localized.confirmedOnly}</p>
              </section>
            ) : (
              <section className="match-detail-panel" aria-label={localized.access}>
                <p className="match-detail-panel-kicker">{localized.ticketDetail}</p>
                <h2>{match.isOnSale ? localized.onSale : localized.unavailable}</h2>
                <dl className="match-detail-prices">
                  <div><dt>{localized.general}</dt><dd>{formatMoney(match.generalPrice, locale, currencyCode)}</dd></div>
                  <div><dt>{localized.vip}</dt><dd>{formatMoney(match.vipPrice, locale, currencyCode)}</dd></div>
                </dl>
                <div className="match-detail-panel-actions">
                  {match.isOnSale ? (
                    mode === "ticket" ? (
                      <Link className="match-detail-action match-detail-action-primary" href="/supporters">
                        <Ticket aria-hidden="true" /> {copy.continueInFanApp}
                      </Link>
                    ) : (
                      <Link className="match-detail-action match-detail-action-primary" href={`/tickets/${encodeURIComponent(match.id)}`}>
                        <Ticket aria-hidden="true" /> {localized.viewTickets}
                      </Link>
                    )
                  ) : (
                    <button className="match-detail-action match-detail-action-primary" type="button" disabled>
                      <Ticket aria-hidden="true" /> {localized.unavailable}
                    </button>
                  )}
                  <Link className="match-detail-action match-detail-action-secondary" href="/membership">
                    {copy.membership}
                  </Link>
                </div>
              </section>
            )}

            <Link
              className="match-detail-cross-link"
              href={
                mode === "ticket"
                  ? `/fixtures/${encodeURIComponent(match.id)}`
                  : `/tickets/${encodeURIComponent(match.id)}`
              }
            >
              {mode === "ticket" ? localized.viewFixture : localized.viewTickets}
            </Link>
          </>
        ) : status === "loading" ? (
          <section className="match-detail-skeleton" aria-label={message.label} aria-busy="true">
            <span />
            <span />
            <span />
          </section>
        ) : (
          <section className="match-detail-empty">
            <CalendarDays aria-hidden="true" />
            <h1>{localized.noDetail}</h1>
            <p>{localized.noDetailBody}</p>
          </section>
        )}
      </div>
    </article>
  );
}
