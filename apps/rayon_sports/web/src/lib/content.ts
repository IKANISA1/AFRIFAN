import type { ClubProfile } from "@/lib/types";
import { rayonClub } from "@/lib/config";
import { teamCrestUrl } from "@/lib/team-identity";

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
  supportedLanguages: ["en"],
  officialContact: "Official club channels and matchday help desk",
  facebookUrl: "https://fb.com/RayonSportsOfficial",
  xUrl: "https://x.com/rayon_sports",
  instagramUrl: "https://instagram.com/rayonsports_official",
  tiktokUrl: "https://tiktok.com/@rayonsports",
  officialLogoUrl: teamCrestUrl(rayonClub.name),
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

// Bootstrap identity only, sourced from the four ClubConfig implementations
// and seed-clubs.sql. Fixtures, prices, content and account state stay live.
export const supportedClubProfiles: readonly ClubProfile[] = [
  fallbackClubProfile,
  ...[
    { id: 44, clubName: "Vital'O FC", clubSlug: "vitalo_bi", shortName: "Vital'O",
      countryCode: "BI", currencyCode: "BIF", currencySymbol: "FBu",
      primaryColorHex: "#7B2D8E", secondaryColorHex: "#D1D5DB", accentColorHex: "#FFD700" },
    { id: 26, clubName: "Nkana FC", clubSlug: "nkana_zm", shortName: "Nkana FC",
      countryCode: "ZM", currencyCode: "ZMW", currencySymbol: "ZK",
      primaryColorHex: "#CC0000", secondaryColorHex: "#D1D5DB", accentColorHex: "#000000" },
    { id: 6, clubName: "AS Vita Club", clubSlug: "as_vita_cd", shortName: "AS Vita Club",
      countryCode: "CD", currencyCode: "CDF", currencySymbol: "FC",
      primaryColorHex: "#006400", secondaryColorHex: "#000000", accentColorHex: "#FFD700" },
  ].map((identity) => ({
    ...identity, nickname: identity.shortName, league: "", region: "",
    defaultLanguage: "en", supportedLanguages: ["en"],
    officialContact: "Official club channels and matchday help desk",
    facebookUrl: null, xUrl: null, instagramUrl: null, tiktokUrl: null,
    officialLogoUrl: teamCrestUrl(identity.clubName), featureFlags: {},
  })),
];

export function getSupportedClubProfile(value: string | number) {
  const normalized = String(value).trim().toLowerCase().replace(/-/g, "_");
  return supportedClubProfiles.find((club) =>
    String(club.id) === normalized || club.clubSlug === normalized ||
    club.clubSlug.replace(/_(rw|bi|zm|cd)$/, "") === normalized,
  ) ?? null;
}

export const adminNavigation = [
  { href: "/admin", label: "Dashboard" },
  { href: "/admin/access", label: "Access" },
  { href: "/admin/settings", label: "Settings" },
  { href: "/admin/cms", label: "CMS" },
  { href: "/admin/cms/banners", label: "Banners" },
  { href: "/admin/cms/content", label: "Content" },
  { href: "/admin/cms/content-blocks", label: "Content Blocks" },
  { href: "/admin/cms/config", label: "Config" },
  { href: "/admin/matches", label: "Matches" },
  { href: "/admin/squad", label: "Squad" },
  { href: "/admin/shop", label: "Shop" },
  { href: "/admin/offers", label: "Offers" },
  { href: "/admin/membership", label: "Membership" },
  { href: "/admin/tickets", label: "Tickets" },
  { href: "/admin/gamification", label: "Gamification" },
  { href: "/admin/gamification/wallet", label: "Wallet Ops" },
  { href: "/admin/predictions", label: "Predictions" },
  { href: "/admin/community", label: "Community" },
  { href: "/admin/standings", label: "Standings" },
  { href: "/admin/notifications", label: "Notifications" },
  { href: "/admin/sms-monitor", label: "SMS" },
  { href: "/admin/football-sync", label: "Football Sync" },
  { href: "/admin/settings/features", label: "Features" },
  { href: "/admin/settings/runtime", label: "Runtime" },
  { href: "/admin/settings/audit", label: "Audit Log" },
];
