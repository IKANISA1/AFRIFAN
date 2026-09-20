import { cache } from "react";
import { headers } from "next/headers";
import { siteConfig } from "@/lib/config";
import { isAdminHostname, resolveRoutingHostname } from "@/lib/host-routing";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import { safeNumber, safeString } from "@/lib/utils";
import { getSupportedClubProfile, fallbackClubProfile } from "@/lib/content";

type ClubLookupRow = Record<string, unknown>;

export interface ActiveClubReference {
  numericId: number;
  slug: string;
  name: string;
  shortName: string;
}

function defaultClubReference(): ActiveClubReference {
  const club = getSupportedClubProfile(siteConfig.defaultClubId)
    ?? getSupportedClubProfile(siteConfig.defaultClubSlug) ?? fallbackClubProfile;
  return {
    numericId: club.id,
    slug: club.clubSlug,
    name: club.clubName,
    shortName: club.shortName,
  };
}

function normalizeCandidate(value: string) {
  const trimmed = value.trim().toLowerCase();
  if (!trimmed) {
    return null;
  }
  return trimmed.replace(/-/g, "_");
}

function getHostOverride(hostname: string) {
  if (!hostname) {
    return null;
  }

  const normalized = hostname.replace(/^www\./, "");
  return (
    siteConfig.clubHostMap[hostname] ??
    siteConfig.clubHostMap[normalized] ??
    null
  );
}

function buildSlugCandidates(hostname: string) {
  const candidates = new Set<string>();
  const override = getHostOverride(hostname);
  if (override && Number.isNaN(Number(override))) {
    const normalizedOverride = normalizeCandidate(override);
    if (normalizedOverride) {
      candidates.add(normalizedOverride);
    }
  }

  if (!hostname || isAdminHostname(hostname)) {
    return [...candidates];
  }

  const firstLabel = hostname
    .replace(/^www\./, "")
    .split(".")[0]
    ?.trim()
    .toLowerCase();
  if (
    firstLabel &&
    firstLabel !== "admin" &&
    firstLabel !== "www" &&
    firstLabel !== "fans"
  ) {
    const normalizedLabel = normalizeCandidate(firstLabel);
    const supported = normalizedLabel && getSupportedClubProfile(normalizedLabel);
    if (supported) {
      candidates.add(supported.clubSlug);
    }
  }

  candidates.add(defaultClubReference().slug);

  return [...candidates];
}

function mapClubRow(row: ClubLookupRow | null | undefined) {
  const supported = row && getSupportedClubProfile(safeNumber(row.id, -1));
  if (!row || !supported) {
    return null;
  }

  return {
    numericId: supported.id,
    slug: safeString(row.club_slug, supported.clubSlug),
    name: safeString(row.club_name, supported.clubName),
    shortName: safeString(row.club_name, supported.shortName),
  } satisfies ActiveClubReference;
}

async function fetchClubById(id: number) {
  const client = getReadOnlySupabase();
  if (client == null) {
    return null;
  }

  try {
    const { data } = await client
      .from("african_football_clubs")
      .select("id, club_slug, club_name, nickname_brand_identity")
      .eq("id", id)
      .maybeSingle();

    return mapClubRow(data);
  } catch {
    return null;
  }
}

async function fetchClubBySlug(slug: string) {
  const client = getReadOnlySupabase();
  if (client == null) {
    return null;
  }

  try {
    const { data } = await client
      .from("african_football_clubs")
      .select("id, club_slug, club_name, nickname_brand_identity")
      .eq("club_slug", slug)
      .maybeSingle();

    return mapClubRow(data);
  } catch {
    return null;
  }
}

async function getRequestHostname() {
  try {
    const headersList = await headers();
    return resolveRoutingHostname(
      headersList.get("x-forwarded-host"),
      headersList.get("host"),
    );
  } catch {
    return "";
  }
}

export const getActiveClubReference = cache(
  async function getActiveClubReference(): Promise<ActiveClubReference> {
    const defaultClub = defaultClubReference();
    const hostname = await getRequestHostname();

    const override = getHostOverride(hostname);
    if (override) {
      const supported = getSupportedClubProfile(override);
      if (supported) {
        return (await fetchClubById(supported.id)) ?? {
          numericId: supported.id, slug: supported.clubSlug,
          name: supported.clubName, shortName: supported.shortName,
        };
      }
    }

    for (const finalSlug of buildSlugCandidates(hostname)) {
      const supported = getSupportedClubProfile(finalSlug);
      if (!supported) continue;
      const resolved = await fetchClubBySlug(finalSlug);
      if (resolved) {
        return resolved;
      }
      return { numericId: supported.id, slug: supported.clubSlug,
        name: supported.clubName, shortName: supported.shortName };
    }

    return defaultClub;
  },
);
