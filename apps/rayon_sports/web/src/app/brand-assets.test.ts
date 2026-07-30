import { describe, expect, it } from "vitest";
import { rayonClub } from "@/lib/config";
import { GET as getBrandMark } from "./brand-mark.svg/route";
import { GET as getBrandSurface } from "./brand-surface.svg/route";

describe("deterministic local brand assets", () => {
  it.each([
    ["brand mark", getBrandMark, 'role="img"', "512"],
    ["brand surface", getBrandSurface, 'role="img"', "1600"],
  ])(
    "returns the %s as a cacheable local SVG without an upstream operation",
    async (_name, handler, semanticMarker, width) => {
      const response = handler();
      const body = await response.text();

      expect(response.status).toBe(200);
      expect(response.headers.get("content-type")).toBe("image/svg+xml");
      expect(response.headers.get("cache-control")).toBe(
        "public, max-age=3600",
      );
      expect(body).toContain("<svg");
      expect(body).toContain(semanticMarker);
      expect(body).toContain(`width="${width}"`);
      expect(body).toContain(rayonClub.shortName);
      expect(body).not.toContain("<script");
      expect(body).not.toMatch(/(?:href|src)="https?:\/\//u);
    },
  );
});
