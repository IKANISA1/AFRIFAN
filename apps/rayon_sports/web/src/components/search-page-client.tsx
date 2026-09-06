"use client";

import Link from "next/link";
import {
  FormEvent,
  PointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { RefreshCw, Search, WifiOff } from "lucide-react";
import type { SearchIndexItem } from "@/lib/types";

const SEARCH_REQUEST_TIMEOUT_MS = 8_000;
const searchCategories = new Set<SearchIndexItem["category"]>([
  "Page",
  "Match",
  "News",
  "Shop",
  "Community",
  "Membership",
]);

export type SearchPageStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

type SearchInteraction = "idle" | "focused" | "pressed" | "selected";

type SearchStateCopy = {
  status: Record<SearchPageStatus, { label: string; detail: string }>;
  refresh: string;
  refreshDisabled: string;
  retry: string;
  suggestions: string;
  suggestionValues: string[];
  resultCount: (count: number) => string;
};

const stateCopy: Record<"en", SearchStateCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading search",
        detail: "Waiting for the first confirmed search index.",
      },
      ready: {
        label: "Search ready",
        detail: "Results come from the latest confirmed club index.",
      },
      empty: {
        label: "No results",
        detail: "Try another club topic or one of the suggestions.",
      },
      error: {
        label: "Search unavailable",
        detail: "Confirmed results are retained. Retry when the service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed results remain visible until the connection returns.",
      },
      permission_denied: {
        label: "Search access denied",
        detail: "This search index is not available to the current visitor.",
      },
      syncing: {
        label: "Refreshing results",
        detail: "Confirmed results remain visible while the index updates.",
      },
      conflict: {
        label: "Search index changed",
        detail: "Refresh to load the current confirmed version.",
      },
      security_timeout: {
        label: "Search timed out",
        detail: "No new result is assumed. Confirmed results remain visible.",
      },
    },
    refresh: "Refresh results",
    refreshDisabled: "Refresh is unavailable while a search update is in progress.",
    retry: "Try again",
    suggestions: "Suggested searches",
    suggestionValues: ["Fixtures", "Tickets", "Membership"],
    resultCount: (count) => `${count} ${count === 1 ? "result" : "results"}`,
  },
};

type SearchPageClientProps = {
  initialQuery: string;
  locale: string;
  copy: {
    search: string;
    title: string;
    intro: string;
    placeholder: string;
    noResults: string;
    trySearchHint: string;
  };
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function resolveSearchPageStateCopy(_locale: string): SearchStateCopy {
  const normalized = "en";
  return stateCopy[normalized as keyof typeof stateCopy] ?? stateCopy.en;
}

export function isSafeSearchHref(href: string): boolean {
  if (
    !href.startsWith("/") ||
    href.startsWith("//") ||
    href.includes("\\") ||
    /[\u0000-\u001f\u007f\s]/u.test(href)
  ) {
    return false;
  }

  try {
    return new URL(href, "https://africlub.invalid").origin ===
      "https://africlub.invalid";
  } catch {
    return false;
  }
}

export function normalizeSearchIndexItems(value: unknown): SearchIndexItem[] {
  if (!Array.isArray(value)) return [];

  const seen = new Set<string>();
  const items: SearchIndexItem[] = [];
  for (const candidate of value) {
    if (!isRecord(candidate)) continue;
    const { id, title, description, href, category, meta } = candidate;
    if (
      typeof id !== "string" ||
      id.trim() === "" ||
      seen.has(id) ||
      typeof title !== "string" ||
      title.trim() === "" ||
      typeof description !== "string" ||
      typeof href !== "string" ||
      !isSafeSearchHref(href) ||
      typeof category !== "string" ||
      !searchCategories.has(category as SearchIndexItem["category"]) ||
      (meta !== undefined && typeof meta !== "string")
    ) {
      continue;
    }
    seen.add(id);
    items.push({
      id,
      title: title.trim(),
      description: description.trim(),
      href,
      category: category as SearchIndexItem["category"],
      ...(typeof meta === "string" && meta.trim() !== ""
        ? { meta: meta.trim() }
        : {}),
    });
  }
  return items.slice(0, 200);
}

export function filterSearchItems(
  items: SearchIndexItem[],
  query: string,
): SearchIndexItem[] {
  const term = query.trim().toLocaleLowerCase();
  if (term === "") return items.slice(0, 24);
  return items
    .filter((item) =>
      `${item.title} ${item.description} ${item.meta ?? ""} ${item.category}`
        .toLocaleLowerCase()
        .includes(term),
    )
    .slice(0, 24);
}

export function resolveSearchFailureStatus(
  status: number,
): Exclude<SearchPageStatus, "loading" | "ready" | "empty" | "syncing"> {
  if (status === 403) return "permission_denied";
  if (status === 409) return "conflict";
  if (status === 504) return "security_timeout";
  return "error";
}

export function SearchPageClient({
  initialQuery,
  locale,
  copy,
}: SearchPageClientProps) {
  const localized = useMemo(() => resolveSearchPageStateCopy(locale), [locale]);
  const [query, setQuery] = useState(initialQuery);
  const [items, setItems] = useState<SearchIndexItem[]>([]);
  const [status, setStatus] = useState<SearchPageStatus>("loading");
  const [interaction, setInteraction] = useState<SearchInteraction>("idle");
  const hasConfirmedIndex = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadIndex = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedIndex.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, SEARCH_REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch("/api/search-index", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (isMounted.current) {
          setStatus(resolveSearchFailureStatus(response.status));
        }
        return;
      }
      if (!isRecord(payload) || !Array.isArray(payload.items)) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const nextItems = normalizeSearchIndexItems(payload.items);
      if (!isMounted.current) return;
      setItems(nextItems);
      hasConfirmedIndex.current = true;
      setStatus(nextItems.length === 0 ? "empty" : "ready");
    } catch (_error) {
      if (!isMounted.current || controller.signal.aborted && !timedOut) return;
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
    void loadIndex();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadIndex();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadIndex]);

  const results = useMemo(
    () => filterSearchItems(items, query),
    [items, query],
  );
  const renderedStatus =
    (status === "ready" || status === "empty") && results.length === 0
      ? "empty"
      : status === "empty" && results.length > 0
        ? "ready"
        : status;
  const message = localized.status[renderedStatus];
  const isBusy = renderedStatus === "loading" || renderedStatus === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(renderedStatus);

  const updateQueryUrl = (nextQuery: string) => {
    const url = new URL(window.location.href);
    if (nextQuery.trim() === "") url.searchParams.delete("q");
    else url.searchParams.set("q", nextQuery.trim());
    window.history.replaceState(window.history.state, "", url);
  };

  const submitSearch = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    updateQueryUrl(query);
  };

  const pressSearch = (event: PointerEvent<HTMLButtonElement>) => {
    if (event.currentTarget.disabled) return;
    setInteraction("pressed");
  };

  return (
    <section
      className="search-surface"
      data-search-page-status={renderedStatus}
      data-search-interaction={interaction}
      data-search-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20 pt-8">
        <header className="search-hero">
          <div>
            <p className="search-eyebrow">{copy.search}</p>
            <h1 className="search-title">{copy.title}</h1>
            <p className="search-intro">{copy.intro}</p>
          </div>

          <aside
            className="search-status"
            data-search-status={renderedStatus}
            role={renderedStatus === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {renderedStatus === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <RefreshCw aria-hidden="true" />
            )}
            <div>
              <p className="search-status-label">{message.label}</p>
              <p className="search-status-detail">{message.detail}</p>
            </div>
          </aside>

          <form className="search-form" onSubmit={submitSearch}>
            <label className="search-field">
              <span className="sr-only">{copy.search}</span>
              <Search aria-hidden="true" />
              <input
                type="search"
                name="q"
                value={query}
                placeholder={copy.placeholder}
                autoComplete="off"
                onChange={(event) => {
                  setQuery(event.target.value);
                  setInteraction("focused");
                }}
                onFocus={() => setInteraction("focused")}
                onBlur={() =>
                  setInteraction((current) =>
                    current === "focused" ? "idle" : current,
                  )
                }
              />
            </label>
            <button
              type="submit"
              className="search-submit"
              onPointerDown={pressSearch}
              onPointerUp={() => setInteraction("focused")}
              onPointerCancel={() => setInteraction("focused")}
            >
              {copy.search}
            </button>
            <button
              type="button"
              className="search-refresh"
              disabled={isBusy}
              aria-describedby={isBusy ? "search-refresh-disabled-reason" : undefined}
              onClick={() => void loadIndex()}
              onPointerDown={pressSearch}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? localized.retry : localized.refresh}
            </button>
            <span id="search-refresh-disabled-reason" className="sr-only">
              {localized.refreshDisabled}
            </span>
          </form>

          <div className="search-suggestions" aria-label={localized.suggestions}>
            <span>{localized.suggestions}</span>
            {localized.suggestionValues.map((suggestion) => {
              const selected =
                query.trim().toLocaleLowerCase() ===
                suggestion.toLocaleLowerCase();
              return (
                <button
                  type="button"
                  key={suggestion}
                  aria-pressed={selected}
                  onClick={() => {
                    setQuery(suggestion);
                    updateQueryUrl(suggestion);
                    setInteraction("selected");
                  }}
                >
                  {suggestion}
                </button>
              );
            })}
          </div>
        </header>

        {isRecovery ? (
          <aside className="search-recovery" role="status">
            <p>{message.label}</p>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <div className="search-results" aria-busy={isBusy}>
          {results.length > 0 ? (
            <>
              <p className="search-count">{localized.resultCount(results.length)}</p>
              <div className="search-result-grid">
                {results.map((item) => (
                  <Link key={item.id} href={item.href} className="search-result">
                    <div className="search-result-meta">
                      <span>{item.category}</span>
                      {item.meta ? <small>{item.meta}</small> : null}
                    </div>
                    <h2>{item.title}</h2>
                    <p>{item.description}</p>
                  </Link>
                ))}
              </div>
            </>
          ) : isBusy ? (
            <div className="search-loading" aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="search-empty">
              <p>{copy.noResults}</p>
              <span>{copy.trySearchHint}</span>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
