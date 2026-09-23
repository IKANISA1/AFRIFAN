import { describe, expect, it } from "vitest";
import {
  canonicalRecoveryPath,
  isAdminHostname,
  isReleaseContractPath,
  isWorkersPreviewHostname,
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

  it("identifies Worker preview hosts without classifying production hosts", () => {
    expect(
      isWorkersPreviewHostname("candidate-gikundiro-web.ikanisa.workers.dev"),
    ).toBe(true);
    expect(isWorkersPreviewHostname("gikundiro.com")).toBe(false);
    expect(isWorkersPreviewHostname("workers.dev.attacker.example")).toBe(
      false,
    );
  });

  it("rewrites admin host paths to the /admin route group", () => {
    expect(mapAdminSubdomainPath("/")).toBe("/admin");
    expect(mapAdminSubdomainPath("/matches")).toBe("/admin/matches");
    expect(mapAdminSubdomainPath("/admin")).toBe("/admin");
  });

  it("normalizes the stale nested admin recovery path", () => {
    expect(canonicalRecoveryPath("/admin/offline")).toBe("/admin-offline");
    expect(canonicalRecoveryPath("/admin-offline")).toBeNull();
    expect(canonicalRecoveryPath("/admin/offline/details")).toBeNull();
  });

  it("bypasses static assets and shared PWA endpoints", () => {
    expect(shouldBypassSubdomainRewrite("/_next/static/chunk.js")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/manifest.webmanifest")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/share-target")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/offline")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/admin-offline")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/brand-mark.svg")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/.well-known/assetlinks.json")).toBe(
      true,
    );
    expect(
      shouldBypassSubdomainRewrite(
        "/.well-known/apple-app-site-association",
      ),
    ).toBe(true);
    expect(shouldBypassSubdomainRewrite("/privacy")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/terms")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/support")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/account-deletion")).toBe(true);
    expect(shouldBypassSubdomainRewrite("/tickets")).toBe(false);
  });

  it("recognizes only the public release-contract paths", () => {
    expect(isReleaseContractPath("/.well-known/assetlinks.json")).toBe(true);
    expect(isReleaseContractPath("/privacy")).toBe(true);
    expect(isReleaseContractPath("/account-deletion/confirmation")).toBe(true);
    expect(isReleaseContractPath("/admin/privacy")).toBe(false);
    expect(isReleaseContractPath("/api/admin/features")).toBe(false);
  });
});
