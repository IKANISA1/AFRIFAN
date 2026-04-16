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

export interface FanProfile {
  id: string;
  clubId: string;
  publicUserId?: string | null;
  displayName?: string | null;
  countryCode?: string | null;
  languageCode?: string | null;
  isActive?: boolean;
  momoNumber?: string | null;
  whatsappNumber?: string | null;
}

export interface FanMembership {
  id: string;
  clubId: number | null;
  partnerId?: string | null;
  tier: "fan" | "bronze" | "gold" | "platinum";
  points: number;
  chapter: string;
  membershipNumber?: string | null;
}

export interface TicketOrder {
  id: string;
  matchId: string;
  userId: string;
  seatType: string;
  amountPaid: number;
  status: string;
  qrCode?: string | null;
  purchasedAt: string;
}

export interface ShopOrder {
  id: string;
  userId: string;
  total: number;
  status: string;
  deliveryAddress?: string | null;
  momoReference?: string | null;
  createdAt: string;
}

export type AdminRole =
  | "super_admin"
  | "admin"
  | "club_admin"
  | "club_moderator"
  | "fan";

export interface AdminAccess {
  hasAccess: boolean;
  isAuthenticated: boolean;
  isSuperAdmin: boolean;
  role: AdminRole | null;
  clubId: string | null;
  assignmentCount: number;
}

export interface AdminDashboardMetrics {
  totalUsers: number;
  activeGroups: number;
  transactionsToday: number;
  ticketsSold: number;
}

export interface AdminActivityRecord {
  id: string;
  title: string;
  detail: string;
  createdAt: string;
}

export interface AdminDashboardSnapshot {
  metrics: AdminDashboardMetrics;
  activity: AdminActivityRecord[];
}

export interface AdminNewsArticle {
  id: string;
  clubId: number | null;
  title: string;
  subtitle: string | null;
  excerpt: string;
  body: string;
  category: string;
  imageUrl: string | null;
  isPublished: boolean;
  isFeatured: boolean;
  sortOrder: number;
  publishedAt: string | null;
  createdAt: string;
}

export interface AdminMatchItem extends MatchItem {
  clubId: number | null;
  partnerId: string | null;
  saleStartsAt: string | null;
  capacity: number;
  soldCount: number;
}

export interface AdminMembershipPackage extends MembershipPackage {
  clubId: number | null;
  isActive: boolean;
  createdAt: string;
}

export interface AdminShopProduct extends ShopProduct {
  clubId: number | null;
  sortOrder: number;
  createdAt: string;
}

export interface AdminFanClub extends FanClubItem {
  clubId: number | null;
  isActive: boolean;
  createdAt: string;
}

export interface AdminStandingRow {
  id: string;
  clubId: number | null;
  position: number;
  club: string;
  played: number;
  goalDifference: number;
  points: number;
  form: string[];
  clubSlug: string | null;
}

export interface AdminContributionGroup extends ContributionGroup {
  creatorId: string | null;
  createdAt: string;
  isClosed: boolean;
}

export interface AdminContributionItem {
  id: string;
  groupId: string;
  userId: string;
  amount: number;
  status: string;
  createdAt: string;
}

export interface AdminContributionSnapshot {
  groups: AdminContributionGroup[];
  contributions: AdminContributionItem[];
  : Record<string, string>;
  monthlyTotal: number;
}

export interface AdminNotificationRecord {
  id: string;
  title: string;
  body: string;
  audienceType: "all_fans" | "by_tier" | "by_group";
  audienceTier: string | null;
  audienceGroupId: string | null;
  audienceGroupName: string | null;
  deliveryMode: "send_now" | "schedule";
  status: string;
  scheduledAt: string | null;
  sentAt: string | null;
  requestedRecipientCount: number;
  sentCount: number;
  failedCount: number;
  createdAt: string;
  lastError: string | null;
}

export interface AdminNotificationContext {
  groups: Array<{ id: string; name: string }>;
  history: AdminNotificationRecord[];
}

export interface AdminSmsSyncRun {
  id: string;
  status: string;
  trigger: string;
  scannedMessages: number;
  uploadedMessages: number;
  startedAt: string | null;
}

export interface AdminSmsSnapshot {
  metrics: Record<string, number>;
  syncRuns: AdminSmsSyncRun[];
}
