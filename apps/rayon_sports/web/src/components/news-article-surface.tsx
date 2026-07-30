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
  ArrowLeft,
  BookOpen,
  RefreshCw,
  ShieldCheck,
  WifiOff,
} from "lucide-react";
import {
  resolveNewsFailureStatus,
  resolveNewsStateCopy,
  type NewsSurfaceStatus,
} from "./news-surface";
import { ShareActionButton } from "./pwa/share-action-button";

const ARTICLE_REQUEST_TIMEOUT_MS = 8_000;
const FALLBACK_IMAGE = "/brand-surface.svg";

type ArticleInteraction = "idle" | "focused" | "pressed" | "selected";

export type PublicNewsArticleDetail = {
  id: string;
  title: string;
  excerpt: string;
  content: string;
  category: string;
  coverImageUrl: string;
  publishedAt: string;
  author: string;
};

type NewsArticleSurfaceProps = {
  articleId: string;
  locale: string;
  copy: {
    newsroom: string;
    details: string;
    standards: string;
    standardsTitle: string;
    standardsPoints: readonly string[];
    minuteRead: string;
    matchdayCoverage: string;
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

export function normalizeNewsArticle(
  value: unknown,
): PublicNewsArticleDetail | null {
  if (!isRecord(value)) return null;
  const {
    id,
    title,
    excerpt,
    content,
    category,
    coverImageUrl,
    publishedAt,
    author,
  } = value;
  if (
    typeof id !== "string" ||
    id.trim() === "" ||
    id.length > 200 ||
    typeof title !== "string" ||
    title.trim() === "" ||
    typeof excerpt !== "string" ||
    excerpt.trim() === "" ||
    typeof content !== "string" ||
    content.trim() === "" ||
    content.length > 12_000 ||
    typeof category !== "string" ||
    category.trim() === "" ||
    typeof publishedAt !== "string" ||
    publishedAt.trim() === "" ||
    Number.isNaN(Date.parse(publishedAt)) ||
    typeof author !== "string" ||
    author.trim() === ""
  ) {
    return null;
  }

  return {
    id: id.trim(),
    title: title.trim(),
    excerpt: excerpt.trim(),
    content: content.trim(),
    category: category.trim(),
    coverImageUrl:
      typeof coverImageUrl === "string" && isSafeMediaUrl(coverImageUrl)
        ? coverImageUrl
        : FALLBACK_IMAGE,
    publishedAt: publishedAt.trim(),
    author: author.trim(),
  };
}

function formatArticleDate(value: string, locale: string) {
  return new Intl.DateTimeFormat(locale, {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

function readingMinutes(content: string) {
  return Math.max(1, Math.ceil(content.trim().split(/\s+/).length / 220));
}

export function NewsArticleSurface({
  articleId,
  locale,
  copy,
}: NewsArticleSurfaceProps) {
  const localized = useMemo(() => resolveNewsStateCopy(locale), [locale]);
  const [article, setArticle] = useState<PublicNewsArticleDetail | null>(null);
  const [status, setStatus] = useState<NewsSurfaceStatus>("loading");
  const [interaction, setInteraction] =
    useState<ArticleInteraction>("idle");
  const [readerMode, setReaderMode] = useState(false);
  const hasConfirmedArticle = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadArticle = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedArticle.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, ARTICLE_REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch(
        `/api/public-content?resource=news-article&articleId=${encodeURIComponent(articleId)}`,
        {
          cache: "no-store",
          headers: { Accept: "application/json" },
          signal: controller.signal,
        },
      );
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (isMounted.current) {
          setStatus(resolveNewsFailureStatus(response.status));
        }
        return;
      }
      if (!isRecord(payload) || !("item" in payload)) {
        if (isMounted.current) setStatus("error");
        return;
      }

      const nextArticle = normalizeNewsArticle(payload.item);
      if (!isMounted.current) return;
      setArticle(nextArticle);
      hasConfirmedArticle.current = true;
      setStatus(nextArticle == null ? "empty" : "ready");
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
  }, [articleId]);

  useEffect(() => {
    isMounted.current = true;
    void loadArticle();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadArticle();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadArticle]);

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

  const paragraphs =
    article?.content
      .split(/(?<=[.!?])\s+/)
      .map((paragraph) => paragraph.trim())
      .filter(Boolean) ?? [];

  return (
    <article
      className="news-article-surface"
      data-article-status={status}
      data-article-interaction={interaction}
      data-reader-mode={readerMode ? "true" : "false"}
      data-article-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20 pt-8">
        <nav className="news-article-nav" aria-label={copy.newsroom}>
          <Link
            href="/news"
            className="news-action news-action-secondary"
            onFocus={() => setInteraction("focused")}
            onBlur={() => setInteraction("idle")}
            onPointerDown={pressControl}
            onPointerUp={() => setInteraction("idle")}
            onPointerCancel={() => setInteraction("idle")}
          >
            <ArrowLeft aria-hidden="true" />
            {copy.newsroom}
          </Link>
          <button
            type="button"
            className="news-action news-action-secondary"
            disabled={isBusy}
            aria-describedby={
              isBusy ? "article-refresh-disabled-reason" : undefined
            }
            onClick={() => void loadArticle()}
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
          <span id="article-refresh-disabled-reason" className="sr-only">
            {localized.refreshDisabled}
          </span>
        </nav>

        <aside
          className="news-status news-article-status"
          data-news-status={status}
          role={status === "permission_denied" ? "alert" : "status"}
          aria-live="polite"
        >
          {status === "offline" ? (
            <WifiOff aria-hidden="true" />
          ) : (
            <ShieldCheck aria-hidden="true" />
          )}
          <div>
            <p className="news-status-label">{message.label}</p>
            <p className="news-status-detail">{message.detail}</p>
          </div>
        </aside>

        {isRecovery ? (
          <aside className="news-recovery" role="status">
            <p>{message.label}</p>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section
          className="news-article-content"
          aria-busy={isBusy}
          aria-label={copy.details}
        >
          {article ? (
            <>
              <header className="news-article-hero">
                <div className="news-article-image">
                  <Image
                    src={article.coverImageUrl}
                    alt=""
                    fill
                    priority
                    sizes="(min-width: 1024px) 44vw, calc(100vw - 2rem)"
                  />
                </div>
                <div className="news-article-heading">
                  <p className="news-eyebrow">{article.category}</p>
                  <h1>{article.title}</h1>
                  <p className="news-article-excerpt">{article.excerpt}</p>
                  <dl className="news-article-meta">
                    <div>
                      <dt>Published</dt>
                      <dd>
                        <time dateTime={article.publishedAt}>
                          {formatArticleDate(article.publishedAt, locale)}
                        </time>
                      </dd>
                    </div>
                    <div>
                      <dt>By</dt>
                      <dd>{article.author}</dd>
                    </div>
                    <div>
                      <dt>Reading time</dt>
                      <dd>
                        {readingMinutes(article.content)} {copy.minuteRead}
                      </dd>
                    </div>
                  </dl>
                  <div className="news-actions">
                    <button
                      type="button"
                      className="news-action news-action-primary"
                      aria-pressed={readerMode}
                      onClick={() => {
                        setReaderMode((current) => !current);
                        setInteraction("selected");
                      }}
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
                      <BookOpen aria-hidden="true" />
                      Reader mode
                    </button>
                    <ShareActionButton
                      title={article.title}
                      text={article.excerpt}
                      url={`/news/${article.id}`}
                      className="news-action news-action-secondary"
                    />
                    <Link
                      href="/fixtures"
                      className="news-action news-action-secondary"
                    >
                      {copy.matchdayCoverage}
                    </Link>
                  </div>
                </div>
              </header>

              <div className="news-article-grid">
                <section className="news-article-body">
                  <p className="news-eyebrow">{copy.details}</p>
                  <div>
                    {paragraphs.map((paragraph, index) => (
                      <p key={`${index}-${paragraph.slice(0, 24)}`}>
                        {paragraph}
                      </p>
                    ))}
                  </div>
                </section>
                <aside className="news-standards">
                  <p className="news-eyebrow">{copy.standards}</p>
                  <h2>{copy.standardsTitle}</h2>
                  <ul>
                    {copy.standardsPoints.map((point) => (
                      <li key={point}>{point}</li>
                    ))}
                  </ul>
                </aside>
              </div>
            </>
          ) : status === "empty" ? (
            <div className="news-empty">
              <BookOpen aria-hidden="true" />
              <p>Story not found</p>
              <span>
                This article is not in the confirmed public newsroom feed.
              </span>
              <Link href="/news" className="news-action news-action-primary">
                {copy.newsroom}
              </Link>
            </div>
          ) : (
            <div className="news-loading" aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
          )}
        </section>
      </div>
    </article>
  );
}
