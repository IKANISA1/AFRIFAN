/**
 * Public-facing site types.
 */

export type FeatureFlags = Record<string, boolean>;

export interface ClubProfile {
  id: number;
  clubName: string;
  clubSlug: string;
  shortName: string;
  nickname: string;
  countryCode: string;
  league: string;
  region: string;
  currencyCode: string;
  currencySymbol: string;
  defaultLanguage: string;
  supportedLanguages: string[];
  officialContact: string;
  facebookUrl?: string | null;
  xUrl?: string | null;
  instagramUrl?: string | null;
  tiktokUrl?: string | null;
  officialLogoUrl?: string | null;
  primaryColorHex: string;
  secondaryColorHex: string;
  accentColorHex: string;
  featureFlags: FeatureFlags;
}

export interface MatchEventItem {
  minute: string;
  event: string;
  side: "home" | "away";
}

export interface MatchItem {
  id: string;
  homeTeam: string;
  awayTeam: string;
  competition: string;
  venue: string;
  matchDate: string;
  kickoffTime?: string | null;
  isOnSale: boolean;
  generalPrice: number;
  vipPrice: number;
  imageUrl?: string | null;
  matchStatus: string;
  homeScore: number;
  awayScore: number;
  liveMinute?: number | null;
  matchSummary?: string | null;
  liveEvents: MatchEventItem[];
  liveStats: Record<string, number | string>;
  isFeatured: boolean;
}

export interface SearchIndexItem {
  id: string;
  title: string;
  description: string;
  href: string;
  category: "Page" | "Match" | "News" | "Shop" | "Community" | "Membership";
  meta?: string;
}

export interface NewsArticle {
  id: string;
  title: string;
  excerpt: string;
  content: string;
  category: string;
  coverImageUrl?: string | null;
  publishedAt: string;
  author: string;
}

export interface ShopProduct {
  id: string;
  name: string;
  subtitle: string;
  description: string;
  category: string;
  price: number;
  imageUrl?: string | null;
  sizes: string[];
  isActive: boolean;
  collection?: string | null;
}

export interface MembershipPackage {
  id: string;
  tier: "fan" | "bronze" | "gold" | "platinum";
  title: string;
  description: string;
  sortOrder: number;
  perks: string[];
  annualPrice: number;
}

export interface FanClubItem {
  id: string;
  name: string;
  region: string;
  description: string;
  memberCount: number;
  eventCount: number;
  rating: number;
  bannerImageUrl?: string | null;
}

export interface ContributionGroup {
  id: string;
  name: string;
  description: string;
  privacy: "public" | "private";
  groupType: "general" | "project" | "savings" | "emergency";
  targetAmount: number;
  currentTotal: number;
  currency: string;
  memberCount: number;
  inviteCode?: string | null;
  isActive: boolean;
}

export interface SquadPlayer {
  id: string;
  name: string;
  role: string;
  number: number;
  nationality: string;
  bio: string;
}

export interface StandingRow {
  position: number;
  club: string;
  played: number;
  goalDifference: number;
  points: number;
  form?: string[];
  highlight?: boolean;
}
