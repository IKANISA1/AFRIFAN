/**
 * Admin partner offers — strict, club-scoped CRUD for FET partner journeys.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const MAX_OFFER_RECORDS = 500;
const MAX_OPTION_RECORDS = 500;

const verificationModes = [
  "api_confirmation",
  "renewal_confirmation",
  "referral_conversion",
  "receipt_scan",
  "geo_checkin",
  "social_share",
  "community_savings",
  "ecommerce_confirmation",
  "mobility_confirmation",
  "event_qr",
  "manual_review",
] as const;

export type AdminOfferVerificationMode = (typeof verificationModes)[number];

export interface AdminOfferCatalogOption {
  id: string;
  code: string;
  itemName: string;
  fetValue: number;
}

export interface AdminOfferPartnerOption {
  id: string;
  name: string;
  slug: string;
  category: string;
}

export interface AdminPartnerOffer {
  id: string;
  clubId: number;
  catalogItemId: string;
  code: string;
  title: string;
  fetValue: number;
  partnerId: string;
  partnerName: string;
  partnerSlug: string;
  partnerCategory: string;
  subtitle: string;
  ctaLabel: string;
  verificationMode: AdminOfferVerificationMode;
  deeplinkRoute: string | null;
  externalUrl: string | null;
  isFeatured: boolean;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface AdminOffersWorkspace {
  offers: AdminPartnerOffer[];
  catalog: AdminOfferCatalogOption[];
  partners: AdminOfferPartnerOption[];
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength);
}

function boundedInteger(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    value >= minimum &&
    value <= maximum
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function safeInternalRoute(value: unknown) {
  const route = nullableText(value, 512);
  if (route == null) return route;
  return route.startsWith("/") &&
    !route.startsWith("//") &&
    !route.includes("\\") &&
    !/[\u0000-\u001f\u007f]/.test(route)
    ? route
    : undefined;
}

function safeExternalUrl(value: unknown) {
  const text = nullableText(value, 2_048);
  if (text == null) return text;
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

function normalizeCatalog(value: unknown): AdminOfferCatalogOption[] {
  if (!Array.isArray(value)) return [];
  const rows: AdminOfferCatalogOption[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_OPTION_RECORDS)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const row = entry as Record<string, unknown>;
    const id = boundedText(row.id, 128);
    const code = boundedText(row.code, 16);
    const itemName = boundedText(row.itemName ?? row.item_name, 160);
    const fetValue = boundedInteger(row.fetValue ?? row.fet_value, 0, 1_000_000);
    if (
      id != null &&
      code != null &&
      itemName != null &&
      fetValue != null &&
      !seen.has(id)
    ) {
      rows.push({ id, code: code.toUpperCase(), itemName, fetValue });
      seen.add(id);
    }
  }
  return rows;
}

function normalizePartners(value: unknown): AdminOfferPartnerOption[] {
  if (!Array.isArray(value)) return [];
  const rows: AdminOfferPartnerOption[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_OPTION_RECORDS)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const row = entry as Record<string, unknown>;
    const id = boundedText(row.id, 128);
    const name = boundedText(row.name, 160);
    const slug = boundedText(row.slug, 160);
    const category = boundedText(row.category, 80);
    if (
      id != null &&
      name != null &&
      slug != null &&
      category != null &&
      !seen.has(id)
    ) {
      rows.push({ id, name, slug, category });
      seen.add(id);
    }
  }
  return rows;
}

function mapOffer(
  row: Record<string, unknown>,
  catalogById: Map<string, AdminOfferCatalogOption>,
  partnerById: Map<string, AdminOfferPartnerOption>,
): AdminPartnerOffer | null {
  const id = boundedText(row.id, 128);
  const clubId = boundedInteger(row.clubId ?? row.club_id, 1, 2_147_483_647);
  const catalogItemId = boundedText(
    row.catalogItemId ?? row.catalog_item_id,
    128,
  );
  const partnerId = boundedText(row.partnerId ?? row.partner_id, 128);
  const catalog =
    catalogItemId == null ? null : catalogById.get(catalogItemId) ?? null;
  const partner =
    partnerId == null ? null : partnerById.get(partnerId) ?? null;
  const code = boundedText(row.code, 16) ?? catalog?.code ?? null;
  const title =
    boundedText(row.title, 160) ?? catalog?.itemName ?? null;
  const fetValue =
    boundedInteger(row.fetValue ?? row.fet_value, 0, 1_000_000) ??
    catalog?.fetValue ??
    null;
  const partnerName =
    boundedText(row.partnerName ?? row.partner_name, 160) ??
    partner?.name ??
    null;
  const partnerSlug =
    boundedText(row.partnerSlug ?? row.partner_slug, 160) ??
    partner?.slug ??
    null;
  const partnerCategory =
    boundedText(row.partnerCategory ?? row.partner_category, 80) ??
    partner?.category ??
    null;
  const subtitle = nullableText(row.subtitle, 500);
  const ctaLabel = boundedText(row.ctaLabel ?? row.cta_label, 80);
  const modeValue = boundedText(
    row.verificationMode ?? row.verification_mode,
    64,
  );
  const verificationMode = verificationModes.find(
    (mode) => mode === modeValue,
  );
  const deeplinkRoute = safeInternalRoute(
    row.deeplinkRoute ?? row.deeplink_route,
  );
  const externalUrl = safeExternalUrl(row.externalUrl ?? row.external_url);
  const isFeatured = row.isFeatured ?? row.is_featured;
  const isActive = row.isActive ?? row.is_active;
  const sortOrder = boundedInteger(
    row.sortOrder ?? row.sort_order,
    0,
    1_000_000,
  );
  const createdAt = boundedDate(row.createdAt ?? row.created_at);
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);

  if (
    id == null ||
    clubId == null ||
    catalogItemId == null ||
    partnerId == null ||
    code == null ||
    title == null ||
    fetValue == null ||
    partnerName == null ||
    partnerSlug == null ||
    partnerCategory == null ||
    subtitle === undefined ||
    ctaLabel == null ||
    verificationMode == null ||
    deeplinkRoute === undefined ||
    externalUrl === undefined ||
    typeof isFeatured !== "boolean" ||
    typeof isActive !== "boolean" ||
    sortOrder == null ||
    createdAt == null ||
    updatedAt == null
  ) {
    return null;
  }

  return {
    id,
    clubId,
    catalogItemId,
    code: code.toUpperCase(),
    title,
    fetValue,
    partnerId,
    partnerName,
    partnerSlug,
    partnerCategory,
    subtitle: subtitle ?? "",
    ctaLabel,
    verificationMode,
    deeplinkRoute,
    externalUrl,
    isFeatured,
    isActive,
    sortOrder,
    createdAt,
    updatedAt,
  };
}

export function normalizeAdminOffersWorkspace(
  value: unknown,
): AdminOffersWorkspace {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return { offers: [], catalog: [], partners: [] };
  }
  const raw = value as Record<string, unknown>;
  const catalog = normalizeCatalog(raw.catalog);
  const partners = normalizePartners(raw.partners);
  const catalogById = new Map(catalog.map((item) => [item.id, item]));
  const partnerById = new Map(partners.map((item) => [item.id, item]));
  const offers: AdminPartnerOffer[] = [];
  const seen = new Set<string>();
  if (Array.isArray(raw.offers)) {
    for (const entry of raw.offers.slice(0, MAX_OFFER_RECORDS)) {
      if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
        continue;
      }
      const offer = mapOffer(
        entry as Record<string, unknown>,
        catalogById,
        partnerById,
      );
      if (offer != null && !seen.has(offer.id)) {
        offers.push(offer);
        seen.add(offer.id);
      }
    }
  }
  return { offers, catalog, partners };
}

export async function getAdminOffers(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminOffersWorkspace> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("offers", {
      signal: options.signal,
    });
    return normalizeAdminOffersWorkspace(result);
  }

  const clubId = requireAdminClubId(access, "load partner offers");
  const [offerResult, catalogResult, partnerResult] = await Promise.all([
    client
      .from("fet_partner_offers")
      .select(
        "id,club_id,catalog_item_id,partner_id,subtitle,cta_label,verification_mode,deeplink_route,external_url,is_featured,is_active,sort_order,created_at,updated_at",
      )
      .eq("club_id", clubId)
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: false })
      .limit(MAX_OFFER_RECORDS),
    client
      .from("fan_engagement_token_catalog")
      .select("id,code,item_name,fet_value")
      .eq("club_id", clubId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .order("code", { ascending: true })
      .limit(MAX_OPTION_RECORDS),
    client
      .from("partners")
      .select("id,name,slug,category")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true })
      .limit(MAX_OPTION_RECORDS),
  ]);

  if (offerResult.error) throw new Error(offerResult.error.message);
  if (catalogResult.error) throw new Error(catalogResult.error.message);
  if (partnerResult.error) throw new Error(partnerResult.error.message);

  return normalizeAdminOffersWorkspace({
    offers: offerResult.data,
    catalog: catalogResult.data,
    partners: partnerResult.data,
  });
}

function requireInputText(value: unknown, label: string, maxLength: number) {
  const result = boundedText(value, maxLength);
  if (result == null) {
    throw new Error(`${label} is required and must be within ${maxLength} characters.`);
  }
  return result;
}

function buildPayload(
  clubId: number,
  input: {
    catalogItemId: string;
    partnerId: string;
    subtitle?: string;
    ctaLabel: string;
    verificationMode: AdminOfferVerificationMode;
    deeplinkRoute?: string | null;
    externalUrl?: string | null;
    isFeatured: boolean;
    isActive: boolean;
    sortOrder: number;
  },
) {
  const catalogItemId = requireInputText(
    input.catalogItemId,
    "Catalog item",
    128,
  );
  const partnerId = requireInputText(input.partnerId, "Partner", 128);
  const ctaLabel = requireInputText(input.ctaLabel, "Action label", 80);
  const subtitle = nullableText(input.subtitle, 500);
  const deeplinkRoute = safeInternalRoute(input.deeplinkRoute);
  const externalUrl = safeExternalUrl(input.externalUrl);
  const sortOrder = boundedInteger(input.sortOrder, 0, 1_000_000);
  if (subtitle === undefined) throw new Error("Subtitle is too long.");
  if (!verificationModes.includes(input.verificationMode)) {
    throw new Error("Choose a supported verification mode.");
  }
  if (deeplinkRoute === undefined) {
    throw new Error("Deep link must be a safe internal route.");
  }
  if (externalUrl === undefined) {
    throw new Error("External URL must use credential-free HTTPS without a fragment.");
  }
  if (sortOrder == null) {
    throw new Error("Sort order must be a whole number from 0 to 1000000.");
  }

  return {
    club_id: clubId,
    catalog_item_id: catalogItemId,
    partner_id: partnerId,
    subtitle,
    cta_label: ctaLabel,
    verification_mode: input.verificationMode,
    deeplink_route: deeplinkRoute,
    external_url: externalUrl,
    is_featured: input.isFeatured,
    is_active: input.isActive,
    sort_order: sortOrder,
  };
}

export async function saveAdminOffer(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    catalogItemId: string;
    partnerId: string;
    subtitle?: string;
    ctaLabel: string;
    verificationMode: AdminOfferVerificationMode;
    deeplinkRoute?: string | null;
    externalUrl?: string | null;
    isFeatured: boolean;
    isActive: boolean;
    sortOrder: number;
  },
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("offers", {
      method: "POST",
      body: input,
    });
  }

  const clubId = requireAdminClubId(access, "save partner offers");
  const payload = buildPayload(clubId, input);
  if (input.id) {
    return mutateRecordWithVariantsIfUnchanged(
      client,
      "fet_partner_offers",
      input.id,
      input.expectedUpdatedAt,
      [payload],
      { club_id: clubId },
    );
  }

  const { data, error } = await client
    .from("fet_partner_offers")
    .insert(payload)
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  const insertedId = boundedText(data?.id, 128);
  if (insertedId == null) {
    throw new Error("The partner offer was saved but its identifier was not confirmed.");
  }
  return insertedId;
}

export async function deleteAdminOffer(
  client: SupabaseClient,
  access: AdminAccess,
  offerId: string,
  expectedUpdatedAt: string,
): Promise<void> {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("offers", {
      method: "DELETE",
      query: { id: offerId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }

  const clubId = requireAdminClubId(access, "delete partner offers");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "fet_partner_offers",
    offerId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      requiresPlatformAdmin: true,
      action: "delete_partner_offer",
      source: "admin_offers",
    },
  );
}
