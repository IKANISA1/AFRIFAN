import { NextRequest } from "next/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ environment: vi.fn(), record: vi.fn() }));
vi.mock("@/lib/web-observation-server", () => ({ webObservationEnvironment: mocks.environment }));
import { POST } from "./route";
import { POST as VITALS } from "../../telemetry/vitals/route";

const pwa = { schemaVersion: 1, event: "pwa_event", eventType: "install-completed",
  surface: "site", displayMode: "standalone" };
const vital = { schemaVersion: 1, event: "web_vital", name: "LCP", value: 1200, rating: "good" };
const configured = () => ({ WEB_OBSERVATIONS_ENABLED: "true", WEB_OBSERVATIONS_ENVIRONMENT: "isolated-staging",
  WEB_OBSERVATIONS_ORIGIN: "https://synthetic.invalid", WEB_OBSERVATIONS_CLUB_ID: "24",
  WEB_OBSERVATIONS_RETENTION_MS: "3600000", WEB_OBSERVATIONS_POLICY_REF: "SYNTHETIC_TEST_POLICY",
  WEB_OBSERVATIONS: { record: mocks.record } });
function request(body: unknown = pwa, path = "/api/pwa/events", headers: Record<string,string> = {}) {
  return new NextRequest("https://synthetic.invalid" + path, { method: "POST",
    headers: { "content-type": "application/json", origin: "https://synthetic.invalid", ...headers },
    body: JSON.stringify(body) });
}
beforeEach(() => {
  vi.clearAllMocks(); mocks.environment.mockResolvedValue(configured());
  mocks.record.mockResolvedValue({ schemaVersion: 1, recorded: true });
});
afterEach(() => vi.useRealTimers());

describe("private PWA and vitals route wiring", () => {
  it("finite PWA events invoke only the selected private binding", async () => {
    const response = await POST(request());
    expect(response.status).toBe(201);
    expect(response.headers.get("cache-control")).toBe("no-store, private");
    expect(mocks.record).toHaveBeenCalledExactlyOnceWith({
      observation: pwa, clubId: 24, retentionMs: 3600000, policyRef: "SYNTHETIC_TEST_POLICY" });
    expect(mocks.environment).toHaveBeenCalledTimes(1);
  });
  it("the vitals route uses the same private contract with a distinct finite event", async () => {
    const response = await VITALS(request(vital, "/api/telemetry/vitals"));
    expect(response.status).toBe(201);
    expect(mocks.record.mock.calls[0][0].observation).toEqual(vital);
  });
  it("disabled collection reads no body and invokes no provider", async () => {
    mocks.environment.mockResolvedValue({});
    const raw = request();
    Object.defineProperty(raw, "body", { get: () => { throw Error("private body inspected"); } });
    expect((await POST(raw)).status).toBe(503); expect(mocks.record).not.toHaveBeenCalled();
  });
  it.each([{ userId: "private" }, { path: "/private/actor" }, { user_agent: "private" },
    { payload: { note: "+250700000099" } }, { clubId: 26 }])("rejects foreign context", async extra => {
    expect((await POST(request({ ...pwa, ...extra }))).status).toBe(400);
    expect(mocks.record).not.toHaveBeenCalled();
  });
  it("cookies and bearer credentials cannot enter the anonymous observation sink", async () => {
    const candidates: Record<string, string>[] = [{ cookie: "private-session" }, { authorization: "Bearer private" }];
    for (const headers of candidates)
      expect((await POST(request(pwa, "/api/pwa/events", headers))).status).toBe(403);
    expect(mocks.record).not.toHaveBeenCalled();
  });
  it("foreign origin is denied even with a CSRF marker", async () => {
    expect((await POST(request(pwa, "/api/pwa/events", {
      origin: "https://foreign.invalid", "x-africlub-csrf": "1" }))).status).toBe(403);
    expect(mocks.record).not.toHaveBeenCalled();
  });
  it("server errors never expose storage details or retry a failed call", async () => {
    mocks.record.mockRejectedValue(Error("private phone=+250700000099 token=private"));
    const response = await POST(request());
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ schemaVersion: 1, error: "web_observation_unavailable" });
    expect(mocks.record).toHaveBeenCalledTimes(1);
  });
  it("an unresponsive binding has a finite deadline and cannot report completion", async () => {
    vi.useFakeTimers(); mocks.record.mockReturnValue(new Promise(() => {}));
    const pending = POST(request());
    await vi.advanceTimersByTimeAsync(250);
    expect((await pending).status).toBe(503); expect(mocks.record).toHaveBeenCalledTimes(1);
  });
  it("a PWA event cannot be routed through the vitals namespace", async () => {
    expect((await VITALS(request(pwa, "/api/telemetry/vitals"))).status).toBe(400);
    expect(mocks.record).not.toHaveBeenCalled();
  });
});
