import { httpFixtureClubId, httpFixtureClub, httpFixtureOrigin, registerLocalHttpAssertions } from "../../../../../e2e/fixtures/local-http-route-assertions";
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
  WEB_OBSERVATIONS_ORIGIN: httpFixtureOrigin("https://synthetic.invalid"), WEB_OBSERVATIONS_CLUB_ID: httpFixtureClubId(),
  WEB_OBSERVATIONS_RETENTION_MS: "3600000", WEB_OBSERVATIONS_POLICY_REF: "SYNTHETIC_TEST_POLICY",
  WEB_OBSERVATIONS: { record: mocks.record } });
function request(body: unknown = pwa, path = "/api/pwa/events", headers: Record<string,string> = {}) {
  return new NextRequest(httpFixtureOrigin("https://synthetic.invalid") + path, { method: "POST",
    headers: { "content-type": "application/json", origin: httpFixtureOrigin("https://synthetic.invalid"), ...headers },
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
      observation: pwa, clubId: httpFixtureClub.id, retentionMs: 3600000, policyRef: "SYNTHETIC_TEST_POLICY" });
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

const localObservationRoutes = [
  { path: "/api/pwa/events", invoke: POST, body: pwa },
  { path: "/api/telemetry/vitals", invoke: VITALS, body: vital },
];
// Anonymous append-only observations have no loaded revision or conflict branch;
// failed or unavailable storage is deliberately projected as an unavailable error.
const localObservationStates = ["empty", "error", "permission_denied", "syncing", "security_timeout"] as const;
for (const route of localObservationRoutes) for (const state of localObservationStates) {
  it(`${route.path}: ${state} handler outcome`, async () => {
    let release: ((value: { schemaVersion: number; recorded: boolean }) => void) | undefined;
    if (state === "error") mocks.record.mockRejectedValue(Error("private diagnostic"));
    else if (state === "security_timeout") { vi.useFakeTimers(); mocks.record.mockReturnValue(new Promise(() => {})); }
    else if (state === "syncing") mocks.record.mockReturnValue(new Promise((resolve) => { release = resolve; }));
    let settled = false;
    const responsePromise = route.invoke(request(state === "empty" ? {} : route.body, route.path,
      state === "permission_denied" ? { origin: "https://foreign.invalid" } : {}))
      .then((response) => { settled = true; return response; });
    if (state === "syncing") {
      for (let i = 0; i < 24; i++) await Promise.resolve();
      expect(mocks.record).toHaveBeenCalledTimes(1); expect(settled).toBe(false);
      expect(mocks.record.mock.calls[0][0].clubId).toBe(httpFixtureClub.id);
      release?.({ schemaVersion: 1, recorded: true });
    }
    if (state === "security_timeout") await vi.advanceTimersByTimeAsync(250);
    const response = await responsePromise;
    expect(response.status).toBe({ empty: 400, error: 503, permission_denied: 403, syncing: 201, security_timeout: 503 }[state]);
    expect(response.headers.get("cache-control")).toBe("no-store, private");
    const body = await response.json();
    if (state === "syncing") expect(body).toEqual({ schemaVersion: 1, recorded: true });
    else { expect(body.recorded).toBeUndefined(); expect(JSON.stringify(body)).not.toContain("private"); }
    if (state === "empty" || state === "permission_denied") expect(mocks.record).not.toHaveBeenCalled();
  });
}
registerLocalHttpAssertions(localObservationRoutes.flatMap((route) => localObservationStates.map((state) => ({
  name: `${route.path}: ${state} handler outcome`, route: route.path, state,
}))));
