import {
  cn,
  formatCurrency,
  isValidHexColor,
  normalizeHexColorInput,
  safeNumber,
  sanitizeHexColorDraft,
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

  it("sanitizes and normalizes hex color input", () => {
    expect(sanitizeHexColorDraft("0038a8")).toBe("#0038A8");
    expect(sanitizeHexColorDraft("#d4a")).toBe("#D4A");
    expect(normalizeHexColorInput("#d4a")).toBe("#DD44AA");
    expect(normalizeHexColorInput(" 0038a8 ")).toBe("#0038A8");
    expect(isValidHexColor("#0038A8")).toBe(true);
    expect(isValidHexColor("#GGGGGG")).toBe(false);
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
