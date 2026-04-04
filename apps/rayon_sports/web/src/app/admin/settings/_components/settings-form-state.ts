import type { ClubProfile, FeatureFlags } from "@/lib/types";

export type SettingsForm = {
  id: number;
  clubSlug: string;
  clubName: string;
  shortName: string;
  nickname: string;
  countryCode: string;
  league: string;
  region: string;
  currencyCode: string;
  currencySymbol: string;
  defaultLanguage: string;
  supportedLanguagesText: string;
  officialContact: string;
  facebookUrl: string;
  xUrl: string;
  instagramUrl: string;
  tiktokUrl: string;
  officialLogoUrl: string;
  primaryColorHex: string;
  secondaryColorHex: string;
  accentColorHex: string;
  featureFlags: FeatureFlags;
};

export const defaultFeatureFlags: FeatureFlags = {
  biopay: true,
  chat: true,
  fan_clubs: true,
  shop: true,
  sms_ledger: true,
  ticketing: true,
};

export function profileToForm(profile: ClubProfile): SettingsForm {
  return {
    id: profile.id,
    clubSlug: profile.clubSlug,
    clubName: profile.clubName,
    shortName: profile.shortName,
    nickname: profile.nickname,
    countryCode: profile.countryCode,
    league: profile.league,
    region: profile.region,
    currencyCode: profile.currencyCode,
    currencySymbol: profile.currencySymbol,
    defaultLanguage: profile.defaultLanguage,
    supportedLanguagesText: profile.supportedLanguages.join(", "),
    officialContact: profile.officialContact,
    facebookUrl: profile.facebookUrl ?? "",
    xUrl: profile.xUrl ?? "",
    instagramUrl: profile.instagramUrl ?? "",
    tiktokUrl: profile.tiktokUrl ?? "",
    officialLogoUrl: profile.officialLogoUrl ?? "",
    primaryColorHex: profile.primaryColorHex,
    secondaryColorHex: profile.secondaryColorHex,
    accentColorHex: profile.accentColorHex,
    featureFlags: {
      ...defaultFeatureFlags,
      ...profile.featureFlags,
    },
  };
}

export function formToProfile(form: SettingsForm): ClubProfile {
  return {
    id: form.id,
    clubName: form.clubName.trim(),
    clubSlug: form.clubSlug.trim(),
    shortName: form.shortName.trim(),
    nickname: form.nickname.trim(),
    countryCode: form.countryCode.trim(),
    league: form.league.trim(),
    region: form.region.trim(),
    currencyCode: form.currencyCode.trim(),
    currencySymbol: form.currencySymbol.trim(),
    defaultLanguage: form.defaultLanguage.trim(),
    supportedLanguages: form.supportedLanguagesText
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean),
    officialContact: form.officialContact.trim(),
    facebookUrl: form.facebookUrl.trim() || null,
    xUrl: form.xUrl.trim() || null,
    instagramUrl: form.instagramUrl.trim() || null,
    tiktokUrl: form.tiktokUrl.trim() || null,
    officialLogoUrl: form.officialLogoUrl.trim() || null,
    primaryColorHex: form.primaryColorHex.trim(),
    secondaryColorHex: form.secondaryColorHex.trim(),
    accentColorHex: form.accentColorHex.trim(),
    featureFlags: form.featureFlags,
  };
}
