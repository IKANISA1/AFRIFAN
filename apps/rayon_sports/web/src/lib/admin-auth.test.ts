import { describe, expect, it } from "vitest";
import {
  formatAdminPhoneForDisplay,
  normalizeAdminPhone,
} from "@/lib/admin-auth";

describe("normalizeAdminPhone", () => {
  it("normalizes local Rwanda numbers", () => {
    expect(normalizeAdminPhone("0788123456")).toBe("+250788123456");
    expect(normalizeAdminPhone("788123456")).toBe("+250788123456");
  });

  it("normalizes international input", () => {
    expect(normalizeAdminPhone("00250788123456")).toBe("+250788123456");
    expect(normalizeAdminPhone("+250 788 123 456")).toBe("+250788123456");
  });

  it("rejects invalid numbers", () => {
    expect(() => normalizeAdminPhone("123")).toThrow(
      "Use a valid phone number in international format.",
    );
  });
});

describe("formatAdminPhoneForDisplay", () => {
  it("formats Rwanda numbers for display", () => {
    expect(formatAdminPhoneForDisplay("+250788123456")).toBe(
      "+250 788 123 456",
    );
  });
});
