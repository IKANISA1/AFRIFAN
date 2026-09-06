"use client";

import Image from "next/image";
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
  BadgeCheck,
  CalendarDays,
  Newspaper,
  RefreshCw,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  Sparkles,
  Ticket,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const HOME_TIMEOUT_MS = 8_000;

export type PublicHomeMatch = {
  id: string;
  homeTeam: string;
  awayTeam: string;
  competition: string;
  venue: string;
  matchDate: string;
  kickoffTime: string | null;
  matchStatus: string;
};

export type PublicHomeNews = {
  id: string;
  title: string;
  excerpt: string;
  category: string;
  publishedAt: string;
  author: string;
};

export type PublicHomeProduct = {
  id: string;
  name: string;
  subtitle: string;
  category: string;
  price: number;
  isAvailable: boolean;
};

export type PublicHomeMembership = {
  id: string;
  tier: string;
  title: string;
  description: string;
  annualPrice: number;
  perks: string[];
};

export type PublicHomeSnapshot = {
  matches: PublicHomeMatch[];
  news: PublicHomeNews[];
  products: PublicHomeProduct[];
  memberships: PublicHomeMembership[];
};

type HomeInteraction = "idle" | "focused" | "pressed" | "selected";

type HomeSurfaceProps = {
  locale: string;
  clubShortName: string;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
};

type HomeCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  eyebrow: string;
  title: (club: string) => string;
  description: string;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  app: string;
  appPending: string;
  confirmed: string;
  nextMatch: string;
  latestNews: string;
  shop: string;
  membership: string;
  noContent: string;
  noContentDetail: string;
  quickActions: string;
  chooseAction: string;
  openSelected: string;
  fixtures: string;
  tickets: string;
  supporters: string;
  selected: string;
  boundaryEyebrow: string;
  boundaryTitle: string;
  boundaryDetail: string;
};

const en: HomeCopy = {
  status: {
    loading: {
      label: "Loading the official club home",
      detail: "Waiting for the first confirmed public club snapshot.",
    },
    ready: {
      label: "Club home confirmed",
      detail: "Match, news, membership, and shop previews are current.",
    },
    empty: {
      label: "No public highlights",
      detail: "The club has not confirmed public home highlights yet.",
    },
    error: {
      label: "Club home unavailable",
      detail: "Confirmed highlights remain visible. Retry when service recovers.",
    },
    offline: {
      label: "You are offline",
      detail: "Confirmed highlights remain visible until connection returns.",
    },
    permission_denied: {
      label: "Home access denied",
      detail: "Previously loaded public highlights have been cleared.",
    },
    syncing: {
      label: "Refreshing club highlights",
      detail: "Confirmed highlights remain visible during refresh.",
    },
    conflict: {
      label: "Club highlights changed",
      detail: "Refresh to load the current confirmed snapshot.",
    },
    security_timeout: {
      label: "Home request timed out",
      detail: "No booking, membership, order, or payment is assumed.",
    },
  },
  eyebrow: "Official club home",
  title: (club) => `${club}. Matchday starts here.`,
  description:
    "One privacy-safe view of confirmed fixtures, club news, membership, and merchandise. Transactions and supporter accounts remain in approved club channels.",
  refresh: "Refresh highlights",
  retry: "Try again",
  refreshDisabled: "Refresh is unavailable while highlights are loading.",
  app: "Open supporter app",
  appPending: "Supporter app coming soon",
  confirmed: "Confirmed public highlights",
  nextMatch: "Next match",
  latestNews: "Latest news",
  shop: "Shop preview",
  membership: "Membership preview",
  noContent: "No public highlights",
  noContentDetail: "Highlights appear only after club confirmation.",
  quickActions: "Choose your next step",
  chooseAction: "Select an action",
  openSelected: "Open selected",
  fixtures: "Fixtures",
  tickets: "Tickets",
  supporters: "Supporters",
  selected: "Selected",
  boundaryEyebrow: "Public home boundary",
  boundaryTitle: "Discover here. Complete protected tasks in approved channels.",
  boundaryDetail:
    "This page exposes no supporter identity, private membership state, ticket booking, cart, order, delivery address, payment detail, receipt, internal lineup, or authenticated mutation.",
};

function localizedCopy(_locale: string): HomeCopy {
  const _language = "en";
  return en;
}

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

function boundedNumber(value: unknown) {
  const number = Number(value);
  return Number.isFinite(number) &&
    number >= 0 &&
    number <= 1_000_000_000_000
    ? number
    : null;
}

export function normalizeHomeSnapshot(value: unknown): PublicHomeSnapshot {
  const empty: PublicHomeSnapshot = {
    matches: [],
    news: [],
    products: [],
    memberships: [],
  };
  if (typeof value !== "object" || value == null) return empty;
  const payload = value as Record<string, unknown>;
  const unique = <T extends { id: string }>(items: T[], maximum: number) => {
    const ids = new Set<string>();
    return items.filter((item) => {
      if (ids.has(item.id) || ids.size >= maximum) return false;
      ids.add(item.id);
      return true;
    });
  };

  const matches = unique(
    (Array.isArray(payload.matches) ? payload.matches : [])
      .map((entry): PublicHomeMatch | null => {
        if (typeof entry !== "object" || entry == null) return null;
        const row = entry as Record<string, unknown>;
        const item = {
          id: boundedString(row.id, 200),
          homeTeam: boundedString(row.homeTeam, 160),
          awayTeam: boundedString(row.awayTeam, 160),
          competition: boundedString(row.competition, 160),
          venue: boundedString(row.venue, 200),
          matchDate: boundedString(row.matchDate, 100),
          kickoffTime: boundedString(row.kickoffTime, 40) || null,
          matchStatus: boundedString(row.matchStatus, 40),
        };
        return item.id &&
          item.homeTeam &&
          item.awayTeam &&
          item.competition &&
          item.venue &&
          item.matchDate &&
          item.matchStatus
          ? item
          : null;
      })
      .filter((item): item is PublicHomeMatch => item != null),
    3,
  );

  const news = unique(
    (Array.isArray(payload.news) ? payload.news : [])
      .map((entry): PublicHomeNews | null => {
        if (typeof entry !== "object" || entry == null) return null;
        const row = entry as Record<string, unknown>;
        const item = {
          id: boundedString(row.id, 200),
          title: boundedString(row.title, 200),
          excerpt: boundedString(row.excerpt, 600),
          category: boundedString(row.category, 100),
          publishedAt: boundedString(row.publishedAt, 100),
          author: boundedString(row.author, 160),
        };
        return Object.values(item).every(Boolean) ? item : null;
      })
      .filter((item): item is PublicHomeNews => item != null),
    3,
  );

  const products = unique(
    (Array.isArray(payload.products) ? payload.products : [])
      .map((entry): PublicHomeProduct | null => {
        if (typeof entry !== "object" || entry == null) return null;
        const row = entry as Record<string, unknown>;
        const price = boundedNumber(row.price);
        const item = {
          id: boundedString(row.id, 200),
          name: boundedString(row.name, 160),
          subtitle: boundedString(row.subtitle, 500),
          category: boundedString(row.category, 100),
          price: price ?? -1,
          isAvailable: row.isAvailable === true,
        };
        return item.id &&
          item.name &&
          item.subtitle &&
          item.category &&
          price != null &&
          typeof row.isAvailable === "boolean"
          ? item
          : null;
      })
      .filter((item): item is PublicHomeProduct => item != null),
    3,
  );

  const memberships = unique(
    (Array.isArray(payload.memberships) ? payload.memberships : [])
      .map((entry): PublicHomeMembership | null => {
        if (typeof entry !== "object" || entry == null) return null;
        const row = entry as Record<string, unknown>;
        const annualPrice = boundedNumber(row.annualPrice);
        const perks = Array.isArray(row.perks)
          ? Array.from(
              new Set(
                row.perks
                  .map((perk) => boundedString(perk, 200))
                  .filter(Boolean),
              ),
            ).slice(0, 3)
          : [];
        const item = {
          id: boundedString(row.id, 200),
          tier: boundedString(row.tier, 80),
          title: boundedString(row.title, 160),
          description: boundedString(row.description, 600),
          annualPrice: annualPrice ?? -1,
          perks,
        };
        return item.id &&
          item.tier &&
          item.title &&
          item.description &&
          annualPrice != null &&
          perks.length > 0
          ? item
          : null;
      })
      .filter((item): item is PublicHomeMembership => item != null),
    3,
  );

  return { matches, news, products, memberships };
}

export function resolveHomeCopy(locale: string) {
  return localizedCopy(locale);
}

function snapshotHasContent(snapshot: PublicHomeSnapshot) {
  return (
    snapshot.matches.length > 0 ||
    snapshot.news.length > 0 ||
    snapshot.products.length > 0 ||
    snapshot.memberships.length > 0
  );
}

function useHomeResource() {
  const [snapshot, setSnapshot] = useState<PublicHomeSnapshot>({
    matches: [],
    news: [],
    products: [],
    memberships: [],
  });
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const hasConfirmed = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const load = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmed.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, HOME_TIMEOUT_MS);
    try {
      const response = await fetch("/api/public-content?resource=home", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (!isMounted.current) return;
        if (response.status === 403) {
          setSnapshot({
            matches: [],
            news: [],
            products: [],
            memberships: [],
          });
          hasConfirmed.current = false;
        }
        setStatus(resolveFixturesFailureStatus(response.status));
        return;
      }
      const next = normalizeHomeSnapshot(payload);
      if (!isMounted.current) return;
      setSnapshot(next);
      hasConfirmed.current = snapshotHasContent(next);
      setStatus(hasConfirmed.current ? "ready" : "empty");
    } catch {
      if (!isMounted.current || (controller.signal.aborted && !timedOut))
        return;
      setStatus(
        typeof navigator !== "undefined" && !navigator.onLine
          ? "offline"
          : timedOut
            ? "security_timeout"
            : "error",
      );
    } finally {
      window.clearTimeout(timeout);
      if (activeRequest.current === controller) activeRequest.current = null;
    }
  }, []);

  useEffect(() => {
    isMounted.current = true;
    void load();
    const offline = () => setStatus("offline");
    const online = () => void load();
    window.addEventListener("offline", offline);
    window.addEventListener("online", online);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", offline);
      window.removeEventListener("online", online);
    };
  }, [load]);

  return { snapshot, status, load };
}

function formatPrice(value: number, _locale: string) {
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency: "RWF",
      maximumFractionDigits: 0,
    }).format(value);
  } catch {
    return `${value.toLocaleString()} RWF`;
  }
}

function formatMatchDate(value: string, _locale: string) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return value;
  try {
    return new Intl.DateTimeFormat("en", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(date);
  } catch {
    return value;
  }
}

export function HomeSurface({
  locale,
  clubShortName,
  fanAppHref,
  hasExternalAppUrl,
}: HomeSurfaceProps) {
  const copy = useMemo(() => localizedCopy(locale), [locale]);
  const { snapshot, status, load } = useHomeResource();
  const [interaction, setInteraction] = useState<HomeInteraction>("idle");
  const [selectedAction, setSelectedAction] = useState("fixtures");
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = copy.status[status];
  const actions = [
    {
      id: "fixtures",
      label: copy.fixtures,
      href: "/fixtures",
      icon: CalendarDays,
    },
    { id: "tickets", label: copy.tickets, href: "/tickets", icon: Ticket },
    {
      id: "membership",
      label: copy.membership,
      href: "/membership",
      icon: BadgeCheck,
    },
    { id: "shop", label: copy.shop, href: "/shop", icon: ShoppingBag },
  ];
  const selected = actions.find(({ id }) => id === selectedAction) ?? actions[0];
  const match = snapshot.matches[0] ?? null;
  const press = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled)
      return;
    setInteraction("pressed");
  };

  return (
    <section
      className="home-surface circles-surface"
      data-home-status={status}
      data-home-interaction={interaction}
      data-home-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="circles-hero home-hero">
          <Image
            className="blue-wall-hero-media"
            src="https://img.youtube.com/vi/36FYr-CL0ww/maxresdefault.jpg"
            alt="Rayon Sports players entering Amahoro Stadium for the CECAFA Kagame Cup"
            fill
            priority
            sizes="100vw"
          />
          <div>
            <p className="circles-eyebrow">CECAFA Kagame Cup 2026 · Final</p>
            <h1 aria-label="Champions again.">
              <span>Champions</span>
              <span>again.</span>
            </h1>
            <div className="blue-wall-score" aria-label="Full time: Rayon Sports 2, Gor Mahia 1">
              <span>Full time</span>
              <strong>Rayon Sports</strong>
              <b>2</b>
              <i aria-hidden="true">—</i>
              <b>1</b>
              <strong>Gor Mahia</strong>
            </div>
            <p className="circles-description">
              {clubShortName}. Gikundiro, the beloved. Matchday, membership,
              tickets, shop and supporter culture in one official clubhouse.
            </p>
          </div>
          <aside
            className="home-status circles-status"
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <Sparkles aria-hidden="true" />
            )}
            <div>
              <p>{message.label}</p>
              <span>{message.detail}</span>
            </div>
          </aside>
          <div className="circles-actions">
            <a
              href="https://www.youtube.com/watch?v=5TPQFCu2DsE"
              target="_blank"
              rel="noreferrer"
              className="home-action circles-action circles-action-primary"
            >
              Watch real highlights <ArrowRight aria-hidden="true" />
            </a>
            <Link href="/tickets" className="home-action circles-action circles-action-secondary">
              Get tickets <Ticket aria-hidden="true" />
            </Link>
            {hasExternalAppUrl ? (
              <Link href={fanAppHref} className="home-action circles-action circles-action-secondary">
                <Smartphone aria-hidden="true" /> {copy.app}
              </Link>
            ) : null}
            <button
              type="button"
              className="home-action circles-action circles-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "home-refresh-disabled" : undefined}
              onClick={() => void load()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? copy.retry : copy.refresh}
            </button>
            <span id="home-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
          <dl className="circles-stats">
            <div>
              <dt>{copy.fixtures}</dt>
              <dd>{snapshot.matches.length}</dd>
            </div>
            <div>
              <dt>{copy.latestNews}</dt>
              <dd>{snapshot.news.length}</dd>
            </div>
            <div>
              <dt>{copy.selected}</dt>
              <dd>{selected.label}</dd>
            </div>
          </dl>
        </header>

        <section className="blue-wall-feature-grid" aria-label="Gikundiro highlights">
          <article className="blue-wall-feature blue-wall-feature-matchday">
            <Image
              src="https://img.youtube.com/vi/_ZVYBy0DXF8/maxresdefault.jpg"
              alt="Rayon Sports supporters wearing the club colours"
              fill
              sizes="(max-width: 800px) 100vw, 58vw"
            />
            <div>
              <span>Matchday</span>
              <h2>Your place in the Blue Wall.</h2>
              <p>Choose a fixture, stand and quantity, then complete the protected mobile ticket journey.</p>
              <Link href="/tickets">Start ticket journey <ArrowRight aria-hidden="true" /></Link>
            </div>
          </article>
          <article className="blue-wall-feature blue-wall-feature-membership">
            <Image
              src="https://img.youtube.com/vi/9GH2mnKXX4s/maxresdefault.jpg"
              alt="Rayon Sports supporters presenting the official blue and white kits"
              fill
              sizes="(max-width: 800px) 100vw, 42vw"
            />
            <div>
              <span>Membership</span>
              <h2>The club belongs to its people.</h2>
              <p>WhatsApp-secured membership, a private six-digit member number and confirmed contribution history.</p>
              <Link href="/membership">Join Gikundiro <ArrowRight aria-hidden="true" /></Link>
            </div>
          </article>
        </section>

        {isRecovery ? (
          <aside className="circles-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="circles-content" aria-busy={isBusy}>
          {snapshotHasContent(snapshot) ? (
            <>
              <div className="home-lead-grid">
                <article className="home-match-card">
                  <p className="circles-eyebrow">{copy.nextMatch}</p>
                  {match ? (
                    <>
                      <h2>
                        {match.homeTeam} <span>vs</span> {match.awayTeam}
                      </h2>
                      <p>
                        {match.competition} · {match.venue}
                      </p>
                      <time dateTime={match.matchDate}>
                        {formatMatchDate(match.matchDate, locale)}
                      </time>
                      <Link
                        href={`/fixtures/${encodeURIComponent(match.id)}`}
                        className="home-action circles-action circles-action-secondary"
                      >
                        {copy.fixtures} <ArrowRight aria-hidden="true" />
                      </Link>
                    </>
                  ) : (
                    <p>{copy.noContentDetail}</p>
                  )}
                </article>

                <section className="home-actions-panel">
                  <p className="circles-eyebrow">{copy.quickActions}</p>
                  <h2>{copy.chooseAction}</h2>
                  <div className="home-action-grid">
                    {actions.map((action) => {
                      const Icon = action.icon;
                      return (
                        <button
                          type="button"
                          key={action.id}
                          className="home-action-choice"
                          aria-pressed={selectedAction === action.id}
                          onClick={() => {
                            setSelectedAction(action.id);
                            setInteraction("selected");
                          }}
                          onFocus={() => setInteraction("focused")}
                          onBlur={() =>
                            setInteraction((current) =>
                              current === "focused" ? "idle" : current,
                            )
                          }
                          onPointerDown={press}
                          onPointerUp={() => setInteraction("selected")}
                          onPointerCancel={() => setInteraction("idle")}
                        >
                          <Icon aria-hidden="true" />
                          {action.label}
                        </button>
                      );
                    })}
                  </div>
                  <Link
                    href={selected.href}
                    className="home-action circles-action circles-action-primary"
                  >
                    {copy.openSelected}: {selected.label}
                    <ArrowRight aria-hidden="true" />
                  </Link>
                </section>
              </div>

              <section className="home-preview-section">
                <header>
                  <div>
                    <p className="circles-eyebrow">{copy.confirmed}</p>
                    <h2>{copy.latestNews}</h2>
                  </div>
                  <Link href="/news">{copy.latestNews}</Link>
                </header>
                <div className="home-preview-grid">
                  {snapshot.news.map((article) => (
                    <article key={article.id} className="home-preview-card">
                      <span>{article.category}</span>
                      <h3>{article.title}</h3>
                      <p>{article.excerpt}</p>
                      <Link href={`/news/${encodeURIComponent(article.id)}`}>
                        {copy.latestNews} <ArrowRight aria-hidden="true" />
                      </Link>
                    </article>
                  ))}
                </div>
              </section>

              <div className="home-preview-columns">
                <section className="home-preview-section">
                  <header>
                    <div>
                      <p className="circles-eyebrow">{copy.shop}</p>
                      <h2>{copy.shop}</h2>
                    </div>
                    <Link href="/shop">{copy.shop}</Link>
                  </header>
                  <div className="home-preview-grid">
                    {snapshot.products.map((product) => (
                      <article key={product.id} className="home-preview-card">
                        <span>{product.category}</span>
                        <h3>{product.name}</h3>
                        <p>{product.subtitle}</p>
                        <strong>{formatPrice(product.price, locale)}</strong>
                        <Link href={`/shop/${encodeURIComponent(product.id)}`}>
                          {copy.shop} <ArrowRight aria-hidden="true" />
                        </Link>
                      </article>
                    ))}
                  </div>
                </section>

                <section className="home-preview-section">
                  <header>
                    <div>
                      <p className="circles-eyebrow">{copy.membership}</p>
                      <h2>{copy.membership}</h2>
                    </div>
                    <Link href="/membership">{copy.membership}</Link>
                  </header>
                  <div className="home-preview-grid">
                    {snapshot.memberships.map((membership) => (
                      <article key={membership.id} className="home-preview-card">
                        <span>{membership.tier}</span>
                        <h3>{membership.title}</h3>
                        <p>{membership.description}</p>
                        <strong>
                          {formatPrice(membership.annualPrice, locale)}
                        </strong>
                      </article>
                    ))}
                  </div>
                </section>
              </div>
            </>
          ) : status === "loading" ? (
            <div
              className="circles-skeleton"
              role="status"
              aria-label={message.label}
            >
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="circles-empty">
              <Newspaper aria-hidden="true" />
              <h2>{copy.noContent}</h2>
              <p>{copy.noContentDetail}</p>
            </div>
          )}
        </section>

        <aside className="circles-boundary">
          <ShieldCheck aria-hidden="true" />
          <div>
            <p className="circles-eyebrow">{copy.boundaryEyebrow}</p>
            <h2>{copy.boundaryTitle}</h2>
            <p>{copy.boundaryDetail}</p>
          </div>
        </aside>
      </div>
    </section>
  );
}
