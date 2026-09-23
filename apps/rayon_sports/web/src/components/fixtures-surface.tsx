"use client";

import { FixtureTeams, TeamCard } from "@/components/team-card";

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
  CalendarDays,
  Radio,
  RefreshCw,
  Ticket,
  Trophy,
  WifiOff,
} from "lucide-react";

const FIXTURES_REQUEST_TIMEOUT_MS = 8_000;

export type FixturesSurfaceStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

type FixturesInteraction = "idle" | "focused" | "pressed" | "selected";

export type PublicFixture = {
  id: string;
  homeTeam: string;
  awayTeam: string;
  competition: string;
  venue: string;
  matchDate: string;
  kickoffTime: string | null;
  isOnSale: boolean;
  generalPrice: number;
  matchStatus: string;
  homeScore: number;
  awayScore: number;
  liveMinute: number | null;
  matchSummary: string | null;
};

type FixturesStateCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  live: string;
  upcoming: string;
  result: string;
  listed: string;
  onSale: string;
  selectedFixture: string;
  viewFixture: string;
  noFixtures: string;
  noFixturesDetail: string;
};

const fixturesStateCopy: Record<
  "en",
  FixturesStateCopy
> = {
  en: {
    status: {
      loading: {
        label: "Loading fixtures",
        detail: "Waiting for the first confirmed match schedule.",
      },
      ready: {
        label: "Fixture list confirmed",
        detail: "These matches come from the latest confirmed public schedule.",
      },
      empty: {
        label: "No fixtures listed",
        detail: "The club has no confirmed public match yet.",
      },
      error: {
        label: "Fixtures unavailable",
        detail: "Confirmed matches remain visible. Retry when the service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed matches remain visible until the connection returns.",
      },
      permission_denied: {
        label: "Fixture access denied",
        detail: "The public match schedule is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing fixtures",
        detail: "Confirmed matches remain visible while the schedule updates.",
      },
      conflict: {
        label: "Fixture list changed",
        detail: "Refresh to load the current confirmed schedule.",
      },
      security_timeout: {
        label: "Fixture request timed out",
        detail: "No schedule change is assumed. Confirmed matches remain visible.",
      },
    },
    refresh: "Refresh fixtures",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while fixtures are loading.",
    live: "Live",
    upcoming: "Upcoming",
    result: "Full time",
    listed: "Listed",
    onSale: "On sale",
    selectedFixture: "Selected fixture",
    viewFixture: "View fixture",
    noFixtures: "No club fixtures are listed yet.",
    noFixturesDetail: "Return later for the confirmed public match schedule.",
  },
};

type FixturesSurfaceProps = {
  locale: string;
  currencyCode: string;
  copy: {
    eyebrow: string;
    title: string;
    description: string;
    buyTickets: string;
    recentResults: string;
  };
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function boundedText(value: unknown, maximum = 160) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || normalized.length > maximum) return null;
  return normalized;
}

function boundedNumber(value: unknown, maximum = 1_000_000_000) {
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value >= 0 &&
    value <= maximum
    ? value
    : null;
}

export function resolveFixturesStateCopy(_locale: string): FixturesStateCopy {
  const normalized = "en";
  return (
    fixturesStateCopy[normalized as keyof typeof fixturesStateCopy] ??
    fixturesStateCopy.en
  );
}

export function normalizeFixtures(value: unknown): PublicFixture[] {
  if (!Array.isArray(value)) return [];

  const seen = new Set<string>();
  const fixtures: PublicFixture[] = [];
  for (const candidate of value) {
    if (!isRecord(candidate)) continue;
    const id = boundedText(candidate.id, 200);
    const homeTeam = boundedText(candidate.homeTeam);
    const awayTeam = boundedText(candidate.awayTeam);
    const competition = boundedText(candidate.competition);
    const venue = boundedText(candidate.venue);
    const matchDate = boundedText(candidate.matchDate, 80);
    const generalPrice = boundedNumber(candidate.generalPrice);
    const homeScore = boundedNumber(candidate.homeScore, 999);
    const awayScore = boundedNumber(candidate.awayScore, 999);
    if (
      id == null ||
      seen.has(id) ||
      homeTeam == null ||
      awayTeam == null ||
      competition == null ||
      venue == null ||
      matchDate == null ||
      Number.isNaN(Date.parse(matchDate)) ||
      generalPrice == null ||
      homeScore == null ||
      awayScore == null ||
      typeof candidate.isOnSale !== "boolean"
    ) {
      continue;
    }

    const matchStatus =
      boundedText(candidate.matchStatus, 40)?.toLowerCase() ?? "scheduled";
    const liveMinute =
      candidate.liveMinute == null
        ? null
        : boundedNumber(candidate.liveMinute, 240);
    if (candidate.liveMinute != null && liveMinute == null) continue;

    seen.add(id);
    fixtures.push({
      id,
      homeTeam,
      awayTeam,
      competition,
      venue,
      matchDate,
      kickoffTime: boundedText(candidate.kickoffTime, 40),
      isOnSale: candidate.isOnSale,
      generalPrice,
      matchStatus,
      homeScore,
      awayScore,
      liveMinute,
      matchSummary: boundedText(candidate.matchSummary, 500),
    });
  }
  return fixtures.slice(0, 20);
}

export function resolveFixturesFailureStatus(
  status: number,
): Exclude<FixturesSurfaceStatus, "loading" | "ready" | "empty" | "syncing"> {
  if (status === 403) return "permission_denied";
  if (status === 409) return "conflict";
  if (status === 504) return "security_timeout";
  return "error";
}

function isLive(status: string) {
  return status === "live";
}

function isResult(status: string) {
  return status === "fulltime" || status === "finished";
}

function formatFixtureDate(value: string, _locale: string) {
  return new Intl.DateTimeFormat("en", {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function formatFixturePrice(
  value: number,
  locale: string,
  currencyCode: string,
) {
  return new Intl.NumberFormat("en", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 0,
  }).format(value);
}

export function FixturesSurface({
  locale,
  currencyCode,
  copy,
}: FixturesSurfaceProps) {
  const localized = useMemo(() => resolveFixturesStateCopy(locale), [locale]);
  const [fixtures, setFixtures] = useState<PublicFixture[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] =
    useState<FixturesInteraction>("idle");
  const hasConfirmedFixtures = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadFixtures = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedFixtures.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, FIXTURES_REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch("/api/public-content?resource=fixtures", {
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
      if (!isRecord(payload) || !Array.isArray(payload.items)) {
        if (isMounted.current) setStatus("error");
        return;
      }

      const nextFixtures = normalizeFixtures(payload.items);
      if (!isMounted.current) return;
      setFixtures(nextFixtures);
      setSelectedId((current) =>
        nextFixtures.some((fixture) => fixture.id === current)
          ? current
          : nextFixtures[0]?.id ?? null,
      );
      hasConfirmedFixtures.current = true;
      setStatus(nextFixtures.length === 0 ? "empty" : "ready");
    } catch {
      if (!isMounted.current || (controller.signal.aborted && !timedOut)) {
        return;
      }
      if (typeof navigator !== "undefined" && !navigator.onLine) {
        setStatus("offline");
      } else if (timedOut) {
        setStatus("security_timeout");
      } else {
        setStatus("error");
      }
    } finally {
      window.clearTimeout(timeout);
      if (activeRequest.current === controller) {
        activeRequest.current = null;
      }
    }
  }, []);

  useEffect(() => {
    isMounted.current = true;
    void loadFixtures();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadFixtures();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadFixtures]);

  const selectedFixture =
    fixtures.find((fixture) => fixture.id === selectedId) ??
    fixtures[0] ??
    null;
  const message = localized.status[status];
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const liveCount = fixtures.filter((fixture) =>
    isLive(fixture.matchStatus),
  ).length;
  const onSaleCount = fixtures.filter((fixture) => fixture.isOnSale).length;

  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) {
      return;
    }
    setInteraction("pressed");
  };

  return (
    <section
      className="fixtures-surface"
      data-fixtures-status={status}
      data-fixtures-interaction={interaction}
      data-fixtures-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20 pt-8">
        <header className="fixtures-hero">
          <div>
            <p className="fixtures-eyebrow">{copy.eyebrow}</p>
            <h1 className="fixtures-title">{copy.title}</h1>
            <p className="fixtures-description">{copy.description}</p>
          </div>

          <aside
            className="fixtures-status"
            data-fixtures-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <CalendarDays aria-hidden="true" />
            )}
            <div>
              <p className="fixtures-status-label">{message.label}</p>
              <p className="fixtures-status-detail">{message.detail}</p>
            </div>
          </aside>

          <div className="fixtures-actions">
            <Link
              href="/tickets"
              className="fixtures-action fixtures-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <Ticket aria-hidden="true" />
              {copy.buyTickets}
            </Link>
            <button
              type="button"
              className="fixtures-action fixtures-action-secondary"
              disabled={isBusy}
              aria-describedby={
                isBusy ? "fixtures-refresh-disabled-reason" : undefined
              }
              onClick={() => void loadFixtures()}
              onFocus={() => setInteraction("focused")}
              onBlur={() =>
                setInteraction((current) =>
                  current === "focused" ? "idle" : current,
                )
              }
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? localized.retry : localized.refresh}
            </button>
            <span id="fixtures-refresh-disabled-reason" className="sr-only">
              {localized.refreshDisabled}
            </span>
          </div>

          <dl className="fixtures-stats">
            <div>
              <dt>{localized.live}</dt>
              <dd>{liveCount}</dd>
            </div>
            <div>
              <dt>{localized.onSale}</dt>
              <dd>{onSaleCount}</dd>
            </div>
            <div>
              <dt>{localized.listed}</dt>
              <dd>{fixtures.length}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="fixtures-recovery" role="status">
            <p>{message.label}</p>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="fixtures-content" aria-busy={isBusy}>
          {fixtures.length > 0 && selectedFixture ? (
            <>
              <article className="fixtures-featured">
                <div className="fixtures-featured-heading">
                  <p className="fixtures-eyebrow">
                    {localized.selectedFixture}
                  </p>
                  <span className="fixtures-status-pill">
                    {isLive(selectedFixture.matchStatus)
                      ? localized.live
                      : isResult(selectedFixture.matchStatus)
                        ? localized.result
                        : localized.upcoming}
                  </span>
                </div>
                <p className="fixtures-competition">
                  {selectedFixture.competition}
                </p>
                <div className="fixtures-score">
                  <div>
                    <TeamCard name={selectedFixture.homeTeam} vertical />
                  </div>
                  <b aria-label="Score">
                    {isLive(selectedFixture.matchStatus) ||
                    isResult(selectedFixture.matchStatus)
                      ? `${selectedFixture.homeScore}–${selectedFixture.awayScore}`
                      : "VS"}
                  </b>
                  <div>
                    <TeamCard name={selectedFixture.awayTeam} vertical />
                  </div>
                </div>
                <dl className="fixtures-meta">
                  <div>
                    <dt>Date</dt>
                    <dd>
                      <time dateTime={selectedFixture.matchDate}>
                        {formatFixtureDate(selectedFixture.matchDate, locale)}
                      </time>
                    </dd>
                  </div>
                  <div>
                    <dt>Venue</dt>
                    <dd>{selectedFixture.venue}</dd>
                  </div>
                  <div>
                    <dt>{localized.onSale}</dt>
                    <dd>
                      {selectedFixture.isOnSale
                        ? formatFixturePrice(
                            selectedFixture.generalPrice,
                            locale,
                            currencyCode,
                          )
                        : "—"}
                    </dd>
                  </div>
                </dl>
                <p className="fixtures-summary">
                  {selectedFixture.matchSummary ??
                    "Confirmed match details will appear here when published."}
                </p>
                <Link
                  href={`/fixtures/${encodeURIComponent(selectedFixture.id)}`}
                  className="fixtures-action fixtures-action-primary"
                >
                  {localized.viewFixture}
                  <ArrowRight aria-hidden="true" />
                </Link>
              </article>

              <div className="fixtures-list" aria-label={localized.listed}>
                {fixtures.map((fixture) => (
                  <button
                    type="button"
                    className="fixtures-card"
                    key={fixture.id}
                    aria-pressed={fixture.id === selectedFixture.id}
                    onClick={() => {
                      setSelectedId(fixture.id);
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
                    <span className="fixtures-card-icon" aria-hidden="true">
                      {isLive(fixture.matchStatus) ? (
                        <Radio />
                      ) : isResult(fixture.matchStatus) ? (
                        <Trophy />
                      ) : (
                        <CalendarDays />
                      )}
                    </span>
                    <span className="fixtures-card-copy">
                      <small>{fixture.competition}</small>
                      <strong>
                        <FixtureTeams homeTeam={fixture.homeTeam} awayTeam={fixture.awayTeam} />
                      </strong>
                      <time dateTime={fixture.matchDate}>
                        {formatFixtureDate(fixture.matchDate, locale)}
                      </time>
                    </span>
                  </button>
                ))}
              </div>
            </>
          ) : status === "empty" ? (
            <div className="fixtures-empty">
              <CalendarDays aria-hidden="true" />
              <p>{localized.noFixtures}</p>
              <span>{localized.noFixturesDetail}</span>
              <Link
                href="/results"
                className="fixtures-action fixtures-action-primary"
              >
                {copy.recentResults}
              </Link>
            </div>
          ) : (
            <div className="fixtures-loading" aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
          )}
        </section>
      </div>
    </section>
  );
}
