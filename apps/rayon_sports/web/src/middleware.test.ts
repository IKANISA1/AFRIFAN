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
});
