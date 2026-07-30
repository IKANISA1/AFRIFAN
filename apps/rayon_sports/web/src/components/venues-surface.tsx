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
  MapPin,
  RefreshCw,
  ShieldCheck,
  Smartphone,
  Ticket,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const VENUES_TIMEOUT_MS = 8_000;

export type PublicVenue = {
  id: string;
  displayName: string;
  slug: string;
  city: string;
  summary: string;
};

type VenuesInteraction = "idle" | "focused" | "pressed" | "selected";

type VenuesSurfaceProps = {
  locale: string;
  clubShortName: string;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
};

type VenuesStateCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  eyebrow: string;
  title: (club: string) => string;
  description: string;
  openApp: string;
  appPending: string;
  browseTickets: string;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  approved: string;
  cities: string;
  selected: string;
  selectedVenue: string;
  venueDirectory: string;
  directoryDetail: string;
  city: string;
  publicProfile: string;
  emptyTitle: string;
  emptyDetail: string;
  privacyEyebrow: string;
  privacyTitle: string;
  privacyDetail: string;
};

const venueCopy: Record<"en" | "fr" | "rw" | "sw", VenuesStateCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading approved venues",
        detail: "Waiting for the first confirmed public venue directory.",
      },
      ready: {
        label: "Venue directory confirmed",
        detail: "These profiles come from the latest club-approved directory.",
      },
      empty: {
        label: "No approved venues listed",
        detail: "No public partner venue profile is confirmed yet.",
      },
      error: {
        label: "Venue directory unavailable",
        detail: "Confirmed profiles remain visible. Retry when service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed profiles remain visible until the connection returns.",
      },
      permission_denied: {
        label: "Venue access denied",
        detail: "The public venue directory is not available to this visitor.",
      },
      syncing: {
        label: "Refreshing approved venues",
        detail: "Confirmed profiles remain visible while the directory updates.",
      },
      conflict: {
        label: "Venue directory changed",
        detail: "Refresh to load the current club-approved profiles.",
      },
      security_timeout: {
        label: "Venue request timed out",
        detail: "No change is assumed. Confirmed profiles remain visible.",
      },
    },
    eyebrow: "Partner venues",
    title: (club) => `${club} matchday venues`,
    description:
      "Discover approved public profiles here. Check-in, rewards, and ordering stay in the secure supporter app.",
    openApp: "Open supporter app",
    appPending: "App links coming soon",
    browseTickets: "Browse tickets",
    refresh: "Refresh venues",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while venues are loading.",
    approved: "Approved",
    cities: "Cities",
    selected: "Selected",
    selectedVenue: "Selected venue",
    venueDirectory: "Approved directory",
    directoryDetail: "Choose a public profile to inspect its confirmed summary.",
    city: "City",
    publicProfile: "Public profile",
    emptyTitle: "No approved venues listed",
    emptyDetail: "Profiles appear only after club review and public approval.",
    privacyEyebrow: "Privacy boundary",
    privacyTitle: "Discovery here. Secure actions in the app.",
    privacyDetail:
      "Public web never performs authenticated check-in, exposes precise supporter location, or displays live order queues.",
  },
  fr: {
    status: {
      loading: {
        label: "Chargement des lieux approuvés",
        detail: "En attente du premier répertoire public confirmé.",
      },
      ready: {
        label: "Répertoire des lieux confirmé",
        detail: "Ces profils viennent du dernier répertoire approuvé par le club.",
      },
      empty: {
        label: "Aucun lieu approuvé",
        detail: "Aucun profil public de partenaire n’est encore confirmé.",
      },
      error: {
        label: "Répertoire indisponible",
        detail: "Les profils confirmés restent visibles. Réessayez plus tard.",
      },
      offline: {
        label: "Vous êtes hors ligne",
        detail: "Les profils confirmés restent visibles jusqu’au retour du réseau.",
      },
      permission_denied: {
        label: "Accès aux lieux refusé",
        detail: "Le répertoire public n’est pas disponible pour ce visiteur.",
      },
      syncing: {
        label: "Actualisation des lieux",
        detail: "Les profils confirmés restent visibles pendant la mise à jour.",
      },
      conflict: {
        label: "Le répertoire a changé",
        detail: "Actualisez pour charger les profils actuellement approuvés.",
      },
      security_timeout: {
        label: "Délai de la demande dépassé",
        detail: "Aucun changement n’est supposé. Les profils restent visibles.",
      },
    },
    eyebrow: "Lieux partenaires",
    title: (club) => `Lieux de match de ${club}`,
    description:
      "Découvrez ici les profils publics approuvés. L’enregistrement, les récompenses et les commandes restent dans l’application sécurisée.",
    openApp: "Ouvrir l’application",
    appPending: "Liens bientôt disponibles",
    browseTickets: "Voir les billets",
    refresh: "Actualiser les lieux",
    retry: "Réessayer",
    refreshDisabled: "L’actualisation est indisponible pendant le chargement.",
    approved: "Approuvés",
    cities: "Villes",
    selected: "Sélection",
    selectedVenue: "Lieu sélectionné",
    venueDirectory: "Répertoire approuvé",
    directoryDetail: "Choisissez un profil public pour voir son résumé confirmé.",
    city: "Ville",
    publicProfile: "Profil public",
    emptyTitle: "Aucun lieu approuvé",
    emptyDetail: "Les profils apparaissent après l’examen et l’accord du club.",
    privacyEyebrow: "Limite de confidentialité",
    privacyTitle: "Découverte ici. Actions sécurisées dans l’application.",
    privacyDetail:
      "Le site public ne fait jamais d’enregistrement authentifié, n’expose pas la position précise d’un supporter et n’affiche pas les files de commandes.",
  },
  rw: {
    status: {
      loading: {
        label: "Ahantu hemejwe harimo gutangira",
        detail: "Dutegereje urutonde rwa mbere rwemejwe.",
      },
      ready: {
        label: "Urutonde rw’ahantu rwemejwe",
        detail: "Aya makuru ava ku rutonde rwa vuba rwemejwe n’ikipe.",
      },
      empty: {
        label: "Nta hantu hemejwe",
        detail: "Nta mwirondoro rusange w’ahantu wemejwe uraboneka.",
      },
      error: {
        label: "Urutonde ntiruboneka",
        detail: "Ahemejwe haragumaho. Ongera ugerageze nyuma.",
      },
      offline: {
        label: "Nta murongo wa interineti",
        detail: "Ahemejwe haragumaho kugeza umurongo ugarutse.",
      },
      permission_denied: {
        label: "Urutonde ntirwemerewe",
        detail: "Urutonde rusange ntirwemerewe uyu mushyitsi.",
      },
      syncing: {
        label: "Ahantu harimo kuvugururwa",
        detail: "Ahemejwe haragumaho mu gihe urutonde ruvugururwa.",
      },
      conflict: {
        label: "Urutonde rwahindutse",
        detail: "Vugurura kugira ngo ubone ahantu hemejwe ubu.",
      },
      security_timeout: {
        label: "Igihe cyo gusaba cyarangiye",
        detail: "Nta gihindutse cyemezwa. Ahemejwe haragumaho.",
      },
    },
    eyebrow: "Ahantu h’abafatanyabikorwa",
    title: (club) => `Ahantu h’umunsi w’umukino wa ${club}`,
    description:
      "Reba imyirondoro rusange yemejwe hano. Kwiyandikisha, ibihembo no gutumiza bikorwa muri porogaramu itekanye.",
    openApp: "Fungura porogaramu",
    appPending: "Imiyoboro izaboneka vuba",
    browseTickets: "Reba amatike",
    refresh: "Vugurura ahantu",
    retry: "Ongera ugerageze",
    refreshDisabled: "Ntushobora kuvugurura mu gihe urutonde rutangira.",
    approved: "Ahemejwe",
    cities: "Imijyi",
    selected: "Ahatowe",
    selectedVenue: "Ahantu hatowe",
    venueDirectory: "Urutonde rwemejwe",
    directoryDetail: "Hitamo umwirondoro rusange urebe incamake yemejwe.",
    city: "Umujyi",
    publicProfile: "Umwirondoro rusange",
    emptyTitle: "Nta hantu hemejwe",
    emptyDetail: "Imyirondoro igaragara nyuma yo gusuzumwa no kwemezwa n’ikipe.",
    privacyEyebrow: "Imipaka y’ibanga",
    privacyTitle: "Menya hano. Ibikorwa bitekanye muri porogaramu.",
    privacyDetail:
      "Urubuga rusange ntirwandikisha umuntu, ntirwerekana aho umufana aherereye neza kandi ntirwerekana imirongo y’ibitumizwa.",
  },
  sw: {
    status: {
      loading: {
        label: "Inapakia maeneo yaliyoidhinishwa",
        detail: "Inasubiri orodha ya kwanza ya umma iliyothibitishwa.",
      },
      ready: {
        label: "Orodha ya maeneo imethibitishwa",
        detail: "Wasifu huu unatoka kwenye orodha iliyoidhinishwa na klabu.",
      },
      empty: {
        label: "Hakuna maeneo yaliyoidhinishwa",
        detail: "Hakuna wasifu wa umma wa mshirika uliothibitishwa.",
      },
      error: {
        label: "Orodha haipatikani",
        detail: "Wasifu uliothibitishwa unaendelea kuonekana. Jaribu tena.",
      },
      offline: {
        label: "Huna mtandao",
        detail: "Wasifu uliothibitishwa unaonekana hadi mtandao urudi.",
      },
      permission_denied: {
        label: "Ufikiaji wa maeneo umekataliwa",
        detail: "Orodha ya umma haipatikani kwa mgeni huyu.",
      },
      syncing: {
        label: "Inasasisha maeneo",
        detail: "Wasifu uliothibitishwa unaonekana wakati wa kusasisha.",
      },
      conflict: {
        label: "Orodha imebadilika",
        detail: "Sasisha ili kuona wasifu ulioidhinishwa kwa sasa.",
      },
      security_timeout: {
        label: "Ombi la maeneo limepitwa na muda",
        detail: "Hakuna badiliko linalodhaniwa. Wasifu unaendelea kuonekana.",
      },
    },
    eyebrow: "Maeneo washirika",
    title: (club) => `Maeneo ya siku ya mechi ya ${club}`,
    description:
      "Gundua wasifu wa umma ulioidhinishwa hapa. Kuingia, zawadi na kuagiza hubaki kwenye programu salama.",
    openApp: "Fungua programu",
    appPending: "Viungo vinakuja hivi karibuni",
    browseTickets: "Tazama tiketi",
    refresh: "Sasisha maeneo",
    retry: "Jaribu tena",
    refreshDisabled: "Huwezi kusasisha wakati orodha inapakia.",
    approved: "Yaliyoidhinishwa",
    cities: "Miji",
    selected: "Lililochaguliwa",
    selectedVenue: "Eneo lililochaguliwa",
    venueDirectory: "Orodha iliyoidhinishwa",
    directoryDetail: "Chagua wasifu wa umma ili kuona muhtasari uliothibitishwa.",
    city: "Mji",
    publicProfile: "Wasifu wa umma",
    emptyTitle: "Hakuna maeneo yaliyoidhinishwa",
    emptyDetail: "Wasifu huonekana baada ya ukaguzi na idhini ya klabu.",
    privacyEyebrow: "Mpaka wa faragha",
    privacyTitle: "Gundua hapa. Vitendo salama kwenye programu.",
    privacyDetail:
      "Tovuti ya umma haifanyi kuingia kwa uthibitisho, haionyeshi eneo kamili la mshabiki, wala foleni za oda.",
  },
};

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

export function normalizeVenues(value: unknown): PublicVenue[] {
  if (!Array.isArray(value)) return [];
  const identities = new Set<string>();
  const slugs = new Set<string>();
  const venues: PublicVenue[] = [];
  for (const entry of value) {
    if (typeof entry !== "object" || entry == null) continue;
    const row = entry as Record<string, unknown>;
    const id = boundedString(row.id, 200);
    const displayName = boundedString(row.displayName, 160);
    const slug = boundedString(row.slug, 160);
    const city = boundedString(row.city, 120);
    const summary = boundedString(row.summary, 1_000);
    if (
      !id ||
      !displayName ||
      !slug ||
      !city ||
      !summary ||
      identities.has(id) ||
      slugs.has(slug)
    ) {
      continue;
    }
    identities.add(id);
    slugs.add(slug);
    venues.push({ id, displayName, slug, city, summary });
    if (venues.length === 12) break;
  }
  return venues.sort(
    (a, b) =>
      a.city.localeCompare(b.city) ||
      a.displayName.localeCompare(b.displayName),
  );
}

export function resolveVenuesCopy(locale: string) {
  const language = locale.trim().toLowerCase().split(/[-_]/)[0];
  return venueCopy[language as keyof typeof venueCopy] ?? venueCopy.en;
}

export function VenuesSurface({
  locale,
  clubShortName,
  fanAppHref,
  hasExternalAppUrl,
}: VenuesSurfaceProps) {
  const copy = useMemo(() => resolveVenuesCopy(locale), [locale]);
  const [venues, setVenues] = useState<PublicVenue[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] = useState<VenuesInteraction>("idle");
  const hasConfirmedVenues = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadVenues = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmedVenues.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, VENUES_TIMEOUT_MS);
    try {
      const response = await fetch("/api/public-content?resource=venues", {
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
      const nextVenues = normalizeVenues(items);
      if (!isMounted.current) return;
      setVenues(nextVenues);
      setSelectedId((current) =>
        nextVenues.some(({ id }) => id === current)
          ? current
          : (nextVenues[0]?.id ?? null),
      );
      hasConfirmedVenues.current = nextVenues.length > 0;
      setStatus(nextVenues.length === 0 ? "empty" : "ready");
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
    void loadVenues();
    const handleOffline = () => setStatus("offline");
    const handleOnline = () => void loadVenues();
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, [loadVenues]);

  const selected =
    venues.find(({ id }) => id === selectedId) ?? venues[0] ?? null;
  const cityCount = new Set(venues.map(({ city }) => city.toLowerCase())).size;
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
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) return;
    setInteraction("pressed");
  };

  return (
    <section
      className="venues-surface"
      data-venues-status={status}
      data-venues-interaction={interaction}
      data-venues-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="venues-hero">
          <div>
            <p className="venues-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title(clubShortName)}</h1>
            <p className="venues-description">{copy.description}</p>
          </div>
          <aside
            className="venues-status"
            data-venues-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <MapPin aria-hidden="true" />
            )}
            <div>
              <p>{message.label}</p>
              <span>{message.detail}</span>
            </div>
          </aside>
          <div className="venues-actions">
            <Link
              href={fanAppHref}
              className="venues-action venues-action-primary"
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
              href="/tickets"
              className="venues-action venues-action-secondary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <Ticket aria-hidden="true" /> {copy.browseTickets}
            </Link>
            <button
              type="button"
              className="venues-action venues-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "venues-refresh-disabled" : undefined}
              onClick={() => void loadVenues()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={pressControl}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? copy.retry : copy.refresh}
            </button>
            <span id="venues-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
          <dl className="venues-stats">
            <div>
              <dt>{copy.approved}</dt>
              <dd>{venues.length}</dd>
            </div>
            <div>
              <dt>{copy.cities}</dt>
              <dd>{cityCount}</dd>
            </div>
            <div>
              <dt>{copy.selected}</dt>
              <dd>{selected?.displayName ?? "—"}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="venues-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="venues-content" aria-busy={isBusy}>
          {selected ? (
            <article className="venues-featured">
              <span className="venues-featured-mark" aria-hidden="true">
                <MapPin />
              </span>
              <div>
                <p className="venues-eyebrow">{copy.selectedVenue}</p>
                <h2>{selected.displayName}</h2>
                <dl className="venues-featured-stats">
                  <div>
                    <dt>{copy.city}</dt>
                    <dd>{selected.city}</dd>
                  </div>
                  <div>
                    <dt>{copy.publicProfile}</dt>
                    <dd>{copy.approved}</dd>
                  </div>
                </dl>
                <p>{selected.summary}</p>
                <Link
                  href={fanAppHref}
                  className="venues-action venues-action-primary"
                >
                  {hasExternalAppUrl ? copy.openApp : copy.appPending}
                  <ArrowRight aria-hidden="true" />
                </Link>
              </div>
            </article>
          ) : status === "loading" ? (
            <div className="venues-skeleton" aria-label={message.label}>
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="venues-empty">
              <MapPin aria-hidden="true" />
              <h2>{copy.emptyTitle}</h2>
              <p>{copy.emptyDetail}</p>
            </div>
          )}

          {venues.length > 0 ? (
            <section className="venues-directory">
              <header>
                <div>
                  <p className="venues-eyebrow">{copy.venueDirectory}</p>
                  <h2>{copy.venueDirectory}</h2>
                </div>
                <p>{copy.directoryDetail}</p>
              </header>
              <div className="venues-grid">
                {venues.map((venue) => (
                  <button
                    type="button"
                    key={venue.id}
                    className="venues-card"
                    aria-pressed={venue.id === selected?.id}
                    onClick={() => {
                      setSelectedId(venue.id);
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
                    <span className="venues-card-icon" aria-hidden="true">
                      <MapPin />
                    </span>
                    <span>
                      <strong>{venue.displayName}</strong>
                      <small>{venue.city}</small>
                    </span>
                    <ArrowRight aria-hidden="true" />
                  </button>
                ))}
              </div>
            </section>
          ) : null}
        </section>

        <aside className="venues-privacy">
          <ShieldCheck aria-hidden="true" />
          <div>
            <p className="venues-eyebrow">{copy.privacyEyebrow}</p>
            <h2>{copy.privacyTitle}</h2>
            <p>{copy.privacyDetail}</p>
          </div>
        </aside>
      </div>
    </section>
  );
}
