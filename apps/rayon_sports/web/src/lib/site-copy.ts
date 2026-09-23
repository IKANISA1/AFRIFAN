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
      chapters: "FanClubs",
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
      supporterChapters: "Supporter FanClubs",
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
        bridgeTitle: "FanClubs that amplify every campaign",
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
          `Official ${club.shortName} fan clubs, supporter FanClubs, and community activity across the local community and diaspora.`,
        eyebrow: "Community",
        title: "Supporter FanClubs across the club footprint.",
        description: (club: ClubCopyContext) =>
          `Discover official fan clubs, FanClubs activity, and the supporter network behind every ${club.shortName} matchday.`,
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
        chapter: "FanClubs",
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

export function getSiteCopy(_language: string | null | undefined): SiteCopy {
  const normalized = "en";

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
