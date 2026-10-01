import { beforeEach, describe, expect, it, vi } from "vitest";

const context = vi.hoisted(() => vi.fn());
vi.mock("server-only", () => ({}));
vi.mock("@opennextjs/cloudflare", () => ({ getCloudflareContext: context }));
import { webObservationEnvironment } from "./web-observation-server";

describe("observation runtime environment", () => {
  beforeEach(() => {
    context.mockReset();
  });

  it("uses the actual runtime bindings with asynchronous context lookup", async () => {
    const env = { WEB_OBSERVATIONS_ENABLED: "true", WEB_OBSERVATIONS: { record: vi.fn() } };
    context.mockResolvedValue({ env });
    expect(await webObservationEnvironment()).toBe(env);
    expect(context).toHaveBeenCalledExactlyOnceWith({ async: true });
    expect(env.WEB_OBSERVATIONS.record).not.toHaveBeenCalled();
  });

  it("an unavailable context remains disabled without invoking any provider", async () => {
    context.mockRejectedValue(new Error("synthetic unbound local context"));
    expect(await webObservationEnvironment()).toEqual({});
    expect(context).toHaveBeenCalledTimes(1);
  });
});
