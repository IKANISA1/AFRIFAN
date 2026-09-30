import { describe, expect, it } from "vitest";
import { contentSecurityPolicy, createCspNonce, isHtmlCspPath, validCspNonce } from "./content-security-policy";

describe("request CSP", () => {
  it("uses 128-bit random nonces and never reuses a nonce across requests", () => {
    const nonces = Array.from({ length: 100 }, createCspNonce);
    expect(new Set(nonces).size).toBe(100);
    for (const nonce of nonces) { expect(validCspNonce(nonce)).toBe(true); expect(atob(nonce).length).toBe(16); }
  });
  it("production scripts need the request nonce and permit no inline/eval/event-handler execution", () => {
    const nonce = createCspNonce();
    const csp = contentSecurityPolicy({ nonce, development: false, allowHttpPreview: false });
    const script = csp.split(";").find(part => part.trim().startsWith("script-src "))!;
    expect(script).toContain(`'nonce-${nonce}'`); expect(script).toContain("'strict-dynamic'");
    expect(script).not.toContain("unsafe-inline"); expect(script).not.toContain("unsafe-eval");
    expect(csp).toContain("script-src-attr 'none'");
    expect(csp).toContain("frame-ancestors 'none'"); expect(csp).toContain("form-action 'self'");
    expect(csp).not.toContain("cloudflareinsights"); expect(csp).not.toContain("fonts.googleapis");
  });
  it.each(["private nonce", "'unsafe-inline'", "\r\nHeader: private", "", "A".repeat(24)])(
    "foreign nonce input cannot become policy %s", nonce => {
      expect(validCspNonce(nonce)).toBe(false);
      expect(() => contentSecurityPolicy({ nonce, development: false, allowHttpPreview: false })).toThrow("invalid_csp_nonce");
    });
  it("only development can request the debugging eval permission", () => {
    expect(contentSecurityPolicy({ nonce: createCspNonce(), development: true, allowHttpPreview: false }))
      .toContain("'unsafe-eval'");
  });
  it.each(["/", "/membership", "/admin/community", "/admin-offline", "/unknown-route"])(
    "HTML route %s receives nonce policy", path => expect(isHtmlCspPath(path)).toBe(true));
  it.each(["/api/pwa/events", "/api", "/_next/static/main.js", "/brand-mark.svg", "/sw.js", "/robots.txt"])(
    "asset/API route %s avoids nonce HTML caching policy", path => expect(isHtmlCspPath(path)).toBe(false));
});
