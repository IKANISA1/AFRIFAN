/**
 * Admin partner offers — CRUD for FET-redeemable partner reward offers.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
} from "./helpers";

export interface AdminPartnerOffer {
  id: string;
  title: string;
  description: string;
  partnerName: string;
  fetCost: number;
  originalValue: string;
  categoryTag: string;
  imageUrl: string | null;
  redeemUrl: string | null;
  totalStock: number | null;
  claimedCount: number;
  isActive: boolean;
  startsAt: string | null;
  expiresAt: string | null;
  createdAt: string;
  updatedAt: string;
}

function mapOffer(row: Record<string, unknown>): AdminPartnerOffer {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, "Untitled offer"),
    description: safeString(row.description),
    partnerName: safeString(row.partner_name, "Partner"),
    fetCost: safeNumber(row.fet_cost, 0),
    originalValue: safeString(row.original_value),
    categoryTag: safeString(row.category_tag, "reward"),
    imageUrl: safeString(row.image_url) || null,
    redeemUrl: safeString(row.redeem_url) || null,
    totalStock: row.total_stock == null ? null : safeNumber(row.total_stock, 0),
    claimedCount: safeNumber(row.claimed_count, 0),
    isActive: row.is_active !== false,
    startsAt: safeString(row.starts_at) || null,
    expiresAt: safeString(row.expires_at) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    updatedAt: safeString(row.updated_at, new Date(0).toISOString()),
  };
}

export async function getAdminOffers(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminPartnerOffer[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminPartnerOffer[]>("offers");
  }

  const { data, error } = await client
    .from("fet_partner_offers")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) => mapOffer(row as Record<string, unknown>))
    : [];
}

export async function saveAdminOffer(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    title: string;
    description: string;
    partnerName: string;
    fetCost: number;
    originalValue?: string;
    categoryTag?: string;
    imageUrl?: string;
    redeemUrl?: string;
    totalStock?: number | null;
    isActive: boolean;
    startsAt?: string | null;
    expiresAt?: string | null;
  },
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("offers", {
      method: "POST",
      body: input,
    });
  }

  const payload = {
    title: input.title.trim(),
    description: input.description.trim(),
    partner_name: input.partnerName.trim(),
    fet_cost: safeNumber(input.fetCost, 0),
    original_value: safeString(input.originalValue),
    category_tag: safeString(input.categoryTag, "reward"),
    image_url: safeString(input.imageUrl) || null,
    redeem_url: safeString(input.redeemUrl) || null,
    total_stock: input.totalStock ?? null,
    is_active: input.isActive,
    starts_at: input.startsAt || null,
    expires_at: input.expiresAt || null,
  };

  if (input.id) {
    return mutateRecordWithVariantsIfUnchanged(
      client,
      "fet_partner_offers",
      input.id,
      input.expectedUpdatedAt,
      [payload],
    );
  }

  const { data, error } = await client
    .from("fet_partner_offers")
    .insert(payload)
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
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

  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "fet_partner_offers",
    offerId,
    expectedUpdatedAt,
    {},
    {
      actorId: access.userId,
      requiresPlatformAdmin: true,
      action: "delete_partner_offer",
      source: "admin_offers",
    },
  );
}
