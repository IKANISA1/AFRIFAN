import { describe, expect, it } from "vitest";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
  readCookieValue,
} from "@/lib/admin-club-scope";

describe("admin club scope", () => {
  it("prefers explicit query scope over cookie scope", () => {
    const params = new URLSearchParams("club=48");

    expect(getRequestedAdminClubId(params, "24")).toBe("48");
  });

  it("falls back to cookie scope when the query is absent", () => {
    const params = new URLSearchParams();

    expect(getRequestedAdminClubId(params, "24")).toBe("24");
  });

  it("reads the persisted admin club scope cookie", () => {
    const cookieHeader = [
      "sb-access-token=test-token",
      `${adminClubScopeCookieName}=48`,
      "theme=dark",
    ].join("; ");

    expect(readCookieValue(cookieHeader, adminClubScopeCookieName)).toBe("48");
  });
});
