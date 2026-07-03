/**
 * Public club profile data.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { fallbackClubProfile } from "@/lib/content";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type { ClubProfile } from "@/lib/types";
import { safeNumber, safeString } from "@/lib/utils";
import { sanitizeMediaUrl } from "./helpers";

function mapClubRow(
  row: Record<string, unknown>,
  fallback: ClubProfile,
): ClubProfile {
  const resolvedShortName = safeString(
    row.club_name,
    safeString(row.nickname_brand_identity, fallback.shortName),
  );

  return {
    id: safeNumber(row.id, fallback.id),
    clubName: safeString(row.club_name, fallback.clubName),
    clubSlug: safeString(row.club_slug, fallback.clubSlug),
    shortName: resolvedShortName,
    nickname: safeString(
      row.nickname_brand_identity,
      fallback.nickname,
    ),
    countryCode: safeString(
      row.country_iso_code,
      fallback.countryCode,
    ),
    league: safeString(row.league, fallback.league),
    region: safeString(row.region, fallback.region),
    currencyCode: safeString(
      row.currency_code,
      fallback.currencyCode,
    ),
    currencySymbol: safeString(
      row.currency_symbol,
      fallback.currencySymbol,
    ),
    defaultLanguage: safeString(
      row.default_language,
      fallback.defaultLanguage,
    ),
    supportedLanguages: Array.isArray(row.supported_languages)
      ? row.supported_languages
          .map((entry) => safeString(entry))
          .filter(Boolean)
      : fallback.supportedLanguages,
    officialContact: safeString(
      row.official_contact,
      fallback.officialContact,
    ),
    facebookUrl: safeString(row.facebook_url) || null,
    xUrl: safeString(row.x_twitter_url) || null,
    instagramUrl: safeString(row.instagram_url) || null,
    tiktokUrl: safeString(row.tiktok_url) || null,
    officialLogoUrl: sanitizeMediaUrl(
      row.official_logo_url,
      fallback.officialLogoUrl ?? "/brand-mark.svg",
    ),
    primaryColorHex: safeString(
      row.primary_color_hex,
      fallback.primaryColorHex,
    ),
    secondaryColorHex: safeString(
      row.secondary_color_hex,
      fallback.secondaryColorHex,
    ),
    accentColorHex: safeString(
      row.accent_color_hex,
      fallback.accentColorHex,
    ),
    featureFlags:
      typeof row.feature_flags == "object" && row.feature_flags != null
        ? (row.feature_flags as Record<string, boolean>)
        : fallback.featureFlags,
  };
}

export const getClubProfile = cache(async function getClubProfile() {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  const fallback = {
    ...fallbackClubProfile,
    id: activeClub.numericId,
    clubName: activeClub.name || fallbackClubProfile.clubName,
    clubSlug: activeClub.slug || fallbackClubProfile.clubSlug,
    shortName: activeClub.shortName || fallbackClubProfile.shortName,
  };
  if (client == null) return fallback;

  try {
    const { data } = await client
      .from("african_football_clubs")
      .select("*")
      .eq("club_slug", activeClub.slug)
      .maybeSingle();

    return data ? mapClubRow(data, fallback) : fallback;
  } catch {
    return fallback;
  }
});
