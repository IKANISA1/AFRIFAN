import { describe, expect, test } from "vitest";
import {
  buildAdminMediaStoragePath,
  defaultAspectRatioForAdminMediaKind,
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
      /^rayon-sports-rw\/admin\/shop_product\/\d+-[a-z0-9]{8}\.webp$/,
    );
  });

  test("uses expected default aspect ratios", () => {
    expect(defaultAspectRatioForAdminMediaKind("shop_product")).toBe("1:1");
    expect(defaultAspectRatioForAdminMediaKind("squad_player")).toBe("3:4");
    expect(defaultAspectRatioForAdminMediaKind("news_article")).toBe("16:9");
  });
});
