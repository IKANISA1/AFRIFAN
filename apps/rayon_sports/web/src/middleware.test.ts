import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";
import { middleware } from "./middleware";
import { controlledAdminEvidenceRequestHeader } from "./lib/controlled-admin-evidence";

describe("Cloudflare Edge routing entry", () => {
  it("rewrites admin host paths while preserving the selected club and query", () => {
    const response = middleware(new NextRequest("https://admin.gikundiro.com/community?club=club-24&cursor=next"));
    expect(response.headers.get("x-middleware-rewrite")).toBe("https://admin.gikundiro.com/admin/community?club=club-24&cursor=next");
    expect(response.cookies.get("africlub_admin_club")?.value).toBe("club-24");
    expect(response.cookies.get("africlub_admin_club")?.secure).toBe(true);
  });

  it("removes an injected controlled-evidence request header", () => {
    const response = middleware(new NextRequest("https://gikundiro.com/news", {
      headers: { [controlledAdminEvidenceRequestHeader]: "1" },
    }));
    expect(response.headers.get(`x-middleware-request-${controlledAdminEvidenceRequestHeader}`)).toBeNull();
    expect(response.headers.get("x-middleware-override-headers")).not.toContain(controlledAdminEvidenceRequestHeader);
  });

  it("leaves the canonical independent offline route outside admin rendering", () => {
    const response = middleware(new NextRequest("https://admin.gikundiro.com/admin-offline"));
    expect(response.headers.get("x-middleware-rewrite")).toBeNull();
    expect(response.status).toBe(200);
  });
  it("overwrites attacker nonce and CSP headers with a new private request policy", () => {
    const first = middleware(new NextRequest("https://gikundiro.com/membership", {
      headers: { "x-africlub-csp-nonce": "synthetic-private", "content-security-policy": "script-src * 'unsafe-inline'" },
    }));
    const second = middleware(new NextRequest("https://gikundiro.com/membership"));
    const csp = first.headers.get("content-security-policy")!;
    const nonce = first.headers.get("x-middleware-request-x-africlub-csp-nonce");
    expect(csp).toContain(`'nonce-${nonce}'`);
    expect(csp).not.toContain("synthetic-private");
    expect(first.headers.get("x-middleware-request-content-security-policy")).toBe(csp);
    expect(second.headers.get("x-middleware-request-x-africlub-csp-nonce")).not.toBe(nonce);
    expect(first.headers.get("cache-control")).toBe("private, no-store");
    expect(first.headers.get("cdn-cache-control")).toBe("no-store");
    expect(first.headers.get("cloudflare-cdn-cache-control")).toBe("no-store");
  });
  it("static assets strip caller nonce input and keep their normal cache behavior", () => {
    const response = middleware(new NextRequest("https://gikundiro.com/brand-mark.svg", {
      headers: { "x-africlub-csp-nonce": "synthetic-private" },
    }));
    expect(response.headers.get("x-middleware-request-x-africlub-csp-nonce")).toBeNull();
    expect(response.headers.get("content-security-policy")).toBeNull();
    expect(response.headers.get("cache-control")).toBeNull();
  });
});
