/**
 * Admin settings — club profile management.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import { fallbackClubProfile } from "@/lib/content";
import type { ClubProfile } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { clubTable, mutateRecordWithVariants } from "./helpers";

function mapAdminClubProfile(row: Record<string, unknown>): ClubProfile {
  return {
    id: safeNumber(row.id, fallbackClubProfile.id),
    clubName: safeString(row.club_name, fallbackClubProfile.clubName),
    clubSlug: safeString(row.club_slug, fallbackClubProfile.clubSlug),
    shortName: safeString(row.short_name, fallbackClubProfile.shortName),
    nickname: safeString(row.nickname_brand_identity, fallbackClubProfile.nickname),
    countryCode: safeString(row.country_iso_code, fallbackClubProfile.countryCode),
    league: safeString(row.league, fallbackClubProfile.league),
    region: safeString(row.region, fallbackClubProfile.region),
    currencyCode: safeString(row.currency_code, fallbackClubProfile.currencyCode),
    currencySymbol: safeString(row.currency_symbol, fallbackClubProfile.currencySymbol),
    defaultLanguage: safeString(row.default_language, fallbackClubProfile.defaultLanguage),
    supportedLanguages: Array.isArray(row.supported_languages)
      ? row.supported_languages.map((entry) => safeString(entry)).filter(Boolean)
      : fallbackClubProfile.supportedLanguages,
    officialContact: safeString(row.official_contact, fallbackClubProfile.officialContact),
    facebookUrl: safeString(row.facebook_url) || null,
    xUrl: safeString(row.x_twitter_url) || null,
    instagramUrl: safeString(row.instagram_url) || null,
    tiktokUrl: safeString(row.tiktok_url) || null,
    officialLogoUrl: safeString(row.official_logo_url) || null,
    primaryColorHex: safeString(row.primary_color_hex, fallbackClubProfile.primaryColorHex),
    secondaryColorHex: safeString(row.secondary_color_hex, fallbackClubProfile.secondaryColorHex),
    accentColorHex: safeString(row.accent_color_hex, fallbackClubProfile.accentColorHex),
    featureFlags:
      typeof row.feature_flags === "object" && row.feature_flags != null
        ? (row.feature_flags as Record<string, boolean>)
        : fallbackClubProfile.featureFlags,
  };
}

export async function getAdminClubProfile(client: SupabaseClient): Promise<ClubProfile> {
  const { data, error } = await client
    .from(clubTable)
    .select("*")
    .eq("club_slug", rayonClub.slug)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data ? mapAdminClubProfile(data as Record<string, unknown>) : fallbackClubProfile;
}

export async function saveAdminClubProfile(client: SupabaseClient, input: ClubProfile) {
  const payload = {
    club_name: input.clubName.trim(),
    club_slug: rayonClub.slug,
    short_name: input.shortName.trim(),
    nickname_brand_identity: input.nickname.trim(),
    country_iso_code: input.countryCode.trim(),
    league: input.league.trim(),
    region: input.region.trim(),
    currency_code: input.currencyCode.trim(),
    currency_symbol: input.currencySymbol.trim(),
    default_language: input.defaultLanguage.trim(),
    supported_languages: input.supportedLanguages,
    official_contact: input.officialContact.trim(),
    facebook_url: safeString(input.facebookUrl) || null,
    x_twitter_url: safeString(input.xUrl) || null,
    instagram_url: safeString(input.instagramUrl) || null,
    tiktok_url: safeString(input.tiktokUrl) || null,
    official_logo_url: safeString(input.officialLogoUrl) || null,
    primary_color_hex: input.primaryColorHex.trim(),
    secondary_color_hex: input.secondaryColorHex.trim(),
    accent_color_hex: input.accentColorHex.trim(),
    feature_flags: input.featureFlags,
  };
  const payloadWithoutShortName = Object.fromEntries(
    Object.entries(payload).filter(([key]) => key !== "short_name"),
  ) as Record<string, unknown>;

  const existing = await client
    .from(clubTable)
    .select("id")
    .eq("club_slug", rayonClub.slug)
    .maybeSingle();

  if (existing.error) {
    throw new Error(existing.error.message);
  }

  const existingId = existing.data?.id
    ? toIdString(existing.data.id, crypto.randomUUID())
    : null;
  const payloadVariants = existingId
    ? [payload, payloadWithoutShortName]
    : [
        { id: rayonClub.numericId, ...payload },
        { id: rayonClub.numericId, ...payloadWithoutShortName },
        payload,
        payloadWithoutShortName,
      ];

  return mutateRecordWithVariants(client, clubTable, existingId, payloadVariants);
}
