import { act, cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import AdminPredictionsPage from "@/app/admin/predictions/page";
import { AdminToastProvider } from "../admin-toast";

const portal = vi.hoisted(() => ({ current: {} as Record<string, unknown> }));
vi.mock("../admin-portal-provider", () => ({ useAdminPortal: () => portal.current }));

const timestamp = "2026-10-01T09:00:00.000Z";
const access: AdminAccess = {
  hasAccess: true, isAuthenticated: true, isSuperAdmin: false, userId: "operator-a",
  role: "club_admin", clubId: "24", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1,
};

function workspace(prefix = "", clubId = 24) {
  const markets = Array.from({ length: 26 }, (_, i) => ({
    id: `market-${i + 1}`, slug: `template-${i + 1}`, name: `${prefix}Template ${String(i + 1).padStart(2, "0")}`,
    shortName: `T${i + 1}`, marketGroup: "match_result", marketCategory: "result", betType: "single",
    difficultyTier: "entry", defaultFetValue: 100, description: "Historical template", isActive: true,
    leagueAvailability: ["League"], sortOrder: i, createdAt: timestamp, updatedAt: timestamp,
  }));
  const competitions = [{ id: "competition-1", slug: "league", name: `${prefix}League`, shortName: "L",
    competitionKind: "league", region: "Africa", countryCode: "RW", countryName: "Rwanda", isActive: true,
    createdAt: timestamp, updatedAt: timestamp }];
  const seasons = [{ id: "season-1", competitionId: "competition-1", competitionName: `${prefix}League`,
    slug: "2026-27", label: "2026/27", yearStart: 2026, yearEnd: 2027, startsOn: "2026-08-01",
    endsOn: "2027-06-30", status: "active", isActive: true, createdAt: timestamp, updatedAt: timestamp }];
  const fixtures = Array.from({ length: 26 }, (_, i) => ({ id: `fixture-${i + 1}`, competitionName: `${prefix}League`,
    seasonLabel: "2026/27", roundName: null, kickoffAt: "2026-10-02T16:00:00.000Z", venueName: null,
    homeTeamName: `${prefix}Home ${i + 1}`, homeTeamShortName: `H${i + 1}`, awayTeamName: `Away ${i + 1}`,
    awayTeamShortName: `A${i + 1}`, homeScore: null, awayScore: null, status: "scheduled", updatedAt: timestamp }));
  const partnerPools = [{ id: "pool-1", clubId, partnerId: "partner-1", partnerName: "Historical partner",
    partnerSlug: "historical-partner", initiativeId: null, fixtureId: "fixture-1", title: `${prefix}Historical derby`,
    predictionKind: "wdw", partnerStakeFet: 5000, fanEntryFet: 100, eligibilityMode: "partner_earn_required",
    status: "open", lockAt: "2026-10-02T15:55:00.000Z", totalEntries: 3, totalFanEntryFet: 300, settlement: null }];
  return { markets, competitions, seasons, fixtures, partnerPools, partners: [] };
}

const json = (data: unknown) => new Response(JSON.stringify({ data }), { headers: { "content-type": "application/json" } });
const failure = (status: number, code: string) => new Response(JSON.stringify({ code, error: "Operation not confirmed" }), { status, headers: { "content-type": "application/json" } });
type ApiHandler = (url: URL, options?: RequestInit) => Response | Promise<Response>;
let records: ReturnType<typeof workspace>;
let requests: { url: URL; options?: RequestInit }[];
let api: ApiHandler;

beforeEach(() => {
  records = workspace(); requests = [];
  portal.current = { access, client: {} };
  window.history.replaceState(null, "", "/admin/predictions?club=24");
  api = (url) => url.pathname.endsWith("predict-operations")
    ? json({ settings: { enabled: true, entry_fet: 0, welcome_fet: 0, economics_version: "free_v1" }, fixtures: [] })
    : json(records);
  vi.stubGlobal("fetch", vi.fn((input, options?: RequestInit) => {
    const url = new URL(String(input));
    requests.push({ url, options });
    return Promise.resolve(api(url, options));
  }));
});
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

const page = () => <><AdminToastProvider /><AdminPredictionsPage /></>;
const tab = (label: string) => fireEvent.click(screen.getByRole("button", { name: label }));

describe("canonical predictions page after controller and tab extraction", () => {
  it("retains independent search/pagination across all five tabs and club read-only controls", async () => {
    render(page());
    await screen.findByText("Historical derby");
    expect(screen.queryByRole("button", { name: "Reconcile historical partner pool" })).toBeNull();
    tab("Templates");
    expect(screen.getAllByRole("button", { name: "Disable" }).every((button) => (button as HTMLButtonElement).disabled)).toBe(true);
    fireEvent.click(screen.getByRole("button", { name: "Go to next page" }));
    expect(screen.getByText("Template 26")).toBeVisible();
    fireEvent.change(screen.getByRole("searchbox", { name: "Search prediction templates" }), { target: { value: "Template 01" } });
    expect(screen.getByText("Template 01")).toBeVisible();
    expect(screen.getByText("1–1 of 1")).toBeVisible();
    tab("Competitions");
    expect(screen.getByRole("button", { name: "Disable" })).toBeDisabled();
    fireEvent.change(screen.getByRole("searchbox", { name: "Search competitions" }), { target: { value: "Rwanda" } });
    tab("Seasons");
    expect(screen.getByText("League — 2026/27")).toBeVisible();
    tab("Fixtures");
    fireEvent.change(screen.getByRole("searchbox", { name: "Search fixtures" }), { target: { value: "H12" } });
    fireEvent.click(screen.getByRole("button", { name: "View fixture H12 versus A12" }));
    const drawer = await screen.findByRole("dialog", { name: "Fixture details" });
    expect(within(drawer).getByLabelText("Home 12 versus Away 12")).toBeVisible();
    fireEvent.click(within(drawer).getByRole("button", { name: "Close Fixture details" }));
    tab("Templates");
    expect(screen.getByRole("searchbox", { name: "Search prediction templates" })).toHaveValue("Template 01");
    tab("Competitions");
    expect(screen.getByRole("searchbox", { name: "Search competitions" })).toHaveValue("Rwanda");
    expect(requests.filter((request) => request.options?.method === "POST")).toHaveLength(0);
  });

  it("sends the loaded version token and refreshes a stale template instead of confirming a failed save", async () => {
    portal.current = { access: { ...access, role: "super_admin", isSuperAdmin: true }, client: {} };
    const read = api;
    api = (url, options) => {
      if (options?.method !== "POST") return read(url, options);
      records.markets[0].isActive = false;
      records.markets[0].updatedAt = "2026-10-01T09:01:00.000Z";
      return failure(409, "STALE_RECORD");
    };
    render(page()); await screen.findByText("Historical derby"); tab("Templates");
    fireEvent.change(screen.getByRole("searchbox", { name: "Search prediction templates" }), { target: { value: "Template 01" } });
    fireEvent.click(screen.getByRole("button", { name: "Disable" }));
    await screen.findByText("Could not confirm the prediction-template change.");
    expect(screen.getByRole("button", { name: "Enable" })).toBeEnabled();
    const sent = requests.find((request) => request.options?.method === "POST")!;
    expect(sent.url.pathname).toBe("/api/admin/predictions-markets");
    expect(JSON.parse(String(sent.options?.body))).toMatchObject({ id: "market-1", expectedUpdatedAt: timestamp, isActive: false });
    expect(requests.filter((request) => request.url.pathname.endsWith("/predictions"))).toHaveLength(2);
    expect(screen.queryByText("Template 01 disabled.")).toBeNull();
  });

  it("clears prior rows, active fixture details and searches when permission is denied", async () => {
    render(page()); await screen.findByText("Historical derby"); tab("Fixtures");
    fireEvent.change(screen.getByRole("searchbox", { name: "Search fixtures" }), { target: { value: "H12" } });
    fireEvent.click(screen.getByRole("button", { name: "View fixture H12 versus A12" }));
    await screen.findByRole("dialog", { name: "Fixture details" });
    api = () => failure(403, "ADMIN_ACCESS_DENIED");
    act(() => { window.dispatchEvent(new Event("online")); });
    await waitFor(() => expect(screen.getAllByText("Prediction access denied").length).toBeGreaterThan(0));
    expect(screen.queryByRole("dialog", { name: "Fixture details" })).toBeNull();
    expect(screen.queryByText("Historical derby")).toBeNull();
    expect(screen.queryByRole("searchbox")).toBeNull();
  });

  it("discards an old account/club response after the canonical page changes scope", async () => {
    let oldResponse!: (value: Response) => void;
    const read = api;
    api = (url, options) => url.pathname.endsWith("/predictions") && url.searchParams.get("club") === "24"
      ? new Promise<Response>((resolve) => { oldResponse = resolve; }) : read(url, options);
    const mounted = render(page());
    await waitFor(() => expect(oldResponse).toBeTypeOf("function"));
    portal.current = { access: { ...access, userId: "operator-b", clubId: "25", availableClubIds: ["25"] }, client: {} };
    records = workspace("New ", 25);
    window.history.replaceState(null, "", "/admin/predictions?club=25");
    mounted.rerender(page());
    await screen.findByText("New Historical derby");
    await act(async () => { oldResponse(json(workspace("Old "))); });
    expect(screen.queryByText("Old Historical derby")).toBeNull();
    expect(screen.getByText("New Historical derby")).toBeVisible();
    expect(requests.some((request) => request.url.pathname.endsWith("/predictions") && request.url.searchParams.get("club") === "25")).toBe(true);
  });

  it("keeps a late old-account mutation from refreshing or notifying the new account", async () => {
    portal.current = { access: { ...access, role: "super_admin", isSuperAdmin: true }, client: {} };
    let oldMutation!: (value: Response) => void;
    const read = api;
    api = (url, options) => options?.method === "POST"
      ? new Promise<Response>((resolve) => { oldMutation = resolve; }) : read(url, options);
    const mounted = render(page()); await screen.findByText("Historical derby"); tab("Templates");
    fireEvent.change(screen.getByRole("searchbox", { name: "Search prediction templates" }), { target: { value: "Template 01" } });
    fireEvent.click(screen.getByRole("button", { name: "Disable" }));
    await waitFor(() => expect(oldMutation).toBeTypeOf("function"));
    portal.current = { access: { ...access, userId: "operator-b", clubId: "25", availableClubIds: ["25"] }, client: {} };
    records = workspace("New ", 25); window.history.replaceState(null, "", "/admin/predictions?club=25");
    mounted.rerender(page()); await screen.findByText("New Historical derby");
    const readCount = requests.filter((request) => request.url.pathname.endsWith("/predictions")).length;
    await act(async () => { oldMutation(json("market-1")); });
    expect(requests.filter((request) => request.url.pathname.endsWith("/predictions"))).toHaveLength(readCount);
    expect(screen.queryByText("Template 01 disabled.")).toBeNull();
    expect(screen.getByText("New Historical derby")).toBeVisible();
  });
});
