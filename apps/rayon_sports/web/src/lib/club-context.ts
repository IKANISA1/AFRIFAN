import { cache } from "react";
import { headers } from "next/headers";
import { rayonClub, siteConfig } from "@/lib/config";
import { isAdminHostname, resolveRoutingHostname } from "@/lib/host-routing";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import { safeNumber, safeString } from "@/lib/utils";

type ClubLookupRow = Record<string, unknown>;

export interface ActiveClubReference {
  numericId: number;
  slug: string;
  name: string;
  shortName: string;
}

function defaultClubReference(): ActiveClubReference {
  return {
    numericId: Number.isFinite(siteConfig.defaultClubId)
      ? siteConfig.defaultClubId
      : rayonClub.numericId,
    slug: siteConfig.defaultClubSlug || rayonClub.slug,
    name: rayonClub.name,
    shortName: rayonClub.shortName,
  };
}

function normalizeCandidate(value: string) {
  const trimmed = value.trim().toLowerCase();
  if (!trimmed) {
    return null;
  }
  return trimmed.replace(/-/g, "_");
}

function resolveClubShortName(row: ClubLookupRow | null | undefined) {
  return safeString(
    row?.club_name,
    safeString(row?.nickname_brand_identity, rayonClub.shortName),
  );
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

  if (siteConfig.defaultClubSlug) {
    const normalizedDefault = normalizeCandidate(siteConfig.defaultClubSlug);
    if (normalizedDefault) {
      candidates.add(normalizedDefault);
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
    if (normalizedLabel) {
      candidates.add(normalizedLabel);
    }
  }

  return [...candidates];
}

function mapClubRow(row: ClubLookupRow | null | undefined) {
  if (row == null) {
    return null;
  }

  return {
    numericId: safeNumber(row.id, rayonClub.numericId),
    slug: safeString(row.club_slug, rayonClub.slug),
    name: safeString(row.club_name, rayonClub.name),
    shortName: resolveClubShortName(row),
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
      const numericOverride = Number.parseInt(override, 10);
      if (Number.isFinite(numericOverride)) {
        return (await fetchClubById(numericOverride)) ?? defaultClub;
      }

      const resolvedOverride = await fetchClubBySlug(
        normalizeCandidate(override) ?? override,
      );
      if (resolvedOverride) {
        return resolvedOverride;
      }
    }

    for (const finalSlug of buildSlugCandidates(hostname)) {
      const resolved = await fetchClubBySlug(finalSlug);
      if (resolved) {
        return resolved;
      }
    }

    return defaultClub;
  },
);
