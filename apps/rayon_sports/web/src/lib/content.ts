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
import { rayonClub, siteConfig } from "@/lib/config";

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
  defaultLanguage: "rw",
  supportedLanguages: ["rw", "fr", "en"],
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
    biopay: true,
    shop: true,
    fan_clubs: true,
    ticketing: true,
    chat: true,
    sms_ledger: true,
  },
};

export const fallbackMatches: MatchItem[] = [
  {
    id: "rayon-apr-featured",
    homeTeam: "Rayon Sports",
    awayTeam: "APR FC",
    competition: "Rwanda Premier League",
    venue: "Kigali Pele Stadium",
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
      "A title-race matchday built for a full house in Kigali.",
    liveEvents: [],
    liveStats: {},
    isFeatured: true,
  },
  {
    id: "rayon-kwizera-live",
    homeTeam: "Police FC",
    awayTeam: "Rayon Sports",
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
      "Rayon are pressing down the left and dominating set-piece territory.",
    liveEvents: [
      { minute: "14'", event: "APR-style pressing goal from open play", side: "home" },
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
    id: "rayon-kayonza-result",
    homeTeam: "Rayon Sports",
    awayTeam: "Etincelles FC",
    competition: "Rwanda Premier League",
    venue: "Kigali Pele Stadium",
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
      "A composed second-half surge kept Rayon top of the chasing pack.",
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
    id: "matchday-kigali-blue-wave",
    title: "Matchday pulse: Kigali gets ready for the blue wave",
    excerpt:
      "Supporters' buses, early gates, and a full-day activation plan are locked in for the APR clash.",
    content:
      "Rayon Sports are building a full matchday program around the APR fixture, from supporter hub activations to ticket scanning lanes and post-match player access. The web app gives fans one place to find kickoff details, gate timings, and their purchase history before heading to the stadium.",
    category: "Matchday",
    coverImageUrl: "/media/stadium-hero.jpg",
    publishedAt: "2026-04-03T07:00:00.000Z",
    author: "Club Media",
  },
  {
    id: "membership-gikundiro-circle",
    title: "Membership is now digital-first across phone and web",
    excerpt:
      "Fans can now manage tiers, supporter details, and ticket priority from the web portal.",
    content:
      "The Gikundiro membership program now runs across mobile and web. Supporters can activate a plan, review their tier, update their profile, and keep their fan identity in sync across devices.",
    category: "Membership",
    coverImageUrl: "/media/stadium-hero-2.jpg",
    publishedAt: "2026-04-01T10:15:00.000Z",
    author: "Supporter Experience",
  },
  {
    id: "shop-blue-red-drop",
    title: "New blue-and-red drop lands in the official shop",
    excerpt:
      "Replica shirts, travel hoodies, and matchday scarves are now available in the club store.",
    content:
      "The latest Rayon Sports drop is live with home replicas, travel layers, and premium scarves. The shop experience in the new web build mirrors the app's merchandise flow while improving product discovery and checkout clarity.",
    category: "Shop",
    coverImageUrl: "/media/stadium-hero.jpg",
    publishedAt: "2026-03-30T12:30:00.000Z",
    author: "Retail Desk",
  },
];

export const fallbackProducts: ShopProduct[] = [
  {
    id: "replica-home-26",
    name: "2026 Home Replica Jersey",
    subtitle: "Matchday fit, club crest embroidery, breathable knit.",
    description:
      "Official Rayon Sports replica built for matchdays and supporter travel. Includes woven crest, sponsor print, and a deep royal-blue finish.",
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
      "Supporter travel layer with a clean front mark and a wide cut for cool Kigali evenings.",
    category: "Outerwear",
    price: 42000,
    imageUrl: "/media/stadium-hero-2.jpg",
    sizes: ["M", "L", "XL"],
    isActive: true,
    collection: "Supporter Travel",
  },
  {
    id: "matchday-scarf",
    name: "Gikundiro Matchday Scarf",
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
    id: "fan-core",
    tier: "fan",
    title: "Fan Core",
    description: "Your digital supporter identity across mobile and web.",
    sortOrder: 0,
    annualPrice: 0,
    perks: [
      "Digital fan card",
      "Portal access",
      "News and match reminders",
      "Support circles access",
    ],
  },
  {
    id: "bronze-beloved",
    tier: "bronze",
    title: "Bronze Beloved",
    description: "Priority access for active local supporters.",
    sortOrder: 1,
    annualPrice: 15000,
    perks: [
      "Early ticket window",
      "Supporter badge",
      "Member-only drops",
    ],
  },
  {
    id: "gold-heritage",
    tier: "gold",
    title: "Gold Heritage",
    description: "Premium supporter access for the club's core circle.",
    sortOrder: 2,
    annualPrice: 50000,
    perks: [
      "Priority ticketing",
      "Shop discount",
      "Exclusive events",
      "Premium badge",
    ],
  },
  {
    id: "platinum-matchday",
    tier: "platinum",
    title: "Platinum Matchday",
    description:
      "Top-tier club access for corporate hosts, donors, and matchday leaders.",
    sortOrder: 3,
    annualPrice: 120000,
    perks: [
      "VIP priority access",
      "Hospitality experiences",
      "Concierge service",
      "Limited-edition drops",
    ],
  },
];

export const fallbackFanClubs: FanClubItem[] = [
  {
    id: "kigali-blue-army",
    name: "Kigali Blue Army",
    region: "Kigali",
    description:
      "Central city supporter chapter focused on home-match choreography and away-travel logistics.",
    memberCount: 183,
    eventCount: 24,
    rating: 4.8,
    bannerImageUrl: "/media/stadium-hero.jpg",
  },
  {
    id: "musanze-red-line",
    name: "Musanze Red Line",
    region: "Northern Province",
    description:
      "Supporters coordinating travel, local screenings, and youth outreach around matchweeks.",
    memberCount: 91,
    eventCount: 12,
    rating: 4.6,
    bannerImageUrl: "/media/stadium-hero-2.jpg",
  },
  {
    id: "diaspora-gikundiro",
    name: "Diaspora Gikundiro",
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
      "Support a bigger home-end tifo package for the APR and continental nights.",
    privacy: "public",
    groupType: "project",
    targetAmount: 2500000,
    currentTotal: 1375000,
    currency: "RWF",
    memberCount: 64,
    inviteCode: "BLUE2026",
    isActive: true,
  },
  {
    id: "travel-circle-huye",
    name: "Away Travel Circle",
    description:
      "Shared savings circle for buses, meals, and printed supporter materials.",
    privacy: "public",
    groupType: "savings",
    targetAmount: 900000,
    currentTotal: 355000,
    currency: "RWF",
    memberCount: 27,
    inviteCode: "AWAYRAYN",
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
    club: "APR FC",
    played: 24,
    goalDifference: 25,
    points: 54,
    form: ["W", "W", "D", "W", "W"],
  },
  {
    position: 2,
    club: "Rayon Sports",
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
    title: "The beloved identity",
    body:
      "Gikundiro means 'the beloved'. Every public page carries that identity with the confidence of an official club home.",
  },
  {
    title: "Matchday at scale",
    body:
      "The website anchors matchday logistics, supporter mobilization, and ticketing for mobile and desktop alike.",
  },
  {
    title: "One supporter account across surfaces",
    body:
      "The web and mobile products share one supporter account, with the browser handling discovery and the portal handling authenticated action.",
  },
];

export const siteNavigation = [
  { href: "/", label: "Home" },
  { href: "/fixtures", label: "Fixtures" },
  { href: "/tickets", label: "Tickets" },
  { href: "/membership", label: "Membership" },
  { href: "/circles", label: "Circles" },
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
      { href: "/circles", label: "Support Circles" },
      { href: "/fan-clubs", label: "Fan Clubs" },
      { href: siteConfig.fansUrl, label: "Fan Portal" },
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

export const portalNavigation = [
  { href: "/app/home", label: "Home" },
  { href: "/app/profile", label: "Profile" },
  { href: "/app/membership", label: "Membership" },
  { href: "/app/tickets", label: "Tickets" },
  { href: "/app/shop", label: "Shop" },
  { href: "/app/contributions", label: "Support" },
  { href: "/app/fan-clubs", label: "Fan Clubs" },
  { href: "/app/xp", label: "XP" },
];

export const staticSearchItems: SearchIndexItem[] = [
  {
    id: "page-home",
    title: "Homepage",
    description: "Live matchday, tickets, circles, and club storytelling.",
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
    description: "Official ticket hub with live pricing, fixture detail, and secure portal checkout.",
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
    id: "page-circles",
    title: "Support Circles",
    description:
      "Collective fan funding for tifos, away travel, and club projects.",
    href: "/circles",
    category: "Community",
    meta: "Funding",
  },
  {
    id: "page-fan-clubs",
    title: "Fan Clubs",
    description: "Supporter chapters across Kigali, Rwanda, and the diaspora.",
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
  { href: "/admin/settings", label: "Settings" },
  { href: "/admin/cms", label: "CMS" },
  { href: "/admin/matches", label: "Matches" },
  { href: "/admin/squad", label: "Squad" },
  { href: "/admin/shop", label: "Shop" },
  { href: "/admin/membership", label: "Membership" },
  { href: "/admin/community", label: "Community" },
  { href: "/admin/standings", label: "Standings" },
  { href: "/admin/contributions", label: "Contributions" },
  { href: "/admin/notifications", label: "Notifications" },
  { href: "/admin/sms-monitor", label: "SMS" },
];
