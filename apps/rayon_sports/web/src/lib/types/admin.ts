/**
 * Admin panel types.
 */
import type {
  ContributionGroup,
  FanClubItem,
  MatchItem,
  MembershipPackage,
  ShopProduct,
} from "./site";

export type AdminRole =
  | "super_admin"
  | "admin"
  | "club_admin"
  | "club_moderator"
  | "fan";

export type AdminAssignableRole = Exclude<AdminRole, "fan">;

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

export interface AdminRoleAssignment {
  id: string;
  userId: string;
  userName: string;
  userPhone: string | null;
  userEmail: string | null;
  publicUserId: string | null;
  role: AdminAssignableRole;
  clubId: string | null;
  clubName: string | null;
  partnerScopeId: string | null;
  partnerName: string | null;
  grantedBy: string | null;
  grantedByName: string | null;
  grantedAt: string;
  revokedAt: string | null;
  isActive: boolean;
  notes: string | null;
}

export interface AdminUserCandidate {
  userId: string;
  fullName: string;
  phone: string | null;
  email: string | null;
  publicUserId: string | null;
  isPlatformAdmin: boolean;
  hasProfile: boolean;
}

export interface AdminClubScopeOption {
  id: string;
  clubName: string;
  shortName: string;
  clubSlug: string;
  currencyCode: string;
  currencySymbol: string;
}

export interface AdminDashboardMetrics {
  activeUsers: number;
  pendingVerifications: number;
  activeSupportCircles: number;
  recentTicketSales: number;
  totalFans: number;
  ticketRevenue: number;
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

export interface AdminMembershipApplication {
  id: string;
  userId: string;
  clubId: number;
  tier: "fan" | "bronze" | "gold" | "platinum";
  status: "pending" | "approved" | "rejected";
  paymentStatus: "unpaid" | "paid" | "failed";
  applicationDate: string;
  reviewDate?: string | null;
  reviewerId?: string | null;
  notes?: string | null;
  userName?: string;
  userPhone?: string;
}

export interface AdminSupporter {
  id: string;
  userId: string;
  displayName: string;
  phone: string | null;
  tier: "fan" | "bronze" | "gold" | "platinum";
  status: "active" | "pending" | "suspended" | "expired";
  points: number;
  chapter: string;
  membershipNumber: string;
  joinedAt: string;
}

export interface AdminShopProduct extends ShopProduct {
  clubId: number | null;
  sortOrder: number;
  createdAt: string;
}

export interface PlatformFeature {
  id: string;
  featureKey: string;
  displayName: string;
  description: string | null;
  category: string | null;
  isEnabled: boolean;
  visibilityState: "visible" | "hidden" | "disabled";
  channels: {
    id: string;
    channel: "mobile" | "web" | "both";
    isEnabled: boolean;
    isVisible: boolean;
    showInNavigation: boolean;
    showOnHome: boolean;
    sortOrder: number;
    routeKey: string | null;
    placementKey: string | null;
  }[];
  rules: {
    authRequired: boolean;
    roleRestrictions: string[];
    dependencyRules: Record<string, any>;
    rolloutRules: Record<string, any>;
  } | null;
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

export interface AdminSmsManualReview {
  reviewId: string;
  rawSmsId: string | null;
  parsedSmsId: string | null;
  userId: string | null;
  sender: string;
  txType: string;
  txCategory: string;
  cashflowBucket: string;
  amount: number;
  currency: string;
  momoTxId: string | null;
  payerName: string | null;
  payeeName: string | null;
  payeeNumberOrCode: string | null;
  merchantCode: string | null;
  smsReceivedAt: string | null;
  reviewCreatedAt: string | null;
  updatedAt: string | null;
  reviewKind: string;
  reason: string;
  notes: string | null;
  smsPreview: string;
}

export interface AdminPendingPaymentIntent {
  id: string;
  userId: string;
  userName: string;
  expectedAmount: number;
  currency: string;
  status: string;
  targetTable: string;
  targetRecordId: string;
  createdAt: string;
  expiresAt: string | null;
  summaryLabel: string;
}

export interface AdminSmsManualReviewWorkspace {
  reviews: AdminSmsManualReview[];
  pendingIntents: AdminPendingPaymentIntent[];
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

export interface AdminFetWalletOverviewRow {
  userId: string;
  publicUserId: string | null;
  displayName: string;
  tier: string;
  balance: number;
  transactionCount: number;
  lastTransactionAt: string | null;
  lifetimeEarned: number;
  lifetimeSpent: number;
}

export interface AdminFetWalletLedgerRow {
  id: string;
  userId: string;
  publicUserId: string | null;
  displayName: string;
  entryType: string;
  direction: "credit" | "debit";
  amount: number;
  balanceAfter: number;
  counterpartyUserId: string | null;
  counterpartyDisplayName: string | null;
  counterpartyPublicUserId: string | null;
  note: string | null;
  referenceType: string | null;
  referenceId: string | null;
  createdAt: string;
}

export interface AdminFetWalletSnapshot {
  overview: AdminFetWalletOverviewRow[];
  ledger: AdminFetWalletLedgerRow[];
}

export interface AdminFetWalletAdjustmentResult {
  status: "success";
  amount: number;
  balance: number;
  referenceId: string | null;
  alreadyProcessed?: boolean;
}
