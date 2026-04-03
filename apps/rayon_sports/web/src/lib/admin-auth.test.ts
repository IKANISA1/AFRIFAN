import { describe, expect, it } from "vitest";
import {
  formatAdminPhoneForDisplay,
  isAdminHostname,
  mapAdminSubdomainPath,
  normalizeAdminPhone,
  shouldBypassAdminRewrite,
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
      "Use a valid WhatsApp number in international format.",
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

describe("admin host routing", () => {
  it("detects the admin hostname", () => {
    expect(isAdminHostname("admin.gikundiro.com")).toBe(true);
    expect(isAdminHostname("admin.gikundiro.com:443")).toBe(true);
    expect(isAdminHostname("gikundiro.com")).toBe(false);
  });

  it("rewrites admin host paths to the /admin route group", () => {
    expect(mapAdminSubdomainPath("/")).toBe("/admin");
    expect(mapAdminSubdomainPath("/matches")).toBe("/admin/matches");
    expect(mapAdminSubdomainPath("/admin")).toBe("/admin");
  });

  it("bypasses static assets and framework paths", () => {
    expect(shouldBypassAdminRewrite("/_next/static/chunk.js")).toBe(true);
    expect(shouldBypassAdminRewrite("/manifest.webmanifest")).toBe(true);
    expect(shouldBypassAdminRewrite("/media/rayon-crest.png")).toBe(true);
    expect(shouldBypassAdminRewrite("/matches")).toBe(false);
  });
});
