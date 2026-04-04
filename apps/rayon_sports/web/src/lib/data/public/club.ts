/**
 * Public club profile data.
 */
import { cache } from "react";
import { rayonClub } from "@/lib/config";
import { fallbackClubProfile } from "@/lib/content";
import { getAdminSupabase } from "@/lib/supabase/admin";
import type { ClubProfile } from "@/lib/types";
import { safeNumber, safeString } from "@/lib/utils";
import { sanitizeMediaUrl } from "./helpers";

function mapClubRow(row: Record<string, unknown>): ClubProfile {
  return {
    id: safeNumber(row.id, rayonClub.numericId),
    clubName: safeString(row.club_name, fallbackClubProfile.clubName),
    clubSlug: safeString(row.club_slug, fallbackClubProfile.clubSlug),
    shortName: safeString(row.short_name, fallbackClubProfile.shortName),
    nickname: safeString(
      row.nickname_brand_identity,
      fallbackClubProfile.nickname,
    ),
    countryCode: safeString(
      row.country_iso_code,
      fallbackClubProfile.countryCode,
    ),
    league: safeString(row.league, fallbackClubProfile.league),
    region: safeString(row.region, fallbackClubProfile.region),
    currencyCode: safeString(
      row.currency_code,
      fallbackClubProfile.currencyCode,
    ),
    currencySymbol: safeString(
      row.currency_symbol,
      fallbackClubProfile.currencySymbol,
    ),
    defaultLanguage: safeString(
      row.default_language,
      fallbackClubProfile.defaultLanguage,
    ),
    supportedLanguages: Array.isArray(row.supported_languages)
      ? row.supported_languages
          .map((entry) => safeString(entry))
          .filter(Boolean)
      : fallbackClubProfile.supportedLanguages,
    officialContact: safeString(
      row.official_contact,
      fallbackClubProfile.officialContact,
    ),
    facebookUrl: safeString(row.facebook_url) || null,
    xUrl: safeString(row.x_twitter_url) || null,
    instagramUrl: safeString(row.instagram_url) || null,
    tiktokUrl: safeString(row.tiktok_url) || null,
    officialLogoUrl: sanitizeMediaUrl(
      row.official_logo_url,
      fallbackClubProfile.officialLogoUrl ?? "/media/rayon-crest.png",
    ),
    primaryColorHex: safeString(
      row.primary_color_hex,
      fallbackClubProfile.primaryColorHex,
    ),
    secondaryColorHex: safeString(
      row.secondary_color_hex,
      fallbackClubProfile.secondaryColorHex,
    ),
    accentColorHex: safeString(
      row.accent_color_hex,
      fallbackClubProfile.accentColorHex,
    ),
    featureFlags:
      typeof row.feature_flags == "object" && row.feature_flags != null
        ? (row.feature_flags as Record<string, boolean>)
        : fallbackClubProfile.featureFlags,
  };
}

export const getClubProfile = cache(async function getClubProfile() {
  const client = getAdminSupabase();
  if (client == null) return fallbackClubProfile;

  try {
    const { data } = await client
      .from("african_football_clubs")
      .select("*")
      .eq("club_slug", rayonClub.slug)
      .maybeSingle();

    return data ? mapClubRow(data) : fallbackClubProfile;
  } catch {
    return fallbackClubProfile;
  }
});
