"use client";

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
  RefreshCw,
  Ticket,
  Trophy,
  WifiOff,
} from "lucide-react";
import {
  normalizeFixtures,
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
  type PublicFixture,
} from "./fixtures-surface";

const MATCH_COLLECTION_TIMEOUT_MS = 8_000;

export type MatchCollectionMode = "tickets" | "results";
type MatchCollectionInteraction = "idle" | "focused" | "pressed" | "selected";

type MatchCollectionCopy = {
  eyebrow: string;
  title: string;
  description: string;
  primaryAction: string;
  secondaryAction: string;
  selectedLabel: string;
  viewDetails: string;
  emptyTitle: string;
  emptyDetail: string;
  supportingTitle: string;
  supportingPoints: readonly string[];
};

type MatchCollectionSurfaceProps = {
  mode: MatchCollectionMode;
  locale: string;
  currencyCode: string;
  clubName: string;
  copy: MatchCollectionCopy;
};

type CollectionStateCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  listed: string;
  lowestPrice: string;
  wins: string;
  goals: string;
  checkout: string;
  fanApp: string;
  venue: string;
  date: string;
  price: string;
  unavailable: string;
};

const collectionStateCopy: Record<
  "en" | "fr" | "rw" | "sw",
  CollectionStateCopy
> = {
  en: {
    status: {
      loading: {
        label: "Loading match information",
        detail: "Waiting for the first confirmed public match collection.",
      },
      ready: {
        label: "Match information confirmed",
        detail: "These records come from the latest confirmed public schedule.",
      },
      empty: {
        label: "No matching records",
        detail: "The confirmed schedule has no record for this view.",
      },
      error: {
        label: "Match information unavailable",
        detail: "Confirmed records remain visible. Retry when the service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed records remain visible until the connection returns.",
      },
      permission_denied: {
        label: "Match access denied",
        detail: "This public match collection is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing match information",
        detail: "Confirmed records remain visible while the schedule updates.",
      },
      conflict: {
        label: "Match information changed",
        detail: "Refresh to load the current confirmed collection.",
      },
      security_timeout: {
        label: "Match request timed out",
        detail: "No change is assumed. Confirmed records remain visible.",
      },
    },
    refresh: "Refresh matches",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while match information is loading.",
    listed: "Listed",
    lowestPrice: "From",
    wins: "Wins",
    goals: "Goals for",
    checkout: "Checkout",
    fanApp: "Fan app",
    venue: "Venue",
    date: "Date",
    price: "General admission",
    unavailable: "Not on sale",
  },
  fr: {
    status: {
      loading: {
        label: "Chargement des matchs",
        detail: "En attente de la première collection publique confirmée.",
      },
      ready: {
        label: "Informations confirmées",
        detail: "Ces dossiers viennent du dernier calendrier public confirmé.",
      },
      empty: {
        label: "Aucun dossier correspondant",
        detail: "Le calendrier confirmé ne contient aucun dossier pour cette vue.",
      },
      error: {
        label: "Informations indisponibles",
        detail: "Les dossiers confirmés restent visibles. Réessayez plus tard.",
      },
      offline: {
        label: "Vous êtes hors ligne",
        detail: "Les dossiers confirmés restent visibles jusqu’au retour du réseau.",
      },
      permission_denied: {
        label: "Accès aux matchs refusé",
        detail: "Cette collection publique n’est pas disponible pour ce visiteur.",
      },
      syncing: {
        label: "Actualisation des matchs",
        detail: "Les dossiers confirmés restent visibles pendant la mise à jour.",
      },
      conflict: {
        label: "Les informations ont changé",
        detail: "Actualisez pour charger la collection confirmée actuelle.",
      },
      security_timeout: {
        label: "Délai de la demande dépassé",
        detail: "Aucun changement n’est supposé. Les dossiers confirmés restent visibles.",
      },
    },
    refresh: "Actualiser les matchs",
    retry: "Réessayer",
    refreshDisabled: "L’actualisation est indisponible pendant le chargement.",
    listed: "Listés",
    lowestPrice: "À partir de",
    wins: "Victoires",
    goals: "Buts marqués",
    checkout: "Paiement",
    fanApp: "App supporters",
    venue: "Stade",
    date: "Date",
    price: "Admission générale",
    unavailable: "Pas en vente",
  },
  rw: {
    status: {
      loading: {
        label: "Amakuru y’imikino arimo gutangira",
        detail: "Dutegereje urutonde rusange rwa mbere rwemejwe.",
      },
      ready: {
        label: "Amakuru y’imikino yemejwe",
        detail: "Aya makuru ava muri gahunda rusange ya vuba yemejwe.",
      },
      empty: {
        label: "Nta makuru ahuye",
        detail: "Gahunda yemejwe nta mukino ifite kuri uru rupapuro.",
      },
      error: {
        label: "Amakuru y’imikino ntaboneka",
        detail: "Ayemejwe aragumaho. Ongera ugerageze serivisi igarutse.",
      },
      offline: {
        label: "Nta murongo wa interineti",
        detail: "Ayemejwe aragumaho kugeza umurongo ugarutse.",
      },
      permission_denied: {
        label: "Imikino ntiyemerewe",
        detail: "Uru rutonde rusange nti rwemerewe uyu mushyitsi.",
      },
      syncing: {
        label: "Amakuru arimo kuvugururwa",
        detail: "Ayemejwe aragumaho mu gihe gahunda ivugururwa.",
      },
      conflict: {
        label: "Amakuru yahindutse",
        detail: "Vugurura kugira ngo ubone urutonde rwa vuba rwemejwe.",
      },
      security_timeout: {
        label: "Igihe cyo gusaba amakuru cyarangiye",
        detail: "Nta gihindutse cyemezwa. Ayemejwe aragumaho.",
      },
    },
    refresh: "Vugurura imikino",
    retry: "Ongera ugerageze",
    refreshDisabled: "Ntushobora kuvugurura mu gihe amakuru arimo gutangira.",
    listed: "Iri ku rutonde",
    lowestPrice: "Guhera kuri",
    wins: "Intsinzi",
    goals: "Ibitego yatsinze",
    checkout: "Kwishyura",
    fanApp: "App y’abafana",
    venue: "Ikibuga",
    date: "Itariki",
    price: "Ahantu rusange",
    unavailable: "Ntiragurishwa",
  },
  sw: {
    status: {
      loading: {
        label: "Inapakia taarifa za mechi",
        detail: "Inasubiri mkusanyiko wa kwanza wa umma uliothibitishwa.",
      },
      ready: {
        label: "Taarifa zimethibitishwa",
        detail: "Rekodi hizi zinatoka kwenye ratiba ya umma iliyothibitishwa.",
      },
      empty: {
        label: "Hakuna rekodi zinazolingana",
        detail: "Ratiba iliyothibitishwa haina rekodi kwa mwonekano huu.",
      },
      error: {
        label: "Taarifa hazipatikani",
        detail: "Rekodi zilizothibitishwa zinaendelea kuonekana. Jaribu tena baadaye.",
      },
      offline: {
        label: "Huna mtandao",
        detail: "Rekodi zilizothibitishwa zinaendelea kuonekana hadi mtandao urudi.",
      },
      permission_denied: {
        label: "Ufikiaji umekataliwa",
        detail: "Mkusanyiko huu wa umma haupatikani kwa mgeni huyu.",
      },
      syncing: {
        label: "Inasasisha taarifa",
        detail: "Rekodi zilizothibitishwa zinaendelea kuonekana wakati wa kusasisha.",
      },
      conflict: {
        label: "Taarifa zimebadilika",
        detail: "Sasisha ili kuona mkusanyiko uliothibitishwa wa sasa.",
      },
      security_timeout: {
        label: "Ombi limepitwa na muda",
        detail: "Hakuna badiliko linalodhaniwa. Rekodi zilizothibitishwa zinaendelea kuonekana.",
      },
    },
    refresh: "Sasisha mechi",
    retry: "Jaribu tena",
    refreshDisabled: "Huwezi kusasisha wakati taarifa zinapakia.",
    listed: "Zimeorodheshwa",
    lowestPrice: "Kuanzia",
    wins: "Ushindi",
    goals: "Mabao",
    checkout: "Malipo",
    fanApp: "App ya mashabiki",
    venue: "Uwanja",
    date: "Tarehe",
    price: "Kiingilio cha kawaida",
    unavailable: "Haiuzwi",
  },
};

function isResult(fixture: PublicFixture) {
  return ["fulltime", "finished", "result", "full_time"].includes(
    fixture.matchStatus,
  );
}

export function filterMatchCollection(
  fixtures: PublicFixture[],
  mode: MatchCollectionMode,
) {
  return fixtures.filter((fixture) =>
    mode === "tickets"
      ? fixture.isOnSale || fixture.matchStatus === "live"
      : isResult(fixture),
  );
}

export function resolveMatchCollectionStateCopy(locale: string) {
  const language = locale.trim().toLowerCase().split(/[-_]/)[0];
  return (
    collectionStateCopy[language as keyof typeof collectionStateCopy] ??
    collectionStateCopy.en
  );
}

function formatDate(value: string, locale: string) {
  return new Intl.DateTimeFormat(locale, {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function formatMoney(value: number, locale: string, currencyCode: string) {
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 0,
  }).format(value);
}

function clubScore(fixture: PublicFixture, clubName: string) {
  const normalizedClub = clubName.trim().toLowerCase();
  const clubIsHome = fixture.homeTeam.toLowerCase().includes(normalizedClub);
  return {
    for: clubIsHome ? fixture.homeScore : fixture.awayScore,
    against: clubIsHome ? fixture.awayScore : fixture.homeScore,
  };
}

export function MatchCollectionSurface({
  mode,
  locale,
  currencyCode,
  clubName,
  copy,
}: MatchCollectionSurfaceProps) {
  const localized = useMemo(
    () => resolveMatchCollectionStateCopy(locale),
    [locale],
  );
  const [matches, setMatches] = useState<PublicFixture[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] =
    useState<MatchCollectionInteraction>("idle");
  const hasConfirmedMatches = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadMatches = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedMatches.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, MATCH_COLLECTION_TIMEOUT_MS);
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
      const items =
        typeof payload === "object" &&
        payload !== null &&
        "items" in payload
          ? (payload as { items: unknown }).items
          : null;
      if (!Array.isArray(items)) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const nextMatches = filterMatchCollection(normalizeFixtures(items), mode);
      if (!isMounted.current) return;
      setMatches(nextMatches);
      setSelectedId((current) =>
        nextMatches.some((match) => match.id === current)
          ? current
          : nextMatches[0]?.id ?? null,
      );
      hasConfirmedMatches.current = nextMatches.length > 0;
      setStatus(nextMatches.length === 0 ? "empty" : "ready");
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
  }, [mode]);

  useEffect(() => {
    isMounted.current = true;
    void loadMatches();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadMatches();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadMatches]);

  const selected =
    matches.find((match) => match.id === selectedId) ?? matches[0] ?? null;
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = localized.status[status];
  const minimumPrice =
    mode === "tickets" && matches.length > 0
      ? Math.min(...matches.map((match) => match.generalPrice))
      : 0;
  const resultScores =
    mode === "results"
      ? matches.map((match) => clubScore(match, clubName))
      : [];
  const wins = resultScores.filter((score) => score.for > score.against).length;
  const goals = resultScores.reduce((sum, score) => sum + score.for, 0);

  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) return;
    setInteraction("pressed");
  };

  return (
    <section
      className="match-collection-surface"
      data-collection-mode={mode}
      data-collection-status={status}
      data-collection-interaction={interaction}
      data-collection-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="match-collection-hero">
          <div>
            <p className="match-collection-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title}</h1>
            <p className="match-collection-description">{copy.description}</p>
          </div>

          <aside
            className="match-collection-status"
            data-collection-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : mode === "tickets" ? (
              <Ticket aria-hidden="true" />
            ) : (
              <Trophy aria-hidden="true" />
            )}
            <div>
              <p>{message.label}</p>
              <span>{message.detail}</span>
            </div>
          </aside>

          <div className="match-collection-actions">
            <Link
              href={mode === "tickets" ? "/supporters" : "/fixtures"}
              className="match-collection-action match-collection-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              {mode === "tickets" ? <Ticket aria-hidden="true" /> : <CalendarDays aria-hidden="true" />}
              {copy.primaryAction}
            </Link>
            <Link
              href={mode === "tickets" ? "/membership" : "/standings"}
              className="match-collection-action match-collection-action-secondary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              {copy.secondaryAction}
            </Link>
            <button
              type="button"
              className="match-collection-action match-collection-action-secondary"
              disabled={isBusy}
              aria-describedby={
                isBusy ? `${mode}-collection-refresh-disabled` : undefined
              }
              onClick={() => void loadMatches()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? localized.retry : localized.refresh}
            </button>
            <span
              id={`${mode}-collection-refresh-disabled`}
              className="sr-only"
            >
              {localized.refreshDisabled}
            </span>
          </div>

          <dl className="match-collection-stats">
            <div>
              <dt>{localized.listed}</dt>
              <dd>{matches.length}</dd>
            </div>
            {mode === "tickets" ? (
              <>
                <div>
                  <dt>{localized.lowestPrice}</dt>
                  <dd>{minimumPrice ? formatMoney(minimumPrice, locale, currencyCode) : "—"}</dd>
                </div>
                <div>
                  <dt>{localized.checkout}</dt>
                  <dd>{localized.fanApp}</dd>
                </div>
              </>
            ) : (
              <>
                <div><dt>{localized.wins}</dt><dd>{wins}</dd></div>
                <div><dt>{localized.goals}</dt><dd>{goals}</dd></div>
              </>
            )}
          </dl>
        </header>

        {isRecovery ? (
          <aside className="match-collection-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="match-collection-content" aria-busy={isBusy}>
          {selected ? (
            <>
              <article className="match-collection-featured">
                <div className="match-collection-featured-heading">
                  <p>{copy.selectedLabel}</p>
                  <span>
                    {mode === "tickets"
                      ? selected.isOnSale
                        ? localized.price
                        : localized.unavailable
                      : selected.matchStatus.replace(/[_-]+/g, " ")}
                  </span>
                </div>
                <p className="match-collection-competition">
                  {selected.competition}
                </p>
                <div className="match-collection-score">
                  <strong>{selected.homeTeam}</strong>
                  <b>
                    {mode === "results"
                      ? `${selected.homeScore}–${selected.awayScore}`
                      : "VS"}
                  </b>
                  <strong>{selected.awayTeam}</strong>
                </div>
                <dl className="match-collection-meta">
                  <div>
                    <dt>{localized.date}</dt>
                    <dd><time dateTime={selected.matchDate}>{formatDate(selected.matchDate, locale)}</time></dd>
                  </div>
                  <div><dt>{localized.venue}</dt><dd>{selected.venue}</dd></div>
                  {mode === "tickets" ? (
                    <div>
                      <dt>{localized.price}</dt>
                      <dd>{selected.isOnSale ? formatMoney(selected.generalPrice, locale, currencyCode) : "—"}</dd>
                    </div>
                  ) : null}
                </dl>
                <p className="match-collection-summary">
                  {selected.matchSummary ?? copy.description}
                </p>
                <Link
                  href={`/${mode === "tickets" ? "tickets" : "fixtures"}/${encodeURIComponent(selected.id)}`}
                  className="match-collection-action match-collection-action-primary"
                >
                  {copy.viewDetails} <ArrowRight aria-hidden="true" />
                </Link>
              </article>

              <div className="match-collection-list" aria-label={localized.listed}>
                {matches.map((match) => (
                  <button
                    type="button"
                    key={match.id}
                    className="match-collection-card"
                    aria-pressed={match.id === selected.id}
                    onClick={() => {
                      setSelectedId(match.id);
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
                    <span aria-hidden="true">
                      {mode === "tickets" ? <Ticket /> : <Trophy />}
                    </span>
                    <span>
                      <small>{match.competition}</small>
                      <strong>{match.homeTeam} vs {match.awayTeam}</strong>
                      <time dateTime={match.matchDate}>
                        {formatDate(match.matchDate, locale)}
                      </time>
                    </span>
                    {mode === "results" ? (
                      <b>{match.homeScore}–{match.awayScore}</b>
                    ) : null}
                  </button>
                ))}
              </div>
            </>
          ) : status === "loading" ? (
            <div className="match-collection-skeleton" aria-label={message.label} aria-busy="true">
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="match-collection-empty">
              {mode === "tickets" ? <Ticket aria-hidden="true" /> : <Trophy aria-hidden="true" />}
              <h2>{copy.emptyTitle}</h2>
              <p>{copy.emptyDetail}</p>
            </div>
          )}
        </section>

        <aside className="match-collection-supporting">
          <p className="match-collection-eyebrow">{copy.eyebrow}</p>
          <h2>{copy.supportingTitle}</h2>
          <ul>
            {copy.supportingPoints.map((point) => <li key={point}>{point}</li>)}
          </ul>
        </aside>
      </div>
    </section>
  );
}
