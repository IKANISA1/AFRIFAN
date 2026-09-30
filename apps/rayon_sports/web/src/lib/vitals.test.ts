import { afterEach, describe, expect, it, vi } from "vitest";
import type { Metric } from "web-vitals";
const mocks = vi.hoisted(() => ({ record: vi.fn().mockResolvedValue(true),
  onLCP: vi.fn(), onINP: vi.fn(), onCLS: vi.fn(), onFCP: vi.fn(), onTTFB: vi.fn() }));
vi.mock("web-vitals", () => mocks);
vi.mock("./web-observation-client", () => ({ recordWebObservation: mocks.record }));
import { reportWebVitals, sendToAnalytics } from "./vitals";
afterEach(() => { vi.restoreAllMocks(); vi.clearAllMocks(); vi.unstubAllEnvs(); });
describe("minimal web vitals", () => {
  it("development logging projects only finite rounded values", () => {
    vi.stubEnv("NODE_ENV", "development");
    const log = vi.spyOn(console, "info").mockImplementation(() => {});
    const metric = { name: "CLS", value: .123456, rating: "good" };
    for (const key of ["id", "navigationType", "entries"]) Object.defineProperty(metric, key, {
      get: () => { throw Error("private metric property"); }, enumerable: true,
    });
    sendToAnalytics(metric as Metric);
    expect(log).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1, event: "web_vital",
      name: "CLS", value: .123, rating: "good" });
    expect(mocks.record).not.toHaveBeenCalled();
  });
  it("production submits a projection and ignores foreign analytics endpoint configuration", () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("NEXT_PUBLIC_VITALS_ENDPOINT", "https://foreign.invalid/?token=private");
    sendToAnalytics({ name: "LCP", value: 1234.567, rating: "poor",
      id: "private", navigationType: "private" } as unknown as Metric);
    expect(mocks.record).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1, event: "web_vital",
      name: "LCP", value: 1230, rating: "poor" });
  });
  it("invalid metrics cannot be logged or submitted", () => {
    const log = vi.spyOn(console, "info").mockImplementation(() => {});
    sendToAnalytics({ name: "private", value: Infinity, rating: "private" } as unknown as Metric);
    expect(log).not.toHaveBeenCalled(); expect(mocks.record).not.toHaveBeenCalled();
  });
  it("duplicate mounts cannot register metric listeners twice", () => {
    reportWebVitals(); reportWebVitals();
    for (const callback of [mocks.onLCP,mocks.onINP,mocks.onCLS,mocks.onFCP,mocks.onTTFB])
      expect(callback).toHaveBeenCalledExactlyOnceWith(sendToAnalytics);
  });
});
