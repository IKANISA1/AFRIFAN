export const siteConfig = {
  title: "Gikundiro | Official Rayon Sports website",
  shortTitle: "Gikundiro",
  description:
    "Official Rayon Sports website for fixtures, tickets, membership, news, shop, supporter circles, and live matchday coverage.",
  siteUrl:
    process.env.NEXT_PUBLIC_SITE_URL?.trim() || "https://gikundiro.com",
  fansUrl:
    process.env.NEXT_PUBLIC_FANS_URL?.trim() || "https://fans.gikundiro.com",
  adminUrl:
    process.env.NEXT_PUBLIC_ADMIN_URL?.trim() || "https://admin.gikundiro.com",
};

export const rayonClub = {
  numericId: 24,
  slug: "rayon_sports_rw",
  name: "Rayon Sports FC",
  shortName: "Rayon Sports",
  nickname: "Gikundiro",
  countryCode: "RW",
  currencyCode: "RWF",
  currencySymbol: "FRw",
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
  return Boolean(
    serverSupabaseConfig.url &&
      (serverSupabaseConfig.serviceRoleKey || serverSupabaseConfig.anonKey),
  );
}

export function absoluteUrl(pathname: string) {
  return new URL(pathname, siteConfig.siteUrl).toString();
}
