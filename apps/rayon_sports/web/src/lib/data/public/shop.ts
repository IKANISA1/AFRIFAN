/**
 * Public shop products data.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type { ShopProduct } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import {
  productTableCandidates,
  resolveAccessibleTable,
  sanitizeMediaUrl,
} from "./helpers";

function mapProductRow(row: Record<string, unknown>): ShopProduct {
  const name = safeString(row.name, "Supporter Product");

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name,
    subtitle: safeString(row.subtitle, "Official club merchandise"),
    description:
      safeString(row.description) ||
      safeString(row.subtitle) ||
      "Official product listing.",
    category: safeString(row.category, "Merch"),
    price: safeNumber(row.price, 0),
    imageUrl: sanitizeMediaUrl(row.image_url, "/brand-surface.svg"),
    sizes: Array.isArray(row.sizes)
      ? row.sizes.map((entry) => safeString(entry)).filter(Boolean)
      : ["One Size"],
    isActive: row.is_active !== false,
    collection: safeString(row.collection) || null,
  };
}

export const getProducts = cache(async function getProducts() {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  try {
    const table = await resolveAccessibleTable(client, productTableCandidates);
    const { data } = await client
      .from(table)
      .select("*")
      .eq("club_id", activeClub.numericId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(12);

    if (!data || data.length == 0) return [];
    return data.map((row) => mapProductRow(row));
  } catch {
    return [];
  }
});

export const getProductById = cache(async function getProductById(
  productId: string,
) {
  const products = await getProducts();
  return products.find((product) => product.id === productId) ?? null;
});
