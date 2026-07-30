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
import { ArrowRight, Newspaper, RefreshCw, WifiOff } from "lucide-react";

const NEWS_REQUEST_TIMEOUT_MS = 8_000;
const FALLBACK_IMAGE = "/brand-surface.svg";

export type NewsSurfaceStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

type NewsInteraction = "idle" | "focused" | "pressed" | "selected";

export type PublicNewsArticle = {
  id: string;
  title: string;
  excerpt: string;
  category: string;
  coverImageUrl: string;
  publishedAt: string;
  author: string;
};

type NewsStateCopy = {
  status: Record<NewsSurfaceStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  latestStories: string;
  featuredStory: string;
  story: string;
  stories: string;
  editorialIdentity: string;
  confirmedFeed: string;
  readStory: string;
  noNews: string;
  noNewsDetail: string;
};

const newsStateCopy: Record<"en" | "fr" | "rw" | "sw", NewsStateCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading club news",
        detail: "Waiting for the first confirmed newsroom feed.",
      },
      ready: {
        label: "News feed confirmed",
        detail: "These stories come from the latest confirmed public feed.",
      },
      empty: {
        label: "No stories published",
        detail: "The newsroom has no confirmed public story yet.",
      },
      error: {
        label: "Newsroom unavailable",
        detail: "Confirmed stories remain visible. Retry when the service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed stories remain visible until the connection returns.",
      },
      permission_denied: {
        label: "News access denied",
        detail: "The public newsroom feed is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing newsroom",
        detail: "Confirmed stories remain visible while the feed updates.",
      },
      conflict: {
        label: "News feed changed",
        detail: "Refresh to load the current confirmed version.",
      },
      security_timeout: {
        label: "News request timed out",
        detail: "No new story is assumed. Confirmed stories remain visible.",
      },
    },
    refresh: "Refresh news",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while news is loading.",
    latestStories: "Latest stories",
    featuredStory: "Featured story",
    story: "Story",
    stories: "Stories",
    editorialIdentity: "Editorial identity",
    confirmedFeed: "Confirmed feed",
    readStory: "Read full story",
    noNews: "No club news is published yet.",
    noNewsDetail: "Return later for the confirmed public newsroom feed.",
  },
  fr: {
    status: {
      loading: {
        label: "Chargement des actualités",
        detail: "En attente du premier flux éditorial confirmé.",
      },
      ready: {
        label: "Flux d’actualités confirmé",
        detail: "Ces articles proviennent du dernier flux public confirmé.",
      },
      empty: {
        label: "Aucun article publié",
        detail: "La rédaction n’a encore aucun article public confirmé.",
      },
      error: {
        label: "Rédaction indisponible",
        detail: "Les articles confirmés restent visibles. Réessayez plus tard.",
      },
      offline: {
        label: "Vous êtes hors ligne",
        detail: "Les articles confirmés restent visibles jusqu’au retour du réseau.",
      },
      permission_denied: {
        label: "Accès aux actualités refusé",
        detail: "Le flux public n’est pas disponible pour ce visiteur.",
      },
      syncing: {
        label: "Actualisation des nouvelles",
        detail: "Les articles confirmés restent visibles pendant la mise à jour.",
      },
      conflict: {
        label: "Le flux a changé",
        detail: "Actualisez pour charger la version confirmée actuelle.",
      },
      security_timeout: {
        label: "Délai des actualités dépassé",
        detail: "Aucun nouvel article n’est supposé. Les articles confirmés restent visibles.",
      },
    },
    refresh: "Actualiser les nouvelles",
    retry: "Réessayer",
    refreshDisabled: "L’actualisation est indisponible pendant le chargement.",
    latestStories: "Derniers articles",
    featuredStory: "Article à la une",
    story: "Article",
    stories: "Articles",
    editorialIdentity: "Identité éditoriale",
    confirmedFeed: "Flux confirmé",
    readStory: "Lire l’article",
    noNews: "Aucune actualité du club n’est encore publiée.",
    noNewsDetail: "Revenez plus tard pour consulter le flux public confirmé.",
  },
  rw: {
    status: {
      loading: {
        label: "Amakuru y’ikipe arimo gutangira",
        detail: "Dutegereje amakuru ya mbere yemejwe.",
      },
      ready: {
        label: "Amakuru yemejwe",
        detail: "Izi nkuru ziva mu makuru rusange ya vuba yemejwe.",
      },
      empty: {
        label: "Nta nkuru yatangajwe",
        detail: "Ikinyamakuru nta nkuru rusange yemejwe kiratangaza.",
      },
      error: {
        label: "Amakuru ntashobora kuboneka",
        detail: "Inkuru zemejwe ziragumaho. Ongera ugerageze serivisi igarutse.",
      },
      offline: {
        label: "Nta murongo wa interineti",
        detail: "Inkuru zemejwe ziragumaho kugeza umurongo ugarutse.",
      },
      permission_denied: {
        label: "Amakuru ntiyemerewe",
        detail: "Aya makuru rusange ntiyemerewe uyu mushyitsi.",
      },
      syncing: {
        label: "Amakuru arimo kuvugururwa",
        detail: "Inkuru zemejwe ziragumaho mu gihe amakuru avugururwa.",
      },
      conflict: {
        label: "Amakuru yahindutse",
        detail: "Vugurura kugira ngo ubone amakuru ya vuba yemejwe.",
      },
      security_timeout: {
        label: "Igihe cyo kubona amakuru cyarangiye",
        detail: "Nta nkuru nshya yemezwa. Inkuru zemejwe ziragumaho.",
      },
    },
    refresh: "Vugurura amakuru",
    retry: "Ongera ugerageze",
    refreshDisabled: "Ntushobora kuvugurura mu gihe amakuru arimo gutangira.",
    latestStories: "Inkuru nshya",
    featuredStory: "Inkuru y’ingenzi",
    story: "Inkuru",
    stories: "Inkuru",
    editorialIdentity: "Indangamuntu y’ikinyamakuru",
    confirmedFeed: "Amakuru yemejwe",
    readStory: "Soma inkuru yose",
    noNews: "Nta makuru y’ikipe aratangazwa.",
    noNewsDetail: "Garuka nyuma urebe amakuru rusange yemejwe.",
  },
  sw: {
    status: {
      loading: {
        label: "Habari za klabu zinapakiwa",
        detail: "Tunasubiri mkondo wa kwanza uliothibitishwa.",
      },
      ready: {
        label: "Habari zimethibitishwa",
        detail: "Hadithi hizi zinatoka kwenye mkondo wa sasa wa umma.",
      },
      empty: {
        label: "Hakuna hadithi iliyochapishwa",
        detail: "Chumba cha habari hakina hadithi ya umma iliyothibitishwa.",
      },
      error: {
        label: "Chumba cha habari hakipatikani",
        detail: "Hadithi zilizothibitishwa zinabaki. Jaribu tena huduma ikirejea.",
      },
      offline: {
        label: "Huna mtandao",
        detail: "Hadithi zilizothibitishwa zinabaki hadi mtandao urejee.",
      },
      permission_denied: {
        label: "Ufikiaji wa habari umekataliwa",
        detail: "Mkondo wa umma haupatikani kwa mgeni huyu.",
      },
      syncing: {
        label: "Habari zinasasishwa",
        detail: "Hadithi zilizothibitishwa zinabaki wakati mkondo unasasishwa.",
      },
      conflict: {
        label: "Mkondo wa habari umebadilika",
        detail: "Sasisha ili kupakia toleo la sasa lililothibitishwa.",
      },
      security_timeout: {
        label: "Muda wa habari umeisha",
        detail: "Hakuna hadithi mpya inayodhaniwa. Hadithi zilizothibitishwa zinabaki.",
      },
    },
    refresh: "Sasisha habari",
    retry: "Jaribu tena",
    refreshDisabled: "Usasishaji haupatikani wakati habari zinapakiwa.",
    latestStories: "Hadithi za karibuni",
    featuredStory: "Hadithi kuu",
    story: "Hadithi",
    stories: "Hadithi",
    editorialIdentity: "Utambulisho wa uandishi",
    confirmedFeed: "Mkondo uliothibitishwa",
    readStory: "Soma hadithi yote",
    noNews: "Hakuna habari za klabu zilizochapishwa bado.",
    noNewsDetail: "Rudi baadaye kwa mkondo wa umma uliothibitishwa.",
  },
};

type NewsSurfaceProps = {
  locale: string;
  identity: string;
  copy: {
    eyebrow: string;
    title: string;
    description: string;
    newsroomStandards: string;
    newsroomStandardsTitle: string;
    standardsPoints: readonly string[];
  };
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isSafeMediaUrl(value: string) {
  if (value.startsWith("/") && !value.startsWith("//")) return true;
  try {
    return new URL(value).hostname.endsWith(".supabase.co");
  } catch {
    return false;
  }
}

export function resolveNewsStateCopy(locale: string): NewsStateCopy {
  const normalized = locale.trim().toLowerCase().split(/[-_]/)[0];
  return (
    newsStateCopy[normalized as keyof typeof newsStateCopy] ?? newsStateCopy.en
  );
}

export function normalizeNewsArticles(value: unknown): PublicNewsArticle[] {
  if (!Array.isArray(value)) return [];

  const seen = new Set<string>();
  const articles: PublicNewsArticle[] = [];
  for (const candidate of value) {
    if (!isRecord(candidate)) continue;
    const { id, title, excerpt, category, coverImageUrl, publishedAt, author } =
      candidate;
    if (
      typeof id !== "string" ||
      id.trim() === "" ||
      seen.has(id.trim()) ||
      typeof title !== "string" ||
      title.trim() === "" ||
      typeof excerpt !== "string" ||
      excerpt.trim() === "" ||
      typeof category !== "string" ||
      category.trim() === "" ||
      typeof publishedAt !== "string" ||
      publishedAt.trim() === "" ||
      Number.isNaN(Date.parse(publishedAt)) ||
      typeof author !== "string" ||
      author.trim() === ""
    ) {
      continue;
    }

    const normalizedId = id.trim();
    seen.add(normalizedId);
    articles.push({
      id: normalizedId,
      title: title.trim(),
      excerpt: excerpt.trim(),
      category: category.trim(),
      coverImageUrl:
        typeof coverImageUrl === "string" && isSafeMediaUrl(coverImageUrl)
          ? coverImageUrl
          : FALLBACK_IMAGE,
      publishedAt: publishedAt.trim(),
      author: author.trim(),
    });
  }
  return articles.slice(0, 24);
}

export function resolveNewsFailureStatus(
  status: number,
): Exclude<NewsSurfaceStatus, "loading" | "ready" | "empty" | "syncing"> {
  if (status === 403) return "permission_denied";
  if (status === 409) return "conflict";
  if (status === 504) return "security_timeout";
  return "error";
}

function formatNewsDate(value: string, locale: string) {
  return new Intl.DateTimeFormat(locale, {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(value));
}

export function NewsSurface({ locale, identity, copy }: NewsSurfaceProps) {
  const localized = useMemo(() => resolveNewsStateCopy(locale), [locale]);
  const [articles, setArticles] = useState<PublicNewsArticle[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<NewsSurfaceStatus>("loading");
  const [interaction, setInteraction] = useState<NewsInteraction>("idle");
  const hasConfirmedNews = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadNews = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedNews.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, NEWS_REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch("/api/public-content?resource=news", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (isMounted.current) {
          setStatus(resolveNewsFailureStatus(response.status));
        }
        return;
      }
      if (!isRecord(payload) || !Array.isArray(payload.items)) {
        if (isMounted.current) setStatus("error");
        return;
      }

      const nextArticles = normalizeNewsArticles(payload.items);
      if (!isMounted.current) return;
      setArticles(nextArticles);
      setSelectedId((current) =>
        nextArticles.some((article) => article.id === current)
          ? current
          : nextArticles[0]?.id ?? null,
      );
      hasConfirmedNews.current = true;
      setStatus(nextArticles.length === 0 ? "empty" : "ready");
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
    void loadNews();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadNews();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadNews]);

  const selectedArticle =
    articles.find((article) => article.id === selectedId) ??
    articles[0] ??
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

  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) {
      return;
    }
    setInteraction("pressed");
  };

  return (
    <section
      className="news-surface"
      data-news-status={status}
      data-news-interaction={interaction}
      data-news-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20 pt-8">
        <header className="news-hero">
          <div>
            <p className="news-eyebrow">{copy.eyebrow}</p>
            <h1 className="news-title">{copy.title}</h1>
            <p className="news-description">{copy.description}</p>
          </div>

          <aside
            className="news-status"
            data-news-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <RefreshCw aria-hidden="true" />
            )}
            <div>
              <p className="news-status-label">{message.label}</p>
              <p className="news-status-detail">{message.detail}</p>
            </div>
          </aside>

          <div className="news-actions">
            <Link
              href="/fixtures"
              className="news-action news-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              Matchday
            </Link>
            <button
              type="button"
              className="news-action news-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "news-refresh-disabled-reason" : undefined}
              onClick={() => void loadNews()}
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
            <span id="news-refresh-disabled-reason" className="sr-only">
              {localized.refreshDisabled}
            </span>
          </div>

          <dl className="news-stats">
            <div>
              <dt>{localized.stories}</dt>
              <dd>{articles.length}</dd>
            </div>
            <div>
              <dt>{localized.editorialIdentity}</dt>
              <dd>{identity}</dd>
            </div>
            <div>
              <dt>{localized.confirmedFeed}</dt>
              <dd>{status === "ready" || hasConfirmedNews.current ? "Yes" : "—"}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="news-recovery" role="status">
            <p>{message.label}</p>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="news-content" aria-busy={isBusy}>
          {articles.length > 0 && selectedArticle ? (
            <>
              <article className="news-featured">
                <div className="news-image">
                  <Image
                    src={selectedArticle.coverImageUrl}
                    alt=""
                    fill
                    priority
                    sizes="(min-width: 960px) 56vw, calc(100vw - 2rem)"
                  />
                </div>
                <div className="news-featured-copy">
                  <p className="news-eyebrow">{localized.featuredStory}</p>
                  <p className="news-meta">
                    <span>{selectedArticle.category}</span>
                    <time dateTime={selectedArticle.publishedAt}>
                      {formatNewsDate(selectedArticle.publishedAt, locale)}
                    </time>
                  </p>
                  <h2>{selectedArticle.title}</h2>
                  <p>{selectedArticle.excerpt}</p>
                  <Link
                    href={`/news/${encodeURIComponent(selectedArticle.id)}`}
                    className="news-action news-action-primary"
                  >
                    {localized.readStory} <ArrowRight aria-hidden="true" />
                  </Link>
                </div>
              </article>

              {articles.length > 1 ? (
                <div className="news-story-grid" aria-label={localized.latestStories}>
                  {articles.map((article) => (
                    <button
                      type="button"
                      className="news-story"
                      key={article.id}
                      aria-pressed={article.id === selectedArticle.id}
                      onClick={() => {
                        setSelectedId(article.id);
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
                      <span>{localized.story}</span>
                      <strong>{article.title}</strong>
                      <small>{article.category}</small>
                    </button>
                  ))}
                </div>
              ) : null}
            </>
          ) : isBusy ? (
            <div className="news-loading" aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="news-empty">
              <Newspaper aria-hidden="true" />
              <p>{localized.noNews}</p>
              <span>{localized.noNewsDetail}</span>
            </div>
          )}
        </section>

        <section className="news-standards">
          <p className="news-eyebrow">{copy.newsroomStandards}</p>
          <h2>{copy.newsroomStandardsTitle}</h2>
          <ul>
            {copy.standardsPoints.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
        </section>
      </div>
    </section>
  );
}
