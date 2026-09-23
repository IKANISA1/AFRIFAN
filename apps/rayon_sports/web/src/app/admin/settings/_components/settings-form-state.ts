import type { FeatureFlags } from "@/lib/types";
import type {
  AdminClubProfile,
  AdminClubProfileInput,
} from "@/lib/data/admin/settings";

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
  expectedUpdatedAt: string;
};

export function profileToForm(profile: AdminClubProfile): SettingsForm {
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
    defaultLanguage: "en",
    supportedLanguagesText: "en",
    officialContact: profile.officialContact,
    facebookUrl: profile.facebookUrl ?? "",
    xUrl: profile.xUrl ?? "",
    instagramUrl: profile.instagramUrl ?? "",
    tiktokUrl: profile.tiktokUrl ?? "",
    officialLogoUrl: profile.officialLogoUrl ?? "",
    primaryColorHex: profile.primaryColorHex,
    secondaryColorHex: profile.secondaryColorHex,
    accentColorHex: profile.accentColorHex,
    featureFlags: { ...profile.featureFlags },
    expectedUpdatedAt: profile.updatedAt,
  };
}

export function formToProfile(form: SettingsForm): AdminClubProfileInput {
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
    defaultLanguage: "en".trim(),
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
    expectedUpdatedAt: form.expectedUpdatedAt,
  };
}
