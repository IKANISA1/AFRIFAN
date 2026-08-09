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
  const name = safeString(row.name);

  return {
    id: toIdString(row.id, ""),
    name,
    subtitle: safeString(row.subtitle),
    description: safeString(row.description) || safeString(row.subtitle),
    category: safeString(row.category),
    price: safeNumber(row.price, 0),
    imageUrl: sanitizeMediaUrl(row.image_url, "/brand-surface.svg"),
    sizes: Array.isArray(row.sizes)
      ? row.sizes.map((entry) => safeString(entry)).filter(Boolean)
      : [],
    isActive: row.is_active !== false,
    collection: safeString(row.collection) || null,
  };
}

async function loadProducts() {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  const table = await resolveAccessibleTable(client, productTableCandidates);
  const { data, error } = await client
    .from(table)
    .select(
      "id, club_id, name, subtitle, description, category, price, image_url, sizes, is_active, collection, sort_order",
    )
    .eq("club_id", activeClub.numericId)
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .limit(12);

  if (error) {
    throw error;
  }
  if (!data || data.length == 0) return [];
  return data.map((row) => mapProductRow(row));
}

export const getProductsStrict = cache(async function getProductsStrict() {
  return loadProducts();
});

export const getProducts = cache(async function getProducts() {
  try {
    return await loadProducts();
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

export const getProductByIdStrict = cache(
  async function getProductByIdStrict(productId: string) {
    const products = await getProductsStrict();
    return products.find((product) => product.id === productId) ?? null;
  },
);
