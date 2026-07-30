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
  RefreshCw,
  ShieldCheck,
  Shirt,
  Users,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const SQUAD_TIMEOUT_MS = 8_000;

export type PublicSquadPlayer = {
  id: string;
  name: string;
  role: string;
  number: number;
  nationality: string;
  bio: string;
  imageUrl: string;
};

export type SquadUnitKey =
  | "goalkeepers"
  | "defenders"
  | "midfielders"
  | "attackers";

type SquadInteraction = "idle" | "focused" | "pressed" | "selected";

type SquadSurfaceProps = {
  locale: string;
  copy: {
    eyebrow: string;
    title: string;
    description: string;
    fixtureHub: string;
    leagueTable: string;
    playersShown: string;
    unitsShown: string;
    selectedNumber: string;
    selectedPlayer: string;
    unitView: string;
    tacticalShape: string;
    rosterNote: string;
    goalkeepers: string;
    defenders: string;
    midfielders: string;
    attackers: string;
    nationality: string;
    playerRole: string;
  };
};

type SquadStateCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  noNumber: string;
  players: string;
};

const stateCopy: Record<"en" | "fr" | "rw" | "sw", SquadStateCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading confirmed squad",
        detail: "Waiting for the first confirmed public player list.",
      },
      ready: {
        label: "Squad list confirmed",
        detail: "These players come from the latest confirmed public roster.",
      },
      empty: {
        label: "No squad listed",
        detail: "No confirmed public player profiles are available yet.",
      },
      error: {
        label: "Squad list unavailable",
        detail: "Confirmed players remain visible. Retry when service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed players remain visible until the connection returns.",
      },
      permission_denied: {
        label: "Squad access denied",
        detail: "The public squad list is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing confirmed squad",
        detail: "Confirmed players remain visible while the roster updates.",
      },
      conflict: {
        label: "Squad list changed",
        detail: "Refresh to load the current confirmed player profiles.",
      },
      security_timeout: {
        label: "Squad request timed out",
        detail: "No change is assumed. Confirmed players remain visible.",
      },
    },
    refresh: "Refresh squad",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while the squad is loading.",
    noNumber: "Unassigned",
    players: "players",
  },
  fr: {
    status: {
      loading: {
        label: "Chargement de l’effectif confirmé",
        detail: "En attente de la première liste publique confirmée.",
      },
      ready: {
        label: "Effectif confirmé",
        detail: "Ces joueurs viennent du dernier effectif public confirmé.",
      },
      empty: {
        label: "Aucun effectif listé",
        detail: "Aucun profil public confirmé n’est encore disponible.",
      },
      error: {
        label: "Effectif indisponible",
        detail: "Les joueurs confirmés restent visibles. Réessayez plus tard.",
      },
      offline: {
        label: "Vous êtes hors ligne",
        detail: "Les joueurs confirmés restent visibles jusqu’au retour du réseau.",
      },
      permission_denied: {
        label: "Accès à l’effectif refusé",
        detail: "La liste publique n’est pas disponible pour ce visiteur.",
      },
      syncing: {
        label: "Actualisation de l’effectif",
        detail: "Les joueurs confirmés restent visibles pendant la mise à jour.",
      },
      conflict: {
        label: "L’effectif a changé",
        detail: "Actualisez pour charger les profils actuellement confirmés.",
      },
      security_timeout: {
        label: "Délai de l’effectif dépassé",
        detail: "Aucun changement n’est supposé. Les joueurs restent visibles.",
      },
    },
    refresh: "Actualiser l’effectif",
    retry: "Réessayer",
    refreshDisabled: "L’actualisation est indisponible pendant le chargement.",
    noNumber: "Non attribué",
    players: "joueurs",
  },
  rw: {
    status: {
      loading: {
        label: "Abakinnyi barimo gutangira",
        detail: "Dutegereje urutonde rwa mbere rwemejwe rw’abakinnyi.",
      },
      ready: {
        label: "Abakinnyi bemejwe",
        detail: "Aba bakinnyi bava ku rutonde rusange rwa vuba rwemejwe.",
      },
      empty: {
        label: "Nta bakinnyi bari ku rutonde",
        detail: "Nta myirondoro y’abakinnyi yemejwe iraboneka.",
      },
      error: {
        label: "Urutonde ntiruboneka",
        detail: "Abakinnyi bemejwe baragumaho. Ongera ugerageze nyuma.",
      },
      offline: {
        label: "Nta murongo wa interineti",
        detail: "Abakinnyi bemejwe baragumaho kugeza umurongo ugarutse.",
      },
      permission_denied: {
        label: "Urutonde ntirwemerewe",
        detail: "Urutonde rusange ntirwemerewe uyu mushyitsi.",
      },
      syncing: {
        label: "Abakinnyi barimo kuvugururwa",
        detail: "Abakinnyi bemejwe baragumaho mu gihe bavugururwa.",
      },
      conflict: {
        label: "Urutonde rwahindutse",
        detail: "Vugurura kugira ngo ubone abakinnyi bemejwe ba vuba.",
      },
      security_timeout: {
        label: "Igihe cyo gusaba abakinnyi cyarangiye",
        detail: "Nta gihindutse cyemezwa. Abakinnyi baragumaho.",
      },
    },
    refresh: "Vugurura abakinnyi",
    retry: "Ongera ugerageze",
    refreshDisabled: "Ntushobora kuvugurura mu gihe urutonde rutangira.",
    noNumber: "Nta nomero",
    players: "abakinnyi",
  },
  sw: {
    status: {
      loading: {
        label: "Inapakia kikosi kilichothibitishwa",
        detail: "Inasubiri orodha ya kwanza ya wachezaji iliyothibitishwa.",
      },
      ready: {
        label: "Kikosi kimethibitishwa",
        detail: "Wachezaji hawa wanatoka kwenye orodha ya umma iliyothibitishwa.",
      },
      empty: {
        label: "Hakuna kikosi",
        detail: "Hakuna wasifu wa wachezaji uliothibitishwa kwa sasa.",
      },
      error: {
        label: "Kikosi hakipatikani",
        detail: "Wachezaji waliothibitishwa wanaendelea kuonekana. Jaribu tena.",
      },
      offline: {
        label: "Huna mtandao",
        detail: "Wachezaji waliothibitishwa wanaonekana hadi mtandao urudi.",
      },
      permission_denied: {
        label: "Ufikiaji wa kikosi umekataliwa",
        detail: "Orodha ya umma haipatikani kwa mgeni huyu.",
      },
      syncing: {
        label: "Inasasisha kikosi",
        detail: "Wachezaji waliothibitishwa wanaonekana wakati wa kusasisha.",
      },
      conflict: {
        label: "Kikosi kimebadilika",
        detail: "Sasisha ili kuona wasifu uliothibitishwa wa sasa.",
      },
      security_timeout: {
        label: "Ombi la kikosi limepitwa na muda",
        detail: "Hakuna badiliko linalodhaniwa. Wachezaji wanaendelea kuonekana.",
      },
    },
    refresh: "Sasisha kikosi",
    retry: "Jaribu tena",
    refreshDisabled: "Huwezi kusasisha wakati kikosi kinapakia.",
    noNumber: "Haijapangwa",
    players: "wachezaji",
  },
};

function safeImageUrl(value: unknown) {
  if (typeof value !== "string") return "/brand-surface.svg";
  const candidate = value.trim();
  if (
    candidate.startsWith("/") &&
    !candidate.startsWith("//") &&
    candidate.length <= 2_048
  ) {
    return candidate;
  }
  try {
    const parsed = new URL(candidate);
    if (
      parsed.protocol === "https:" &&
      parsed.hostname.endsWith(".supabase.co") &&
      candidate.length <= 2_048
    ) {
      return candidate;
    }
  } catch {
    // The governed local fallback is used for invalid or untrusted media.
  }
  return "/brand-surface.svg";
}

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

export function normalizeSquad(value: unknown): PublicSquadPlayer[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const players: PublicSquadPlayer[] = [];
  for (const entry of value) {
    if (typeof entry !== "object" || entry == null) continue;
    const row = entry as Record<string, unknown>;
    const id = boundedString(row.id, 200);
    const name = boundedString(row.name, 160);
    const role = boundedString(row.role, 100);
    const nationality = boundedString(row.nationality, 100);
    const bio = boundedString(row.bio, 1_000);
    const number = row.number;
    if (
      !id ||
      !name ||
      !role ||
      !nationality ||
      !bio ||
      !Number.isInteger(number) ||
      (number as number) < 0 ||
      (number as number) > 999 ||
      seen.has(id)
    ) {
      continue;
    }
    seen.add(id);
    players.push({
      id,
      name,
      role,
      number: number as number,
      nationality,
      bio,
      imageUrl: safeImageUrl(row.imageUrl),
    });
    if (players.length === 40) break;
  }
  return players.sort((a, b) => {
    const aNumber = a.number === 0 ? Number.MAX_SAFE_INTEGER : a.number;
    const bNumber = b.number === 0 ? Number.MAX_SAFE_INTEGER : b.number;
    return aNumber - bNumber || a.name.localeCompare(b.name);
  });
}

export function classifySquadPlayer(role: string): SquadUnitKey {
  const normalized = role.trim().toLowerCase();
  if (/keeper|goalie|gardien|umuzamu|kipa/.test(normalized)) {
    return "goalkeepers";
  }
  if (/back|defender|défenseur|myugariro|beki/.test(normalized)) {
    return "defenders";
  }
  if (/mid|milieu|mukina.*hagati|kiungo/.test(normalized)) {
    return "midfielders";
  }
  return "attackers";
}

export function resolveSquadStateCopy(locale: string) {
  const language = locale.trim().toLowerCase().split(/[-_]/)[0];
  return stateCopy[language as keyof typeof stateCopy] ?? stateCopy.en;
}

export function SquadSurface({ locale, copy }: SquadSurfaceProps) {
  const localized = useMemo(() => resolveSquadStateCopy(locale), [locale]);
  const [players, setPlayers] = useState<PublicSquadPlayer[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] = useState<SquadInteraction>("idle");
  const hasConfirmedPlayers = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadSquad = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedPlayers.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, SQUAD_TIMEOUT_MS);
    try {
      const response = await fetch("/api/public-content?resource=squad", {
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
      const nextPlayers = normalizeSquad(items);
      if (!isMounted.current) return;
      setPlayers(nextPlayers);
      setSelectedId((current) =>
        nextPlayers.some(({ id }) => id === current)
          ? current
          : (nextPlayers[0]?.id ?? null),
      );
      hasConfirmedPlayers.current = nextPlayers.length > 0;
      setStatus(nextPlayers.length === 0 ? "empty" : "ready");
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
    void loadSquad();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadSquad();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadSquad]);

  const selected =
    players.find(({ id }) => id === selectedId) ?? players[0] ?? null;
  const units = useMemo(() => {
    const grouped: Record<SquadUnitKey, PublicSquadPlayer[]> = {
      goalkeepers: [],
      defenders: [],
      midfielders: [],
      attackers: [],
    };
    for (const player of players) {
      grouped[classifySquadPlayer(player.role)].push(player);
    }
    return grouped;
  }, [players]);
  const visibleUnitCount = Object.values(units).filter(
    (unit) => unit.length > 0,
  ).length;
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = localized.status[status];
  const unitLabels: Record<SquadUnitKey, string> = {
    goalkeepers: copy.goalkeepers,
    defenders: copy.defenders,
    midfielders: copy.midfielders,
    attackers: copy.attackers,
  };

  const pressControl = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) return;
    setInteraction("pressed");
  };

  return (
    <section
      className="squad-surface"
      data-squad-status={status}
      data-squad-interaction={interaction}
      data-squad-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="squad-hero">
          <div>
            <p className="squad-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title}</h1>
            <p className="squad-description">{copy.description}</p>
          </div>
          <aside
            className="squad-status"
            data-squad-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <Users aria-hidden="true" />
            )}
            <div>
              <p>{message.label}</p>
              <span>{message.detail}</span>
            </div>
          </aside>
          <div className="squad-actions">
            <Link
              href="/fixtures"
              className="squad-action squad-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <Shirt aria-hidden="true" /> {copy.fixtureHub}
            </Link>
            <Link
              href="/standings"
              className="squad-action squad-action-secondary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <ShieldCheck aria-hidden="true" /> {copy.leagueTable}
            </Link>
            <button
              type="button"
              className="squad-action squad-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "squad-refresh-disabled" : undefined}
              onClick={() => void loadSquad()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? localized.retry : localized.refresh}
            </button>
            <span id="squad-refresh-disabled" className="sr-only">
              {localized.refreshDisabled}
            </span>
          </div>
          <dl className="squad-stats">
            <div>
              <dt>{copy.playersShown}</dt>
              <dd>{players.length}</dd>
            </div>
            <div>
              <dt>{copy.unitsShown}</dt>
              <dd>{visibleUnitCount}</dd>
            </div>
            <div>
              <dt>{copy.selectedNumber}</dt>
              <dd>
                {selected?.number
                  ? `#${selected.number}`
                  : selected
                    ? localized.noNumber
                    : "—"}
              </dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="squad-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="squad-content" aria-busy={isBusy}>
          {selected ? (
            <article className="squad-featured">
              <div className="squad-featured-image">
                <Image
                  src={selected.imageUrl}
                  alt={selected.name}
                  fill
                  sizes="(max-width: 832px) 100vw, 42vw"
                  className="object-cover"
                />
              </div>
              <div className="squad-featured-copy">
                <p className="squad-eyebrow">{copy.selectedPlayer}</p>
                <div className="squad-featured-heading">
                  <strong>
                    {selected.number ? `#${selected.number}` : "—"}
                  </strong>
                  <div>
                    <h2>{selected.name}</h2>
                    <p>{selected.role}</p>
                  </div>
                </div>
                <dl className="squad-featured-stats">
                  <div>
                    <dt>{copy.playerRole}</dt>
                    <dd>{selected.role}</dd>
                  </div>
                  <div>
                    <dt>{copy.nationality}</dt>
                    <dd>{selected.nationality}</dd>
                  </div>
                </dl>
                <p className="squad-player-bio">{selected.bio}</p>
                <Link
                  href="/fixtures"
                  className="squad-action squad-action-primary"
                >
                  {copy.fixtureHub} <ArrowRight aria-hidden="true" />
                </Link>
              </div>
            </article>
          ) : status === "loading" ? (
            <div className="squad-skeleton" aria-label={message.label}>
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="squad-empty">
              <Users aria-hidden="true" />
              <h2>{localized.status.empty.label}</h2>
              <p>{localized.status.empty.detail}</p>
            </div>
          )}

          {players.length > 0 ? (
            <div className="squad-units">
              {(
                Object.entries(units) as [
                  SquadUnitKey,
                  PublicSquadPlayer[],
                ][]
              ).map(([unit, unitPlayers]) =>
                unitPlayers.length > 0 ? (
                  <section className="squad-unit" key={unit}>
                    <header>
                      <h2>{unitLabels[unit]}</h2>
                      <span>
                        {unitPlayers.length} {localized.players}
                      </span>
                    </header>
                    <div className="squad-grid">
                      {unitPlayers.map((player) => (
                        <button
                          type="button"
                          key={player.id}
                          className="squad-card"
                          aria-pressed={player.id === selected?.id}
                          onClick={() => {
                            setSelectedId(player.id);
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
                          <span className="squad-card-image">
                            <Image
                              src={player.imageUrl}
                              alt=""
                              fill
                              sizes="6rem"
                              className="object-cover"
                            />
                          </span>
                          <span className="squad-card-copy">
                            <strong>{player.name}</strong>
                            <small>
                              {player.role} · {player.nationality}
                            </small>
                          </span>
                          <b>
                            {player.number ? `#${player.number}` : "—"}
                          </b>
                        </button>
                      ))}
                    </div>
                  </section>
                ) : null,
              )}
            </div>
          ) : null}
        </section>

        <aside className="squad-supporting">
          <p className="squad-eyebrow">{copy.unitView}</p>
          <h2>{copy.tacticalShape}</h2>
          <p>{copy.rosterNote}</p>
          <Link
            href="/standings"
            className="squad-action squad-action-secondary"
          >
            {copy.leagueTable} <ArrowRight aria-hidden="true" />
          </Link>
        </aside>
      </div>
    </section>
  );
}
