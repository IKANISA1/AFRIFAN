/**
 * Admin data layer — barrel re-export.
 *
 * Stable import path: `@/lib/data/admin`
 *
 * All 13 domain modules are now fully extracted from admin-legacy.ts:
 *   ✅ access.ts         — RBAC / role resolution
 *   ✅ cms.ts            — news article CRUD
 *   ✅ dashboard.ts      — metrics snapshot & activity
 *   ✅ matches.ts        — match CRUD with column fallback
 *   ✅ settings.ts       — club profile management
 *   ✅ membership.ts     — tier packages CRUD
 *   ✅ shop.ts           — product CRUD
 *   ✅ fan-clubs.ts      — fan clubs CRUD
 *   ✅ standings.ts      — league table CRUD
 *   ✅ contributions.ts  — circles, Excel export, group CRUD
 *   ✅ notifications.ts  — push notification context + delivery
 *   ✅ sms.ts            — SMS monitor sync runs
 *   ✅ squad.ts          — player CRUD
 */

// RBAC
export {
  emptyAdminAccess,
  normalizeAdminRole,
  formatAdminRoleLabel,
  deriveAdminAccess,
  resolveAdminAccess,
} from "./access";

export {
  getAdminRoleAssignments,
  findAdminUserCandidate,
  assignAdminRole,
  revokeAdminRole,
} from "./access-management";

// CMS
export {
  getAdminArticles,
  saveAdminArticle,
  deleteAdminArticle,
} from "./cms";

export {
  getAdminAppConfig,
  saveAdminConfigEntry,
  deleteAdminConfigEntry,
} from "./cms-content";

// Dashboard
export { getAdminDashboardSnapshot } from "./dashboard";

// Matches
export {
  getAdminMatches,
  saveAdminMatch,
  deleteAdminMatch,
} from "./matches";

// Settings
export {
  getAdminClubScopeOptions,
  getAdminClubProfile,
  saveAdminClubProfile,
} from "./settings";

// Membership
export {
  getAdminMembershipPackages,
  saveAdminMembershipPackage,
  deleteAdminMembershipPackage,
} from "./membership";

// Shop
export {
  getAdminProducts,
  saveAdminProduct,
  deleteAdminProduct,
} from "./shop";

// Fan Clubs
export {
  getAdminFanClubs,
  saveAdminFanClub,
  deleteAdminFanClub,
} from "./fan-clubs";

// Standings
export {
  getAdminStandings,
  saveAdminStandingRow,
  deleteAdminStandingRow,
} from "./standings";

// Contributions
export {
  getAdminContributionSnapshot,
  buildContributionExcel,
  downloadContributionExcel,
  saveAdminContributionGroup,
  deleteAdminContributionGroup,
} from "./contributions";

// Notifications
export {
  getAdminNotificationContext,
  sendAdminNotification,
} from "./notifications";

// SMS
export {
  getAdminSmsSnapshot,
  getAdminSmsManualReviewWorkspace,
  allocateAdminSmsManualReview,
  rejectAdminSmsManualReview,
} from "./sms";

// Squad
export {
  getAdminSquad,
  saveAdminSquadPlayer,
  deleteAdminSquadPlayer,
} from "./squad";

export type { AdminSquadPlayer } from "./squad";

// Gamification / FET
export {
  getAdminFanEngagementTokens,
  saveAdminFanEngagementToken,
  deleteAdminFanEngagementToken,
} from "./gamification";

export {
  getAdminFetWalletSnapshot,
  adjustAdminFetWalletBalance,
} from "./fet-wallet";
