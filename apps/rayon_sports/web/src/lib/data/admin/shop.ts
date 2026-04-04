/**
 * Admin shop — product CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminShopProduct } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteRecordWithMatchers,
  mutateRecordWithVariants,
  requireAdminClubId,
  resolveProductTable,
} from "./helpers";

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

export async function getAdminProducts(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminShopProduct[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminShopProduct[]>("shop");
  }
  const clubId = requireAdminClubId(access, "load products");
  const table = await resolveProductTable(client);
  const { data, error } = await client
    .from(table)
    .select("*")
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row) => mapAdminShopProduct(row as Record<string, unknown>))
    : [];
}

export async function saveAdminProduct(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; name: string; subtitle: string; description: string; category: string; price: number; imageUrl?: string; sizes: string[]; isActive: boolean; collection?: string; sortOrder: number },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("shop", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save products");
  const table = await resolveProductTable(client);
  return mutateRecordWithVariants(client, table, input.id, [{
    club_id: clubId,
    name: input.name.trim(), subtitle: input.subtitle.trim(), description: input.description.trim(),
    category: input.category.trim(), price: safeNumber(input.price, 0),
    image_url: safeString(input.imageUrl) || null, sizes: input.sizes,
    is_active: input.isActive, collection: safeString(input.collection) || null,
    sort_order: safeNumber(input.sortOrder, 0),
  }], { club_id: clubId });
}

export async function deleteAdminProduct(
  client: SupabaseClient,
  access: AdminAccess,
  productId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("shop", {
      method: "DELETE",
      query: { id: productId },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete products");
  const table = await resolveProductTable(client);
  await deleteRecordWithMatchers(client, table, productId, { club_id: clubId });
}
