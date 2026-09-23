import { describe, expect, it } from "vitest";
import { boundedSharedText, safeSharedWebUrl } from "./share-target-input";

describe("share-target input boundary", () => {
  it("bounds shared copy and removes control characters", () => {
    expect(boundedSharedText(["  hello\u0000 \n world  ", "ignored"], 8)).toBe(
      "hello wo",
    );
  });

  it("allows only normalized HTTP and HTTPS destinations", () => {
    expect(safeSharedWebUrl("https://example.com/story")).toBe(
      "https://example.com/story",
    );
    expect(safeSharedWebUrl("http://example.com")).toBe("http://example.com/");
    expect(safeSharedWebUrl("javascript:alert(1)")).toBeNull();
    expect(safeSharedWebUrl("data:text/html,unsafe")).toBeNull();
    expect(safeSharedWebUrl("//example.com/story")).toBeNull();
    expect(safeSharedWebUrl("not a URL")).toBeNull();
  });
});
