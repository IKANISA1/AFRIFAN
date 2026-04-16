function parseHostMap(rawValue: string | undefined) {
  if (!rawValue) {
    return {} as Record<string, string>;
  }

  try {
    const parsed = JSON.parse(rawValue) as Record<string, unknown>;
    return Object.fromEntries(
      Object.entries(parsed)
        .map(([host, club]) => [host.trim().toLowerCase(), String(club).trim()])
        .filter(([host, club]) => host.length > 0 && club.length > 0),
    );
  } catch {
    return {} as Record<string, string>;
  }
}

const configuredFanAppUrl = process.env.NEXT_PUBLIC_FAN_APP_URL?.trim() || "";

export const siteConfig = {
  title:
    process.env.NEXT_PUBLIC_SITE_TITLE?.trim() ||
    "Gikundiro | Official Rayon Sports website",
  shortTitle: process.env.NEXT_PUBLIC_SITE_SHORT_TITLE?.trim() || "Gikundiro",
  description:
    process.env.NEXT_PUBLIC_SITE_DESCRIPTION?.trim() ||
    "Official Rayon Sports website for fixtures, tickets, membership, news, shop, supporter Groups, and fan app journeys.",
  siteUrl:
    process.env.NEXT_PUBLIC_SITE_URL?.trim() || "https://gikundiro.com",
  adminUrl:
    process.env.NEXT_PUBLIC_ADMIN_URL?.trim() || "https://admin.gikundiro.com",
  fanAppUrl: configuredFanAppUrl,
  fanAppLandingPath: "/supporters",
  defaultClubSlug:
    process.env.NEXT_PUBLIC_DEFAULT_CLUB_SLUG?.trim() || "rayon_sports_rw",
  defaultClubId: Number.parseInt(
    process.env.NEXT_PUBLIC_DEFAULT_CLUB_ID?.trim() || "24",
    10,
  ),
  clubHostMap: parseHostMap(
    process.env.CLUB_HOST_MAP_JSON ??
    process.env.NEXT_PUBLIC_CLUB_HOST_MAP_JSON,
  ),
};

export const rayonClub = {
  numericId: 24,
  slug: "rayon_sports_rw",
  name: "Rayon Sports FC",
  shortName: "Rayon Sports",
  nickname: "Gikundiro",
  countryCode: "RW",
  currencyCode:
    process.env.NEXT_PUBLIC_CLUB_CURRENCY_CODE?.trim() || "RWF",
  currencySymbol:
    process.env.NEXT_PUBLIC_CLUB_CURRENCY_SYMBOL?.trim() || "RWF",
  primaryColorHex: "#0038A8",
  secondaryColorHex: "#8885F0",
  accentColorHex: "#D4A017",
};

export const publicSupabaseConfig = {
  url: process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() || "",
  anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() || "",
};

export const serverSupabaseConfig = {
  url:
    process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() ||
    process.env.SUPABASE_URL?.trim() ||
    "",
  anonKey:
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() ||
    process.env.SUPABASE_ANON_KEY?.trim() ||
    "",
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY?.trim() || "",
};

export function hasClientSupabase() {
  return Boolean(publicSupabaseConfig.url && publicSupabaseConfig.anonKey);
}

export function hasServerSupabase() {
  return Boolean(serverSupabaseConfig.url && serverSupabaseConfig.anonKey);
}

export function hasAdminSupabase() {
  return Boolean(
    serverSupabaseConfig.url &&
    serverSupabaseConfig.serviceRoleKey,
  );
}

export function absoluteUrl(pathname: string) {
  return new URL(pathname, siteConfig.siteUrl).toString();
}

export function resolveFanAppHref() {
  return siteConfig.fanAppUrl || siteConfig.fanAppLandingPath;
}
