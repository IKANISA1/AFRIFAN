import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";
import { middleware } from "./middleware";

describe("proxy recovery routing", () => {
  it.each([
    "https://gikundiro.com/admin/offline?source=legacy",
    "https://admin.gikundiro.com/admin/offline?source=legacy",
  ])("redirects the stale nested route before admin rendering: %s", (url) => {
    const response = middleware(new NextRequest(url));

    expect(response.status).toBe(308);
    expect(response.headers.get("location")).toBe(
      new URL("/admin-offline?source=legacy", url).toString(),
    );
  });

  it("leaves the canonical standalone recovery route available", () => {
    const response = middleware(
      new NextRequest("https://admin.gikundiro.com/admin-offline"),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
  });
});
