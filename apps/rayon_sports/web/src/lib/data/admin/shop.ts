/**
 * Admin shop — product CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess, AdminShopProduct } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { mutateRecordWithVariants, resolveProductTable } from "./helpers";

function mapAdminShopProduct(row: Record<string, unknown>): AdminShopProduct {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Supporter product"),
    subtitle: safeString(row.subtitle, "Official club merchandise"),
    description: safeString(row.description) || safeString(row.subtitle) || "Official product listing.",
    category: safeString(row.category, "Merch"),
    price: safeNumber(row.price, 0),
    imageUrl: safeString(row.image_url) || null,
    sizes: Array.isArray(row.sizes) ? row.sizes.map((entry) => safeString(entry)).filter(Boolean) : ["One Size"],
    isActive: row.is_active !== false,
    collection: safeString(row.collection) || null,
    sortOrder: safeNumber(row.sort_order, 0),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminProducts(client: SupabaseClient): Promise<AdminShopProduct[]> {
  const table = await resolveProductTable(client);
  const scoped = await client.from(table).select("*").eq("club_id", rayonClub.numericId).order("sort_order", { ascending: true });
  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row) => mapAdminShopProduct(row as Record<string, unknown>));
  }
  const fallback = await client.from(table).select("*").order("sort_order", { ascending: true });
  if (fallback.error) throw new Error(fallback.error.message);
  return Array.isArray(fallback.data) && fallback.data.length > 0
    ? fallback.data.map((row) => mapAdminShopProduct(row as Record<string, unknown>))
    : [];
}

export async function saveAdminProduct(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; name: string; subtitle: string; description: string; category: string; price: number; imageUrl?: string; sizes: string[]; isActive: boolean; collection?: string; sortOrder: number },
) {
  const table = await resolveProductTable(client);
  return mutateRecordWithVariants(client, table, input.id, [{
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    name: input.name.trim(), subtitle: input.subtitle.trim(), description: input.description.trim(),
    category: input.category.trim(), price: safeNumber(input.price, 0),
    image_url: safeString(input.imageUrl) || null, sizes: input.sizes,
    is_active: input.isActive, collection: safeString(input.collection) || null,
    sort_order: safeNumber(input.sortOrder, 0),
  }]);
}

export async function deleteAdminProduct(client: SupabaseClient, productId: string) {
  const table = await resolveProductTable(client);
  const { error } = await client.from(table).delete().eq("id", productId);
  if (error) throw new Error(error.message);
}
