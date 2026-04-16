/**
 * Public shop products data.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { fallbackProducts } from "@/lib/content";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type { ShopProduct } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { productTableCandidates, resolveAccessibleTable, sanitizeMediaUrl } from "./helpers";

function mapProductRow(row: Record<string, unknown>): ShopProduct {
  const rawPrice = safeNumber(row.price, 0);
  const name = safeString(row.name, "Supporter Product");
  
  // Sanity check: if price is unrealistically low for a kit/jersey (e.g. < 1000 RF), 
  // it's likely seed data or a unit error. Repair to fallback kit pricing.
  const isKit = /kit|jersey|shirt/i.test(name);
  const price = (isKit && rawPrice < 1000) ? 35000 : (rawPrice || 5000);

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name,
    subtitle: safeString(row.subtitle, "Official club merchandise"),
    description:
      safeString(row.description) ||
      safeString(row.subtitle) ||
      "Official product listing.",
    category: safeString(row.category, "Merch"),
    price,
    imageUrl: sanitizeMediaUrl(row.image_url, "/media/stadium-hero.jpg"),
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
  if (client == null) return fallbackProducts;

  try {
    const table = await resolveAccessibleTable(client, productTableCandidates);
    const { data } = await client
      .from(table)
      .select("*")
      .eq("club_id", activeClub.numericId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(12);

    if (!data || data.length == 0) return fallbackProducts;
    return data.map((row) => mapProductRow(row));
  } catch {
    return fallbackProducts;
  }
});

export const getProductById = cache(async function getProductById(productId: string) {
  const products = await getProducts();
  return products.find((product) => product.id === productId) ?? null;
});
