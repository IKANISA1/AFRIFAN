import { describe, expect, test } from "vitest";
import {
  buildAdminMediaStoragePath,
  defaultAspectRatioForAdminMediaKind,
  uploadAdminImage,
} from "./media";

describe("admin media helpers", () => {
  test("builds club-scoped storage paths with stable folders", () => {
    const path = buildAdminMediaStoragePath({
      clubId: 24,
      clubSlug: "rayon_sports_rw",
      kind: "shop_product",
      fileName: "home-kit.webp",
      mimeType: "image/webp",
    });

    expect(path).toMatch(
      /^club-24\/admin\/shop_product\/\d+-[a-z0-9]{8}\.webp$/,
    );
  });

  test("uses expected default aspect ratios", () => {
    expect(defaultAspectRatioForAdminMediaKind("shop_product")).toBe("1:1");
    expect(defaultAspectRatioForAdminMediaKind("squad_player")).toBe("3:4");
    expect(defaultAspectRatioForAdminMediaKind("news_article")).toBe("16:9");
  });

  test("routes manual uploads through the governed Edge boundary", async () => {
    const calls: Array<{ name: string; body: Record<string, unknown> }> = [];
    const client = {
      functions: {
        invoke: async (name: string, options: { body: Record<string, unknown> }) => {
          calls.push({ name, body: options.body });
          return {
            data: {
              image_url: "https://storage.test/object.png",
              storage_path: "club-24/admin/shop_product/1-deadbeef.png",
              bucket: "africlub-product-images",
            },
            error: null,
          };
        },
      },
      get storage(): never {
        throw new Error("browser must not write Storage directly");
      },
    };
    const file = new File(
      [new Uint8Array([0x89, 0x50, 0x4e, 0x47])],
      "image.png",
      { type: "image/png" },
    );

    const result = await uploadAdminImage(
      client as never,
      { clubId: "24" },
      { file, kind: "shop_product" },
    );

    expect(calls).toHaveLength(1);
    expect(calls[0]?.name).toBe("admin-upload-image");
    expect(calls[0]?.body).toMatchObject({
      club_id: 24,
      kind: "shop_product",
      mime_type: "image/png",
    });
    expect(result.storagePath).toBe(
      "club-24/admin/shop_product/1-deadbeef.png",
    );
  });
});
