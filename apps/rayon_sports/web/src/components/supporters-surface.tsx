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
  Award,
  RefreshCw,
  ShieldCheck,
  Smartphone,
  Ticket,
  Trophy,
  Users,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const SUPPORTERS_TIMEOUT_MS = 8_000;

export type PublicSupporterReward = {
  id: string;
  code: string;
  category: string;
  itemName: string;
  fetValue: number;
  triggerCondition: string;
  activationTiming: string;
  description: string;
};

export type PublicSupporterRanking = {
  rank: number;
  supporterAlias: string;
  totalFet: number;
  tier: string;
};

type SupportersSnapshot = {
  catalog: PublicSupporterReward[];
  leaderboard: PublicSupporterRanking[];
};

type SupportersInteraction = "idle" | "focused" | "pressed" | "selected";

type SupportersSurfaceProps = {
  locale: string;
  clubShortName: string;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
};

type SupportersCopy = {
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
  rewards: string;
  publicAliases: string;
  selected: string;
  selectedReward: string;
  rewardCatalog: string;
  catalogDetail: string;
  leaderboard: string;
  leaderboardDetail: string;
  points: string;
  trigger: string;
  timing: string;
  tier: string;
  noRewards: string;
  noRewardsDetail: string;
  noRanking: string;
  noRankingDetail: string;
  privacyEyebrow: string;
  privacyTitle: string;
  privacyDetail: string;
};

const supportersCopy: Record<"en" | "fr" | "rw" | "sw", SupportersCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading supporter program",
        detail: "Waiting for the first confirmed public rewards snapshot.",
      },
      ready: {
        label: "Supporter program confirmed",
        detail: "Rewards and privacy-safe aliases come from the latest public snapshot.",
      },
      empty: {
        label: "No public supporter data",
        detail: "No reward or privacy-safe ranking is confirmed for this club.",
      },
      error: {
        label: "Supporter program unavailable",
        detail: "Confirmed public data remains visible. Retry when service recovers.",
      },
      offline: {
        label: "You are offline",
        detail: "Confirmed public data remains visible until the connection returns.",
      },
      permission_denied: {
        label: "Supporter data access denied",
        detail: "Previously loaded public data has been cleared for this visitor.",
      },
      syncing: {
        label: "Refreshing supporter program",
        detail: "Confirmed rewards and aliases remain visible during refresh.",
      },
      conflict: {
        label: "Supporter program changed",
        detail: "Refresh to load the current confirmed public snapshot.",
      },
      security_timeout: {
        label: "Supporter request timed out",
        detail: "No change is assumed. Confirmed public data remains visible.",
      },
    },
    eyebrow: "Supporter program",
    title: (club) => `${club} rewards and public ranking`,
    description:
      "Discover confirmed rewards and privacy-safe public aliases here. Personal progress, earning, and secure actions stay in the supporter app.",
    openApp: "Open supporter app",
    appPending: "App links coming soon",
    browseTickets: "Browse tickets",
    refresh: "Refresh program",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while supporter data is loading.",
    rewards: "Rewards",
    publicAliases: "Public aliases",
    selected: "Selected",
    selectedReward: "Selected reward",
    rewardCatalog: "Confirmed reward catalog",
    catalogDetail: "Choose a reward to inspect its public trigger and timing.",
    leaderboard: "Privacy-safe public ranking",
    leaderboardDetail: "Only club-approved aliases, rank, tier, and FET total appear.",
    points: "FET points",
    trigger: "Trigger",
    timing: "Timing",
    tier: "Tier",
    noRewards: "No public rewards listed",
    noRewardsDetail: "Rewards appear only after club confirmation.",
    noRanking: "No public ranking listed",
    noRankingDetail: "A ranking appears only when privacy-safe aliases are approved.",
    privacyEyebrow: "Privacy boundary",
    privacyTitle: "Discovery here. Personal progress in the app.",
    privacyDetail:
      "Public web never exposes user IDs, supporter names, contact details, authenticated progress, or earning actions.",
  },
  fr: {
    status: {
      loading: {
        label: "Chargement du programme supporters",
        detail: "En attente du premier instantané public confirmé.",
      },
      ready: {
        label: "Programme supporters confirmé",
        detail: "Les récompenses et alias sûrs viennent du dernier instantané public.",
      },
      empty: {
        label: "Aucune donnée publique",
        detail: "Aucune récompense ou position publique n’est confirmée.",
      },
      error: {
        label: "Programme indisponible",
        detail: "Les données confirmées restent visibles. Réessayez plus tard.",
      },
      offline: {
        label: "Vous êtes hors ligne",
        detail: "Les données confirmées restent visibles jusqu’au retour du réseau.",
      },
      permission_denied: {
        label: "Accès aux données refusé",
        detail: "Les données publiques déjà chargées ont été effacées.",
      },
      syncing: {
        label: "Actualisation du programme",
        detail: "Les récompenses et alias confirmés restent visibles.",
      },
      conflict: {
        label: "Le programme a changé",
        detail: "Actualisez pour charger l’instantané public actuel.",
      },
      security_timeout: {
        label: "Délai de la demande dépassé",
        detail: "Aucun changement n’est supposé. Les données restent visibles.",
      },
    },
    eyebrow: "Programme supporters",
    title: (club) => `Récompenses et classement public de ${club}`,
    description:
      "Découvrez les récompenses confirmées et des alias publics sûrs. La progression personnelle et les actions sécurisées restent dans l’application.",
    openApp: "Ouvrir l’application",
    appPending: "Liens bientôt disponibles",
    browseTickets: "Voir les billets",
    refresh: "Actualiser le programme",
    retry: "Réessayer",
    refreshDisabled: "Actualisation indisponible pendant le chargement.",
    rewards: "Récompenses",
    publicAliases: "Alias publics",
    selected: "Sélection",
    selectedReward: "Récompense sélectionnée",
    rewardCatalog: "Catalogue confirmé",
    catalogDetail: "Choisissez une récompense pour voir son déclencheur et son moment.",
    leaderboard: "Classement public respectueux de la vie privée",
    leaderboardDetail: "Seuls l’alias approuvé, le rang, le niveau et le total FET apparaissent.",
    points: "Points FET",
    trigger: "Déclencheur",
    timing: "Moment",
    tier: "Niveau",
    noRewards: "Aucune récompense publique",
    noRewardsDetail: "Les récompenses apparaissent après confirmation du club.",
    noRanking: "Aucun classement public",
    noRankingDetail: "Le classement apparaît après approbation des alias sûrs.",
    privacyEyebrow: "Limite de confidentialité",
    privacyTitle: "Découverte ici. Progression personnelle dans l’application.",
    privacyDetail:
      "Le site public n’expose jamais les identifiants, noms, contacts, progression authentifiée ou actions de gain.",
  },
  rw: {
    status: {
      loading: {
        label: "Porogaramu y’abafana irimo gutangira",
        detail: "Dutegereje amakuru rusange ya mbere yemejwe.",
      },
      ready: {
        label: "Porogaramu y’abafana yemejwe",
        detail: "Ibihembo n’amazina arinda ibanga biva ku makuru yemejwe.",
      },
      empty: {
        label: "Nta makuru rusange",
        detail: "Nta gihembo cyangwa rutonde rusange byemejwe.",
      },
      error: {
        label: "Porogaramu ntiboneka",
        detail: "Amakuru yemejwe aragumaho. Ongera ugerageze nyuma.",
      },
      offline: {
        label: "Nta murongo wa interineti",
        detail: "Amakuru yemejwe aragumaho kugeza umurongo ugarutse.",
      },
      permission_denied: {
        label: "Amakuru ntiyemerewe",
        detail: "Amakuru rusange yari yafunguwe yasibwe.",
      },
      syncing: {
        label: "Porogaramu irimo kuvugururwa",
        detail: "Ibihembo n’amazina byemejwe biragumaho.",
      },
      conflict: {
        label: "Porogaramu yahindutse",
        detail: "Vugurura kugira ngo ubone amakuru rusange ariho.",
      },
      security_timeout: {
        label: "Igihe cyo gusaba cyarangiye",
        detail: "Nta gihindutse cyemezwa. Amakuru yemejwe aragumaho.",
      },
    },
    eyebrow: "Porogaramu y’abafana",
    title: (club) => `Ibihembo n’urutonde rusange rwa ${club}`,
    description:
      "Menya ibihembo byemejwe n’amazina rusange arinda ibanga. Iterambere ry’umuntu n’ibikorwa birinzwe biguma muri porogaramu.",
    openApp: "Fungura porogaramu",
    appPending: "Imiyoboro izaboneka vuba",
    browseTickets: "Reba amatike",
    refresh: "Vugurura porogaramu",
    retry: "Ongera ugerageze",
    refreshDisabled: "Ntushobora kuvugurura mu gihe amakuru atangira.",
    rewards: "Ibihembo",
    publicAliases: "Amazina rusange",
    selected: "Icyatoranyijwe",
    selectedReward: "Igihembo cyatoranyijwe",
    rewardCatalog: "Urutonde rw’ibihembo rwemejwe",
    catalogDetail: "Hitamo igihembo urebe igikorwa n’igihe byacyo.",
    leaderboard: "Urutonde rusange rurinda ibanga",
    leaderboardDetail: "Hagaragara gusa izina ryemejwe, umwanya, icyiciro n’amanota FET.",
    points: "Amanota FET",
    trigger: "Igikorwa",
    timing: "Igihe",
    tier: "Icyiciro",
    noRewards: "Nta bihembo rusange",
    noRewardsDetail: "Ibihembo bigaragara nyuma yo kwemezwa n’ikipe.",
    noRanking: "Nta rutonde rusange",
    noRankingDetail: "Urutonde rugaragara amazina arinda ibanga amaze kwemezwa.",
    privacyEyebrow: "Imipaka y’ibanga",
    privacyTitle: "Menya hano. Iterambere ry’umuntu muri porogaramu.",
    privacyDetail:
      "Urubuga rusange ntirwerekana imyirondoro, amazina, amakuru yo kuvugana, iterambere ryihariye cyangwa ibikorwa byo kubona amanota.",
  },
  sw: {
    status: {
      loading: {
        label: "Inapakia programu ya mashabiki",
        detail: "Inasubiri picha ya kwanza ya umma iliyothibitishwa.",
      },
      ready: {
        label: "Programu ya mashabiki imethibitishwa",
        detail: "Zawadi na majina salama zinatoka kwenye picha ya umma.",
      },
      empty: {
        label: "Hakuna data ya umma",
        detail: "Hakuna zawadi au nafasi ya umma iliyothibitishwa.",
      },
      error: {
        label: "Programu haipatikani",
        detail: "Data iliyothibitishwa inaonekana. Jaribu tena baadaye.",
      },
      offline: {
        label: "Huna mtandao",
        detail: "Data iliyothibitishwa inaonekana hadi mtandao urudi.",
      },
      permission_denied: {
        label: "Ufikiaji wa data umekataliwa",
        detail: "Data ya umma iliyopakiwa imeondolewa.",
      },
      syncing: {
        label: "Inasasisha programu",
        detail: "Zawadi na majina yaliyothibitishwa yanaendelea kuonekana.",
      },
      conflict: {
        label: "Programu imebadilika",
        detail: "Sasisha ili kupakia picha ya sasa ya umma.",
      },
      security_timeout: {
        label: "Ombi limepitwa na muda",
        detail: "Hakuna badiliko linalodhaniwa. Data inaendelea kuonekana.",
      },
    },
    eyebrow: "Programu ya mashabiki",
    title: (club) => `Zawadi na nafasi za umma za ${club}`,
    description:
      "Gundua zawadi zilizothibitishwa na majina salama ya umma. Maendeleo binafsi na hatua salama hubaki kwenye programu.",
    openApp: "Fungua programu",
    appPending: "Viungo vinakuja hivi karibuni",
    browseTickets: "Tazama tiketi",
    refresh: "Sasisha programu",
    retry: "Jaribu tena",
    refreshDisabled: "Huwezi kusasisha wakati data inapakia.",
    rewards: "Zawadi",
    publicAliases: "Majina ya umma",
    selected: "Iliyochaguliwa",
    selectedReward: "Zawadi iliyochaguliwa",
    rewardCatalog: "Catalog ya zawadi iliyothibitishwa",
    catalogDetail: "Chagua zawadi kuona kichocheo na wakati wake.",
    leaderboard: "Jedwali la umma linalolinda faragha",
    leaderboardDetail: "Jina lililoidhinishwa, nafasi, daraja na jumla ya FET pekee huonekana.",
    points: "Pointi za FET",
    trigger: "Kichocheo",
    timing: "Wakati",
    tier: "Daraja",
    noRewards: "Hakuna zawadi za umma",
    noRewardsDetail: "Zawadi huonekana baada ya uthibitisho wa klabu.",
    noRanking: "Hakuna jedwali la umma",
    noRankingDetail: "Jedwali huonekana baada ya majina salama kuidhinishwa.",
    privacyEyebrow: "Mpaka wa faragha",
    privacyTitle: "Gundua hapa. Maendeleo binafsi kwenye programu.",
    privacyDetail:
      "Tovuti ya umma haionyeshi vitambulisho, majina, mawasiliano, maendeleo ya akaunti au hatua za kupata pointi.",
  },
};

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

export function normalizeSupportersSnapshot(value: unknown): SupportersSnapshot {
  if (typeof value !== "object" || value == null) {
    return { catalog: [], leaderboard: [] };
  }
  const payload = value as Record<string, unknown>;
  const catalogIds = new Set<string>();
  const catalogCodes = new Set<string>();
  const catalog: PublicSupporterReward[] = [];
  if (Array.isArray(payload.catalog)) {
    for (const entry of payload.catalog) {
      if (typeof entry !== "object" || entry == null) continue;
      const row = entry as Record<string, unknown>;
      const id = boundedString(row.id, 200);
      const code = boundedString(row.code, 64);
      const category = boundedString(row.category, 120);
      const itemName = boundedString(row.itemName, 160);
      const fetValue = Number(row.fetValue);
      const triggerCondition = boundedString(row.triggerCondition, 500);
      const activationTiming = boundedString(row.activationTiming, 300);
      const description = boundedString(row.description, 1_000);
      if (
        !id ||
        !code ||
        !category ||
        !itemName ||
        !Number.isInteger(fetValue) ||
        fetValue < 0 ||
        fetValue > 1_000_000_000 ||
        !triggerCondition ||
        !activationTiming ||
        !description ||
        catalogIds.has(id) ||
        catalogCodes.has(code.toLowerCase())
      ) {
        continue;
      }
      catalogIds.add(id);
      catalogCodes.add(code.toLowerCase());
      catalog.push({
        id,
        code,
        category,
        itemName,
        fetValue,
        triggerCondition,
        activationTiming,
        description,
      });
      if (catalog.length === 8) break;
    }
  }

  const ranks = new Set<number>();
  const aliases = new Set<string>();
  const leaderboard: PublicSupporterRanking[] = [];
  if (Array.isArray(payload.leaderboard)) {
    for (const entry of payload.leaderboard) {
      if (typeof entry !== "object" || entry == null) continue;
      const row = entry as Record<string, unknown>;
      const rank = Number(row.rank);
      const supporterAlias = boundedString(row.supporterAlias, 32);
      const totalFet = Number(row.totalFet);
      const tier = boundedString(row.tier, 40);
      const normalizedAlias = supporterAlias.toLowerCase();
      if (
        !Number.isInteger(rank) ||
        rank < 1 ||
        rank > 100_000 ||
        !/^[A-Za-z0-9_-]{2,32}$/.test(supporterAlias) ||
        /^\d{7,}$/.test(supporterAlias) ||
        !Number.isInteger(totalFet) ||
        totalFet < 0 ||
        totalFet > 1_000_000_000_000 ||
        !tier ||
        ranks.has(rank) ||
        aliases.has(normalizedAlias)
      ) {
        continue;
      }
      ranks.add(rank);
      aliases.add(normalizedAlias);
      leaderboard.push({ rank, supporterAlias, totalFet, tier });
      if (leaderboard.length === 10) break;
    }
  }
  leaderboard.sort((a, b) => a.rank - b.rank);
  return { catalog, leaderboard };
}

export function resolveSupportersCopy(locale: string) {
  const language = locale.trim().toLowerCase().split(/[-_]/)[0];
  return supportersCopy[language as keyof typeof supportersCopy] ?? supportersCopy.en;
}

export function SupportersSurface({
  locale,
  clubShortName,
  fanAppHref,
  hasExternalAppUrl,
}: SupportersSurfaceProps) {
  const copy = useMemo(() => resolveSupportersCopy(locale), [locale]);
  const [snapshot, setSnapshot] = useState<SupportersSnapshot>({
    catalog: [],
    leaderboard: [],
  });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] = useState<SupportersInteraction>("idle");
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
    }, SUPPORTERS_TIMEOUT_MS);
    try {
      const response = await fetch("/api/public-content?resource=supporters", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        if (!isMounted.current) return;
        if (response.status === 403) {
          setSnapshot({ catalog: [], leaderboard: [] });
          setSelectedId(null);
          hasConfirmedSnapshot.current = false;
        }
        setStatus(resolveFixturesFailureStatus(response.status));
        return;
      }
      if (
        typeof payload !== "object" ||
        payload == null ||
        !("catalog" in payload) ||
        !("leaderboard" in payload)
      ) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const nextSnapshot = normalizeSupportersSnapshot(payload);
      if (!isMounted.current) return;
      setSnapshot(nextSnapshot);
      setSelectedId((current) =>
        nextSnapshot.catalog.some(({ id }) => id === current)
          ? current
          : (nextSnapshot.catalog[0]?.id ?? null),
      );
      const hasData =
        nextSnapshot.catalog.length > 0 || nextSnapshot.leaderboard.length > 0;
      hasConfirmedSnapshot.current = hasData;
      setStatus(hasData ? "ready" : "empty");
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

  const selected =
    snapshot.catalog.find(({ id }) => id === selectedId) ??
    snapshot.catalog[0] ??
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
    if ("disabled" in event.currentTarget && event.currentTarget.disabled) return;
    setInteraction("pressed");
  };

  return (
    <section
      className="supporters-surface"
      data-supporters-status={status}
      data-supporters-interaction={interaction}
      data-supporters-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="supporters-hero">
          <div>
            <p className="supporters-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title(clubShortName)}</h1>
            <p className="supporters-description">{copy.description}</p>
          </div>
          <aside
            className="supporters-status"
            data-supporters-status={status}
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
          <div className="supporters-actions">
            <Link
              href={fanAppHref}
              className="supporters-action supporters-action-primary"
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
              className="supporters-action supporters-action-secondary"
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
              className="supporters-action supporters-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "supporters-refresh-disabled" : undefined}
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
            <span id="supporters-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
          <dl className="supporters-stats">
            <div>
              <dt>{copy.rewards}</dt>
              <dd>{snapshot.catalog.length}</dd>
            </div>
            <div>
              <dt>{copy.publicAliases}</dt>
              <dd>{snapshot.leaderboard.length}</dd>
            </div>
            <div>
              <dt>{copy.selected}</dt>
              <dd>{selected?.code ?? "—"}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="supporters-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="supporters-content" aria-busy={isBusy}>
          {selected ? (
            <article className="supporters-featured">
              <span className="supporters-featured-mark" aria-hidden="true">
                <Award />
              </span>
              <div>
                <p className="supporters-eyebrow">{copy.selectedReward}</p>
                <h2>{selected.itemName}</h2>
                <dl className="supporters-featured-stats">
                  <div>
                    <dt>{copy.points}</dt>
                    <dd>{selected.fetValue.toLocaleString()}</dd>
                  </div>
                  <div>
                    <dt>{copy.selected}</dt>
                    <dd>{selected.code}</dd>
                  </div>
                </dl>
                <p>{selected.description}</p>
                <p>
                  <strong>{copy.trigger}:</strong> {selected.triggerCondition}
                </p>
                <p>
                  <strong>{copy.timing}:</strong> {selected.activationTiming}
                </p>
                <Link
                  href={fanAppHref}
                  className="supporters-action supporters-action-primary"
                >
                  {hasExternalAppUrl ? copy.openApp : copy.appPending}
                  <ArrowRight aria-hidden="true" />
                </Link>
              </div>
            </article>
          ) : status === "loading" ? (
            <div
              className="supporters-skeleton"
              role="status"
              aria-label={message.label}
            >
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="supporters-empty">
              <Award aria-hidden="true" />
              <h2>{copy.noRewards}</h2>
              <p>{copy.noRewardsDetail}</p>
            </div>
          )}

          {snapshot.catalog.length > 0 ? (
            <section className="supporters-catalog">
              <header>
                <div>
                  <p className="supporters-eyebrow">{copy.rewardCatalog}</p>
                  <h2>{copy.rewardCatalog}</h2>
                </div>
                <p>{copy.catalogDetail}</p>
              </header>
              <div className="supporters-grid">
                {snapshot.catalog.map((reward) => (
                  <button
                    type="button"
                    key={reward.id}
                    className="supporters-card"
                    aria-pressed={reward.id === selected?.id}
                    onClick={() => {
                      setSelectedId(reward.id);
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
                    <span className="supporters-card-icon" aria-hidden="true">
                      <Award />
                    </span>
                    <span>
                      <strong>{reward.itemName}</strong>
                      <small>
                        {reward.category} · {reward.fetValue.toLocaleString()} FET
                      </small>
                    </span>
                    <ArrowRight aria-hidden="true" />
                  </button>
                ))}
              </div>
            </section>
          ) : null}

          <section className="supporters-leaderboard">
            <header>
              <div>
                <p className="supporters-eyebrow">{copy.leaderboard}</p>
                <h2>{copy.leaderboard}</h2>
              </div>
              <p>{copy.leaderboardDetail}</p>
            </header>
            {snapshot.leaderboard.length > 0 ? (
              <ol>
                {snapshot.leaderboard.map((entry) => (
                  <li key={`${entry.rank}-${entry.supporterAlias}`}>
                    <span aria-label={`Rank ${entry.rank}`}>{entry.rank}</span>
                    <div>
                      <strong>#{entry.supporterAlias}</strong>
                      <small>
                        {copy.tier}: {entry.tier.toUpperCase()}
                      </small>
                    </div>
                    <b>
                      {entry.totalFet.toLocaleString()} {copy.points}
                    </b>
                  </li>
                ))}
              </ol>
            ) : (
              <div className="supporters-empty supporters-empty-compact">
                <Trophy aria-hidden="true" />
                <h2>{copy.noRanking}</h2>
                <p>{copy.noRankingDetail}</p>
              </div>
            )}
          </section>
        </section>

        <aside className="supporters-privacy">
          <ShieldCheck aria-hidden="true" />
          <div>
            <p className="supporters-eyebrow">{copy.privacyEyebrow}</p>
            <h2>{copy.privacyTitle}</h2>
            <p>{copy.privacyDetail}</p>
          </div>
        </aside>
      </div>
    </section>
  );
}
