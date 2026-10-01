"use client";

import Link from "next/link";
import {
  PointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { ArrowRight, Flag, RefreshCw, WifiOff } from "lucide-react";

const HISTORY_REQUEST_TIMEOUT_MS = 8_000;

export type HistorySurfaceStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

type HistoryInteraction = "idle" | "focused" | "pressed" | "selected";

export type HistoryMoment = {
  id: string;
  title: string;
  body: string;
};

type HistoryStateCopy = {
  status: Record<HistorySurfaceStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  chapters: string;
  chapter: string;
  noHistory: string;
  noHistoryDetail: string;
};

const historyStateCopy: Record<"en", HistoryStateCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading club history",
        detail: "Waiting for the first confirmed history record.",
      },
      ready: {
        label: "History confirmed",
        detail: "These moments come from the latest confirmed club record.",
      },
      empty: {
        label: "History not published",
        detail: "No confirmed public history moment is available yet.",
      },
      error: {
        label: "History unavailable",
        detail: "Published moments remain visible. Retry when the service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Published moments remain visible until the connection returns.",
      },
      permission_denied: {
        label: "History access denied",
        detail: "The public history record is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing history",
        detail: "Published moments remain visible while the record updates.",
      },
      conflict: {
        label: "History changed",
        detail: "Refresh to load the current confirmed version.",
      },
      security_timeout: {
        label: "History request timed out",
        detail: "No new moment is assumed. Published moments remain visible.",
      },
    },
    refresh: "Refresh history",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while history is loading.",
    chapters: "History moments",
    chapter: "Moment",
    noHistory: "Club history is not published yet.",
    noHistoryDetail: "Return later for the confirmed public club record.",
  },
};

type HistorySurfaceProps = {
  locale: string;
  identity: string;
  copy: {
    eyebrow: string;
    title: string;
    description: string;
    newsroom: string;
    supporterChapters: string;
    moments: string;
    identity: string;
    surface: string;
    surfaceValue: string;
    clubIdentity: string;
    historyAcrossClub: string;
    identityParagraph: string;
    seeMembershipIdentity: string;
  };
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function resolveHistoryStateCopy(_locale: string): HistoryStateCopy {
  const normalized = "en";
  return historyStateCopy[normalized as keyof typeof historyStateCopy] ??
    historyStateCopy.en;
}

export function normalizeHistoryMoments(value: unknown): HistoryMoment[] {
  if (!Array.isArray(value)) return [];

  const seen = new Set<string>();
  const moments: HistoryMoment[] = [];
  for (const candidate of value) {
    if (!isRecord(candidate)) continue;
    const { id, title, body } = candidate;
    if (
      typeof id !== "string" ||
      id.trim() === "" ||
      seen.has(id.trim()) ||
      typeof title !== "string" ||
      title.trim() === "" ||
      typeof body !== "string" ||
      body.trim() === ""
    ) {
      continue;
    }
    const normalizedId = id.trim();
    seen.add(normalizedId);
    moments.push({
      id: normalizedId,
      title: title.trim(),
      body: body.trim(),
    });
  }
  return moments.slice(0, 24);
}

export function resolveHistoryFailureStatus(
  status: number,
): Exclude<HistorySurfaceStatus, "loading" | "ready" | "empty" | "syncing"> {
  if (status === 403) return "permission_denied";
  if (status === 409) return "conflict";
  if (status === 504) return "security_timeout";
  return "error";
}

export function HistorySurface({
  locale,
  identity,
  copy,
}: HistorySurfaceProps) {
  const localized = useMemo(() => resolveHistoryStateCopy(locale), [locale]);
  const [moments, setMoments] = useState<HistoryMoment[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<HistorySurfaceStatus>("loading");
  const [interaction, setInteraction] =
    useState<HistoryInteraction>("idle");
  const hasConfirmedHistory = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadHistory = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedHistory.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, HISTORY_REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch("/api/public-content?resource=history", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (isMounted.current) {
          setStatus(resolveHistoryFailureStatus(response.status));
        }
        return;
      }
      if (!isRecord(payload) || !Array.isArray(payload.items)) {
        if (isMounted.current) setStatus("error");
        return;
      }

      const nextMoments = normalizeHistoryMoments(payload.items);
      if (!isMounted.current) return;
      setMoments(nextMoments);
      setSelectedId((current) =>
        nextMoments.some((moment) => moment.id === current)
          ? current
          : nextMoments[0]?.id ?? null,
      );
      hasConfirmedHistory.current = true;
      setStatus(nextMoments.length === 0 ? "empty" : "ready");
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
    void loadHistory();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadHistory();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadHistory]);

  const selectedMoment =
    moments.find((moment) => moment.id === selectedId) ?? moments[0] ?? null;
  const message = localized.status[status];
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);

  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) {
      return;
    }
    setInteraction("pressed");
  };

  return (
    <section
      className="history-surface"
      data-history-status={status}
      data-history-interaction={interaction}
      data-history-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20 pt-8">
        <header className="history-hero">
          <div>
            <p className="history-eyebrow">{copy.eyebrow}</p>
            <h1 className="history-title">{copy.title}</h1>
            <p className="history-description">{copy.description}</p>
          </div>

          <aside
            className="history-status"
            data-history-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <RefreshCw aria-hidden="true" />
            )}
            <div>
              <p className="history-status-label">{message.label}</p>
              <p className="history-status-detail">{message.detail}</p>
            </div>
          </aside>

          <div className="history-actions">
            <Link
              href="/news"
              className="history-action history-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              {copy.newsroom}
            </Link>
            <Link
              href="/fan-clubs"
              className="history-action history-action-secondary"
            >
              {copy.supporterChapters}
            </Link>
            <button
              type="button"
              className="history-action history-action-secondary"
              disabled={isBusy}
              aria-describedby={
                isBusy ? "history-refresh-disabled-reason" : undefined
              }
              onClick={() => void loadHistory()}
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
            <span id="history-refresh-disabled-reason" className="sr-only">
              {localized.refreshDisabled}
            </span>
          </div>

          <dl className="history-stats">
            <div>
              <dt>{copy.moments}</dt>
              <dd>{moments.length}</dd>
            </div>
            <div>
              <dt>{copy.identity}</dt>
              <dd>{identity}</dd>
            </div>
            <div>
              <dt>{copy.surface}</dt>
              <dd>{copy.surfaceValue}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="history-recovery" role="status">
            <p>{message.label}</p>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="history-content" aria-busy={isBusy}>
          {moments.length > 0 && selectedMoment ? (
            <>
              <div
                className="history-chapters"
                role="group"
                aria-label={localized.chapters}
              >
                {moments.map((moment, index) => (
                  <button
                    type="button"
                    key={moment.id}
                    aria-pressed={moment.id === selectedMoment.id}
                    onClick={() => {
                      setSelectedId(moment.id);
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
                    <span>{localized.chapter}</span>
                    <strong>{index + 1}</strong>
                    <small>{moment.title}</small>
                  </button>
                ))}
              </div>

              <article className="history-chapter" aria-live="polite">
                <span className="history-chapter-icon" aria-hidden="true">
                  <Flag />
                </span>
                <p className="history-chapter-kicker">
                  {localized.chapter}{" "}
                  {moments.findIndex(
                    (moment) => moment.id === selectedMoment.id,
                  ) + 1}
                </p>
                <h2>{selectedMoment.title}</h2>
                <p>{selectedMoment.body}</p>
              </article>
            </>
          ) : isBusy ? (
            <div className="history-loading" aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="history-empty">
              <p>{localized.noHistory}</p>
              <span>{localized.noHistoryDetail}</span>
            </div>
          )}
        </section>

        <section className="history-identity">
          <p className="history-eyebrow">{copy.clubIdentity}</p>
          <h2>{copy.historyAcrossClub}</h2>
          <p>{copy.identityParagraph}</p>
          <Link
            href="/membership"
            className="history-action history-action-secondary"
          >
            {copy.seeMembershipIdentity} <ArrowRight aria-hidden="true" />
          </Link>
        </section>
      </div>
    </section>
  );
}
