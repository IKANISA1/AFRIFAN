/**
 * Admin shop — bounded, scope-safe product CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminShopProduct } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  resolveProductTable,
} from "./helpers";

export const MAX_ADMIN_SHOP_PRODUCTS = 500;
const MAX_PRODUCT_SIZES = 20;
const productProjection =
  "id,club_id,name,subtitle,description,category,price,image_url,sizes,is_active,collection,sort_order,created_at,updated_at";
const idPattern = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/;

export class AdminShopValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminShopValidationError";
  }
}

export interface AdminShopProductInput {
  id: string | null;
  expectedUpdatedAt: string | null;
  name: string;
  subtitle: string;
  description: string;
  category: string;
  price: number;
  imageUrl: string | null;
  sizes: string[];
  isActive: boolean;
  collection: string | null;
  sortOrder: number;
}

function record(value: unknown, label: string) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new AdminShopValidationError(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function boundedString(
  value: unknown,
  label: string,
  maxLength: number,
  options: { allowEmpty?: boolean; nullable?: boolean } = {},
) {
  if (value == null && options.nullable) return null;
  if (typeof value !== "string") {
    throw new AdminShopValidationError(`${label} must be text.`);
  }
  const normalized = value.trim();
  if (!normalized && !options.allowEmpty) {
    throw new AdminShopValidationError(`${label} is required.`);
  }
  if (normalized.length > maxLength) {
    throw new AdminShopValidationError(`${label} is too long.`);
  }
  return normalized;
}

function optionalString(value: unknown, label: string, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedString(value, label, maxLength, { nullable: true });
}

function identifier(value: unknown, label: string, nullable = false) {
  if (value == null && nullable) return null;
  const normalized = boundedString(value, label, 128);
  if (normalized == null || !idPattern.test(normalized)) {
    throw new AdminShopValidationError(`${label} is invalid.`);
  }
  return normalized;
}

function finiteNumber(
  value: unknown,
  label: string,
  { integer = false, min = 0, max = 1_000_000_000 } = {},
) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new AdminShopValidationError(`${label} must be a finite number.`);
  }
  if ((integer && !Number.isInteger(value)) || value < min || value > max) {
    throw new AdminShopValidationError(`${label} is outside the allowed range.`);
  }
  return value;
}

function timestamp(value: unknown, label: string, nullable = false) {
  if (value == null && nullable) return null;
  const normalized = boundedString(value, label, 64);
  if (normalized == null || Number.isNaN(Date.parse(normalized))) {
    throw new AdminShopValidationError(`${label} is invalid.`);
  }
  return new Date(normalized).toISOString();
}

function productUrl(value: unknown) {
  const normalized = optionalString(value, "Product image URL", 2_048);
  if (normalized == null) return null;
  let parsed: URL;
  try {
    parsed = new URL(normalized);
  } catch {
    throw new AdminShopValidationError("Product image URL is invalid.");
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new AdminShopValidationError("Product image URL must use HTTP or HTTPS.");
  }
  return parsed.toString();
}

function productSizes(value: unknown) {
  if (!Array.isArray(value) || value.length > MAX_PRODUCT_SIZES) {
    throw new AdminShopValidationError("Product sizes exceed the safe limit.");
  }
  const sizes = value.map((entry) =>
    boundedString(entry, "Product size", 32),
  ) as string[];
  const unique = new Set(sizes.map((size) => size.toLocaleLowerCase()));
  if (unique.size !== sizes.length) {
    throw new AdminShopValidationError("Product sizes must be unique.");
  }
  return sizes;
}

function assertAllowedKeys(
  value: Record<string, unknown>,
  allowed: readonly string[],
) {
  const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) {
    throw new AdminShopValidationError("Product input contains unsupported fields.");
  }
}

function normalizeProductRecord(value: unknown): AdminShopProduct {
  const row = record(value, "Shop product");
  const clubId =
    row.clubId == null
      ? null
      : finiteNumber(row.clubId, "Club id", {
          integer: true,
          min: 1,
          max: Number.MAX_SAFE_INTEGER,
        });
  if (typeof row.isActive !== "boolean") {
    throw new AdminShopValidationError("Product active state is invalid.");
  }
  return {
    id: identifier(row.id, "Product id") as string,
    clubId,
    name: boundedString(row.name, "Product name", 120) as string,
    subtitle: boundedString(row.subtitle, "Product subtitle", 240, {
      allowEmpty: true,
    }) as string,
    description: boundedString(row.description, "Product description", 4_000, {
      allowEmpty: true,
    }) as string,
    category: boundedString(row.category, "Product category", 80) as string,
    price: finiteNumber(row.price, "Product price"),
    imageUrl: productUrl(row.imageUrl),
    sizes: productSizes(row.sizes),
    isActive: row.isActive,
    collection: optionalString(row.collection, "Product collection", 120),
    sortOrder: finiteNumber(row.sortOrder, "Product sort order", {
      integer: true,
      min: -100_000,
      max: 100_000,
    }),
    createdAt: timestamp(row.createdAt, "Product creation time") as string,
    updatedAt: timestamp(row.updatedAt, "Product update time") as string,
  };
}

function mapAdminShopProduct(row: Record<string, unknown>) {
  return normalizeProductRecord({
    id: row.id == null ? null : String(row.id),
    clubId: row.club_id,
    name: row.name,
    subtitle: row.subtitle,
    description: row.description,
    category: row.category,
    price: row.price,
    imageUrl: row.image_url,
    sizes: row.sizes,
    isActive: row.is_active,
    collection: row.collection,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  });
}

export function normalizeAdminShopProducts(value: unknown) {
  if (!Array.isArray(value)) {
    throw new AdminShopValidationError("Shop catalogue must be a list.");
  }
  if (value.length > MAX_ADMIN_SHOP_PRODUCTS) {
    throw new AdminShopValidationError("Shop catalogue exceeds the safe limit.");
  }
  const products = value.map(normalizeProductRecord);
  const ids = new Set(products.map((product) => product.id));
  if (ids.size !== products.length) {
    throw new AdminShopValidationError("Shop catalogue contains duplicate products.");
  }
  return products;
}

export function normalizeAdminShopProductInput(
  value: unknown,
): AdminShopProductInput {
  const input = record(value, "Product input");
  assertAllowedKeys(input, [
    "id",
    "expectedUpdatedAt",
    "name",
    "subtitle",
    "description",
    "category",
    "price",
    "imageUrl",
    "sizes",
    "isActive",
    "collection",
    "sortOrder",
  ]);
  if (typeof input.isActive !== "boolean") {
    throw new AdminShopValidationError("Product active state is invalid.");
  }
  return {
    id: identifier(input.id, "Product id", true),
    expectedUpdatedAt: timestamp(
      input.expectedUpdatedAt,
      "Expected product update time",
      true,
    ),
    name: boundedString(input.name, "Product name", 120) as string,
    subtitle: boundedString(input.subtitle, "Product subtitle", 240, {
      allowEmpty: true,
    }) as string,
    description: boundedString(
      input.description,
      "Product description",
      4_000,
      { allowEmpty: true },
    ) as string,
    category: boundedString(input.category, "Product category", 80) as string,
    price: finiteNumber(input.price, "Product price"),
    imageUrl: productUrl(input.imageUrl),
    sizes: productSizes(input.sizes),
    isActive: input.isActive,
    collection: optionalString(input.collection, "Product collection", 120),
    sortOrder: finiteNumber(input.sortOrder, "Product sort order", {
      integer: true,
      min: -100_000,
      max: 100_000,
    }),
  };
}

function requireShopEditor(access: AdminAccess) {
  if (!access.hasAccess || (!access.isSuperAdmin && access.role !== "club_admin")) {
    throw new AdminShopValidationError("Shop editor access is required.");
  }
}

export async function getAdminProducts(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminShopProduct[]> {
  if (typeof window !== "undefined") {
    return normalizeAdminShopProducts(
      await requestAdminApi<unknown>("shop", { signal: options.signal }),
    );
  }
  const clubId = requireAdminClubId(access, "load products");
  const table = await resolveProductTable(client);
  const { data, error } = await client
    .from(table)
    .select(productProjection)
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true })
    .limit(MAX_ADMIN_SHOP_PRODUCTS + 1);
  if (error) throw new Error(error.message);
  if (!Array.isArray(data)) {
    throw new AdminShopValidationError("Shop catalogue response is invalid.");
  }
  if (data.length > MAX_ADMIN_SHOP_PRODUCTS) {
    throw new AdminShopValidationError("Shop catalogue exceeds the safe limit.");
  }
  return data.map((row) =>
    mapAdminShopProduct(row as Record<string, unknown>),
  );
}

export async function saveAdminProduct(
  client: SupabaseClient,
  access: AdminAccess,
  value: unknown,
) {
  requireShopEditor(access);
  const input = normalizeAdminShopProductInput(value);
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("shop", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save products");
  const table = await resolveProductTable(client);
  return mutateRecordWithVariantsIfUnchanged(
    client,
    table,
    input.id,
    input.expectedUpdatedAt,
    [
      {
        club_id: clubId,
        name: input.name,
        subtitle: input.subtitle,
        description: input.description,
        category: input.category,
        price: input.price,
        image_url: input.imageUrl,
        sizes: input.sizes,
        is_active: input.isActive,
        collection: input.collection,
        sort_order: input.sortOrder,
      },
    ],
    { club_id: clubId },
  );
}

export async function deleteAdminProduct(
  client: SupabaseClient,
  access: AdminAccess,
  productId: string,
  expectedUpdatedAt: string,
) {
  requireShopEditor(access);
  const id = identifier(productId, "Product id") as string;
  const expected = timestamp(
    expectedUpdatedAt,
    "Expected product update time",
  ) as string;
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("shop", {
      method: "DELETE",
      query: { id, expected_updated_at: expected },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete products");
  const table = await resolveProductTable(client);
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    table,
    id,
    expected,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_shop_product",
      source: "admin_shop",
    },
  );
}
