// @vitest-environment node

import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminShopProduct } from "@/lib/types";
import {
  MAX_ADMIN_SHOP_PRODUCTS,
  getAdminProducts,
  normalizeAdminShopProductInput,
  normalizeAdminShopProducts,
  saveAdminProduct,
} from "./shop";

const timestamp = "2026-07-30T09:00:00.000Z";
const clubAdminAccess: AdminAccess = {
  hasAccess: true,
  isAuthenticated: true,
  isSuperAdmin: false,
  userId: "club-admin-1",
  role: "club_admin",
  clubId: "24",
  availableClubIds: ["24"],
  canSelectClub: false,
  assignmentCount: 1,
};

const validProduct: AdminShopProduct = {
  id: "product-1",
  clubId: 24,
  name: "Replica Kit",
  subtitle: "2026 home shirt",
  description: "Official supporter replica shirt.",
  category: "Merch",
  price: 35_000,
  imageUrl: "https://cdn.example.com/kit.webp",
  sizes: ["S", "M", "L"],
  isActive: true,
  collection: "Home",
  sortOrder: 10,
  createdAt: timestamp,
  updatedAt: timestamp,
};

function toRow(product: AdminShopProduct) {
  return {
    id: product.id,
    club_id: product.clubId,
    name: product.name,
    subtitle: product.subtitle,
    description: product.description,
    category: product.category,
    price: product.price,
    image_url: product.imageUrl,
    sizes: product.sizes,
    is_active: product.isActive,
    collection: product.collection,
    sort_order: product.sortOrder,
    created_at: product.createdAt,
    updated_at: product.updatedAt,
  };
}

describe("admin shop catalogue", () => {
  it("accepts strict API products and ignores unowned fields", () => {
    expect(
      normalizeAdminShopProducts([
        { ...validProduct, internal_secret: "not-public" },
      ]),
    ).toEqual([validProduct]);
  });

  it.each([
    ["duplicate ids", [validProduct, validProduct]],
    [
      "duplicate sizes",
      [{ ...validProduct, sizes: ["M", "m"] }],
    ],
    [
      "unsafe image protocol",
      [{ ...validProduct, imageUrl: "javascript:alert(1)" }],
    ],
    ["invalid price", [{ ...validProduct, price: Number.NaN }]],
  ])("rejects %s instead of returning a partial catalogue", (_label, value) => {
    expect(() => normalizeAdminShopProducts(value)).toThrow();
  });

  it("rejects an oversized catalogue", () => {
    expect(() =>
      normalizeAdminShopProducts(
        Array.from(
          { length: MAX_ADMIN_SHOP_PRODUCTS + 1 },
          (_, index) => ({ ...validProduct, id: `product-${index}` }),
        ),
      ),
    ).toThrow("safe limit");
  });

  it("normalizes mutation input and rejects unsupported fields", () => {
    expect(
      normalizeAdminShopProductInput({
        id: null,
        expectedUpdatedAt: null,
        name: "  Replica Kit  ",
        subtitle: "",
        description: "",
        category: " Merch ",
        price: 35_000,
        imageUrl: "",
        sizes: ["S", "M"],
        isActive: true,
        collection: "",
        sortOrder: 10,
      }),
    ).toMatchObject({
      id: null,
      name: "Replica Kit",
      category: "Merch",
      imageUrl: null,
      collection: null,
    });

    expect(() =>
      normalizeAdminShopProductInput({
        id: null,
        expectedUpdatedAt: null,
        name: "Replica Kit",
        subtitle: "",
        description: "",
        category: "Merch",
        price: 35_000,
        imageUrl: "",
        sizes: ["M"],
        isActive: true,
        collection: "",
        sortOrder: 10,
        actorId: "private",
      }),
    ).toThrow("unsupported");
  });

  it("uses a bounded, projected, club-scoped query", async () => {
    const limit = vi.fn().mockResolvedValue({
      data: [toRow(validProduct)],
      error: null,
    });
    const order = vi.fn(() => ({ limit }));
    const eq = vi.fn(() => ({ order }));
    const select = vi.fn((projection: string) =>
      projection === "id"
        ? { limit: vi.fn().mockResolvedValue({ error: null }) }
        : { eq },
    );
    const from = vi.fn(() => ({ select }));

    await expect(
      getAdminProducts(
        { from } as unknown as SupabaseClient,
        clubAdminAccess,
      ),
    ).resolves.toEqual([validProduct]);
    expect(select).toHaveBeenCalledWith(
      "id,club_id,name,subtitle,description,category,price,image_url,sizes,is_active,collection,sort_order,created_at,updated_at",
    );
    expect(eq).toHaveBeenCalledWith("club_id", 24);
    expect(limit).toHaveBeenCalledWith(MAX_ADMIN_SHOP_PRODUCTS + 1);
  });

  it("keeps club moderators read-only before invoking storage", async () => {
    const from = vi.fn();
    await expect(
      saveAdminProduct(
        { from } as unknown as SupabaseClient,
        { ...clubAdminAccess, role: "club_moderator" },
        {
          id: null,
          expectedUpdatedAt: null,
          name: "Replica Kit",
          subtitle: "",
          description: "",
          category: "Merch",
          price: 35_000,
          imageUrl: "",
          sizes: ["M"],
          isActive: true,
          collection: "",
          sortOrder: 10,
        },
      ),
    ).rejects.toThrow("editor access is required");
    expect(from).not.toHaveBeenCalled();
  });
});
