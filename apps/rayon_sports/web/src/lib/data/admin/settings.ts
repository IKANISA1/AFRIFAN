/**
 * Admin settings — strict, club-scoped profile management.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminClubScopeOption,
  ClubProfile,
  FeatureFlags,
} from "@/lib/types";
import {
  isValidHexColor,
  normalizeHexColorInput,
} from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  clubTable,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const MAX_CLUB_SCOPE_OPTIONS = 500;
const MAX_FEATURE_FLAGS = 50;
const profileProjection = [
  "id",
  "club_name",
  "club_slug",
  "nickname_brand_identity",
  "country_iso_code",
  "league",
  "region",
  "currency_code",
  "currency_symbol",
  "default_language",
  "supported_languages",
  "official_contact",
  "facebook_url",
  "x_twitter_url",
  "instagram_url",
  "tiktok_url",
  "official_logo_url",
  "primary_color_hex",
  "secondary_color_hex",
  "accent_color_hex",
  "feature_flags",
  "updated_at",
].join(", ");

export interface AdminClubProfile extends ClubProfile {
  updatedAt: string;
}

export interface AdminClubProfileInput extends ClubProfile {
  expectedUpdatedAt: string;
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength) ?? undefined;
}

function positiveInteger(value: unknown) {
  return typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value > 0
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function normalizeHttpsUrl(value: unknown) {
  const text = nullableText(value, 2_048);
  if (text == null || text === undefined) return text;
  try {
    const url = new URL(text);
    return url.protocol === "https:" &&
      url.username === "" &&
      url.password === "" &&
      url.hash === ""
      ? url.toString()
      : undefined;
  } catch {
    return undefined;
  }
}

function normalizeFeatureFlags(value: unknown): FeatureFlags | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const entries = Object.entries(value);
  if (entries.length > MAX_FEATURE_FLAGS) {
    return null;
  }

  const flags: FeatureFlags = {};
  for (const [key, enabled] of entries) {
    if (
      !/^[a-z][a-z0-9_]{0,63}$/.test(key) ||
      typeof enabled !== "boolean"
    ) {
      return null;
    }
    flags[key] = enabled;
  }
  return flags;
}



export function normalizeAdminClubProfile(
  value: unknown,
): AdminClubProfile | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  const id = positiveInteger(row.id);
  const clubName = boundedText(row.clubName ?? row.club_name, 160);
  const clubSlug = boundedText(row.clubSlug ?? row.club_slug, 160);
  const nickname = boundedText(
    row.nickname ?? row.nickname_brand_identity,
    120,
  );
  const shortName =
    boundedText(row.shortName ?? row.short_name, 80) ?? nickname;
  const countryCode = boundedText(
    row.countryCode ?? row.country_iso_code,
    2,
  )?.toUpperCase();
  const league =
    nullableText(row.league, 160);
  const region =
    nullableText(row.region, 160);
  const currencyCode = boundedText(
    row.currencyCode ?? row.currency_code,
    3,
  )?.toUpperCase();
  const currencySymbol = boundedText(
    row.currencySymbol ?? row.currency_symbol,
    12,
  );
  const defaultLanguage = "en";
  const supportedLanguages = ["en"];
  const officialContact =
    nullableText(row.officialContact ?? row.official_contact, 500);
  const facebookUrl = normalizeHttpsUrl(row.facebookUrl ?? row.facebook_url);
  const xUrl = normalizeHttpsUrl(row.xUrl ?? row.x_twitter_url);
  const instagramUrl = normalizeHttpsUrl(
    row.instagramUrl ?? row.instagram_url,
  );
  const tiktokUrl = normalizeHttpsUrl(row.tiktokUrl ?? row.tiktok_url);
  const officialLogoUrl = normalizeHttpsUrl(
    row.officialLogoUrl ?? row.official_logo_url,
  );
  const primaryColorHex = normalizeHexColorInput(
    boundedText(row.primaryColorHex ?? row.primary_color_hex, 7) ?? "",
  );
  const secondaryColorHex = normalizeHexColorInput(
    boundedText(row.secondaryColorHex ?? row.secondary_color_hex, 7) ?? "",
  );
  const accentColorHex = normalizeHexColorInput(
    boundedText(row.accentColorHex ?? row.accent_color_hex, 7) ?? "",
  );
  const featureFlags = normalizeFeatureFlags(
    row.featureFlags ?? row.feature_flags,
  );
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);

  if (
    id == null ||
    clubName == null ||
    clubSlug == null ||
    !/^[a-z0-9]+(?:[-_][a-z0-9]+)*$/.test(clubSlug) ||
    shortName == null ||
    nickname == null ||
    countryCode == null ||
    !/^[A-Z]{2}$/.test(countryCode) ||
    league === undefined ||
    region === undefined ||
    currencyCode == null ||
    !/^[A-Z]{3}$/.test(currencyCode) ||
    currencySymbol == null ||
    defaultLanguage == null ||
    supportedLanguages == null ||
    !supportedLanguages.includes(defaultLanguage) ||
    officialContact === undefined ||
    facebookUrl === undefined ||
    xUrl === undefined ||
    instagramUrl === undefined ||
    tiktokUrl === undefined ||
    officialLogoUrl === undefined ||
    !isValidHexColor(primaryColorHex) ||
    !isValidHexColor(secondaryColorHex) ||
    !isValidHexColor(accentColorHex) ||
    featureFlags == null ||
    updatedAt == null
  ) {
    return null;
  }

  return {
    id,
    clubName,
    clubSlug,
    shortName,
    nickname,
    countryCode,
    league: league ?? "",
    region: region ?? "",
    currencyCode,
    currencySymbol,
    defaultLanguage,
    supportedLanguages,
    officialContact: officialContact ?? "",
    facebookUrl,
    xUrl,
    instagramUrl,
    tiktokUrl,
    officialLogoUrl,
    primaryColorHex,
    secondaryColorHex,
    accentColorHex,
    featureFlags,
    updatedAt,
  };
}

function normalizeAdminClubScopeOption(
  value: unknown,
): AdminClubScopeOption | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  // Database IDs arrive as numbers; the admin API serializes selector IDs as
  // canonical decimal strings. Both representations must survive this boundary.
  const id = positiveInteger(
    typeof row.id === "string" && /^[1-9][0-9]*$/.test(row.id)
      ? Number(row.id)
      : row.id,
  );
  const clubName = boundedText(row.clubName ?? row.club_name, 160);
  const shortName =
    boundedText(row.shortName ?? row.short_name, 80) ??
    boundedText(row.nickname_brand_identity, 120);
  const clubSlug = boundedText(row.clubSlug ?? row.club_slug, 160);
  const currencyCode = boundedText(
    row.currencyCode ?? row.currency_code,
    3,
  )?.toUpperCase();
  const currencySymbol = boundedText(
    row.currencySymbol ?? row.currency_symbol,
    12,
  );
  if (
    id == null ||
    clubName == null ||
    shortName == null ||
    clubSlug == null ||
    !/^[a-z0-9]+(?:[-_][a-z0-9]+)*$/.test(clubSlug) ||
    currencyCode == null ||
    !/^[A-Z]{3}$/.test(currencyCode) ||
    currencySymbol == null
  ) {
    return null;
  }
  return {
    id: id.toString(),
    clubName,
    shortName,
    clubSlug,
    currencyCode,
    currencySymbol,
  };
}

function normalizeAdminClubScopeOptions(value: unknown) {
  if (!Array.isArray(value)) return [];
  const options: AdminClubScopeOption[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_CLUB_SCOPE_OPTIONS)) {
    const option = normalizeAdminClubScopeOption(entry);
    if (option != null && !seen.has(option.id)) {
      options.push(option);
      seen.add(option.id);
    }
  }
  return options;
}

export async function getAdminClubScopeOptions(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminClubScopeOption[]> {
  if (typeof window !== "undefined") {
    return normalizeAdminClubScopeOptions(
      await requestAdminApi<unknown>("club-scope"),
    );
  }

  let query = client
    .from(clubTable)
    .select(
      "id, club_name, nickname_brand_identity, club_slug, currency_code, currency_symbol",
    )
    .order("club_name", { ascending: true })
    .limit(MAX_CLUB_SCOPE_OPTIONS);

  if (!access.isSuperAdmin) {
    const allowedIds = access.availableClubIds
      .map((value) => Number(value))
      .filter(
        (value) => Number.isSafeInteger(value) && value > 0,
      );
    if (allowedIds.length === 0) {
      return [];
    }
    query = query.in("id", allowedIds);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(error.message);
  }
  return normalizeAdminClubScopeOptions(data);
}

export async function getAdminClubProfile(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminClubProfile | null> {
  if (typeof window !== "undefined") {
    const response = await requestAdminApi<unknown>("settings", {
      signal: options.signal,
    });
    if (response == null) {
      return null;
    }
    const profile = normalizeAdminClubProfile(response);
    if (profile == null) {
      throw new Error("The club settings response was invalid.");
    }
    return profile;
  }

  const clubId = requireAdminClubId(access, "load club settings");
  const { data, error } = await client
    .from(clubTable)
    .select(profileProjection)
    .eq("id", clubId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }
  if (data == null) {
    return null;
  }

  const profile = normalizeAdminClubProfile(data);
  if (profile == null) {
    throw new Error("The stored club settings failed validation.");
  }
  return profile;
}

function requireProfileInput(input: AdminClubProfileInput) {
  const profile = normalizeAdminClubProfile({
    ...input,
    updatedAt: input.expectedUpdatedAt,
  });
  if (profile == null) {
    throw new Error("Review the club settings and correct invalid values.");
  }
  return profile;
}

export async function saveAdminClubProfile(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminClubProfileInput,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("settings", {
      method: "POST",
      body: input,
    });
  }
  if (!access.isSuperAdmin && access.role !== "club_admin") {
    throw new Error("Club admin access is required to update settings.");
  }

  const clubId = requireAdminClubId(access, "save club settings");
  const profile = requireProfileInput(input);
  if (profile.id !== clubId) {
    throw new Error("Club settings can only be changed in the active scope.");
  }

  const existing = await client
    .from(clubTable)
    .select("id, club_slug")
    .eq("id", clubId)
    .maybeSingle();
  if (existing.error) {
    throw new Error(existing.error.message);
  }
  if (existing.data == null) {
    throw new Error("The selected club settings record no longer exists.");
  }
  if (existing.data.club_slug !== profile.clubSlug) {
    throw new Error("The locked club scope changed. Reload settings.");
  }

  const payload = {
    club_name: profile.clubName,
    club_slug: profile.clubSlug,
    short_name: profile.shortName,
    nickname_brand_identity: profile.nickname,
    country_iso_code: profile.countryCode,
    league: profile.league || null,
    region: profile.region || null,
    currency_code: profile.currencyCode,
    currency_symbol: profile.currencySymbol,
    default_language: profile.defaultLanguage,
    supported_languages: profile.supportedLanguages,
    official_contact: profile.officialContact || null,
    facebook_url: profile.facebookUrl,
    x_twitter_url: profile.xUrl,
    instagram_url: profile.instagramUrl,
    tiktok_url: profile.tiktokUrl,
    official_logo_url: profile.officialLogoUrl,
    primary_color_hex: profile.primaryColorHex,
    secondary_color_hex: profile.secondaryColorHex,
    accent_color_hex: profile.accentColorHex,
    feature_flags: profile.featureFlags,
  };
  const payloadWithoutShortName = Object.fromEntries(
    Object.entries(payload).filter(([key]) => key !== "short_name"),
  ) as Record<string, unknown>;

  return mutateRecordWithVariantsIfUnchanged(
    client,
    clubTable,
    clubId.toString(),
    profile.updatedAt,
    [payload, payloadWithoutShortName],
    { id: clubId },
  );
}
