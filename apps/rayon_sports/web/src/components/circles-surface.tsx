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
  CircleDollarSign,
  MapPinned,
  RefreshCw,
  ShieldCheck,
  Smartphone,
  Users,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const CIRCLES_TIMEOUT_MS = 8_000;

export type PublicCircle = {
  id: string;
  name: string;
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

const circlesCopy: Record<"en" | "fr" | "rw" | "sw", CirclesCopy> = {
  en: {
    status: {
      loading: {
        label: "Loading support circles",
        detail: "Waiting for the first confirmed public campaign snapshot.",
      },
      ready: {
        label: "Support circles confirmed",
        detail:
          "Campaign totals and chapters come from the latest public snapshot.",
      },
      empty: {
        label: "No public circles listed",
        detail: "No campaign or supporter chapter is currently confirmed.",
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
          "Confirmed campaigns and chapters remain visible during refresh.",
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
      "Discover confirmed club campaigns and official supporter chapters. Secure contribution and membership actions stay in the supporter app.",
    openApp: "Open supporter app",
    appPending: "App links coming soon",
    exploreChapters: "Explore fan clubs",
    refresh: "Refresh circles",
    retry: "Try again",
    refreshDisabled: "Refresh is unavailable while circles are loading.",
    campaigns: "Campaigns",
    chapters: "Chapters",
    selected: "Selected",
    selectedCampaign: "Selected campaign",
    publicCampaigns: "Confirmed public campaigns",
    campaignsDetail:
      "Choose a campaign to inspect its confirmed public totals.",
    chapterNetwork: "Official chapter network",
    chaptersDetail:
      "Only public chapter identity and activity totals appear here.",
    raised: "Raised",
    goal: "Campaign goal",
    backers: "Backers",
    progress: "Progress",
    events: "Events",
    noCampaigns: "No public campaigns listed",
    noCampaignsDetail: "Campaigns appear only after club confirmation.",
    noChapters: "No public chapters listed",
    noChaptersDetail: "Chapters appear only after club confirmation.",
    boundaryEyebrow: "Trust boundary",
    boundaryTitle: "Discovery here. Secure support in the app.",
    boundaryDetail:
      "Public web never exposes contributor identities, payment details, receipts, private balances, or contribution actions. Confirm current totals and terms in the supporter app before acting.",
  },
  fr: {
    status: {
      loading: {
        label: "Chargement des cercles",
        detail: "En attente du premier instantané public confirmé.",
      },
      ready: {
        label: "Cercles confirmés",
        detail:
          "Les campagnes et sections viennent du dernier instantané public.",
      },
      empty: {
        label: "Aucun cercle public",
        detail: "Aucune campagne ou section n’est actuellement confirmée.",
      },
      error: {
        label: "Cercles indisponibles",
        detail: "Les données confirmées restent visibles. Réessayez plus tard.",
      },
      offline: {
        label: "Vous êtes hors ligne",
        detail:
          "Les données confirmées restent visibles jusqu’au retour du réseau.",
      },
      permission_denied: {
        label: "Accès aux cercles refusé",
        detail: "Les données publiques précédentes ont été effacées.",
      },
      syncing: {
        label: "Actualisation des cercles",
        detail:
          "Les campagnes confirmées restent visibles pendant l’actualisation.",
      },
      conflict: {
        label: "Les cercles ont changé",
        detail: "Actualisez pour charger l’instantané public actuel.",
      },
      security_timeout: {
        label: "Délai de demande dépassé",
        detail:
          "Aucun changement n’est présumé. Les données confirmées restent visibles.",
      },
    },
    eyebrow: "Soutien collectif",
    title: (club) => `Cercles de soutien ${club}`,
    description:
      "Découvrez les campagnes confirmées et les sections officielles. Les contributions sécurisées restent dans l’app supporters.",
    openApp: "Ouvrir l’app supporters",
    appPending: "Liens de l’app bientôt disponibles",
    exploreChapters: "Explorer les fan-clubs",
    refresh: "Actualiser les cercles",
    retry: "Réessayer",
    refreshDisabled: "Actualisation indisponible pendant le chargement.",
    campaigns: "Campagnes",
    chapters: "Sections",
    selected: "Sélection",
    selectedCampaign: "Campagne sélectionnée",
    publicCampaigns: "Campagnes publiques confirmées",
    campaignsDetail:
      "Choisissez une campagne pour voir ses totaux publics confirmés.",
    chapterNetwork: "Réseau officiel des sections",
    chaptersDetail:
      "Seules l’identité publique et l’activité des sections apparaissent.",
    raised: "Collecté",
    goal: "Objectif",
    backers: "Soutiens",
    progress: "Progression",
    events: "Événements",
    noCampaigns: "Aucune campagne publique",
    noCampaignsDetail: "Les campagnes apparaissent après confirmation du club.",
    noChapters: "Aucune section publique",
    noChaptersDetail: "Les sections apparaissent après confirmation du club.",
    boundaryEyebrow: "Limite de confiance",
    boundaryTitle: "Découverte ici. Soutien sécurisé dans l’app.",
    boundaryDetail:
      "Le web public n’expose ni identité, paiement, reçu, solde privé ou action de contribution. Confirmez les totaux et conditions dans l’app.",
  },
  rw: {
    status: {
      loading: {
        label: "Amatsinda y’inkunga ari gutwarwa",
        detail: "Hategerejwe amakuru ya mbere yemejwe ku mugaragaro.",
      },
      ready: {
        label: "Amatsinda y’inkunga yemejwe",
        detail: "Imishinga n’amashami biva mu makuru ya vuba yemejwe.",
      },
      empty: {
        label: "Nta matsinda ari ku mugaragaro",
        detail: "Nta mushinga cyangwa ishami ry’abafana byemejwe ubu.",
      },
      error: {
        label: "Amatsinda ntaboneka",
        detail:
          "Amakuru yemejwe aragumaho. Ongera ugerageze serivisi igarutse.",
      },
      offline: {
        label: "Nta murongo wa interineti",
        detail: "Amakuru yemejwe aragumaho kugeza interineti igarutse.",
      },
      permission_denied: {
        label: "Uburenganzira bwanzwe",
        detail: "Amakuru yari yemejwe yasibwe kuri uyu mushyitsi.",
      },
      syncing: {
        label: "Amatsinda ari kuvugururwa",
        detail: "Imishinga yemejwe iragumaho mu gihe cyo kuvugurura.",
      },
      conflict: {
        label: "Amatsinda yarahindutse",
        detail: "Vugurura kugira ngo ubone amakuru agezweho.",
      },
      security_timeout: {
        label: "Igihe cyo gutegereza cyarangiye",
        detail: "Nta mpinduka ifatwa nk’iyabaye. Amakuru yemejwe aragumaho.",
      },
    },
    eyebrow: "Inkunga rusange",
    title: (club) => `Amatsinda y’inkunga ya ${club}`,
    description:
      "Reba imishinga yemejwe n’amashami y’abafana. Gutanga inkunga bikorwa mu buryo bwizewe muri app y’abafana.",
    openApp: "Fungura app y’abafana",
    appPending: "Imiyoboro ya app izaza vuba",
    exploreChapters: "Reba fan-clubs",
    refresh: "Vugurura amatsinda",
    retry: "Ongera ugerageze",
    refreshDisabled: "Kuvugurura ntibishoboka mu gihe amakuru ari gutwarwa.",
    campaigns: "Imishinga",
    chapters: "Amashami",
    selected: "Byatoranyijwe",
    selectedCampaign: "Umushinga watoranyijwe",
    publicCampaigns: "Imishinga yemejwe ku mugaragaro",
    campaignsDetail: "Hitamo umushinga urebe imibare yawo yemejwe.",
    chapterNetwork: "Urusobe rw’amashami yemejwe",
    chaptersDetail: "Hagaragara gusa amazina rusange n’ibikorwa by’amashami.",
    raised: "Byakusanyijwe",
    goal: "Intego",
    backers: "Abashyigikiye",
    progress: "Aho bigeze",
    events: "Ibikorwa",
    noCampaigns: "Nta mishinga iri ku mugaragaro",
    noCampaignsDetail: "Imishinga igaragara nyuma yo kwemezwa na club.",
    noChapters: "Nta mashami ari ku mugaragaro",
    noChaptersDetail: "Amashami agaragara nyuma yo kwemezwa na club.",
    boundaryEyebrow: "Umupaka w’icyizere",
    boundaryTitle: "Menya hano. Tanga inkunga muri app.",
    boundaryDetail:
      "Urubuga rusange ntirwerekana umwirondoro, ubwishyu, inyemezabwishyu, amafaranga bwite cyangwa igikorwa cyo gutanga. Emeza imibare n’amabwiriza muri app.",
  },
  sw: {
    status: {
      loading: {
        label: "Inapakia mizunguko ya msaada",
        detail: "Inasubiri picha ya kwanza ya umma iliyothibitishwa.",
      },
      ready: {
        label: "Mizunguko imethibitishwa",
        detail: "Kampeni na matawi hutoka kwenye picha ya hivi karibuni.",
      },
      empty: {
        label: "Hakuna mizunguko ya umma",
        detail: "Hakuna kampeni au tawi la mashabiki lililothibitishwa.",
      },
      error: {
        label: "Mizunguko haipatikani",
        detail:
          "Data iliyothibitishwa inaendelea kuonekana. Jaribu tena baadaye.",
      },
      offline: {
        label: "Huna mtandao",
        detail:
          "Data iliyothibitishwa itaendelea kuonekana hadi mtandao urudi.",
      },
      permission_denied: {
        label: "Ruhusa imekataliwa",
        detail: "Data ya umma iliyopakiwa awali imeondolewa.",
      },
      syncing: {
        label: "Inasasisha mizunguko",
        detail:
          "Kampeni zilizothibitishwa zinaendelea kuonekana wakati wa kusasisha.",
      },
      conflict: {
        label: "Mizunguko imebadilika",
        detail: "Sasisha ili kupakia picha ya sasa ya umma.",
      },
      security_timeout: {
        label: "Ombi limepitwa na muda",
        detail:
          "Hakuna mabadiliko yanayodhaniwa. Data iliyothibitishwa inaendelea.",
      },
    },
    eyebrow: "Msaada wa pamoja",
    title: (club) => `Mizunguko ya msaada ya ${club}`,
    description:
      "Gundua kampeni zilizothibitishwa na matawi rasmi. Michango salama inabaki kwenye programu ya mashabiki.",
    openApp: "Fungua programu ya mashabiki",
    appPending: "Viungo vya programu vinakuja",
    exploreChapters: "Chunguza fan-clubs",
    refresh: "Sasisha mizunguko",
    retry: "Jaribu tena",
    refreshDisabled: "Kusasisha hakupatikani wakati wa kupakia.",
    campaigns: "Kampeni",
    chapters: "Matawi",
    selected: "Iliyochaguliwa",
    selectedCampaign: "Kampeni iliyochaguliwa",
    publicCampaigns: "Kampeni za umma zilizothibitishwa",
    campaignsDetail: "Chagua kampeni kuona jumla zake za umma.",
    chapterNetwork: "Mtandao rasmi wa matawi",
    chaptersDetail: "Utambulisho wa umma na jumla za shughuli pekee huonekana.",
    raised: "Iliyokusanywa",
    goal: "Lengo",
    backers: "Wasaidizi",
    progress: "Maendeleo",
    events: "Matukio",
    noCampaigns: "Hakuna kampeni za umma",
    noCampaignsDetail: "Kampeni huonekana baada ya kuthibitishwa na klabu.",
    noChapters: "Hakuna matawi ya umma",
    noChaptersDetail: "Matawi huonekana baada ya kuthibitishwa na klabu.",
    boundaryEyebrow: "Mpaka wa uaminifu",
    boundaryTitle: "Gundua hapa. Saidia kwa usalama kwenye programu.",
    boundaryDetail:
      "Tovuti ya umma haionyeshi utambulisho, malipo, risiti, salio binafsi au hatua za kuchangia. Thibitisha jumla na masharti kwenye programu.",
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

export function resolveCirclesCopy(locale: string) {
  const language = locale.trim().toLowerCase().split(/[-_]/)[0];
  return circlesCopy[language as keyof typeof circlesCopy] ?? circlesCopy.en;
}

export function resolveFanClubsCopy(locale: string): CirclesCopy {
  const language = locale.trim().toLowerCase().split(/[-_]/)[0];
  const base =
    circlesCopy[language as keyof typeof circlesCopy] ?? circlesCopy.en;
  if (language === "fr") {
    return {
      ...base,
      status: {
        ...base.status,
        loading: {
          label: "Chargement des fan-clubs",
          detail: "En attente du premier annuaire public confirmé.",
        },
        ready: {
          label: "Fan-clubs confirmés",
          detail:
            "Les sections et campagnes viennent du dernier annuaire public.",
        },
        empty: {
          label: "Aucun fan-club public",
          detail: "Aucune section ou campagne n’est actuellement confirmée.",
        },
        error: {
          label: "Fan-clubs indisponibles",
          detail:
            "Les données confirmées restent visibles. Réessayez plus tard.",
        },
        permission_denied: {
          label: "Accès aux fan-clubs refusé",
          detail: "Les données publiques précédentes ont été effacées.",
        },
        syncing: {
          label: "Actualisation des fan-clubs",
          detail: "Les sections et campagnes confirmées restent visibles.",
        },
        conflict: {
          label: "L’annuaire a changé",
          detail: "Actualisez pour charger l’annuaire public actuel.",
        },
        security_timeout: {
          label: "Délai de l’annuaire dépassé",
          detail:
            "Aucun changement n’est présumé. Les données restent visibles.",
        },
      },
      eyebrow: "Sections officielles",
      title: (club) => `Fan-clubs officiels de ${club}`,
      description:
        "Découvrez les sections de supporters confirmées et leurs campagnes publiques. L’adhésion et les paiements sécurisés restent dans l’app.",
      exploreChapters: "Explorer les cercles",
      refresh: "Actualiser les fan-clubs",
      refreshDisabled:
        "Actualisation indisponible pendant le chargement des fan-clubs.",
      publicCampaigns: "Campagnes des fan-clubs",
      campaignsDetail: "Choisissez une campagne publique confirmée.",
      chapterNetwork: "Annuaire officiel des fan-clubs",
      chaptersDetail:
        "Seules l’identité publique et l’activité approuvée apparaissent.",
      boundaryTitle: "Annuaire ici. Adhésion sécurisée dans l’app.",
    };
  }
  if (language === "rw") {
    return {
      ...base,
      status: {
        ...base.status,
        loading: {
          label: "Fan-clubs zirimo gutwarwa",
          detail: "Hategerejwe urutonde rusange rwa mbere rwemejwe.",
        },
        ready: {
          label: "Fan-clubs zemejwe",
          detail: "Amashami n’imishinga biva ku rutonde rwa vuba rwemejwe.",
        },
        empty: {
          label: "Nta fan-club iri ku mugaragaro",
          detail: "Nta shami cyangwa umushinga byemejwe ubu.",
        },
        error: {
          label: "Fan-clubs ntiziboneka",
          detail: "Amakuru yemejwe aragumaho. Ongera ugerageze nyuma.",
        },
        permission_denied: {
          label: "Uburenganzira bwa fan-clubs bwanzwe",
          detail: "Amakuru rusange yari afunguwe yasibwe.",
        },
        syncing: {
          label: "Fan-clubs zirimo kuvugururwa",
          detail: "Amashami n’imishinga byemejwe biragumaho.",
        },
        conflict: {
          label: "Urutonde rwa fan-clubs rwahindutse",
          detail: "Vugurura kugira ngo ubone urutonde rushya.",
        },
        security_timeout: {
          label: "Igihe cyo gutegereza urutonde cyarangiye",
          detail: "Nta mpinduka ifatwa nk’iyabaye. Amakuru aragumaho.",
        },
      },
      eyebrow: "Amashami yemejwe",
      title: (club) => `Fan-clubs zemejwe za ${club}`,
      description:
        "Menya amashami y’abafana yemejwe n’imishinga yayo rusange. Kwinjira no kwishyura bikorwa muri app.",
      exploreChapters: "Reba amatsinda y’inkunga",
      refresh: "Vugurura fan-clubs",
      refreshDisabled: "Kuvugurura ntibishoboka fan-clubs zirimo gutwarwa.",
      publicCampaigns: "Imishinga ya fan-clubs",
      campaignsDetail: "Hitamo umushinga rusange wemejwe.",
      chapterNetwork: "Urutonde rwemejwe rwa fan-clubs",
      chaptersDetail:
        "Hagaragara gusa umwirondoro rusange n’ibikorwa byemejwe.",
      boundaryTitle: "Urutonde hano. Kwinjira muri app mu buryo bwizewe.",
    };
  }
  if (language === "sw") {
    return {
      ...base,
      status: {
        ...base.status,
        loading: {
          label: "Inapakia fan-clubs",
          detail: "Inasubiri orodha ya kwanza ya umma iliyothibitishwa.",
        },
        ready: {
          label: "Fan-clubs zimethibitishwa",
          detail: "Matawi na kampeni hutoka kwenye orodha ya sasa ya umma.",
        },
        empty: {
          label: "Hakuna fan-club ya umma",
          detail: "Hakuna tawi au kampeni iliyothibitishwa sasa.",
        },
        error: {
          label: "Fan-clubs hazipatikani",
          detail:
            "Data iliyothibitishwa inaendelea kuonekana. Jaribu tena baadaye.",
        },
        permission_denied: {
          label: "Ruhusa ya fan-clubs imekataliwa",
          detail: "Data ya umma iliyopakiwa awali imeondolewa.",
        },
        syncing: {
          label: "Inasasisha fan-clubs",
          detail: "Matawi na kampeni zilizothibitishwa zinaendelea kuonekana.",
        },
        conflict: {
          label: "Orodha ya fan-clubs imebadilika",
          detail: "Sasisha ili kupakia orodha ya sasa.",
        },
        security_timeout: {
          label: "Ombi la orodha limepitwa na muda",
          detail: "Hakuna mabadiliko yanayodhaniwa. Data inaendelea kuonekana.",
        },
      },
      eyebrow: "Matawi rasmi",
      title: (club) => `Fan-clubs rasmi za ${club}`,
      description:
        "Gundua matawi yaliyothibitishwa na kampeni zao za umma. Uanachama na malipo salama hubaki kwenye programu.",
      exploreChapters: "Chunguza mizunguko ya msaada",
      refresh: "Sasisha fan-clubs",
      refreshDisabled: "Kusasisha hakupatikani wakati fan-clubs zinapakia.",
      publicCampaigns: "Kampeni za fan-clubs",
      campaignsDetail: "Chagua kampeni ya umma iliyothibitishwa.",
      chapterNetwork: "Orodha rasmi ya fan-clubs",
      chaptersDetail:
        "Utambulisho wa umma na shughuli zilizoidhinishwa pekee huonekana.",
      boundaryTitle: "Orodha hapa. Uanachama salama kwenye programu.",
    };
  }
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
        detail: "Chapters and campaigns come from the latest public directory.",
      },
      empty: {
        label: "No public fan clubs listed",
        detail: "No chapter or campaign is currently confirmed.",
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
          "Confirmed chapters and campaigns remain visible during refresh.",
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
    eyebrow: "Official supporter chapters",
    title: (club) => `${club} official fan clubs`,
    description:
      "Discover confirmed supporter chapters and their public campaigns. Secure membership and payment actions stay in the supporter app.",
    exploreChapters: "Explore support circles",
    refresh: "Refresh fan clubs",
    refreshDisabled: "Refresh is unavailable while fan clubs are loading.",
    publicCampaigns: "Fan-club campaigns",
    campaignsDetail:
      "Choose a confirmed public campaign to inspect its totals.",
    chapterNetwork: "Official fan-club directory",
    chaptersDetail:
      "Only approved public chapter identity and activity totals appear.",
    boundaryTitle: "Directory here. Secure membership in the app.",
  };
}

function formatAmount(value: number, currency: string, locale: string) {
  try {
    return new Intl.NumberFormat(locale, {
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
        nextSnapshot.groups.length > 0 || nextSnapshot.chapters.length > 0;
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
  const progress = selected
    ? Math.min(
        100,
        Math.max(0, (selected.currentTotal / selected.targetAmount) * 100),
      )
    : 0;
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
          <aside
            className="circles-status"
            data-circles-status={status}
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
          <dl className="circles-stats">
            <div>
              <dt>{copy.campaigns}</dt>
              <dd>{snapshot.groups.length}</dd>
            </div>
            <div>
              <dt>{copy.chapters}</dt>
              <dd>{snapshot.chapters.length}</dd>
            </div>
            <div>
              <dt>{copy.selected}</dt>
              <dd>{selected?.name ?? "—"}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="circles-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="circles-content" aria-busy={isBusy}>
          {selected ? (
            <article className="circles-featured">
              <span className="circles-featured-mark" aria-hidden="true">
                <CircleDollarSign />
              </span>
              <div>
                <p className="circles-eyebrow">{copy.selectedCampaign}</p>
                <h2>{selected.name}</h2>
                <p>{selected.description}</p>
                <dl className="circles-featured-stats">
                  <div>
                    <dt>{copy.raised}</dt>
                    <dd>
                      {formatAmount(
                        selected.currentTotal,
                        selected.currency,
                        locale,
                      )}
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.goal}</dt>
                    <dd>
                      {formatAmount(
                        selected.targetAmount,
                        selected.currency,
                        locale,
                      )}
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.backers}</dt>
                    <dd>{selected.memberCount.toLocaleString()}</dd>
                  </div>
                </dl>
                <div className="circles-progress">
                  <span>
                    <b>{copy.progress}</b>
                    <strong>{Math.round(progress)}%</strong>
                  </span>
                  <div
                    role="progressbar"
                    aria-label={`${selected.name} ${copy.progress}`}
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-valuenow={Math.round(progress)}
                  >
                    <i style={{ width: `${progress}%` }} />
                  </div>
                </div>
                <Link
                  href={fanAppHref}
                  className="circles-action circles-action-primary"
                >
                  {hasExternalAppUrl ? copy.openApp : copy.appPending}
                  <ArrowRight aria-hidden="true" />
                </Link>
              </div>
            </article>
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
              <CircleDollarSign aria-hidden="true" />
              <h2>{copy.noCampaigns}</h2>
              <p>{copy.noCampaignsDetail}</p>
            </div>
          )}

          {snapshot.groups.length > 0 ? (
            <section className="circles-campaigns">
              <header>
                <div>
                  <p className="circles-eyebrow">{copy.campaigns}</p>
                  <h2>{copy.publicCampaigns}</h2>
                </div>
                <p>{copy.campaignsDetail}</p>
              </header>
              <div className="circles-grid">
                {snapshot.groups.map((group) => (
                  <button
                    type="button"
                    key={group.id}
                    className="circles-card"
                    aria-pressed={group.id === selected?.id}
                    onClick={() => {
                      setSelectedId(group.id);
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
                    <span className="circles-card-icon" aria-hidden="true">
                      <CircleDollarSign />
                    </span>
                    <span>
                      <strong>{group.name}</strong>
                      <small>
                        {formatAmount(
                          group.currentTotal,
                          group.currency,
                          locale,
                        )}
                        {" · "}
                        {group.memberCount.toLocaleString()} {copy.backers}
                      </small>
                    </span>
                    <ArrowRight aria-hidden="true" />
                  </button>
                ))}
              </div>
            </section>
          ) : null}

          <section className="circles-chapters">
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
                  <li key={chapter.id}>
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
          </section>
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
