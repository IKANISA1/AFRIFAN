"use client";

import Link from "next/link";
import Image from "next/image";
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
  CircleDollarSign,
  MapPinned,
  RefreshCw,
  Smartphone,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const CIRCLES_TIMEOUT_MS = 8_000;

export type PublicCircle = {
  id: string;
  name: string;
  imageUrl?: string;
  description: string;
  groupType: "project" | "community";
  targetAmount: number;
  currentTotal: number;
  currency: string;
  memberCount: number;
};

export type PublicChapter = {
  id: string;
  name: string;
  region: string;
  description: string;
  memberCount: number;
  eventCount: number;
};

type CirclesSnapshot = {
  groups: PublicCircle[];
  chapters: PublicChapter[];
};

type CirclesInteraction = "idle" | "focused" | "pressed" | "selected";

type CirclesSurfaceProps = {
  locale: string;
  clubShortName: string;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
  variant?: "circles" | "fan-clubs";
};

type CirclesCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  eyebrow: string;
  title: (club: string) => string;
  description: string;
  openApp: string;
  appPending: string;
  exploreChapters: string;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  campaigns: string;
  chapters: string;
  selected: string;
  selectedCampaign: string;
  publicCampaigns: string;
  campaignsDetail: string;
  chapterNetwork: string;
  chaptersDetail: string;
  raised: string;
  goal: string;
  backers: string;
  progress: string;
  events: string;
  noCampaigns: string;
  noCampaignsDetail: string;
  noChapters: string;
  noChaptersDetail: string;
  boundaryEyebrow: string;
  boundaryTitle: string;
  boundaryDetail: string;
};

const circlesCopy: Record<"en", CirclesCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading support circles",
        detail: "Waiting for the first confirmed public campaign snapshot.",
      },
      ready: {
        label: "Support circles confirmed",
        detail:
          "Campaign totals and fan clubs come from the latest public snapshot.",
      },
      empty: {
        label: "No public circles listed",
        detail: "No campaign or supporter fan clubs is currently confirmed.",
      },
      error: {
        label: "Support circles unavailable",
        detail:
          "Confirmed public data remains visible. Retry when service recovers.",
      },
      offline: {
        label: "You are offline",
        detail:
          "Confirmed public data remains visible until the connection returns.",
      },
      permission_denied: {
        label: "Support-circle access denied",
        detail:
          "Previously loaded public data has been cleared for this visitor.",
      },
      syncing: {
        label: "Refreshing support circles",
        detail:
          "Confirmed campaigns and fan clubs remain visible during refresh.",
      },
      conflict: {
        label: "Support circles changed",
        detail: "Refresh to load the current confirmed public snapshot.",
      },
      security_timeout: {
        label: "Support-circle request timed out",
        detail: "No change is assumed. Confirmed public data remains visible.",
      },
    },
    eyebrow: "Collective support",
    title: (club) => `${club} support circles`,
    description:
      "Explore club projects and community initiatives. Open the supporter app to contribute.",
    openApp: "Open supporter app",
    appPending: "App links coming soon",
    exploreChapters: "Explore fan clubs",
    refresh: "Refresh circles",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while circles are loading.",
    campaigns: "Campaigns",
    chapters: "fan clubs",
    selected: "Selected",
    selectedCampaign: "Selected campaign",
    publicCampaigns: "Confirmed public campaigns",
    campaignsDetail:
      "Choose a campaign to inspect its confirmed public totals.",
    chapterNetwork: "Official fan clubs network",
    chaptersDetail:
      "Only public fan clubs identity and activity totals appear here.",
    raised: "Raised",
    goal: "Campaign goal",
    backers: "Backers",
    progress: "Progress",
    events: "Events",
    noCampaigns: "No public campaigns listed",
    noCampaignsDetail: "Campaigns appear only after club confirmation.",
    noChapters: "No public fan clubs listed",
    noChaptersDetail: "fan clubs appear only after club confirmation.",
    boundaryEyebrow: "Trust boundary",
    boundaryTitle: "Discovery here. Secure support in the app.",
    boundaryDetail:
      "Public web never exposes contributor identities, payment details, receipts, private balances, or contribution actions. Confirm current totals and terms in the supporter app before acting.",
  },
};

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

export function normalizeCirclesSnapshot(value: unknown): CirclesSnapshot {
  if (typeof value !== "object" || value == null) {
    return { groups: [], chapters: [] };
  }
  const payload = value as Record<string, unknown>;
  const groupIds = new Set<string>();
  const groups: PublicCircle[] = [];
  if (Array.isArray(payload.groups)) {
    for (const entry of payload.groups) {
      if (typeof entry !== "object" || entry == null) continue;
      const row = entry as Record<string, unknown>;
      const id = boundedString(row.id, 200);
      const name = boundedString(row.name, 160);
      const description = boundedString(row.description, 1_000);
      const groupType = row.groupType === "project" ? "project" : "community";
      const targetAmount = Number(row.targetAmount);
      const currentTotal = Number(row.currentTotal);
      const currency = boundedString(row.currency, 3).toUpperCase();
      const memberCount = Number(row.memberCount);
      if (
        !id ||
        !name ||
        !description ||
        !Number.isFinite(targetAmount) ||
        targetAmount <= 0 ||
        targetAmount > 1_000_000_000_000 ||
        !Number.isFinite(currentTotal) ||
        currentTotal < 0 ||
        currentTotal > 1_000_000_000_000 ||
        !/^[A-Z]{3}$/.test(currency) ||
        !Number.isInteger(memberCount) ||
        memberCount < 0 ||
        memberCount > 100_000_000 ||
        groupIds.has(id)
      ) {
        continue;
      }
      groupIds.add(id);
      groups.push({
        id,
        name,
        description,
        groupType,
        targetAmount,
        currentTotal,
        currency,
        memberCount,
        ...(safeProjectImage(row.imageUrl) ? { imageUrl: safeProjectImage(row.imageUrl) } : {}),
      });
      if (groups.length === 8) break;
    }
  }

  const chapterIds = new Set<string>();
  const chapters: PublicChapter[] = [];
  if (Array.isArray(payload.chapters)) {
    for (const entry of payload.chapters) {
      if (typeof entry !== "object" || entry == null) continue;
      const row = entry as Record<string, unknown>;
      const id = boundedString(row.id, 200);
      const name = boundedString(row.name, 160);
      const region = boundedString(row.region, 120);
      const description = boundedString(row.description, 1_000);
      const memberCount = Number(row.memberCount);
      const eventCount = Number(row.eventCount);
      if (
        !id ||
        !name ||
        !region ||
        !description ||
        !Number.isInteger(memberCount) ||
        memberCount < 0 ||
        memberCount > 100_000_000 ||
        !Number.isInteger(eventCount) ||
        eventCount < 0 ||
        eventCount > 1_000_000 ||
        chapterIds.has(id)
      ) {
        continue;
      }
      chapterIds.add(id);
      chapters.push({ id, name, region, description, memberCount, eventCount });
      if (chapters.length === 12) break;
    }
  }
  return { groups, chapters };
}

export function resolveCirclesCopy(_locale: string) {
  const language = "en";
  return circlesCopy[language as keyof typeof circlesCopy] ?? circlesCopy.en;
}

export function resolveFanClubsCopy(_locale: string): CirclesCopy {
  const language = "en";
  const base =
    circlesCopy[language as keyof typeof circlesCopy] ?? circlesCopy.en;
  return {
    ...base,
    status: {
      ...base.status,
      loading: {
        label: "Loading fan clubs",
        detail: "Waiting for the first confirmed public directory.",
      },
      ready: {
        label: "Official fan clubs confirmed",
        detail: "Discover the club’s published supporter communities.",
      },
      empty: {
        label: "No public fan clubs listed",
        detail: "There are no published fan clubs yet.",
      },
      error: {
        label: "Fan clubs unavailable",
        detail:
          "Confirmed public data remains visible. Retry when service recovers.",
      },
      permission_denied: {
        label: "Fan-club access denied",
        detail:
          "Previously loaded public data has been cleared for this visitor.",
      },
      syncing: {
        label: "Refreshing fan clubs",
        detail:
          "Saved fan clubs remain visible during refresh.",
      },
      conflict: {
        label: "Fan-club directory changed",
        detail: "Refresh to load the current confirmed public directory.",
      },
      security_timeout: {
        label: "Fan-club request timed out",
        detail: "No change is assumed. Confirmed public data remains visible.",
      },
    },
    eyebrow: "Official supporter fan clubs",
    title: (club) => `${club} official fan clubs`,
    description:
      "Find a supporter community near you and discover its matchday activities.",
    exploreChapters: "Explore support circles",
    refresh: "Refresh fan clubs",
    refreshDisabled: "Refresh is unavailable while fan clubs are loading.",
    publicCampaigns: "Fan-club campaigns",
    campaignsDetail:
      "Choose a confirmed public campaign to inspect its totals.",
    chapterNetwork: "Official fan-club directory",
    chaptersDetail:
      "Find your local supporter community.",
    boundaryTitle: "Directory here. Secure membership in the app.",
  };
}

function formatAmount(value: number, currency: string, _locale: string) {
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency,
      maximumFractionDigits: 0,
    }).format(value);
  } catch {
    return `${value.toLocaleString()} ${currency}`;
  }
}

export function CirclesSurface({
  locale,
  clubShortName,
  fanAppHref,
  hasExternalAppUrl,
  variant = "circles",
}: CirclesSurfaceProps) {
  const copy = useMemo(
    () =>
      variant === "fan-clubs"
        ? resolveFanClubsCopy(locale)
        : resolveCirclesCopy(locale),
    [locale, variant],
  );
  const [snapshot, setSnapshot] = useState<CirclesSnapshot>({
    groups: [],
    chapters: [],
  });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] = useState<CirclesInteraction>("idle");
  const hasConfirmedSnapshot = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadSnapshot = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedSnapshot.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, CIRCLES_TIMEOUT_MS);
    try {
      const response = await fetch(
        `/api/public-content?resource=${variant === "fan-clubs" ? "fan-clubs" : "circles"}`,
        {
          cache: "no-store",
          headers: { Accept: "application/json" },
          signal: controller.signal,
        },
      );
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (!isMounted.current) return;
        if (response.status === 403) {
          setSnapshot({ groups: [], chapters: [] });
          setSelectedId(null);
          hasConfirmedSnapshot.current = false;
        }
        setStatus(resolveFixturesFailureStatus(response.status));
        return;
      }
      if (
        typeof payload !== "object" ||
        payload == null ||
        !("groups" in payload) ||
        !("chapters" in payload)
      ) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const nextSnapshot = normalizeCirclesSnapshot(payload);
      if (!isMounted.current) return;
      setSnapshot(nextSnapshot);
      setSelectedId((current) =>
        nextSnapshot.groups.some(({ id }) => id === current)
          ? current
          : (nextSnapshot.groups[0]?.id ?? null),
      );
      const hasData =
        variant === "fan-clubs" ? nextSnapshot.chapters.length > 0 : nextSnapshot.groups.length > 0;
      hasConfirmedSnapshot.current = hasData;
      setStatus(hasData ? "ready" : "empty");
    } catch {
      if (!isMounted.current || (controller.signal.aborted && !timedOut))
        return;
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
  }, [variant]);

  useEffect(() => {
    isMounted.current = true;
    void loadSnapshot();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadSnapshot();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadSnapshot]);

  useEffect(() => {
    if (variant !== "fan-clubs") return;
    const revealChapter = () => {
      let id: string;
      try { id = decodeURIComponent(window.location.hash.slice(1)); }
      catch { return; }
      if (!snapshot.chapters.some((chapter) => id === `fan-club-${chapter.id}`)) return;
      document.getElementById(id)?.scrollIntoView({ block: "center", behavior: "instant" });
    };
    revealChapter();
    window.addEventListener("hashchange", revealChapter);
    return () => window.removeEventListener("hashchange", revealChapter);
  }, [snapshot.chapters, variant]);

  const selected =
    snapshot.groups.find(({ id }) => id === selectedId) ??
    snapshot.groups[0] ??
    null;
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = copy.status[status];
  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled)
      return;
    setInteraction("pressed");
  };

  return (
    <section
      className="circles-surface"
      data-circles-status={status}
      data-circles-interaction={interaction}
      data-circles-refresh-disabled={isBusy ? "true" : "false"}
      data-public-surface={variant}
    >
      <div className="page-shell section-grid pb-20">
        <header className="circles-hero">
          <div>
            <p className="circles-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title(clubShortName)}</h1>
            <p className="circles-description">{copy.description}</p>
          </div>
          <div className="circles-actions">
            <Link
              href={fanAppHref}
              className="circles-action circles-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <Smartphone aria-hidden="true" />
              {hasExternalAppUrl ? copy.openApp : copy.appPending}
            </Link>
            <Link
              href={variant === "fan-clubs" ? "/circles" : "/fan-clubs"}
              className="circles-action circles-action-secondary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <MapPinned aria-hidden="true" /> {copy.exploreChapters}
            </Link>
            <button
              type="button"
              className="circles-action circles-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "circles-refresh-disabled" : undefined}
              onClick={() => void loadSnapshot()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? copy.retry : copy.refresh}
            </button>
            <span id="circles-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
        </header>

        <aside className={isRecovery ? "circles-status circles-recovery" : "circles-status sr-only"}
          role={status === "permission_denied" ? "alert" : "status"} aria-live="polite">
          <strong>{message.label}</strong><span>{message.detail}</span>
        </aside>

        <section className="circles-content" aria-busy={isBusy}>
          {variant === "circles" && (snapshot.groups.length ? (
            <section className="circles-campaigns" aria-label={copy.campaigns}>
              <div className="project-grid">
                {snapshot.groups.map((group) => {
                  const expanded = group.id === selected?.id;
                  const percentage = Math.min(100, Math.max(0,
                    Math.round(group.currentTotal / group.targetAmount * 100)));
                  return <article className="project-card" key={group.id}>
                    {group.imageUrl && <Image src={group.imageUrl} alt="" width={800} height={520}
                      unoptimized className="project-card-image"
                      onError={(event) => { event.currentTarget.style.display = "none"; }} />}
                    <div className="project-card-body">
                      <h2><button type="button" aria-expanded={expanded}
                        aria-controls={`project-${group.id}`} aria-pressed={expanded}
                        onClick={() => { setSelectedId(group.id); setInteraction("selected"); }}
                        onFocus={() => setInteraction("focused")}
                        onBlur={() => setInteraction("idle")}
                        onPointerDown={pressControl} onPointerUp={() => setInteraction("selected")}
                        onPointerCancel={() => setInteraction("idle")}>
                        {group.name}<ArrowRight aria-hidden="true" />
                      </button></h2>
                      <dl className="project-card-metrics">
                        <div><dt>Total raised</dt><dd>{formatAmount(group.currentTotal, group.currency, locale)}</dd></div>
                        <div><dt>Participants</dt><dd>{group.memberCount.toLocaleString()}</dd></div>
                      </dl>
                      <div className="circles-progress">
                        <div role="progressbar" aria-label={`${group.name} ${copy.progress}`}
                          aria-valuemin={0} aria-valuemax={100} aria-valuenow={percentage}>
                          <i style={{ width: `${percentage}%` }} />
                        </div>
                        <span>Target {formatAmount(group.targetAmount, group.currency, locale)} · {percentage}%</span>
                      </div>
                      <div id={`project-${group.id}`} hidden={!expanded}>
                        <p>{group.description}</p>
                        <Link href={fanAppHref} className="circles-action circles-action-primary">
                          {hasExternalAppUrl ? copy.openApp : copy.appPending}
                          <ArrowRight aria-hidden="true" />
                        </Link>
                      </div>
                    </div>
                  </article>;
                })}
              </div>
            </section>
          ) : status === "loading" ? (
            <div className="circles-skeleton" role="status" aria-label={message.label}>
              <span /><span /><span />
            </div>
          ) : (
            <div className="circles-empty">
              <CircleDollarSign aria-hidden="true" />
              <h2>{copy.noCampaigns}</h2><p>{copy.noCampaignsDetail}</p>
            </div>
          ))}

          {variant === "fan-clubs" && <section className="circles-chapters">
            <header>
              <div>
                <p className="circles-eyebrow">{copy.chapters}</p>
                <h2>{copy.chapterNetwork}</h2>
              </div>
              <p>{copy.chaptersDetail}</p>
            </header>
            {snapshot.chapters.length > 0 ? (
              <ul>
                {snapshot.chapters.map((chapter) => (
                  <li key={chapter.id} id={`fan-club-${chapter.id}`}>
                    <MapPinned aria-hidden="true" />
                    <div>
                      <strong>{chapter.name}</strong>
                      <small>{chapter.region}</small>
                      <p>{chapter.description}</p>
                    </div>
                    <dl>
                      <div>
                        <dt>{copy.backers}</dt>
                        <dd>{chapter.memberCount.toLocaleString()}</dd>
                      </div>
                      <div>
                        <dt>{copy.events}</dt>
                        <dd>{chapter.eventCount.toLocaleString()}</dd>
                      </div>
                    </dl>
                  </li>
                ))}
              </ul>
            ) : (
              <div className="circles-empty circles-empty-compact">
                <MapPinned aria-hidden="true" />
                <h2>{copy.noChapters}</h2>
                <p>{copy.noChaptersDetail}</p>
              </div>
            )}
          </section>}
        </section>


      </div>
    </section>
  );
}

// CMS-published media only. Reject embedded credentials and executable schemes.
function safeProjectImage(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  if (value.startsWith("/") && !value.startsWith("//") && !value.includes("\\")) return value;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password ? url.toString() : undefined;
  } catch { return undefined; }
}
