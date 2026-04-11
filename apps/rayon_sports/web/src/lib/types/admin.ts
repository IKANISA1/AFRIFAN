/**
 * Admin panel types.
 */
import type { ContributionGroup, FanClubItem, MatchItem, MembershipPackage, ShopProduct } from "./site";
import type { FantasyCompetitionMode } from "./site";

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
  availableClubIds: string[];
  canSelectClub: boolean;
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
  aliases: Record<string, string>;
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

export type AdminFanEngagementTemplateScope = "generic" | "club_specific";

export interface AdminFanEngagementToken {
  id: string;
  clubId: number | null;
  code: string;
  templateScope: AdminFanEngagementTemplateScope;
  category: string;
  itemName: string;
  fetValue: number;
  triggerCondition: string;
  activationTiming: string;
  description: string;
  badgeName: string;
  implementationNotes: string | null;
  sortOrder: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AdminFantasyCompetition {
  id: string;
  clubId: number | null;
  slug: string;
  name: string;
  shortName: string;
  season: string;
  description: string;
  mode: FantasyCompetitionMode;
  backendStatus: "draft" | "active" | "finished";
  primaryColor: string;
  logoUrl: string | null;
  countryCode: string | null;
  provider: string | null;
  externalLeagueId: number | null;
  promoTitle: string | null;
  promoBody: string | null;
  badgeLabel: string | null;
  ctaLabel: string | null;
  heroImageUrl: string | null;
  sortOrder: number;
  isVisible: boolean;
  isFeatured: boolean;
  isPlayable: boolean;
  activeEntries: number;
  startAt: string;
  endAt: string;
  entryWindowOpensAt: string | null;
  entryWindowClosesAt: string | null;
}

export type AdminFantasyPlayerPosition = "GK" | "DEF" | "MID" | "FWD";
export type AdminFantasyGameweekStatus =
  | "upcoming"
  | "live"
  | "scoring"
  | "finished";

export interface AdminFantasyPlayer {
  id: string;
  competitionId: string;
  externalId: number;
  name: string;
  shortName: string;
  position: AdminFantasyPlayerPosition;
  teamId: number;
  teamName: string;
  teamShort: string;
  nationality: string | null;
  photoUrl: string | null;
  teamLogoUrl: string | null;
  price: number;
  priceChange: number;
  ownershipPercent: number;
  updatedAt: string;
}

export interface AdminFantasyGameweek {
  id: string;
  competitionId: string;
  number: number;
  name: string;
  status: AdminFantasyGameweekStatus;
  deadlineAt: string;
  startAt: string;
  endAt: string;
  isDoubleGameweek: boolean;
  averageScore: number | null;
  highestScore: number | null;
}

export interface AdminFantasyOperationsSnapshot {
  competitionId: string;
  players: AdminFantasyPlayer[];
  gameweeks: AdminFantasyGameweek[];
  leagueCount: number;
  headToHeadFixtureCount: number;
  injuryCount: number;
  notificationTopic: string | null;
  nextDeadlineAt: string | null;
}
