import {
  cn,
  formatCurrency,
  safeNumber,
  safeString,
  slugify,
  toIdString,
} from "@/lib/utils";

describe("utils", () => {
  it("slugifies supporter-facing labels", () => {
    expect(slugify(" Blue Wall Travel Fund ")).toBe("blue-wall-travel-fund");
  });

  it("guards string and numeric fallbacks", () => {
    expect(safeString("  Gikundiro  ")).toBe("Gikundiro");
    expect(safeString("", "fallback")).toBe("fallback");
    expect(safeNumber("42")).toBe(42);
    expect(safeNumber("not-a-number", 9)).toBe(9);
  });

  it("formats currency and ids consistently", () => {
    expect(formatCurrency(15000)).toContain("15,000");
    expect(toIdString(24, "fallback")).toBe("24");
    expect(toIdString(null, "fallback")).toBe("fallback");
  });

  it("joins class names safely", () => {
    expect(cn("glass-panel", false, undefined, "rounded")).toBe(
      "glass-panel rounded",
    );
  });
});
