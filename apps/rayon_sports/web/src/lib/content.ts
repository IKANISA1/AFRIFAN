import type {
  ClubProfile,
  ContributionGroup,
  FanClubItem,
  MatchItem,
  MembershipPackage,
  NewsArticle,
  SearchIndexItem,
  ShopProduct,
  SquadPlayer,
  StandingRow,
} from "@/lib/types";
import { rayonClub, resolveFanAppHref } from "@/lib/config";

export const fallbackClubProfile: ClubProfile = {
  id: rayonClub.numericId,
  clubName: rayonClub.name,
  clubSlug: rayonClub.slug,
  shortName: rayonClub.shortName,
  nickname: rayonClub.nickname,
  countryCode: rayonClub.countryCode,
  league: "Rwanda Premier League",
  region: "East Africa",
  currencyCode: rayonClub.currencyCode,
  currencySymbol: rayonClub.currencySymbol,
  defaultLanguage: "en",
  supportedLanguages: ["en", "fr"],
  officialContact: "Official club channels and matchday help desk",
  facebookUrl: "https://fb.com/RayonSportsOfficial",
  xUrl: "https://x.com/rayon_sports",
  instagramUrl: "https://instagram.com/rayonsports_official",
  tiktokUrl: "https://tiktok.com/@rayonsports",
  officialLogoUrl: "/icons/icon-192x192.png",
  primaryColorHex: rayonClub.primaryColorHex,
  secondaryColorHex: rayonClub.secondaryColorHex,
  accentColorHex: rayonClub.accentColorHex,
  featureFlags: {
    shop: true,
    fan_clubs: true,
    ticketing: true,
    chat: true,
    sms_ledger: true,
  },
};

export const fallbackMatches: MatchItem[] = [
  {
    id: "featured-home-fixture",
    homeTeam: fallbackClubProfile.shortName,
    awayTeam: "Rayon Sports FC",
    competition: fallbackClubProfile.league,
    venue: "Club Stadium",
    matchDate: "2026-04-20T15:00:00.000Z",
    kickoffTime: "18:00",
    isOnSale: true,
    generalPrice: 3000,
    vipPrice: 10000,
    imageUrl: "/media/stadium-hero.jpg",
    matchStatus: "scheduled",
    homeScore: 0,
    awayScore: 0,
    liveMinute: null,
    matchSummary:
      `A high-demand matchday built for a full house around ${fallbackClubProfile.shortName}.`,
    liveEvents: [],
    liveStats: {},
    isFeatured: true,
  },
  {
    id: "cup-live-fixture",
    homeTeam: "Police FC",
    awayTeam: fallbackClubProfile.shortName,
    competition: "Peace Cup",
    venue: "Mumena Stadium",
    matchDate: "2026-04-12T12:30:00.000Z",
    kickoffTime: "15:30",
    isOnSale: false,
    generalPrice: 2500,
    vipPrice: 8000,
    imageUrl: "/media/stadium-hero-2.jpg",
    matchStatus: "live",
    homeScore: 1,
    awayScore: 2,
    liveMinute: 67,
    matchSummary:
      `${fallbackClubProfile.shortName} are pressing hard and controlling the decisive moments.`,
    liveEvents: [
      { minute: "14'", event: "Rayon Sports-style pressing goal from open play", side: "home" },
      { minute: "39'", event: "Mukundane levels from the spot", side: "away" },
      { minute: "61'", event: "Ndayishimiye curls home from range", side: "away" },
    ],
    liveStats: {
      possession: "58%",
      shotsOnTarget: 6,
      corners: 5,
    },
    isFeatured: false,
  },
  {
    id: "recent-result-fixture",
    homeTeam: fallbackClubProfile.shortName,
    awayTeam: "Etincelles FC",
    competition: fallbackClubProfile.league,
    venue: "Club Stadium",
    matchDate: "2026-04-02T15:00:00.000Z",
    kickoffTime: "18:00",
    isOnSale: false,
    generalPrice: 2500,
    vipPrice: 7000,
    imageUrl: "/media/stadium-hero.jpg",
    matchStatus: "fulltime",
    homeScore: 3,
    awayScore: 1,
    liveMinute: null,
    matchSummary:
      `A composed second-half surge kept ${fallbackClubProfile.shortName} in the title conversation.`,
    liveEvents: [
      { minute: "8'", event: "Mugisha heads in the opener", side: "away" },
      { minute: "24'", event: "Equalizer from a deep free-kick routine", side: "home" },
      { minute: "72'", event: "Counter-attack finish after a high regain", side: "home" },
      { minute: "88'", event: "Late insurance goal from the bench", side: "home" },
    ],
    liveStats: {
      possession: "62%",
      shotsOnTarget: 7,
      corners: 8,
    },
    isFeatured: false,
  },
];

export const fallbackNewsArticles: NewsArticle[] = [
  {
    id: "matchday-club-pulse",
    title: `The Blue Wall: Preparing for Matchday at the Cathedral`,
    excerpt:
      "Witness the mobilization of Rwanda's most passionate fanbase as we prepare for the headline clash against Police FC.",
    content:
      `${fallbackClubProfile.clubName} is finalizing a world-class matchday experience for our supporters. From the choreographed Blue Wall tifo to enhanced Gold member hospitality, every detail is being refined to ensure matchday remains the heartbeat of Rwandan football. Gates open at 14:00. Arrive early, wear your colors, and be the twelfth man.`,
    category: "Matchday",
    coverImageUrl: "/media/stadium-hero.jpg",
    publishedAt: "2026-04-15T07:00:00.000Z",
    author: "Gikundiro Media",
  },
  {
    id: "membership-gikundiro-Group",
    title: "Digital Fan Identity: Your Portal to the Beloved",
    excerpt:
      "Manage your membership, secure priority tickets, and join Support Circles through our new integrated digital platform.",
    content:
      `Being a member of ${fallbackClubProfile.shortName} is more than just a ticket—it's a digital-first identity. Our new fan portal allows supporters across Rwanda and the diaspora to manage their tiers, earn FET tokens, and fund community projects through Support Circles. Your fan card is now live in the supporter app. Access the future of fan engagement today.`,
    category: "Membership",
    coverImageUrl: "/media/stadium-hero-2.jpg",
    publishedAt: "2026-04-12T10:15:00.000Z",
    author: "Supporter Experience",
  },
  {
    id: "shop-blue-red-drop",
    title: "The 2026 Heritage Collection: Out Now",
    excerpt:
      "The new home kit has arrived. A tribute to our 50-year legacy, built for the modern supporter.",
    content:
      `Our 2026 Heritage Collection is officially live. Featuring the iconic cobalt blue with gold accents, the new home replica jersey combines breathable performance fabrics with the prestige of the Gikundiro crest. Available now in the official shop and selected retail partners across Kigali. Own the colors. Own the history.`,
    category: "Shop",
    coverImageUrl: "/media/stadium-hero.jpg",
    publishedAt: "2026-04-10T12:30:00.000Z",
    author: "Retail Desk",
  },
];

export const fallbackProducts: ShopProduct[] = [
  {
    id: "replica-home-26",
    name: "2026 Home Replica Jersey",
    subtitle: "Matchday fit, club crest embroidery, breathable knit.",
    description:
      `Official ${fallbackClubProfile.shortName} replica built for matchdays and supporter travel. Includes woven crest, sponsor print, and a premium finish.`,
    category: "Replica",
    price: 35000,
    imageUrl: "/media/stadium-hero.jpg",
    sizes: ["S", "M", "L", "XL"],
    isActive: true,
    collection: "2026 Matchday",
  },
  {
    id: "travel-hoodie",
    name: "Blue Travel Hoodie",
    subtitle: "Heavyweight fleece with a tonal crest hit.",
    description:
      "Supporter travel layer with a clean front mark and a wide cut for cooler evening kickoffs.",
    category: "Outerwear",
    price: 42000,
    imageUrl: "/media/stadium-hero-2.jpg",
    sizes: ["M", "L", "XL"],
    isActive: true,
    collection: "Supporter Travel",
  },
  {
    id: "matchday-scarf",
    name: `${fallbackClubProfile.shortName} Matchday Scarf`,
    subtitle: "Stadium knit in blue, white, and gold.",
    description:
      "A supporter staple for derby days, cup nights, and away sections.",
    category: "Accessories",
    price: 12000,
    imageUrl: "/media/stadium-hero.jpg",
    sizes: ["One Size"],
    isActive: true,
    collection: "Accessories",
  },
];

export const fallbackMembershipPackages: MembershipPackage[] = [
  {
    id: "ingenzi-imanzi",
    tier: "ingenzi-imanzi",
    title: "Ingenzi / Imanzi",
    description: "Official entry supporter identity across mobile and web.",
    sortOrder: 0,
    annualPrice: 0,
    perks: [
      "Digital supporter card",
      "Supporter app access",
      "News and match reminders",
      "Support Groups access",
    ],
  },
  {
    id: "inyamibwa",
    tier: "inyamibwa",
    title: "Inyamibwa",
    description: "Recognized supporter status for regular club followers.",
    sortOrder: 1,
    annualPrice: 5000,
    perks: ["Supporter badge", "Club news updates", "Support Groups access"],
  },
  {
    id: "imena",
    tier: "imena",
    title: "Imena",
    description: "Standard official membership for active supporters.",
    sortOrder: 2,
    annualPrice: 10000,
    perks: ["Digital membership card", "Ticket updates", "Member campaigns"],
  },
  {
    id: "bronze-beloved",
    tier: "bronze",
    title: "Bronze Beloved",
    description: "Priority access for active local supporters.",
    sortOrder: 3,
    annualPrice: 15000,
    perks: [
      "Early ticket window",
      "Supporter badge",
      "Member-only drops",
    ],
  },
  {
    id: "silver-priority",
    tier: "silver",
    title: "Silver Priority",
    description: "Priority ticket and campaign access for committed members.",
    sortOrder: 4,
    annualPrice: 30000,
    perks: ["Priority ticket window", "Shop drops", "Member-only campaigns"],
  },
  {
    id: "gold-heritage",
    tier: "gold",
    title: "Gold Heritage",
    description: "Premium supporter access for the club's core Group.",
    sortOrder: 5,
    annualPrice: 50000,
    perks: [
      "Priority ticketing",
      "Shop discount",
      "Exclusive events",
      "Premium badge",
    ],
  },
];

export const fallbackFanClubs: FanClubItem[] = [
  {
    id: "capital-supporters",
    name: `${fallbackClubProfile.shortName} City Chapter`,
    region: "Capital Region",
    description:
      "Central city supporter chapter focused on home-match choreography and away-travel logistics.",
    memberCount: 183,
    eventCount: 24,
    rating: 4.8,
    bannerImageUrl: "/media/stadium-hero.jpg",
  },
  {
    id: "northern-supporters",
    name: `${fallbackClubProfile.shortName} Northern Chapter`,
    region: "Northern Province",
    description:
      "Supporters coordinating travel, local screenings, and youth outreach around matchweeks.",
    memberCount: 91,
    eventCount: 12,
    rating: 4.6,
    bannerImageUrl: "/media/stadium-hero-2.jpg",
  },
  {
    id: "diaspora-supporters",
    name: `${fallbackClubProfile.shortName} Diaspora Network`,
    region: "Global",
    description:
      "A digital-first fan club for international supporters following every matchday online.",
    memberCount: 244,
    eventCount: 18,
    rating: 4.9,
    bannerImageUrl: "/media/stadium-hero.jpg",
  },
];

export const fallbackContributionGroups: ContributionGroup[] = [
  {
    id: "stadium-tifo-26",
    name: "Blue Wall Tifo Fund",
    description:
      "Support a bigger home-end tifo package for the Rayon Sports and continental nights.",
    groupType: "project",
    targetAmount: 2500000,
    currentTotal: 1375000,
    currency: fallbackClubProfile.currencyCode,
    memberCount: 64,
    isActive: true,
  },
  {
    id: "travel-community-huye",
    name: "Away Travel Community",
    description:
      "Supporters coordinating buses, meals, and printed supporter materials for away matchdays.",
    groupType: "community",
    targetAmount: 900000,
    currentTotal: 355000,
    currency: fallbackClubProfile.currencyCode,
    memberCount: 27,
    isActive: true,
  },
];

export const fallbackSquad: SquadPlayer[] = [
  {
    id: "p1",
    name: "Mugenzi Mukunzi",
    role: "Goalkeeper",
    number: 1,
    nationality: "Rwanda",
    bio: "Commanding in the box and vocal in matchday organization.",
  },
  {
    id: "p2",
    name: "Thierry Manzi",
    role: "Centre Back",
    number: 4,
    nationality: "Rwanda",
    bio: "Aggressive first defender and aerial anchor in both boxes.",
  },
  {
    id: "p3",
    name: "Kevin Muhire",
    role: "Midfielder",
    number: 11,
    nationality: "Rwanda",
    bio: "Creative tempo-setter between the lines and on restarts.",
  },
  {
    id: "p4",
    name: "Fall Ngagne",
    role: "Forward",
    number: 9,
    nationality: "Senegal",
    bio: "Penalty-box finisher built for transition and second-ball attacks.",
  },
  {
    id: "p5",
    name: "Yannick Mukunzi",
    role: "Winger",
    number: 17,
    nationality: "Rwanda",
    bio: "High-output winger stretching the game from touchline to touchline.",
  },
];

export const fallbackStandings: StandingRow[] = [
  {
    position: 1,
    club: "Rayon Sports FC",
    played: 24,
    goalDifference: 25,
    points: 54,
    form: ["W", "W", "D", "W", "W"],
  },
  {
    position: 2,
    club: fallbackClubProfile.shortName,
    played: 24,
    goalDifference: 18,
    points: 50,
    form: ["W", "W", "W", "L", "D"],
    highlight: true,
  },
  {
    position: 3,
    club: "Police FC",
    played: 24,
    goalDifference: 13,
    points: 44,
    form: ["W", "L", "W", "D", "W"],
  },
  {
    position: 4,
    club: "Kiyovu Sports",
    played: 24,
    goalDifference: 8,
    points: 39,
    form: ["D", "W", "L", "D", "W"],
  },
  {
    position: 5,
    club: "Etincelles FC",
    played: 24,
    goalDifference: 6,
    points: 37,
    form: ["L", "W", "D", "W", "D"],
  },
  {
    position: 6,
    club: "AS Kigali",
    played: 24,
    goalDifference: 5,
    points: 35,
    form: ["D", "L", "W", "W", "D"],
  },
  {
    position: 7,
    club: "Musanze FC",
    played: 24,
    goalDifference: 2,
    points: 33,
    form: ["W", "D", "L", "D", "L"],
  },
  {
    position: 8,
    club: "Mukura VS",
    played: 24,
    goalDifference: -1,
    points: 32,
    form: ["L", "W", "D", "W", "L"],
  },
  {
    position: 9,
    club: "Bugesera FC",
    played: 24,
    goalDifference: -4,
    points: 29,
    form: ["D", "D", "L", "W", "L"],
  },
  {
    position: 10,
    club: "Marines FC",
    played: 24,
    goalDifference: -8,
    points: 26,
    form: ["L", "L", "W", "D", "D"],
  },
];

export const clubHistoryMoments = [
  {
    title: "Official club identity",
    body:
      `${fallbackClubProfile.shortName} carries a distinct supporter identity. Every public page should feel like an official club home rather than a generic sports template.`,
  },
  {
    title: "Matchday at scale",
    body:
      "The website anchors matchday logistics, supporter mobilization, and ticketing for mobile and desktop alike.",
  },
  {
    title: "One supporter account across surfaces",
    body:
      "The website handles discovery while the mobile supporter app handles authenticated fan action.",
  },
];

export const siteNavigation = [
  { href: "/", label: "Home" },
  { href: "/fixtures", label: "Fixtures" },
  { href: "/tickets", label: "Tickets" },
  { href: "/membership", label: "Membership" },
  { href: "/Groups", label: "Groups" },
  { href: "/shop", label: "Shop" },
  { href: "/news", label: "News" },
  { href: "/squad", label: "Squad" },
  { href: "/standings", label: "Standings" },
  { href: "/fan-clubs", label: "Fan Clubs" },
  { href: "/history", label: "History" },
  { href: "/contact", label: "Contact" },
];

export const utilityNavigation = [
  { href: "/results", label: "Results" },
  { href: "/history", label: "History" },
  { href: "/contact", label: "Contact" },
];

export const footerNavigationGroups = [
  {
    title: "Matchday",
    links: [
      { href: "/fixtures", label: "Fixtures" },
      { href: "/tickets", label: "Tickets" },
      { href: "/results", label: "Results" },
      { href: "/standings", label: "Standings" },
    ],
  },
  {
    title: "Supporters",
    links: [
      { href: "/membership", label: "Membership" },
      { href: "/Groups", label: "Support Groups" },
      { href: "/fan-clubs", label: "Fan Clubs" },
      { href: resolveFanAppHref(), label: "Fan App" },
    ],
  },
  {
    title: "Club",
    links: [
      { href: "/news", label: "News" },
      { href: "/squad", label: "Squad" },
      { href: "/history", label: "History" },
      { href: "/contact", label: "Contact" },
    ],
  },
  {
    title: "Legal",
    links: [
      { href: "/privacy", label: "Privacy" },
      { href: "/terms", label: "Terms" },
    ],
  },
];

export const staticSearchItems: SearchIndexItem[] = [
  {
    id: "page-home",
    title: "Homepage",
    description: "Live matchday, tickets, Groups, and club storytelling.",
    href: "/",
    category: "Page",
    meta: "Overview",
  },
  {
    id: "page-fixtures",
    title: "Fixtures",
    description: "Upcoming matches, live center links, and recent results.",
    href: "/fixtures",
    category: "Match",
    meta: "Schedule",
  },
  {
    id: "page-tickets",
    title: "Tickets",
    description: "Official ticket hub with live pricing, fixture detail, and supporter app follow-through.",
    href: "/tickets",
    category: "Match",
    meta: "Buy",
  },
  {
    id: "page-membership",
    title: "Membership",
    description: "Tier comparison, benefits, and supporter identity.",
    href: "/membership",
    category: "Membership",
    meta: "Plans",
  },
  {
    id: "page-Groups",
    title: "Support Groups",
    description:
      "Collective fan funding for tifos, away travel, and club projects.",
    href: "/Groups",
    category: "Community",
    meta: "Funding",
  },
  {
    id: "page-fan-clubs",
    title: "Fan Clubs",
    description: "Supporter chapters across the club footprint and diaspora.",
    href: "/fan-clubs",
    category: "Community",
    meta: "Community",
  },
  {
    id: "page-shop",
    title: "Club Shop",
    description: "Replica shirts, matchday scarves, and supporter essentials.",
    href: "/shop",
    category: "Shop",
    meta: "Merch",
  },
  {
    id: "page-news",
    title: "Newsroom",
    description: "Club media, matchday coverage, and campaign stories.",
    href: "/news",
    category: "News",
    meta: "Editorial",
  },
  {
    id: "page-squad",
    title: "Squad",
    description: "Player profiles, roles, and matchday personalities.",
    href: "/squad",
    category: "Page",
    meta: "Players",
  },
];

export const adminNavigation = [
  { href: "/admin", label: "Dashboard" },
  { href: "/admin/access", label: "Access" },
  { href: "/admin/settings", label: "Settings" },
  { href: "/admin/cms", label: "CMS" },
  { href: "/admin/cms/banners", label: "Banners" },
  { href: "/admin/cms/content", label: "Content" },
  { href: "/admin/cms/config", label: "Config" },
  { href: "/admin/matches", label: "Matches" },
  { href: "/admin/squad", label: "Squad" },
  { href: "/admin/shop", label: "Shop" },
  { href: "/admin/offers", label: "Offers" },
  { href: "/admin/membership", label: "Membership" },
  { href: "/admin/gamification", label: "Gamification" },
  { href: "/admin/gamification/wallet", label: "Wallet Ops" },
  { href: "/admin/predictions", label: "Predictions" },
  { href: "/admin/community", label: "Community" },
  { href: "/admin/standings", label: "Standings" },
  { href: "/admin/contributions", label: "Contributions" },
  { href: "/admin/notifications", label: "Notifications" },
  { href: "/admin/sms-monitor", label: "SMS" },
  { href: "/admin/football-sync", label: "Football Sync" },
  { href: "/admin/settings/features", label: "Features" },
  { href: "/admin/settings/audit", label: "Audit Log" },
];
