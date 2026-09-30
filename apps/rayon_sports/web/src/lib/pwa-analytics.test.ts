import { afterEach, describe, expect, it, vi } from "vitest";
const record = vi.hoisted(() => vi.fn().mockResolvedValue(true));
vi.mock("./web-observation-client", () => ({ recordWebObservation: record }));
import { trackPwaEvent } from "./pwa-analytics";
afterEach(() => { vi.clearAllMocks(); vi.unstubAllGlobals(); });

describe("finite PWA projection", () => {
  it("legacy path and payload are never read or forwarded", () => {
    const input = { eventType: "install-completed", surface: "site" as const, displayMode: "standalone" };
    for (const key of ["path", "payload"]) Object.defineProperty(input, key, {
      get: () => { throw Error("private field inspected"); }, enumerable: true,
    });
    trackPwaEvent(input);
    expect(record).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1, event: "pwa_event",
      eventType: "install-completed", surface: "site", displayMode: "standalone" });
  });
  it.each([
    { eventType: "private-phone-250700000099", surface: "site", displayMode: "browser" },
    { eventType: "install-completed", surface: "private", displayMode: "browser" },
    { eventType: "install-completed", surface: "site", displayMode: "private" },
  ])("rejects a foreign event label", input => {
    trackPwaEvent(input as Parameters<typeof trackPwaEvent>[0]);
    expect(record).not.toHaveBeenCalled();
  });
});
