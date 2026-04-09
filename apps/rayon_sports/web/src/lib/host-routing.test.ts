import { describe, expect, it } from "vitest";
import {
  isAdminHostname,
  mapAdminSubdomainPath,
  resolveRoutingHostname,
  shouldBypassSubdomainRewrite,
} from "@/lib/host-routing";

describe("host routing", () => {
  it("detects managed subdomain hostnames", () => {
    expect(isAdminHostname("admin.gikundiro.com")).toBe(true);
    expect(isAdminHostname("admin.gikundiro.com:443")).toBe(true);
    expect(isAdminHostname("gikundiro.com")).toBe(false);
  });

  it("normalizes forwarded host values", () => {
    expect(
      resolveRoutingHostname(
        "admin.gikundiro.com, gikundiro-web.ikanisa.workers.dev",
      ),
    ).toBe("admin.gikundiro.com");
  });

  it("rewrites admin host paths to the /admin route group", () => {
    expect(mapAdminSubdomainPath("/")).toBe("/admin");
    expect(mapAdminSubdomainPath("/matches")).toBe("/admin/matches");
    expect(mapAdminSubdomainPath("/admin")).toBe("/admin");
  });

  it("bypasses static assets and shared PWA endpoints", () => {
    expect(shouldBypassSubdomainRewrite("/_next/static/chunk.js")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/manifest.webmanifest")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/share-target")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/offline")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/media/rayon-crest.png")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/tickets")).toBe(false);
  });
});
