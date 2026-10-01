// @vitest-environment node
import { createClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { normalizeAdminMembershipPackages, saveAdminMembershipPackage, type AdminMembershipPackageInput } from "./membership";
import { getAdminPartnerOptions } from "./partner-pools";

const membershipPackage = {
  id: "tier-1",
  clubId: 24,
  tier: "gold",
  title: "Gold supporter",
  description: "Annual supporter package.",
  sortOrder: 10,
  perks: ["Priority ticketing", "Member events"],
  annualPrice: 75_000,
  isActive: true,
  createdAt: "2026-07-29T10:00:00.000Z",
  updatedAt: "2026-07-29T10:00:00.000Z",
};

describe("membership package normalization", () => {
  it("keeps only strict bounded fields", () => {
    const normalized = normalizeAdminMembershipPackages([
      {
        ...membershipPackage,
        privatePaymentReference: "private",
        metadata: { accessToken: "private" },
      },
    ]);

    expect(normalized).toEqual([membershipPackage]);
    expect(JSON.stringify(normalized)).not.toContain("privatePaymentReference");
    expect(JSON.stringify(normalized)).not.toContain("accessToken");
  });

  it("drops malformed and duplicate packages", () => {
    expect(
      normalizeAdminMembershipPackages([
        membershipPackage,
        { ...membershipPackage, title: "Duplicate" },
        { ...membershipPackage, id: "tier-2", tier: "unknown" },
        { ...membershipPackage, id: "tier-3", annualPrice: -1 },
        { ...membershipPackage, id: "tier-4", updatedAt: "not-a-date" },
      ]),
    ).toEqual([membershipPackage]);
  });

  it("caps the catalogue at 100 input records", () => {
    const records = Array.from({ length: 110 }, (_, index) => ({
      ...membershipPackage,
      id: `tier-${index}`,
    }));

    expect(normalizeAdminMembershipPackages(records)).toHaveLength(100);
  });
});

const partnerId = "99967000-0000-4000-8000-000000000100";
const foreignPartner = "99968000-0000-4000-8000-000000000100";
const creationId = "99967000-0000-4000-8000-000000000800";
const version = "2026-10-01T10:00:00.000Z";
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: false, userId: "staff-1", role: "club_admin", clubId: "24", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1 };
const validInput: AdminMembershipPackageInput = { creationId, partnerId, tier: "imena", title: "Club supporter", subtitle: "Annual supporter membership", description: "Reviewed supporter benefits", annualPrice: 1000, perks: ["Member events"], sortOrder: 1, isActive: false };
function canonicalClient() {
  const rows = new Map<string, Record<string, unknown>>();
  const state = { partnerIds: [partnerId] as unknown, resolutionFailure: false, loseResponse: false, readUnavailable: false, inserts: 0, updates: 0 };
  const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input)); const method = init?.method ?? "GET";
    const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    if (url.pathname.endsWith("/rpc/resolve_partner_ids_for_club")) {
      expect(JSON.parse(String(init?.body))).toEqual({ p_club_id: 24 });
      return state.resolutionFailure ? json({ message: "Scope unavailable" }, 503) : json(state.partnerIds);
    }
    if (url.pathname.endsWith("/partners")) {
      expect(url.searchParams.get("is_active")).toBe("eq.true"); expect(url.searchParams.get("limit")).toBe("500");
      expect(url.searchParams.get("id")).toBe(`in.(${partnerId})`);
      return json([{ id: partnerId, name: "Current club partner", slug: "club-partner", category: "football" }]);
    }
    expect(url.pathname).toBe("/rest/v1/membership_packages");
    if (method === "GET") {
      if (state.readUnavailable) throw new Error("Readback unavailable after commit");
      expect(url.searchParams.get("club_id")).toBe("eq.24");
      const row = rows.get(url.searchParams.get("id")!.slice(3));
      return json(row?.club_id === 24 ? [row] : []);
    }
    const payload = JSON.parse(String(init?.body));
    if (method === "POST") {
      state.inserts++; expect(payload).toEqual({ id: creationId, club_id: 24, partner_id: partnerId, tier: "imena", title: "Club supporter", subtitle: "Annual supporter membership", description: "Reviewed supporter benefits", annual_price: 1000, price: 1000, benefits: ["Member events"], sort_order: 1, is_active: false });
      if (rows.has(payload.id)) return json({ message: "Duplicate creation reference", code: "23505" }, 409);
      rows.set(payload.id, { ...payload, benefit_scope: "unclassified", store_billing_required: false, updated_at: version });
      if (state.loseResponse) { state.readUnavailable = true; throw new Error("Committed response was lost"); }
      return json({ id: payload.id }, 201);
    }
    expect(method).toBe("PATCH"); state.updates++;
    expect(url.searchParams.get("club_id")).toBe("eq.24"); expect(url.searchParams.get("updated_at")).toBe(`eq.${version}`);
    expect(payload).not.toHaveProperty("benefit_scope"); expect(payload).not.toHaveProperty("store_billing_required");
    const row = rows.get(url.searchParams.get("id")!.slice(3));
    if (row?.club_id !== 24 || row.updated_at !== version) return json(null);
    rows.set(String(row.id), { ...row, ...payload }); return json({ id: row.id });
  });
  return { rows, state, fetcher, client: createClient("https://membership.test", "test-key", { global: { fetch: fetcher }, auth: { persistSession: false, autoRefreshToken: false } }) };
}
describe("actual canonical membership package consumer", () => {
  it("resolves only active current-club partners and supplies every required insert field", async () => {
    const fixture = canonicalClient(); expect(await saveAdminMembershipPackage(fixture.client, access, validInput)).toBe(creationId);
    expect(fixture.state.inserts).toBe(1); expect(fixture.rows.get(creationId)).toMatchObject({ subtitle: validInput.subtitle, partner_id: partnerId, benefit_scope: "unclassified", store_billing_required: false });
  });
  it("recovers the original committed creation reference after response loss without another insert", async () => {
    const fixture = canonicalClient(); fixture.state.loseResponse = true;
    await expect(saveAdminMembershipPackage(fixture.client, access, validInput)).rejects.toThrow("Readback unavailable");
    fixture.state.loseResponse = false; fixture.state.readUnavailable = false;
    expect(await saveAdminMembershipPackage(fixture.client, access, validInput)).toBe(creationId); expect(fixture.state.inserts).toBe(1);
    await expect(saveAdminMembershipPackage(fixture.client, access, { ...validInput, title: "Different command" })).rejects.toThrow("different package");
    expect(fixture.state.inserts).toBe(1);
  });
  it("keeps exact club/version predicates and preserves reviewed policy fields on update", async () => {
    const fixture = canonicalClient(); await saveAdminMembershipPackage(fixture.client, access, validInput);
    fixture.rows.set(creationId, { ...fixture.rows.get(creationId), benefit_scope: "physical_membership", store_billing_required: true });
    expect(await saveAdminMembershipPackage(fixture.client, access, { ...validInput, id: creationId, expectedUpdatedAt: version, title: "Updated title" })).toBe(creationId);
    expect(fixture.rows.get(creationId)).toMatchObject({ title: "Updated title", benefit_scope: "physical_membership", store_billing_required: true });
    fixture.rows.set(creationId, { ...fixture.rows.get(creationId), updated_at: "2026-10-02T10:00:00Z" });
    await expect(saveAdminMembershipPackage(fixture.client, access, { ...validInput, id: creationId, expectedUpdatedAt: version })).rejects.toThrow("changed");
  });
  it("rejects foreign-club updates and foreign/no active partner without writing", async () => {
    const fixture = canonicalClient(); fixture.rows.set(creationId, { id: creationId, club_id: 25, updated_at: version });
    await expect(saveAdminMembershipPackage(fixture.client, access, { ...validInput, id: creationId, expectedUpdatedAt: version })).rejects.toThrow("changed");
    await expect(saveAdminMembershipPackage(fixture.client, access, { ...validInput, partnerId: foreignPartner })).rejects.toThrow("selected club");
    fixture.state.partnerIds = []; await expect(saveAdminMembershipPackage(fixture.client, access, validInput)).rejects.toThrow("selected club"); expect(fixture.state.inserts).toBe(0);
  });
  it("fails closed on unresolved partner scope and never falls back to all partners", async () => {
    const fixture = canonicalClient(); fixture.state.partnerIds = null;
    await expect(getAdminPartnerOptions(fixture.client, access)).rejects.toThrow("scope could not be verified");
    fixture.state.partnerIds = ["forged-partner"]; await expect(getAdminPartnerOptions(fixture.client, access)).rejects.toThrow("scope could not be verified");
    fixture.state.resolutionFailure = true; await expect(getAdminPartnerOptions(fixture.client, access)).rejects.toThrow("Scope unavailable");
    expect(fixture.fetcher.mock.calls.every(([url]) => String(url).includes("/rpc/"))).toBe(true);
  });
  it.each([{ annualPrice: Infinity }, { annualPrice: NaN }, { annualPrice: 1.5 }, { sortOrder: -1 }, { subtitle: "" }, { partnerId: "" }, { creationId: undefined }, { benefitScope: "physical_membership" }])("rejects invalid or approval-bearing input before any request: %j", async patch => {
    const fixture = canonicalClient(); await expect(saveAdminMembershipPackage(fixture.client, access, { ...validInput, ...patch } as AdminMembershipPackageInput)).rejects.toThrow("fields"); expect(fixture.fetcher).not.toHaveBeenCalled();
  });
  it.each([{ role: "club_moderator" }, { hasAccess: false }, { clubId: "25" }, { isAuthenticated: false }])("does not authorize configuration through a forged or read-only context: %j", async patch => {
    const fixture = canonicalClient(); await expect(saveAdminMembershipPackage(fixture.client, { ...access, ...patch } as AdminAccess, validInput)).rejects.toThrow("administrator access"); expect(fixture.fetcher).not.toHaveBeenCalled();
  });
});
