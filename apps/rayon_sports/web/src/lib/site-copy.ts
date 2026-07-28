import type { ClubProfile } from "@/lib/types";

type ClubCopyContext = Pick<
  ClubProfile,
  "shortName" | "clubName" | "nickname" | "league"
>;

function clubDisplay(club: ClubCopyContext) {
  return club.nickname || club.shortName;
}

const translations = {
  en: {
    officialWebsite: "Official website",
    officialClubWebsite: "Official club website",
    search: "Search",
    fanApp: "Fan app",
    openFanApp: "Open fan app",
    buyTickets: "Buy tickets",
    supportGroups: "Support Groups",
    home: "Home",
    tickets: "Tickets",
    membership: "Membership",
    next: "Next",
    details: "Details",
    followLive: "Follow live",
    common: {
      languages: "Languages",
      channels: "Channels",
      club: "Club",
      Groups: "Groups",
      members: "Members",
      raised: "Raised",
      chapters: "Chapters",
      competitions: "Competitions",
      playable: "Playable",
      preview: "Preview",
      tiers: "Tiers",
      paidPlans: "Paid plans",
      from: "From",
      moments: "Moments",
      stories: "Stories",
      categories: "Categories",
      featured: "Featured",
      onSale: "On sale",
      listed: "Listed",
      checkout: "Checkout",
      completed: "Completed",
      wins: "Wins",
      goalsFor: "Goals for",
      products: "Products",
      players: "Players",
      nationalities: "Nationalities",
      coreUnits: "Core units",
      played: "Played",
      goalDifference: "GD",
      form: "Form",
      clubsShown: "Clubs shown",
      points: "Points",
      league: "League",
      identity: "Identity",
      surface: "Surface",
      mobile: "Mobile",
      web: "Web",
      current: "Current",
      target: "Target",
      invite: "Invite",
      position: "Position",
      global: "Global",
      searchPlaceholder: "Search fixtures, news, Groups, or shop",
      searchIntro:
        "Fixtures, matchday details, supporter products, membership tiers, and club news.",
      findItFast: "Find it fast.",
      noResults: "No results",
      trySearchHint: "Try fixtures, tickets, membership, Groups, or shop.",
      matchdaySchedule: "Matchday schedule",
      membershipStories: "Membership stories",
      featuredStory: "Featured story",
      openStory: "Open story",
      clubNewsroom: "Club newsroom",
      supporterChapters: "Supporter chapters",
      playerStories: "Player stories",
      nextFixtures: "Next fixtures",
      fixtureHub: "Fixture hub",
      recentResults: "Recent results",
      memberPerks: "Member perks",
      shopInFanApp: "Shop in fan app",
      openProduct: "Open product",
      appLinksComingSoon: "App links coming soon",
      browseTicketsFirst: "Browse tickets first",
      continueInFanApp: "Continue in fan app",
      joinInFanApp: "Join in fan app",
      activateInFanApp: "Activate in fan app",
      activateMembershipInFanApp: "Activate membership in fan app",
      unlockPriorityAccess: "Unlock priority access",
      ticketPriority: "Ticket priority",
      exploreGroups: "Explore Groups",
      fanClubs: "Fan clubs",
      seeFanClubs: "See fan clubs",
      supportAGroup: "Support a Group",
      joinFromFanApp: "Join from fan app",
      backToHomepage: "Back to homepage",
      backToFixtures: "Back to fixtures",
      buyNextTickets: "Buy next tickets",
      comparePlans: "Compare plans",
      leagueTable: "League table",
      matchdayCoverage: "Matchday coverage",
      recentScorelines: "Recent scorelines",
      upcomingMatches: "Upcoming matches",
      perYear: "/ year",
      included: "Included",
      minuteRead: "min read",
      live: "Live",
      archived: "Archived",
      planned: "Planned",
      seasonLong: "Season long",
      tournament: "Tournament",
    },
    pages: {
      Groups: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} supporter Groups`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} supporter Groups for tifos, away travel, club campaigns, and community fundraising.`,
        eyebrow: "Support Groups",
        title: "Supporter Groups and live campaigns.",
        description: (club: ClubCopyContext) =>
          `Back tifos, away travel, and club projects through official ${club.shortName} supporter Groups.`,
        whyEyebrow: "Why Groups matter",
        whyTitle: "Back the campaign together",
        bridgeEyebrow: "Community bridge",
        bridgeTitle: "Chapters that amplify every campaign",
        campaignProgress: "Campaign progress",
      },
      contact: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} contact`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} contact details, digital support routes, and club social channels.`,
        eyebrow: "Contact",
        title: "Official club contact and digital support in one place.",
        description:
          "Find official club channels, supporter help, and the right path into membership, ticketing, and fan app support.",
        membershipSupport: "Membership support",
        contactCardTitle: "Club contact",
        digitalSupport: "Digital support",
        digitalSupportDescription:
          "Use the fan app for profile, membership, shop, and ticketing requests. Public club updates and campaign announcements remain on the public site.",
        socialChannels: "Social channels",
      },
      fanClubs: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} fan clubs`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} fan clubs, supporter chapters, and community activity across the local community and diaspora.`,
        eyebrow: "Community",
        title: "Supporter chapters across the club footprint.",
        description: (club: ClubCopyContext) =>
          `Discover official fan clubs, chapter activity, and the supporter network behind every ${club.shortName} matchday.`,
        activeSupportGroups: "Active support Groups",
        rating: "rating",
        events: "events",
      },
      fixtures: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} fixtures`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} fixture list with live matches, upcoming kickoffs, ticket links, and recent results.`,
        eyebrow: "Fixtures",
        title: "Live, next, and recent fixtures.",
        description: (club: ClubCopyContext) =>
          `Track the current ${club.shortName} match, see the next kickoff, and move straight into ticketing when a fixture is on sale.`,
        liveNowTitle: "Matchday at full speed",
        upcomingTitle: "Ticket-ready fixtures",
      },
      history: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} history`,
        metaDescription: (club: ClubCopyContext) =>
          `The story of ${club.shortName}, club identity, supporter culture, and the history behind ${club.clubName}.`,
        eyebrow: "History",
        title: (club: ClubCopyContext) => `The story of ${clubDisplay(club)}.`,
        description: (club: ClubCopyContext) =>
          `Club identity, supporter culture, and the history that gives ${club.shortName} its voice.`,
        clubIdentity: "Club identity",
        historyAcrossClub: "History across the club",
        chapter: "Chapter",
        surfaceValue: "Club-first",
        seeMembershipIdentity: "See membership identity",
        identityParagraph:
          "History belongs across matchday, membership, supporter campaigns, and club storytelling. This page holds the source material for that wider voice.",
      },
      membership: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} membership`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} membership tiers with pricing, benefits, ticket priority, and supporter status across website and fan app.`,
        eyebrow: "Membership",
        title: "Membership built for matchday.",
        description: (club: ClubCopyContext) =>
          `Compare every ${club.shortName} membership tier, see the benefits clearly, and activate in the supporter app.`,
        membershipBenefits: "Membership benefits",
        whatEveryTierCovers: "What every tier covers",
        whyItMatters: "Why it matters",
        oneSupporterIdentity: "One supporter identity",
        identityPoints: [
          "Membership keeps login, supporter status, and club access consistent across the website and the fan app.",
          "Ticket priority is the clearest reason to move up a tier.",
        ],
      },
      news: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} news`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} news, matchday updates, supporter features, and club announcements.`,
        eyebrow: "Newsroom",
        title: "Club news, matchday, and supporter stories.",
        description: (club: ClubCopyContext) =>
          `Latest updates from ${club.shortName}, with direct paths into fixtures, tickets, membership, and supporter campaigns.`,
        newsroomStandards: "Newsroom standards",
        newsroomStandardsTitle: "Every story earns the click",
        latestStories: "Latest stories",
        acrossTheClub: "Across the club",
        standardsPoints: [
          "Every card carries a real excerpt for search and sharing.",
          "Matchday, supporter culture, and club updates lead the coverage.",
          "Stories connect cleanly to fixtures, tickets, membership, and shop drops.",
        ],
      },
      privacy: {
        metaTitle: "Privacy policy",
        metaDescription: (club: ClubCopyContext) =>
          `How ${club.shortName} handles supporter data across the public website and fan app.`,
        eyebrow: "Privacy",
        fallbackTitle: "Supporter data with clear boundaries.",
        fallbackBody:
          "The club website and fan app process the minimum account, membership, ticket, shop, contribution, prediction, check-in, and support-circle data needed to provide the features a supporter chooses to use. Private contacts, payment records, authentication data, and public profile data are separated and access-controlled.\n\nOptional notifications require permission. App attestation and security identifiers may be processed to prevent abuse. Analytics, crash, and performance collection remain disabled unless the release configuration and applicable consent allow them. We do not sell personal data. Service providers such as Supabase and configured Firebase services process data only to operate and protect the platform.\n\nSupporters can access or correct profile information and request account deletion in Settings. Transaction, fraud-prevention, security, and audit records may be retained where law or legitimate operational obligations require it, then access-restricted and deleted under the approved schedule. Questions or rights requests can be sent to support@ikanisa.com. Last updated 18 July 2026.",
      },
      results: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} results`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} results with recent scorelines, match context, and links into the next fixture.`,
        eyebrow: "Results",
        title: "Recent results and match momentum.",
        description: (club: ClubCopyContext) =>
          `See final scores, match summaries, and the direct route into the next ${club.shortName} fixture.`,
        recentForm: "Recent form",
        resultsWithContext: "Results with context",
        contextPoints: [
          "Final score, venue, and competition stay visible at a glance.",
          "Key moments stay attached to the match instead of disappearing into a feed.",
          "Every completed fixture points toward the next action.",
        ],
      },
      searchPage: {
        metaTitle: "Search",
        metaDescription:
          "Search fixtures, tickets, membership, Groups, shop, and club news.",
      },
      shop: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} shop`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} merch, jerseys, travel wear, scarves, and supporter essentials.`,
        eyebrow: "Club shop",
        title: "Official merch and matchday essentials.",
        description: (club: ClubCopyContext) =>
          `Browse the latest ${club.shortName} drop, check sizes and pricing, and continue secure checkout in the fan app.`,
        featuredDrop: "Featured drop",
        shopStandards: "Shop standards",
        clearBeforeCheckout: "Clear before checkout",
        unlockMemberDiscounts: "Unlock member discounts",
        standardsPoints: [
          "Product imagery and collection context lead every launch.",
          "Sizes and prices are visible before the supporter leaves the public site.",
          "The fan app handles checkout while the public shop handles discovery.",
        ],
      },
      squad: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} squad`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} squad list with player numbers, roles, and nationalities.`,
        eyebrow: "Squad",
        title: "Squad, numbers, and roles.",
        description: (club: ClubCopyContext) =>
          `Meet the ${club.shortName} squad with player numbers, positions, and the shape of the group behind every matchday.`,
        unitView: "Unit view",
        tacticalShape: "Tactical shape at a glance",
        goalkeepers: "Goalkeepers",
        defenders: "Defenders",
        midfielders: "Midfielders",
        attackers: "Attackers",
        rosterNote:
          "This roster becomes even stronger with photography, player stats, and direct links into matchday and editorial coverage.",
      },
      standings: {
        metaTitle: (club: ClubCopyContext) => `${club.league} standings`,
        metaDescription: (club: ClubCopyContext) =>
          `Official league table with ${club.shortName} position, points, goal difference, and recent form.`,
        eyebrow: "League table",
        title: "League table and form.",
        description: (club: ClubCopyContext) =>
          `Track ${club.shortName} in the table with full context around the clubs above and below.`,
        clubPosition: (club: ClubCopyContext) => `${club.shortName} position`,
        positionInRace: "Position in the race",
        highlightedClub: "Highlighted club",
        summaryPoints: [
          "The full table keeps the race readable.",
          "The club stays highlighted in every standings view.",
          "Recent form shows momentum without sending the supporter elsewhere.",
        ],
      },
      supporters: {
        metaTitle: "Supporter app",
        metaDescription:
          "Continue membership, ticketing, shop, and supporter actions in the mobile app.",
        eyebrow: "Fan app",
        title: "The supporter journey continues on mobile.",
        description:
          "The website now handles discovery and club storytelling. Membership activation, secure checkout, and authenticated supporter actions continue in the mobile app.",
        supporterIdentity: "Supporter identity",
        secureActions: "Secure actions",
        rolloutReady: "Rollout ready",
        rolloutReadyConfigured:
          "Your club-specific app destination is configured for this environment.",
        rolloutReadyPending:
          "Configure NEXT_PUBLIC_FAN_APP_URL when store, deep-link, or landing destinations are ready.",
        liveFetCatalog: "Live FET catalog",
        adminManagedRewards: "Admin-managed fan engagement rewards",
        supporterLeaderboard: "Supporter leaderboard",
        currentFetRanking: "Current FET ranking",
        noCatalog: "The live FET catalog is not available yet for this club scope.",
        noLeaderboard: "No public supporter ranking is available yet.",
        activeRewards: "Active rewards",
        topReward: "Top reward",
        trigger: "Trigger",
        timing: "Timing",
        identityBody:
          "Sign in once and keep club membership, profile, and supporter status together on the native mobile surface.",
        secureActionsBody:
          "Ticket purchases, community contributions, and protected fan activity now stay inside the mobile app.",
        catalogIntro:
          "The supporter app now reads the same canonical Fan Engagement Token catalog the admin panel manages. The website exposes the live rewards program and the current supporter leaderboard while authenticated earning flows continue in mobile.",
        leaderboardIntro:
          "Rankings come from the same live fan membership points used by the mobile app. The website exposes the public board while personal progress, earning, and secure supporter actions continue on mobile.",
      },
      terms: {
        metaTitle: "Terms and conditions",
        metaDescription: (club: ClubCopyContext) =>
          `Terms for tickets, memberships, shop orders, and supporter activity across the ${club.shortName} website and fan app.`,
        eyebrow: "Terms",
        fallbackTitle: "One supporter platform across web and mobile.",
        fallbackBody:
          "Ticketing, shop orders, memberships, and contribution records created through the website are part of the same supporter platform used by the mobile app. Availability, pricing, and supporter eligibility remain subject to club policy and live operational status.",
      },
      tickets: {
        metaTitle: (club: ClubCopyContext) => `${club.shortName} tickets`,
        metaDescription: (club: ClubCopyContext) =>
          `Official ${club.shortName} ticket hub with fixture detail, live pricing, and secure checkout continuation in the fan app.`,
        eyebrow: "Ticketing",
        title: "Tickets and matchday access.",
        description: (club: ClubCopyContext) =>
          `See venue, kickoff, pricing, and availability before moving into secure checkout in the ${club.shortName} fan app.`,
        checkoutFanApp: "Fan app",
        matchdayEssentials: "Matchday essentials",
        buyWithConfidence: "Buy with confidence",
        confidencePoints: [
          "Pricing stays visible before sign-in.",
          "Venue, competition, and kickoff stay attached to every fixture.",
          "Membership priority is visible before checkout opens.",
        ],
      },
    },
  },
  fr: {
    officialWebsite: "Site officiel",
    officialClubWebsite: "Site officiel du club",
    search: "Recherche",
    fanApp: "App supporters",
    openFanApp: "Ouvrir l'app",
    buyTickets: "Billetterie",
    supportGroups: "Cercles de soutien",
    home: "Accueil",
    tickets: "Billets",
    membership: "Adhésion",
    next: "Prochain",
    details: "Détails",
    followLive: "Suivre le direct",
    common: {
      languages: "Langues",
      channels: "Canaux",
      club: "Club",
      Groups: "Cercles",
      members: "Membres",
      raised: "Collecté",
      chapters: "Chapitres",
      competitions: "Compétitions",
      playable: "Jouable",
      preview: "Aperçu",
      tiers: "Paliers",
      paidPlans: "Formules payantes",
      from: "Dès",
      moments: "Moments",
      stories: "Articles",
      categories: "Catégories",
      featured: "À la une",
      onSale: "En vente",
      listed: "Listés",
      checkout: "Paiement",
      completed: "Terminés",
      wins: "Victoires",
      goalsFor: "Buts marqués",
      products: "Produits",
      players: "Joueurs",
      nationalities: "Nationalités",
      coreUnits: "Unités",
      played: "Joués",
      goalDifference: "Diff",
      form: "Forme",
      clubsShown: "Clubs affichés",
      points: "Points",
      league: "Ligue",
      identity: "Identité",
      surface: "Surface",
      mobile: "Mobile",
      web: "Web",
      current: "Actuel",
      target: "Objectif",
      invite: "Invitation",
      position: "Position",
      global: "Global",
      searchPlaceholder: "Chercher un match, une actu, un cercle ou la boutique",
      searchIntro:
        "Matchs, infos de match, produits supporters, adhésions et actualités du club.",
      findItFast: "Trouvez vite.",
      noResults: "Aucun résultat",
      trySearchHint: "Essayez matchs, billets, adhésion, cercles ou boutique.",
      matchdaySchedule: "Calendrier de match",
      membershipStories: "Articles adhésion",
      featuredStory: "Article à la une",
      openStory: "Ouvrir l'article",
      clubNewsroom: "Rédaction du club",
      supporterChapters: "Chapitres supporters",
      playerStories: "Histoires de joueurs",
      nextFixtures: "Prochains matchs",
      fixtureHub: "Centre des matchs",
      recentResults: "Résultats récents",
      memberPerks: "Avantages membres",
      shopInFanApp: "Boutique dans l'app",
      openProduct: "Ouvrir le produit",
      appLinksComingSoon: "Liens de l'app bientôt disponibles",
      browseTicketsFirst: "Voir les billets d'abord",
      continueInFanApp: "Continuer dans l'app",
      joinInFanApp: "Rejoindre dans l'app",
      activateInFanApp: "Activer dans l'app",
      activateMembershipInFanApp: "Activer l'adhésion dans l'app",
      unlockPriorityAccess: "Débloquer l'accès prioritaire",
      ticketPriority: "Priorité billetterie",
      exploreGroups: "Explorer les cercles",
      fanClubs: "Clubs de supporters",
      seeFanClubs: "Voir les clubs",
      supportAGroup: "Soutenir un cercle",
      joinFromFanApp: "Rejoindre depuis l'app",
      backToHomepage: "Retour à l'accueil",
      backToFixtures: "Retour aux matchs",
      buyNextTickets: "Acheter les prochains billets",
      comparePlans: "Comparer les offres",
      leagueTable: "Classement",
      matchdayCoverage: "Couverture matchday",
      recentScorelines: "Scores récents",
      upcomingMatches: "Matchs à venir",
      perYear: "/ an",
      included: "Inclus",
      minuteRead: "min de lecture",
      live: "Direct",
      archived: "Archivé",
      planned: "Planifié",
      seasonLong: "Saison complète",
      tournament: "Tournoi",
    },
    pages: {
      Groups: {
        metaTitle: (club: ClubCopyContext) => `Cercles de soutien ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Cercles officiels de ${club.shortName} pour tifos, déplacements et campagnes du club.`,
        eyebrow: "Cercles de soutien",
        title: "Cercles supporters et campagnes en direct.",
        description: (club: ClubCopyContext) =>
          `Soutenez les tifos, les déplacements et les projets du club via les cercles officiels de ${club.shortName}.`,
        whyEyebrow: "Pourquoi les cercles comptent",
        whyTitle: "Porter la campagne ensemble",
        bridgeEyebrow: "Pont communautaire",
        bridgeTitle: "Des chapitres qui amplifient chaque campagne",
        campaignProgress: "Progression de campagne",
      },
      contact: {
        metaTitle: (club: ClubCopyContext) => `Contact ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Coordonnées officielles de ${club.shortName}, support digital et canaux sociaux.`,
        eyebrow: "Contact",
        title: "Contact officiel du club et support digital au même endroit.",
        description:
          "Retrouvez les canaux officiels du club, l'aide supporters et le bon point d'entrée vers l'adhésion, la billetterie et l'app.",
        membershipSupport: "Support adhésion",
        contactCardTitle: "Contact du club",
        digitalSupport: "Support digital",
        digitalSupportDescription:
          "Utilisez l'app pour le profil, l'adhésion, la boutique et la billetterie. Les annonces publiques restent sur le site.",
        socialChannels: "Canaux sociaux",
      },
      fanClubs: {
        metaTitle: (club: ClubCopyContext) => `Clubs de supporters ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Clubs de supporters officiels de ${club.shortName} et activité communautaire locale et diaspora.`,
        eyebrow: "Communauté",
        title: "Des chapitres supporters à travers l'écosystème du club.",
        description: (club: ClubCopyContext) =>
          `Découvrez les fan clubs officiels, l'activité des chapitres et le réseau qui porte chaque match de ${club.shortName}.`,
        activeSupportGroups: "Cercles de soutien actifs",
        rating: "note",
        events: "événements",
      },
      fixtures: {
        metaTitle: (club: ClubCopyContext) => `Matchs ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Liste officielle des matchs de ${club.shortName} avec directs, prochains coups d'envoi et billetterie.`,
        eyebrow: "Matchs",
        title: "En direct, à venir et récents.",
        description: (club: ClubCopyContext) =>
          `Suivez le match actuel de ${club.shortName}, voyez le prochain coup d'envoi et passez à la billetterie quand un match est en vente.`,
        liveNowTitle: "Le matchday à plein régime",
        upcomingTitle: "Matchs prêts pour la billetterie",
      },
      history: {
        metaTitle: (club: ClubCopyContext) => `Histoire de ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `L'histoire de ${club.shortName}, l'identité du club et la culture supporters derrière ${club.clubName}.`,
        eyebrow: "Histoire",
        title: (club: ClubCopyContext) => `L'histoire de ${clubDisplay(club)}.`,
        description: (club: ClubCopyContext) =>
          `Identité du club, culture supporters et histoire qui donnent sa voix à ${club.shortName}.`,
        clubIdentity: "Identité du club",
        historyAcrossClub: "L'histoire dans tout le club",
        chapter: "Chapitre",
        surfaceValue: "Club d'abord",
        seeMembershipIdentity: "Voir l'identité d'adhésion",
        identityParagraph:
          "L'histoire doit vivre dans le matchday, l'adhésion, les campagnes supporters et le récit du club. Cette page en garde la matière première.",
      },
      membership: {
        metaTitle: (club: ClubCopyContext) => `Adhésion ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Paliers d'adhésion officiels de ${club.shortName} avec prix, avantages et priorité billetterie.`,
        eyebrow: "Adhésion",
        title: "Une adhésion pensée pour le matchday.",
        description: (club: ClubCopyContext) =>
          `Comparez chaque palier d'adhésion ${club.shortName}, voyez clairement les avantages et activez dans l'app.`,
        membershipBenefits: "Avantages d'adhésion",
        whatEveryTierCovers: "Ce que couvre chaque palier",
        whyItMatters: "Pourquoi c'est important",
        oneSupporterIdentity: "Une seule identité supporter",
        identityPoints: [
          "L'adhésion garde la connexion, le statut supporter et l'accès club cohérents entre le site et l'app.",
          "La priorité billetterie reste la raison la plus claire de monter de palier.",
        ],
      },
      news: {
        metaTitle: (club: ClubCopyContext) => `Actualités ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Actualités officielles de ${club.shortName}, infos matchday et annonces du club.`,
        eyebrow: "Rédaction",
        title: "Actualités du club, matchday et récits supporters.",
        description: (club: ClubCopyContext) =>
          `Dernières mises à jour de ${club.shortName}, avec des accès directs vers matchs, billets, adhésion et campagnes.`,
        newsroomStandards: "Standards éditoriaux",
        newsroomStandardsTitle: "Chaque article mérite le clic",
        latestStories: "Derniers articles",
        acrossTheClub: "Dans tout le club",
        standardsPoints: [
          "Chaque carte porte un vrai extrait utile pour la recherche et le partage.",
          "Le matchday, la culture supporters et les infos club mènent la couverture.",
          "Les articles relient proprement matchs, billets, adhésion et nouveautés boutique.",
        ],
      },
      privacy: {
        metaTitle: "Politique de confidentialité",
        metaDescription: (club: ClubCopyContext) =>
          `Comment ${club.shortName} gère les données supporters sur le site public et l'app.`,
        eyebrow: "Confidentialité",
        fallbackTitle: "Des données supporters avec des limites claires.",
        fallbackBody:
          "L'expérience web du club ne stocke que les données strictement nécessaires pour faire fonctionner le site et l'app: adhésion, billets, boutique et cercles de soutien. Les données de paiement sensibles et les coordonnées privées restent séparées du profil public.",
      },
      results: {
        metaTitle: (club: ClubCopyContext) => `Résultats ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Résultats officiels de ${club.shortName} avec scores récents, contexte du match et lien vers le prochain.`,
        eyebrow: "Résultats",
        title: "Résultats récents et dynamique du match.",
        description: (club: ClubCopyContext) =>
          `Voyez les scores finaux, les résumés et l'accès direct vers le prochain match de ${club.shortName}.`,
        recentForm: "Forme récente",
        resultsWithContext: "Des résultats avec contexte",
        contextPoints: [
          "Le score final, le stade et la compétition restent lisibles d'un coup d'œil.",
          "Les moments clés restent attachés au match au lieu de disparaître dans un flux.",
          "Chaque rencontre terminée pointe vers la prochaine action utile.",
        ],
      },
      searchPage: {
        metaTitle: "Recherche",
        metaDescription:
          "Cherchez des matchs, billets, adhésions, cercles, boutique et actualités du club.",
      },
      shop: {
        metaTitle: (club: ClubCopyContext) => `Boutique ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Merch officiel ${club.shortName}, maillots, tenues de voyage et essentiels supporters.`,
        eyebrow: "Boutique du club",
        title: "Merch officiel et essentiels de matchday.",
        description: (club: ClubCopyContext) =>
          `Parcourez la dernière collection ${club.shortName}, vérifiez tailles et prix, puis continuez le paiement dans l'app.`,
        featuredDrop: "Collection à la une",
        shopStandards: "Standards boutique",
        clearBeforeCheckout: "Tout est clair avant le paiement",
        unlockMemberDiscounts: "Débloquer les remises membres",
        standardsPoints: [
          "L'imagerie produit et le contexte de collection ouvrent chaque lancement.",
          "Les tailles et les prix restent visibles avant que le supporter quitte le site.",
          "L'app gère le paiement pendant que la boutique publique gère la découverte.",
        ],
      },
      squad: {
        metaTitle: (club: ClubCopyContext) => `Effectif ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Effectif officiel ${club.shortName} avec numéros, rôles et nationalités.`,
        eyebrow: "Effectif",
        title: "Effectif, numéros et rôles.",
        description: (club: ClubCopyContext) =>
          `Découvrez l'effectif ${club.shortName}, les numéros, les postes et l'ossature du groupe derrière chaque matchday.`,
        unitView: "Vue par unité",
        tacticalShape: "Lecture tactique en un coup d'œil",
        goalkeepers: "Gardiens",
        defenders: "Défenseurs",
        midfielders: "Milieux",
        attackers: "Attaquants",
        rosterNote:
          "Cet effectif devient encore plus fort avec des photos, des stats joueurs et des liens directs vers le matchday et l'éditorial.",
      },
      standings: {
        metaTitle: (club: ClubCopyContext) => `Classement ${club.league}`,
        metaDescription: (club: ClubCopyContext) =>
          `Classement officiel avec position de ${club.shortName}, points, différence de buts et forme récente.`,
        eyebrow: "Classement",
        title: "Classement et forme.",
        description: (club: ClubCopyContext) =>
          `Suivez ${club.shortName} dans le tableau avec le contexte complet autour des clubs au-dessus et au-dessous.`,
        clubPosition: (club: ClubCopyContext) => `Position de ${club.shortName}`,
        positionInRace: "Position dans la course",
        highlightedClub: "Club mis en avant",
        summaryPoints: [
          "Le tableau complet garde la course lisible.",
          "Le club reste mis en avant dans chaque vue du classement.",
          "La forme récente montre la dynamique sans envoyer le supporter ailleurs.",
        ],
      },
      supporters: {
        metaTitle: "App supporters",
        metaDescription:
          "Poursuivez l'adhésion, la billetterie, la boutique et les actions supporters dans l'app mobile.",
        eyebrow: "App supporters",
        title: "Le parcours supporter continue sur mobile.",
        description:
          "Le site gère désormais la découverte et le récit du club. L'activation d'adhésion, le paiement sécurisé et les actions authentifiées continuent dans l'app mobile.",
        supporterIdentity: "Identité supporter",
        secureActions: "Actions sécurisées",
        rolloutReady: "Prêt au déploiement",
        rolloutReadyConfigured:
          "La destination d'app spécifique au club est configurée pour cet environnement.",
        rolloutReadyPending:
          "Configurez NEXT_PUBLIC_FAN_APP_URL quand les destinations store ou deep-link sont prêtes.",
        liveFetCatalog: "Catalogue FET en direct",
        adminManagedRewards: "Récompenses FET gérées par l'admin",
        supporterLeaderboard: "Classement supporters",
        currentFetRanking: "Classement FET actuel",
        noCatalog: "Le catalogue FET en direct n'est pas encore disponible pour ce club.",
        noLeaderboard: "Aucun classement public n'est encore disponible.",
        activeRewards: "Récompenses actives",
        topReward: "Meilleure récompense",
        trigger: "Déclencheur",
        timing: "Moment",
        identityBody:
          "Connectez-vous une fois et gardez l'adhésion, le profil et le statut supporter ensemble sur la surface mobile native.",
        secureActionsBody:
          "Achats de billets, contributions communautaires et actions protégées restent désormais dans l'app mobile.",
        catalogIntro:
          "L'app supporters lit désormais le même catalogue canonique de Fan Engagement Token que gère l'admin. Le site expose le programme de récompenses en direct et le classement actuel pendant que les actions authentifiées restent sur mobile.",
        leaderboardIntro:
          "Les classements utilisent les mêmes points membres en direct que l'app mobile. Le site expose le tableau public pendant que la progression personnelle et les actions sécurisées restent sur mobile.",
      },
      terms: {
        metaTitle: "Conditions générales",
        metaDescription: (club: ClubCopyContext) =>
          `Conditions pour billets, adhésions, commandes boutique et activité supporters sur le site ${club.shortName} et l'app.`,
        eyebrow: "Conditions",
        fallbackTitle: "Une seule plateforme supporter entre web et mobile.",
        fallbackBody:
          "Les billets, commandes boutique, adhésions et contributions créés via le site font partie de la même plateforme supporter que l'app mobile. La disponibilité, les prix et l'éligibilité restent soumis à la politique du club et au statut opérationnel en direct.",
      },
      tickets: {
        metaTitle: (club: ClubCopyContext) => `Billets ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Hub billetterie officiel ${club.shortName} avec détail des matchs, prix et poursuite du paiement dans l'app.`,
        eyebrow: "Billetterie",
        title: "Billets et accès matchday.",
        description: (club: ClubCopyContext) =>
          `Voyez le stade, l'horaire, les tarifs et la disponibilité avant de continuer le paiement sécurisé dans l'app ${club.shortName}.`,
        checkoutFanApp: "App supporters",
        matchdayEssentials: "Essentiels de matchday",
        buyWithConfidence: "Acheter en confiance",
        confidencePoints: [
          "Les prix restent visibles avant la connexion.",
          "Le stade, la compétition et l'horaire restent attachés à chaque match.",
          "La priorité membre reste visible avant l'ouverture du paiement.",
        ],
      },
    },
  },
  rw: {
    officialWebsite: "Urubuga rwemewe",
    officialClubWebsite: "Urubuga rwemewe rw'ikipe",
    search: "Shakisha",
    fanApp: "App y'abafana",
    openFanApp: "Fungura app",
    buyTickets: "Gura itike",
    supportGroups: "Amatsinda y'inkunga",
    home: "Ahabanza",
    tickets: "Itike",
    membership: "Ubunyamuryango",
    next: "Ibikurikiyeho",
    details: "Birambuye",
    followLive: "Kurikirana live",
    common: {
      languages: "Indimi",
      channels: "Imiyoboro",
      club: "Ikipe",
      Groups: "Amatsinda",
      members: "Abanyamuryango",
      raised: "Byakusanyijwe",
      chapters: "Amashami",
      competitions: "Amarushanwa",
      playable: "Birakinwa",
      preview: "Ibanza",
      tiers: "Inzego",
      paidPlans: "Gahunda zishyurwa",
      from: "Guhera",
      moments: "Ibihe",
      stories: "Inkuru",
      categories: "Ibyiciro",
      featured: "Byatoranyijwe",
      onSale: "Biragurishwa",
      listed: "Byashyizweho",
      checkout: "Kwishyura",
      completed: "Byarangiye",
      wins: "Intsinzi",
      goalsFor: "Ibitego byatsinzwe",
      products: "Ibicuruzwa",
      players: "Abakinnyi",
      nationalities: "Ubwenegihugu",
      coreUnits: "Amatsinda akomeye",
      played: "Yakinnye",
      goalDifference: "Ikinyuranyo",
      form: "Imiterere",
      clubsShown: "Amakipe yagaragajwe",
      points: "Amanota",
      league: "Shampiyona",
      identity: "Indangamuntu",
      surface: "Urubuga",
      mobile: "Mobile",
      web: "Web",
      current: "Ubu",
      target: "Intego",
      invite: "Invitation",
      position: "Umwanya",
      global: "Rusange",
      searchPlaceholder: "Shakisha umukino, inkuru, itsinda cyangwa shop",
      searchIntro:
        "Imikino, amakuru ya matchday, ibicuruzwa by'abafana, ubunyamuryango n'inkuru z'ikipe.",
      findItFast: "Bibone vuba.",
      noResults: "Nta bisubizo",
      trySearchHint: "Gerageza imikino, itike, ubunyamuryango, amatsinda cyangwa shop.",
      matchdaySchedule: "Ingengabihe y'imikino",
      membershipStories: "Inkuru z'ubunyamuryango",
      featuredStory: "Inkuru yatoranyijwe",
      openStory: "Fungura inkuru",
      clubNewsroom: "Ikinyamakuru cy'ikipe",
      supporterChapters: "Amashami y'abafana",
      playerStories: "Inkuru z'abakinnyi",
      nextFixtures: "Imikino ikurikira",
      fixtureHub: "Ihuriro ry'imikino",
      recentResults: "Ibyavuye mu mikino iheruka",
      memberPerks: "Inyungu z'abanyamuryango",
      shopInFanApp: "Gura muri app",
      openProduct: "Fungura igicuruzwa",
      appLinksComingSoon: "Amahuza ya app ari hafi",
      browseTicketsFirst: "Banza urebe itike",
      continueInFanApp: "Komeza muri app",
      joinInFanApp: "Injiramo muri app",
      activateInFanApp: "Bikoreshe muri app",
      activateMembershipInFanApp: "Koresha ubunyamuryango muri app",
      unlockPriorityAccess: "Fungura uburyo bw'ibanze",
      ticketPriority: "Icyihutirwa ku itike",
      exploreGroups: "Sura amatsinda",
      fanClubs: "Clubs z'abafana",
      seeFanClubs: "Reba clubs z'abafana",
      supportAGroup: "Tera inkunga itsinda",
      joinFromFanApp: "Injiramo ukoresheje app",
      backToHomepage: "Subira ahabanza",
      backToFixtures: "Subira ku mikino",
      buyNextTickets: "Gura itike ikurikira",
      comparePlans: "Geranya gahunda",
      leagueTable: "Urutonde rwa shampiyona",
      matchdayCoverage: "Amakuru ya matchday",
      recentScorelines: "Amanota aheruka",
      upcomingMatches: "Imikino iri imbere",
      perYear: "/ umwaka",
      included: "Birimo",
      minuteRead: "iminota yo gusoma",
      live: "Live",
      archived: "Byabitswe",
      planned: "Byateguwe",
      seasonLong: "Igihembwe cyose",
      tournament: "Irushanwa",
    },
    pages: {
      Groups: {
        metaTitle: (club: ClubCopyContext) => `Amatsinda y'inkunga ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Amatsinda y'inkunga yemewe ya ${club.shortName} yo gufasha tifos, ingendo n'ibikorwa by'ikipe.`,
        eyebrow: "Amatsinda y'inkunga",
        title: "Amatsinda y'abafana n'ibikorwa biri live.",
        description: (club: ClubCopyContext) =>
          `Tera inkunga tifos, ingendo n'imishinga y'ikipe ukoresheje amatsinda yemewe ya ${club.shortName}.`,
        whyEyebrow: "Impamvu amatsinda ari ingenzi",
        whyTitle: "Dushyigikire igikorwa hamwe",
        bridgeEyebrow: "Ihuriro ry'umuryango",
        bridgeTitle: "Amashami ashyigikira buri gikorwa",
        campaignProgress: "Uko igikorwa gihagaze",
      },
      contact: {
        metaTitle: (club: ClubCopyContext) => `Uko wabona ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Aho wavugana na ${club.shortName}, ubufasha bwa digital n'imbuga nkoranyambaga.`,
        eyebrow: "Twandikire",
        title: "Aho wavugana n'ikipe n'ubufasha bwa digital hamwe.",
        description:
          "Shaka imiyoboro yemewe y'ikipe, ubufasha ku bafana n'inzira iboneye ijya ku bunyamuryango, itike na app.",
        membershipSupport: "Ubufasha ku bunyamuryango",
        contactCardTitle: "Uko wabona ikipe",
        digitalSupport: "Ubufasha bwa digital",
        digitalSupportDescription:
          "Koresha app ku bijyanye na profile, ubunyamuryango, shop n'itike. Amatangazo rusange aguma ku rubuga.",
        socialChannels: "Imbuga nkoranyambaga",
      },
      fanClubs: {
        metaTitle: (club: ClubCopyContext) => `Clubs z'abafana za ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Clubs z'abafana zemewe za ${club.shortName} n'ibikorwa by'umuryango imbere mu gihugu no hanze.`,
        eyebrow: "Umuryango",
        title: "Amashami y'abafana mu rugendo rwose rw'ikipe.",
        description: (club: ClubCopyContext) =>
          `Menya fan clubs zemewe, ibikorwa by'amashami n'umuyoboro w'abafana ushyigikira buri mukino wa ${club.shortName}.`,
        activeSupportGroups: "Amatsinda y'inkunga akora",
        rating: "amanota",
        events: "ibikorwa",
      },
      fixtures: {
        metaTitle: (club: ClubCopyContext) => `Imikino ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Urutonde rwemewe rw'imikino ya ${club.shortName} hamwe na live, imikino iri imbere n'itike.`,
        eyebrow: "Imikino",
        title: "Live, ikurikiyeho n'iyabaye.",
        description: (club: ClubCopyContext) =>
          `Kurikirana umukino wa ${club.shortName} uriho, reba umukino ukurikira kandi uhite ujya ku itike igihe yafunguwe.`,
        liveNowTitle: "Matchday iri ku muvuduko",
        upcomingTitle: "Imikino ifite itike",
      },
      history: {
        metaTitle: (club: ClubCopyContext) => `Amateka ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Amateka ya ${club.shortName}, umuco w'ikipe n'uw'abafana inyuma ya ${club.clubName}.`,
        eyebrow: "Amateka",
        title: (club: ClubCopyContext) => `Amateka ya ${clubDisplay(club)}.`,
        description: (club: ClubCopyContext) =>
          `Indangamuntu y'ikipe, umuco w'abafana n'amateka biha ${club.shortName} ijwi ryayo.`,
        clubIdentity: "Indangamuntu y'ikipe",
        historyAcrossClub: "Amateka mu ikipe yose",
        chapter: "Igice",
        surfaceValue: "Ikipe mbere",
        seeMembershipIdentity: "Reba indangamuntu y'ubunyamuryango",
        identityParagraph:
          "Amateka akwiye kuboneka muri matchday, ubunyamuryango, ibikorwa by'abafana n'inkuru z'ikipe. Uru rupapuro rubika inkomoko y'iyo nkuru yose.",
      },
      membership: {
        metaTitle: (club: ClubCopyContext) => `Ubunyamuryango bwa ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Inzego z'ubunyamuryango za ${club.shortName} hamwe n'ibiciro, inyungu n'icyihutirwa ku itike.`,
        eyebrow: "Ubunyamuryango",
        title: "Ubunyamuryango bwubakiwe matchday.",
        description: (club: ClubCopyContext) =>
          `Geranya inzego z'ubunyamuryango bwa ${club.shortName}, ubone neza inyungu kandi ubukoreshe muri app.`,
        membershipBenefits: "Inyungu z'ubunyamuryango",
        whatEveryTierCovers: "Icyo buri rwego gikubiyemo",
        whyItMatters: "Impamvu ari ingenzi",
        oneSupporterIdentity: "Indangamuntu imwe y'umufana",
        identityPoints: [
          "Ubunyamuryango butuma login, status y'umufana n'ukwinjira ku ikipe bihora bihuye hagati ya web na app.",
          "Icyihutirwa ku itike ni yo mpamvu igaragara yo kuzamuka urwego.",
        ],
      },
      news: {
        metaTitle: (club: ClubCopyContext) => `Amakuru ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Amakuru yemewe ya ${club.shortName}, updates za matchday n'itangazo ry'ikipe.`,
        eyebrow: "Ikinyamakuru",
        title: "Amakuru y'ikipe, matchday n'inkuru z'abafana.",
        description: (club: ClubCopyContext) =>
          `Amakuru mashya ya ${club.shortName} n'inzira zijya ku mikino, itike, ubunyamuryango n'ibikorwa by'abafana.`,
        newsroomStandards: "Imyandikire y'ikinyamakuru",
        newsroomStandardsTitle: "Buri nkuru ikwiye gukurura",
        latestStories: "Inkuru nshya",
        acrossTheClub: "Mu ikipe yose",
        standardsPoints: [
          "Buri karita ifite excerpt nyakuri ifasha gushakisha no gusangira.",
          "Matchday, umuco w'abafana n'amatangazo y'ikipe ni byo biza imbere.",
          "Inkuru zihuza neza imikino, itike, ubunyamuryango n'ibisohoka muri shop.",
        ],
      },
      privacy: {
        metaTitle: "Politiki y'ubwirinzi bw'amakuru",
        metaDescription: (club: ClubCopyContext) =>
          `Uko ${club.shortName} icunga amakuru y'abafana ku rubuga no muri app.`,
        eyebrow: "Ubwirinzi bw'amakuru",
        fallbackTitle: "Amakuru y'abafana afite imipaka isobanutse.",
        fallbackBody:
          "Urubuga rw'ikipe rubika gusa amakuru y'ibanze akenewe kugira ngo web na app bikore: ubunyamuryango, itike, shop n'amatsinda y'inkunga. Amakuru y'ubwishyu n'ay'itumanaho bwihariye atandukanijwe na profile rusange.",
      },
      results: {
        metaTitle: (club: ClubCopyContext) => `Ibyavuye mu mikino ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Ibyavuye mu mikino bya ${club.shortName} hamwe n'amanota n'umuhanda ujya ku mukino ukurikiyeho.`,
        eyebrow: "Ibyavuye mu mikino",
        title: "Ibyavuye mu mikino n'uko ikipe ihagaze.",
        description: (club: ClubCopyContext) =>
          `Reba amanota ya nyuma, ibisobanuro by'umukino n'inzira ijya ku mukino ukurikiyeho wa ${club.shortName}.`,
        recentForm: "Imiterere iheruka",
        resultsWithContext: "Ibisubizo bifite ibisobanuro",
        contextPoints: [
          "Amanota ya nyuma, stade n'irushanwa bigaragara ako kanya.",
          "Ibihe by'ingenzi biguma ku mukino aho kuburira mu feed.",
          "Buri mukino warangiye werekana igikurikiraho.",
        ],
      },
      searchPage: {
        metaTitle: "Gushakisha",
        metaDescription:
          "Shakisha imikino, itike, ubunyamuryango, amatsinda, shop n'amakuru y'ikipe.",
      },
      shop: {
        metaTitle: (club: ClubCopyContext) => `Shop ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Ibicuruzwa byemewe bya ${club.shortName}, imyambaro n'ibikoresho by'abafana.`,
        eyebrow: "Shop y'ikipe",
        title: "Ibicuruzwa byemewe n'ibya matchday.",
        description: (club: ClubCopyContext) =>
          `Sura ibicuruzwa bishya bya ${club.shortName}, urebe sizes n'ibiciro kandi ukomeze kwishyura muri app.`,
        featuredDrop: "Igicuruzwa cyatoranyijwe",
        shopStandards: "Uburyo bwa shop",
        clearBeforeCheckout: "Byumvikana mbere yo kwishyura",
        unlockMemberDiscounts: "Fungura kugabanyirizwa kw'abanyamuryango",
        standardsPoints: [
          "Amafoto y'ibicuruzwa n'imiterere ya collection biza imbere kuri buri launch.",
          "Sizes n'ibiciro bigaragara mbere y'uko umufana ava kuri web.",
          "App ni yo ikora checkout naho shop ya public igakora discovery.",
        ],
      },
      squad: {
        metaTitle: (club: ClubCopyContext) => `Abakinnyi ba ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Urutonde rw'abakinnyi ba ${club.shortName} n'imibare, inshingano n'ubwenegihugu.`,
        eyebrow: "Abakinnyi",
        title: "Abakinnyi, nimero n'inshingano.",
        description: (club: ClubCopyContext) =>
          `Menya abakinnyi ba ${club.shortName} n'inomero, positions n'imiterere y'itsinda rya matchday.`,
        unitView: "Kureba mu matsinda",
        tacticalShape: "Imiterere y'ikipe vuba",
        goalkeepers: "Abanyezamu",
        defenders: "Ba myugariro",
        midfielders: "Ba hagati",
        attackers: "Ba rutahizamu",
        rosterNote:
          "Uru rutonde ruba rwiza kurushaho iyo rwongerewe amafoto, stats z'abakinnyi n'inzira zijya kuri matchday n'inkuru z'ikipe.",
      },
      standings: {
        metaTitle: (club: ClubCopyContext) => `Urutonde rwa ${club.league}`,
        metaDescription: (club: ClubCopyContext) =>
          `Urutonde rwa shampiyona rwerekana umwanya wa ${club.shortName}, amanota n'itandukaniro ry'ibitego.`,
        eyebrow: "Urutonde rwa shampiyona",
        title: "Urutonde n'imiterere.",
        description: (club: ClubCopyContext) =>
          `Kurikirana ${club.shortName} ku rutonde hamwe n'andi makipe ari hejuru cyangwa hasi yayo.`,
        clubPosition: (club: ClubCopyContext) => `Umwanya wa ${club.shortName}`,
        positionInRace: "Umwanya mu rugamba",
        highlightedClub: "Ikipe yagaragajwe",
        summaryPoints: [
          "Urutonde rwose rutuma ihatana risomeka neza.",
          "Ikipe iguma igaragazwa muri buri view ya standings.",
          "Imiterere iheruka yerekana momentum itajyanye umufana ahandi.",
        ],
      },
      supporters: {
        metaTitle: "App y'abafana",
        metaDescription:
          "Komeza ubunyamuryango, itike, shop n'ibikorwa by'abafana muri app mobile.",
        eyebrow: "App y'abafana",
        title: "Urugendo rw'umufana rukomereza kuri mobile.",
        description:
          "Urubuga rukora discovery n'inkuru z'ikipe. Gukoresha ubunyamuryango, kwishyura neza n'ibikorwa byihariye bikomereza muri app.",
        supporterIdentity: "Indangamuntu y'umufana",
        secureActions: "Ibikorwa birinzwe",
        rolloutReady: "Byiteguye gutangizwa",
        rolloutReadyConfigured:
          "Aho app y'iyi club ijya hamaze gushyirwaho kuri environment.",
        rolloutReadyPending:
          "Shyiraho NEXT_PUBLIC_FAN_APP_URL igihe store cyangwa deep-link byiteguye.",
        liveFetCatalog: "Catalog FET iri live",
        adminManagedRewards: "Ibihembo FET bicungwa na admin",
        supporterLeaderboard: "Urutonde rw'abafana",
        currentFetRanking: "Urutonde rwa FET ubu",
        noCatalog: "Catalog FET ya live ntiraboneka kuri iyi club.",
        noLeaderboard: "Nta rutonde rusange rw'abafana ruraboneka.",
        activeRewards: "Ibihembo bikora",
        topReward: "Igihembo cyo hejuru",
        trigger: "Impamvu",
        timing: "Igihe",
        identityBody:
          "Injira rimwe gusa kandi ugumane ubunyamuryango, profile na status y'umufana kuri mobile app.",
        secureActionsBody:
          "Kugura itike, gutanga inkunga n'ibikorwa birinzwe byose bikomeza gukorerwa muri app.",
        catalogIntro:
          "App y'abafana isoma catalogue imwe ya Fan Engagement Token icungwa na admin. Web yerekana rewards za live n'urutonde rw'abafana mu gihe ibikorwa byihariye bikomeza muri mobile.",
        leaderboardIntro:
          "Urutonde ruvana ku manota nyakuri akoreshwa na mobile app. Web yerekana board rusange mu gihe progress y'umuntu ku giti cye n'ibikorwa birinzwe bikomeza muri mobile.",
      },
      terms: {
        metaTitle: "Amategeko n'amabwiriza",
        metaDescription: (club: ClubCopyContext) =>
          `Amategeko ku itike, ubunyamuryango, ibyaguzwe muri shop n'ibikorwa by'abafana kuri ${club.shortName}.`,
        eyebrow: "Amabwiriza",
        fallbackTitle: "Urubuga rumwe rw'abafana hagati ya web na mobile.",
        fallbackBody:
          "Itike, ibyo uguze muri shop, ubunyamuryango n'inkunga bikozwe kuri web ni igice cya platform imwe ikoreshwa na mobile app. Kuboneka, ibiciro n'uburenganzira bugengwa n'amategeko y'ikipe n'uko ibintu bihagaze ako kanya.",
      },
      tickets: {
        metaTitle: (club: ClubCopyContext) => `Itike za ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Ihuriro ry'itike rya ${club.shortName} hamwe n'ibiciro n'uburyo bwo gukomeza kwishyura muri app.`,
        eyebrow: "Itike",
        title: "Itike n'uburyo bwo kwinjira ku mukino.",
        description: (club: ClubCopyContext) =>
          `Reba stade, kickoff, ibiciro n'uko bihagaze mbere yo gukomeza kwishyura neza muri app ya ${club.shortName}.`,
        checkoutFanApp: "App y'abafana",
        matchdayEssentials: "Iby'ingenzi bya matchday",
        buyWithConfidence: "Gura ubifitiye icyizere",
        confidencePoints: [
          "Ibiciro bigaragara mbere yo kwinjira.",
          "Stade, irushanwa na kickoff bigumana na buri mukino.",
          "Icyihutirwa cy'abanyamuryango kigaragara mbere ya checkout.",
        ],
      },
    },
  },
  sw: {
    officialWebsite: "Tovuti rasmi",
    officialClubWebsite: "Tovuti rasmi ya klabu",
    search: "Tafuta",
    fanApp: "App ya mashabiki",
    openFanApp: "Fungua app",
    buyTickets: "Nunua tiketi",
    supportGroups: "Mizunguko ya msaada",
    home: "Nyumbani",
    tickets: "Tiketi",
    membership: "Uanachama",
    next: "Inayofuata",
    details: "Maelezo",
    followLive: "Fuata mubashara",
    common: {
      languages: "Lugha",
      channels: "Njia",
      club: "Klabu",
      Groups: "Mizunguko",
      members: "Wanachama",
      raised: "Kilichokusanywa",
      chapters: "Matawi",
      competitions: "Mashindano",
      playable: "Inaweza kuchezwa",
      preview: "Muhtasari",
      tiers: "Ngazi",
      paidPlans: "Mipango ya kulipia",
      from: "Kuanzia",
      moments: "Vipindi",
      stories: "Hadithi",
      categories: "Kategoria",
      featured: "Iliyoangaziwa",
      onSale: "Inauzwa",
      listed: "Vilivyoorodheshwa",
      checkout: "Malipo",
      completed: "Zilizokamilika",
      wins: "Ushindi",
      goalsFor: "Mabao ya kufunga",
      products: "Bidhaa",
      players: "Wachezaji",
      nationalities: "Utaifa",
      coreUnits: "Vitengo vikuu",
      played: "Imechezwa",
      goalDifference: "Tofauti",
      form: "Fomu",
      clubsShown: "Vilabu vilivyoonyeshwa",
      points: "Pointi",
      league: "Ligi",
      identity: "Utambulisho",
      surface: "Uso",
      mobile: "Simu",
      web: "Tovuti",
      current: "Sasa",
      target: "Lengo",
      invite: "Mwaliko",
      position: "Nafasi",
      global: "Dunia",
      searchPlaceholder: "Tafuta mechi, habari, mzunguko au shop",
      searchIntro:
        "Mechi, maelezo ya matchday, bidhaa za mashabiki, uanachama na habari za klabu.",
      findItFast: "Pata haraka.",
      noResults: "Hakuna matokeo",
      trySearchHint: "Jaribu mechi, tiketi, uanachama, mizunguko au shop.",
      matchdaySchedule: "Ratiba ya mechi",
      membershipStories: "Hadithi za uanachama",
      featuredStory: "Hadithi iliyoangaziwa",
      openStory: "Fungua hadithi",
      clubNewsroom: "Habari za klabu",
      supporterChapters: "Matawi ya mashabiki",
      playerStories: "Hadithi za wachezaji",
      nextFixtures: "Mechi zijazo",
      fixtureHub: "Kitovu cha mechi",
      recentResults: "Matokeo ya karibuni",
      memberPerks: "Faida za wanachama",
      shopInFanApp: "Nunua kwenye app",
      openProduct: "Fungua bidhaa",
      appLinksComingSoon: "Viungo vya app vinakuja",
      browseTicketsFirst: "Tazama tiketi kwanza",
      continueInFanApp: "Endelea kwenye app",
      joinInFanApp: "Jiunge kwenye app",
      activateInFanApp: "Washa kwenye app",
      activateMembershipInFanApp: "Washa uanachama kwenye app",
      unlockPriorityAccess: "Fungua upendeleo wa mwanzo",
      ticketPriority: "Kipaumbele cha tiketi",
      exploreGroups: "Chunguza mizunguko",
      fanClubs: "Vilabu vya mashabiki",
      seeFanClubs: "Tazama vilabu vya mashabiki",
      supportAGroup: "Saidia mzunguko",
      joinFromFanApp: "Jiunge kutoka app",
      backToHomepage: "Rudi mwanzo",
      backToFixtures: "Rudi kwenye mechi",
      buyNextTickets: "Nunua tiketi ijayo",
      comparePlans: "Linganisha mipango",
      leagueTable: "Jedwali la ligi",
      matchdayCoverage: "Habari za matchday",
      recentScorelines: "Alama za karibuni",
      upcomingMatches: "Mechi zijazo",
      perYear: "/ mwaka",
      included: "Imejumuishwa",
      minuteRead: "dakika za kusoma",
      live: "Mubashara",
      archived: "Imehifadhiwa",
      planned: "Imepangwa",
      seasonLong: "Msimu mzima",
      tournament: "Mashindano",
    },
    pages: {
      Groups: {
        metaTitle: (club: ClubCopyContext) => `Mizunguko ya msaada ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Mizunguko rasmi ya ${club.shortName} kwa tifos, safari za ugenini na kampeni za klabu.`,
        eyebrow: "Mizunguko ya msaada",
        title: "Mizunguko ya mashabiki na kampeni za mubashara.",
        description: (club: ClubCopyContext) =>
          `Saidia tifos, safari za ugenini na miradi ya klabu kupitia mizunguko rasmi ya ${club.shortName}.`,
        whyEyebrow: "Kwa nini mizunguko ni muhimu",
        whyTitle: "Beba kampeni pamoja",
        bridgeEyebrow: "Daraja la jamii",
        bridgeTitle: "Matawi yanayoongeza nguvu kwa kila kampeni",
        campaignProgress: "Maendeleo ya kampeni",
      },
      contact: {
        metaTitle: (club: ClubCopyContext) => `Mawasiliano ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Maelezo rasmi ya mawasiliano ya ${club.shortName}, msaada wa kidijitali na njia za kijamii.`,
        eyebrow: "Mawasiliano",
        title: "Mawasiliano rasmi ya klabu na msaada wa kidijitali pamoja.",
        description:
          "Pata njia rasmi za klabu, msaada kwa mashabiki na njia sahihi ya kuingia kwenye uanachama, tiketi na app.",
        membershipSupport: "Msaada wa uanachama",
        contactCardTitle: "Mawasiliano ya klabu",
        digitalSupport: "Msaada wa kidijitali",
        digitalSupportDescription:
          "Tumia app kwa wasifu, uanachama, shop na tiketi. Taarifa za umma hubaki kwenye tovuti.",
        socialChannels: "Njia za kijamii",
      },
      fanClubs: {
        metaTitle: (club: ClubCopyContext) => `Vilabu vya mashabiki vya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Vilabu rasmi vya mashabiki vya ${club.shortName} na shughuli za jamii ndani na nje ya nchi.`,
        eyebrow: "Jamii",
        title: "Matawi ya mashabiki katika mfumo mzima wa klabu.",
        description: (club: ClubCopyContext) =>
          `Gundua vilabu rasmi vya mashabiki, shughuli za matawi na mtandao wa mashabiki unaobeba kila matchday ya ${club.shortName}.`,
        activeSupportGroups: "Mizunguko ya msaada iliyo hai",
        rating: "ukadiriaji",
        events: "matukio",
      },
      fixtures: {
        metaTitle: (club: ClubCopyContext) => `Ratiba ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Ratiba rasmi ya ${club.shortName} yenye mechi za mubashara, zijazo na viungo vya tiketi.`,
        eyebrow: "Ratiba",
        title: "Mubashara, inayofuata na iliyopita.",
        description: (club: ClubCopyContext) =>
          `Fuatilia mechi ya sasa ya ${club.shortName}, angalia kickoff ijayo na nenda moja kwa moja kwenye tiketi mechi ikifunguliwa.`,
        liveNowTitle: "Matchday kwa kasi kamili",
        upcomingTitle: "Mechi tayari kwa tiketi",
      },
      history: {
        metaTitle: (club: ClubCopyContext) => `Historia ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Historia ya ${club.shortName}, utambulisho wa klabu na utamaduni wa mashabiki nyuma ya ${club.clubName}.`,
        eyebrow: "Historia",
        title: (club: ClubCopyContext) => `Hadithi ya ${clubDisplay(club)}.`,
        description: (club: ClubCopyContext) =>
          `Utambulisho wa klabu, utamaduni wa mashabiki na historia inayoipa ${club.shortName} sauti yake.`,
        clubIdentity: "Utambulisho wa klabu",
        historyAcrossClub: "Historia ndani ya klabu yote",
        chapter: "Sura",
        surfaceValue: "Klabu kwanza",
        seeMembershipIdentity: "Tazama utambulisho wa uanachama",
        identityParagraph:
          "Historia inapaswa kuonekana kwenye matchday, uanachama, kampeni za mashabiki na simulizi za klabu. Ukurasa huu unahifadhi msingi wa sauti hiyo.",
      },
      membership: {
        metaTitle: (club: ClubCopyContext) => `Uanachama wa ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Ngazi rasmi za uanachama za ${club.shortName} zenye bei, faida na kipaumbele cha tiketi.`,
        eyebrow: "Uanachama",
        title: "Uanachama ulioundwa kwa matchday.",
        description: (club: ClubCopyContext) =>
          `Linganisha kila ngazi ya uanachama ya ${club.shortName}, ona faida wazi na uwashe kwenye app.`,
        membershipBenefits: "Faida za uanachama",
        whatEveryTierCovers: "Kila ngazi inatoa nini",
        whyItMatters: "Kwa nini ni muhimu",
        oneSupporterIdentity: "Utambulisho mmoja wa shabiki",
        identityPoints: [
          "Uanachama huweka login, hadhi ya shabiki na ufikiaji wa klabu sawa kati ya tovuti na app.",
          "Kipaumbele cha tiketi ndicho sababu iliyo wazi zaidi ya kupanda ngazi.",
        ],
      },
      news: {
        metaTitle: (club: ClubCopyContext) => `Habari za ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Habari rasmi za ${club.shortName}, masasisho ya matchday na matangazo ya klabu.`,
        eyebrow: "Habari",
        title: "Habari za klabu, matchday na simulizi za mashabiki.",
        description: (club: ClubCopyContext) =>
          `Masasisho ya karibuni kutoka ${club.shortName}, na njia za moja kwa moja kwenda ratiba, tiketi, uanachama na kampeni za mashabiki.`,
        newsroomStandards: "Viwango vya uandishi",
        newsroomStandardsTitle: "Kila hadithi inastahili kubofya",
        latestStories: "Hadithi za karibuni",
        acrossTheClub: "Ndani ya klabu yote",
        standardsPoints: [
          "Kila kadi hubeba excerpt halisi kwa utafutaji na ushiriki.",
          "Matchday, utamaduni wa mashabiki na taarifa za klabu huongoza uandishi.",
          "Hadithi zinaunganisha ratiba, tiketi, uanachama na bidhaa mpya za shop kwa usafi.",
        ],
      },
      privacy: {
        metaTitle: "Sera ya faragha",
        metaDescription: (club: ClubCopyContext) =>
          `Jinsi ${club.shortName} inavyoshughulikia data za mashabiki kwenye tovuti na app.`,
        eyebrow: "Faragha",
        fallbackTitle: "Data za mashabiki zenye mipaka iliyo wazi.",
        fallbackBody:
          "Tovuti ya klabu huhifadhi tu data ya msingi inayohitajika kuendesha tovuti na app kama uanachama, tiketi, oda za shop na mizunguko ya msaada. Data nyeti za malipo na mawasiliano binafsi hutenganishwa na wasifu wa umma.",
      },
      results: {
        metaTitle: (club: ClubCopyContext) => `Matokeo ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Matokeo rasmi ya ${club.shortName} yenye alama za karibuni na njia ya mechi inayofuata.`,
        eyebrow: "Matokeo",
        title: "Matokeo ya karibuni na mwelekeo wa mechi.",
        description: (club: ClubCopyContext) =>
          `Ona alama za mwisho, muhtasari wa mechi na njia ya moja kwa moja kwenda mechi ijayo ya ${club.shortName}.`,
        recentForm: "Fomu ya karibuni",
        resultsWithContext: "Matokeo yenye muktadha",
        contextPoints: [
          "Alama ya mwisho, uwanja na mashindano huonekana kwa haraka.",
          "Nyakati muhimu hubaki kwenye mechi badala ya kupotea ndani ya feed.",
          "Kila mechi iliyokamilika inaelekeza hatua inayofuata.",
        ],
      },
      searchPage: {
        metaTitle: "Utafutaji",
        metaDescription:
          "Tafuta mechi, tiketi, uanachama, mizunguko, shop na habari za klabu.",
      },
      shop: {
        metaTitle: (club: ClubCopyContext) => `Shop ya ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Merch rasmi ya ${club.shortName}, jezi, mavazi ya safari na mahitaji ya mashabiki.`,
        eyebrow: "Shop ya klabu",
        title: "Merch rasmi na mahitaji ya matchday.",
        description: (club: ClubCopyContext) =>
          `Vinjari drop mpya ya ${club.shortName}, angalia sizes na bei, kisha uendelee na malipo kwenye app.`,
        featuredDrop: "Drop iliyoangaziwa",
        shopStandards: "Viwango vya shop",
        clearBeforeCheckout: "Wazi kabla ya malipo",
        unlockMemberDiscounts: "Fungua punguzo la wanachama",
        standardsPoints: [
          "Picha za bidhaa na muktadha wa collection huongoza kila uzinduzi.",
          "Sizes na bei huonekana kabla shabiki hajaondoka kwenye tovuti.",
          "App hushughulikia checkout wakati shop ya umma inahudumia discovery.",
        ],
      },
      squad: {
        metaTitle: (club: ClubCopyContext) => `Kikosi cha ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Orodha rasmi ya kikosi cha ${club.shortName} na namba, nafasi na utaifa.`,
        eyebrow: "Kikosi",
        title: "Kikosi, namba na majukumu.",
        description: (club: ClubCopyContext) =>
          `Kutana na kikosi cha ${club.shortName} kwa namba za wachezaji, nafasi na umbo la kundi la matchday.`,
        unitView: "Mwonekano wa vitengo",
        tacticalShape: "Muundo wa kiufundi kwa haraka",
        goalkeepers: "Makipa",
        defenders: "Mabeki",
        midfielders: "Viungo",
        attackers: "Washambuliaji",
        rosterNote:
          "Kikosi hiki huwa bora zaidi kwa picha, takwimu za wachezaji na viungo vya moja kwa moja kwenda matchday na uandishi wa klabu.",
      },
      standings: {
        metaTitle: (club: ClubCopyContext) => `Jedwali la ${club.league}`,
        metaDescription: (club: ClubCopyContext) =>
          `Jedwali rasmi la ligi likionyesha nafasi ya ${club.shortName}, pointi na tofauti ya mabao.`,
        eyebrow: "Jedwali la ligi",
        title: "Jedwali la ligi na fomu.",
        description: (club: ClubCopyContext) =>
          `Fuatilia ${club.shortName} ndani ya jedwali ukiwa na muktadha kamili wa vilabu vilivyo juu na chini yake.`,
        clubPosition: (club: ClubCopyContext) => `Nafasi ya ${club.shortName}`,
        positionInRace: "Nafasi kwenye mbio",
        highlightedClub: "Klabu iliyoangaziwa",
        summaryPoints: [
          "Jedwali lote huweka mbio za ligi zikiendelea kusomeka.",
          "Klabu hubaki kuangaziwa kwenye kila mwonekano wa standings.",
          "Fomu ya karibuni huonyesha momentum bila kumpeleka shabiki mahali pengine.",
        ],
      },
      supporters: {
        metaTitle: "App ya mashabiki",
        metaDescription:
          "Endelea na uanachama, tiketi, shop na hatua za mashabiki kwenye app ya simu.",
        eyebrow: "App ya mashabiki",
        title: "Safari ya shabiki inaendelea kwenye simu.",
        description:
          "Tovuti sasa hushughulikia ugunduzi na simulizi za klabu. Uanachama, malipo salama na hatua zilizolindwa zinaendelea kwenye app ya simu.",
        supporterIdentity: "Utambulisho wa shabiki",
        secureActions: "Hatua salama",
        rolloutReady: "Tayari kwa uzinduzi",
        rolloutReadyConfigured:
          "Mahali pa app maalum ya klabu limewekwa kwenye mazingira haya.",
        rolloutReadyPending:
          "Weka NEXT_PUBLIC_FAN_APP_URL pale store au deep-link zitakapokuwa tayari.",
        liveFetCatalog: "Catalog ya FET ya mubashara",
        adminManagedRewards: "Zawadi za FET zinazosimamiwa na admin",
        supporterLeaderboard: "Jedwali la mashabiki",
        currentFetRanking: "Nafasi ya sasa ya FET",
        noCatalog: "Catalog ya FET ya mubashara haipatikani bado kwa klabu hii.",
        noLeaderboard: "Hakuna jedwali la umma la mashabiki kwa sasa.",
        activeRewards: "Zawadi hai",
        topReward: "Zawadi ya juu",
        trigger: "Kichocheo",
        timing: "Wakati",
        identityBody:
          "Ingia mara moja na uhifadhi uanachama, wasifu na hadhi ya shabiki pamoja kwenye uso wa simu wa asili.",
        secureActionsBody:
          "Ununuzi wa tiketi, michango ya jamii na shughuli zilizolindwa sasa hubaki ndani ya app ya simu.",
        catalogIntro:
          "App ya mashabiki sasa husoma catalog ile ile ya Fan Engagement Token inayosimamiwa na admin. Tovuti inaonyesha programu ya zawadi za moja kwa moja na jedwali la sasa huku earning zilizothibitishwa zikiendelea kwenye simu.",
        leaderboardIntro:
          "Nafasi hizi zinatokana na pointi zile zile za wanachama zinazotumiwa na app ya simu. Tovuti inaonyesha jedwali la umma huku maendeleo binafsi na hatua salama zikiendelea kwenye simu.",
      },
      terms: {
        metaTitle: "Sheria na masharti",
        metaDescription: (club: ClubCopyContext) =>
          `Masharti ya tiketi, uanachama, oda za shop na shughuli za mashabiki kwenye tovuti ya ${club.shortName} na app.`,
        eyebrow: "Masharti",
        fallbackTitle: "Jukwaa moja la mashabiki kati ya web na mobile.",
        fallbackBody:
          "Tiketi, oda za shop, uanachama na rekodi za michango zinazoundwa kupitia tovuti ni sehemu ya jukwaa lile lile la mashabiki linalotumiwa na app ya simu. Upatikanaji, bei na ustahiki wa mashabiki hubaki chini ya sera ya klabu na hali ya uendeshaji wa moja kwa moja.",
      },
      tickets: {
        metaTitle: (club: ClubCopyContext) => `Tiketi za ${club.shortName}`,
        metaDescription: (club: ClubCopyContext) =>
          `Kitovu rasmi cha tiketi cha ${club.shortName} chenye bei na kuendelea na malipo kwenye app.`,
        eyebrow: "Tiketi",
        title: "Tiketi na ufikiaji wa matchday.",
        description: (club: ClubCopyContext) =>
          `Ona uwanja, kickoff, bei na upatikanaji kabla ya kuendelea na malipo salama kwenye app ya ${club.shortName}.`,
        checkoutFanApp: "App ya mashabiki",
        matchdayEssentials: "Mahitaji ya matchday",
        buyWithConfidence: "Nunua kwa kujiamini",
        confidencePoints: [
          "Bei huonekana kabla ya kuingia.",
          "Uwanja, mashindano na kickoff hubaki zimefungwa kwenye kila mechi.",
          "Kipaumbele cha wanachama huonekana kabla ya checkout kufunguka.",
        ],
      },
    },
  },
} as const;

export type SiteCopy = (typeof translations)[keyof typeof translations];
export type SiteChromeCopy = Pick<
  SiteCopy,
  | "officialWebsite"
  | "officialClubWebsite"
  | "search"
  | "fanApp"
  | "openFanApp"
  | "buyTickets"
  | "supportGroups"
  | "home"
  | "tickets"
  | "membership"
  | "next"
  | "details"
  | "followLive"
>;

export function getSiteCopy(language: string | null | undefined): SiteCopy {
  const normalized = (language ?? "en")
    .trim()
    .toLowerCase()
    .split(/[-_]/)[0];

  return translations[normalized as keyof typeof translations] ?? translations.en;
}

export function getSiteChromeCopy(
  language: string | null | undefined,
): SiteChromeCopy {
  const copy = getSiteCopy(language);

  return {
    officialWebsite: copy.officialWebsite,
    officialClubWebsite: copy.officialClubWebsite,
    search: copy.search,
    fanApp: copy.fanApp,
    openFanApp: copy.openFanApp,
    buyTickets: copy.buyTickets,
    supportGroups: copy.supportGroups,
    home: copy.home,
    tickets: copy.tickets,
    membership: copy.membership,
    next: copy.next,
    details: copy.details,
    followLive: copy.followLive,
  };
}
