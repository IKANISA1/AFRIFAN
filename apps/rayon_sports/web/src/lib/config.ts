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

export type FanAppDestinations = { ios?: string; android?: string; web?: string };

function secureAppUrl(value: unknown) {
  if (typeof value !== "string" || value.length > 2048) return undefined;
  try {
    const url = new URL(value.trim());
    return url.protocol === "https:" && !url.username && !url.password
      ? url.toString()
      : undefined;
  } catch { return undefined; }
}

/** Published URLs belong to an explicitly named club, never every host. */
export function parseFanAppDestinations(raw: string | undefined) {
  const result = Object.create(null) as Record<string, FanAppDestinations>;
  try {
    const entries: unknown = JSON.parse(raw || "{}");
    if (!entries || typeof entries !== "object" || Array.isArray(entries)) return result;
    for (const [slug, value] of Object.entries(entries)) {
      if (!value || typeof value !== "object" || Array.isArray(value)) continue;
      const routes = value as Record<string, unknown>;
      const key = slug.trim().toLowerCase().replace(/-/g, "_");
      if (!/^[a-z0-9_]{1,80}$/.test(key) || ["__proto__", "constructor", "prototype"].includes(key)) continue;
      result[key] = {
        ios: secureAppUrl(routes.ios),
        android: secureAppUrl(routes.android),
        web: secureAppUrl(routes.web),
      };
    }
  } catch { /* Unverified configuration leaves app destinations unavailable. */ }
  return result;
}

export const siteConfig = {
  title:
    process.env.NEXT_PUBLIC_SITE_TITLE?.trim() ||
    "Gikundiro | Rayon Sports supporters",
  shortTitle: process.env.NEXT_PUBLIC_SITE_SHORT_TITLE?.trim() || "Gikundiro",
  description:
    process.env.NEXT_PUBLIC_SITE_DESCRIPTION?.trim() ||
    "Gikundiro brings Rayon Sports supporters together for fixtures, tickets, membership, news, shop, and fan clubs.",
  siteUrl:
    process.env.NEXT_PUBLIC_SITE_URL?.trim() || "https://gikundiro.com",
  adminUrl:
    process.env.NEXT_PUBLIC_ADMIN_URL?.trim() || "https://admin.gikundiro.com",
  fanAppUrl: configuredFanAppUrl,
  fanAppLandingPath: "/app",
  // e.g. {"nkana_zm":{"ios":"https://…","android":"https://…"}}.
  fanAppDestinations: parseFanAppDestinations(process.env.NEXT_PUBLIC_FAN_APP_DESTINATIONS_JSON),
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

export function getFanAppDestinations(clubSlug: string): FanAppDestinations {
  const slug = clubSlug.trim().toLowerCase().replace(/-/g, "_");
  const scoped = siteConfig.fanAppDestinations[slug];
  if (scoped) return scoped;
  // The legacy single URL describes only its configured default club.
  if (slug === siteConfig.defaultClubSlug.replace(/-/g, "_")) {
    return { web: secureAppUrl(siteConfig.fanAppUrl) };
  }
  return {};
}

export function hasFanAppDestination(clubSlug: string) {
  return Object.values(getFanAppDestinations(clubSlug)).some(Boolean);
}

export function resolveFanAppHref(clubSlug?: string) {
  // Context-free recovery pages must never inherit a different club's URL.
  return clubSlug ? getFanAppDestinations(clubSlug).web || siteConfig.fanAppLandingPath
    : siteConfig.fanAppLandingPath;
}
