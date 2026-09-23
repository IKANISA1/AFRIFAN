import { describe, expect, it } from "vitest";
import { normalizeAdminOffersWorkspace } from "./offers";

const catalog = {
  id: "catalog-1",
  code: "G041",
  item_name: "Partner matchday reward",
  fet_value: 240,
  private_settlement_rule: "private",
};

const partner = {
  id: "partner-1",
  name: "Verified Mobility",
  slug: "verified-mobility",
  category: "mobility",
  private_contact: "private@example.com",
};

const offer = {
  id: "offer-1",
  club_id: 24,
  catalog_item_id: "catalog-1",
  partner_id: "partner-1",
  subtitle: "Complete the approved journey to earn FET.",
  cta_label: "View journey",
  verification_mode: "mobility_confirmation",
  deeplink_route: "/predict?section=wallet",
  external_url: "https://partner.example/offer",
  is_featured: true,
  is_active: true,
  sort_order: 20,
  created_at: "2026-07-30T08:00:00.000Z",
  updated_at: "2026-07-30T09:00:00.000Z",
  metadata: { token: "private" },
};

describe("partner-offer admin normalization", () => {
  it("projects only schema-owned offer, catalog, and partner fields", () => {
    const normalized = normalizeAdminOffersWorkspace({
      offers: [offer],
      catalog: [catalog],
      partners: [partner],
    });

    expect(normalized).toEqual({
      catalog: [
        {
          id: "catalog-1",
          code: "G041",
          itemName: "Partner matchday reward",
          fetValue: 240,
        },
      ],
      partners: [
        {
          id: "partner-1",
          name: "Verified Mobility",
          slug: "verified-mobility",
          category: "mobility",
        },
      ],
      offers: [
        {
          id: "offer-1",
          clubId: 24,
          catalogItemId: "catalog-1",
          code: "G041",
          title: "Partner matchday reward",
          fetValue: 240,
          partnerId: "partner-1",
          partnerName: "Verified Mobility",
          partnerSlug: "verified-mobility",
          partnerCategory: "mobility",
          subtitle: "Complete the approved journey to earn FET.",
          ctaLabel: "View journey",
          verificationMode: "mobility_confirmation",
          deeplinkRoute: "/predict?section=wallet",
          externalUrl: "https://partner.example/offer",
          isFeatured: true,
          isActive: true,
          sortOrder: 20,
          createdAt: "2026-07-30T08:00:00.000Z",
          updatedAt: "2026-07-30T09:00:00.000Z",
        },
      ],
    });
    expect(JSON.stringify(normalized)).not.toContain("private");
    expect(JSON.stringify(normalized)).not.toContain("metadata");
  });

  it("drops malformed, unsafe, duplicate, and unresolvable offers", () => {
    const normalized = normalizeAdminOffersWorkspace({
      catalog: [catalog],
      partners: [partner],
      offers: [
        offer,
        { ...offer, subtitle: "duplicate" },
        { ...offer, id: "offer-2", catalog_item_id: "missing" },
        { ...offer, id: "offer-3", external_url: "http://unsafe.example" },
        { ...offer, id: "offer-4", deeplink_route: "//unsafe.example" },
        { ...offer, id: "offer-5", updated_at: "not-a-date" },
        { ...offer, id: "offer-6", verification_mode: "unknown" },
      ],
    });

    expect(normalized.offers).toEqual([
      expect.objectContaining({ id: "offer-1" }),
    ]);
  });

  it("accepts already-normalized API values without private extras", () => {
    const first = normalizeAdminOffersWorkspace({
      offers: [offer],
      catalog: [catalog],
      partners: [partner],
    });

    expect(normalizeAdminOffersWorkspace(first)).toEqual(first);
  });

  it("caps all three controlled collections at 500 rows", () => {
    const catalogRows = Array.from({ length: 510 }, (_, index) => ({
      ...catalog,
      id: `catalog-${index}`,
      code: `G${String(index).padStart(3, "0")}`,
    }));
    const partnerRows = Array.from({ length: 510 }, (_, index) => ({
      ...partner,
      id: `partner-${index}`,
      slug: `partner-${index}`,
    }));
    const offerRows = Array.from({ length: 510 }, (_, index) => ({
      ...offer,
      id: `offer-${index}`,
      catalog_item_id: `catalog-${index}`,
      partner_id: `partner-${index}`,
    }));

    const normalized = normalizeAdminOffersWorkspace({
      offers: offerRows,
      catalog: catalogRows,
      partners: partnerRows,
    });
    expect(normalized.catalog).toHaveLength(500);
    expect(normalized.partners).toHaveLength(500);
    expect(normalized.offers).toHaveLength(500);
  });

  it("returns an empty fail-closed workspace for non-object input", () => {
    expect(normalizeAdminOffersWorkspace(null)).toEqual({
      offers: [],
      catalog: [],
      partners: [],
    });
  });
});
