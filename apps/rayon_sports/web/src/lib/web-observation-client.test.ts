import { afterEach, describe, expect, it, vi } from "vitest";
import { createWebObservationReporter } from "./web-observation-client";
import { projectWebVital, type WebObservation, VITAL_NAMES } from "../../../../../cloudflare/web-observations/contracts.mjs";

const vital = { schemaVersion: 1, event: "web_vital", name: "LCP", value: 1200, rating: "good" } as const;
const pwa = { schemaVersion: 1, event: "pwa_event", eventType: "install-completed",
  surface: "site", displayMode: "standalone" } as const;
const accepted = () => new Response(null, { status: 201, headers: { "cache-control": "no-store, private" } });
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); vi.useRealTimers(); });

describe("private web observation transport", () => {
  it.each(["http://synthetic.invalid", "https://synthetic.invalid/path", "https://u:p@synthetic.invalid",
    "https://synthetic.invalid/?token=private"])("rejects noncanonical origin %s without network IO", async origin => {
    const fetch = vi.fn();
    expect(await createWebObservationReporter({ enabled: true, origin, fetch })(vital)).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it("disabled collection does not open network, storage or sync", async () => {
    const fetch = vi.fn();
    expect(await createWebObservationReporter({ enabled: false, origin: "https://synthetic.invalid", fetch })(vital)).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it("five rounded vital names have no actor/context and only one attempt each", async () => {
    const fetch = vi.fn().mockImplementation(accepted);
    const record = createWebObservationReporter({ enabled: true, origin: "https://synthetic.invalid", fetch });
    for (const name of VITAL_NAMES) {
      const raw = { name, value: name === "CLS" ? .12345 : 1234.567, rating: "good",
        id: "private-id", navigationType: "private-navigation", entries: ["private-dom"], phone: "+250700000099" };
      const observation = projectWebVital(raw)!;
      expect(await record(observation)).toBe(true);
      expect(await record(observation)).toBe(false);
    }
    expect(fetch).toHaveBeenCalledTimes(5);
    for (const [url, init] of fetch.mock.calls) {
      expect(url).toBe("https://synthetic.invalid/api/telemetry/vitals");
      expect(init).toMatchObject({ credentials: "omit", redirect: "error", cache: "no-store",
        referrerPolicy: "no-referrer", mode: "same-origin", method: "POST", keepalive: true });
      expect(init.headers).toEqual({ "content-type": "application/json", "x-africlub-csrf": "1" });
      expect(Object.keys(JSON.parse(init.body))).toEqual(["schemaVersion", "event", "name", "value", "rating"]);
      for (const token of ["private-id", "private-navigation", "private-dom", "+250700000099"])
        expect(init.body).not.toContain(token);
    }
  });
  it("unknown extra context is rejected before the first request", async () => {
    const fetch = vi.fn(), record = createWebObservationReporter({ enabled: true,
      origin: "https://synthetic.invalid", fetch });
    expect(await record({ ...vital, id: "private" } as WebObservation)).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it("a lost acknowledgement is not retried even if the sink committed", async () => {
    let committed = 0;
    const fetch = vi.fn(async () => { committed++; throw Error("private sink"); });
    const record = createWebObservationReporter({ enabled: true, origin: "https://synthetic.invalid", fetch });
    expect(await record(vital)).toBe(false); expect(await record(vital)).toBe(false);
    expect(committed).toBe(1); expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("an unresponsive transport has a finite deadline and receives no second call", async () => {
    vi.useFakeTimers();
    const fetch = vi.fn<typeof globalThis.fetch>(() => new Promise<Response>(() => {}));
    const record = createWebObservationReporter({ enabled: true, origin: "https://synthetic.invalid", fetch });
    const pending = record(vital);
    await vi.advanceTimersByTimeAsync(1000);
    expect(await pending).toBe(false); expect(fetch).toHaveBeenCalledTimes(1);
    expect(fetch.mock.calls[0][1]?.signal?.aborted).toBe(true);
  });
  it("PWA events use only the finite private endpoint and a bounded document quota", async () => {
    const fetch = vi.fn().mockImplementation(accepted);
    const record = createWebObservationReporter({ enabled: true, origin: "https://synthetic.invalid", fetch });
    for (let i = 0; i < 35; i++) expect(await record(pwa)).toBe(true);
    expect(await record(pwa)).toBe(false); expect(fetch).toHaveBeenCalledTimes(35);
    expect(fetch.mock.calls.every(([url]) => url === "https://synthetic.invalid/api/pwa/events")).toBe(true);
  });
  it("a cacheable acknowledgement does not claim accepted delivery or retry", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(null, { status: 201 }));
    const record = createWebObservationReporter({ enabled: true, origin: "https://synthetic.invalid", fetch });
    expect(await record(vital)).toBe(false); expect(await record(vital)).toBe(false);
    expect(fetch).toHaveBeenCalledTimes(1);
  });
});
