import { describe, expect, it } from "vitest";
import {
  normalizeAdminAppConfig,
  normalizeAdminBanners,
  normalizeAdminContentBlocks,
  normalizeAdminContentTypes,
} from "./cms-content";

const validBanner = {
  id: "banner-1",
  title: "Matchday at Kigali Pelé Stadium",
  subtitle: "Confirmed home fixture",
  badgeLabel: "MATCHDAY",
  ctaLabel: "View fixture",
  route: "/fixtures/match-1",
  imageUrl: "https://cdn.example.com/banner.webp",
  sortOrder: 1,
  isActive: true,
  distribution: "both",
  updatedAt: "2026-07-29T12:00:00.000Z",
  authorEmail: "private@example.com",
  accessToken: "private-token",
};

describe("admin home-banner response normalization", () => {
  it("keeps only bounded presentation fields and drops private extras", () => {
    const [result] = normalizeAdminBanners([validBanner]);

    expect(result).toEqual({
      id: "banner-1",
      title: "Matchday at Kigali Pelé Stadium",
      subtitle: "Confirmed home fixture",
      badgeLabel: "MATCHDAY",
      ctaLabel: "View fixture",
      route: "/fixtures/match-1",
      imageUrl: "https://cdn.example.com/banner.webp",
      sortOrder: 1,
      isActive: true,
      distribution: "both",
      updatedAt: "2026-07-29T12:00:00.000Z",
    });
    expect(JSON.stringify(result)).not.toContain("authorEmail");
    expect(JSON.stringify(result)).not.toContain("private-token");
  });

  it("rejects invalid routes, required fields, flags, dates, and rows", () => {
    expect(
      normalizeAdminBanners([
        { ...validBanner, id: "" },
        { ...validBanner, id: "external-route", route: "https://example.com" },
        { ...validBanner, id: "scheme-relative", route: "//example.com" },
        { ...validBanner, id: "bad-flag", isActive: "yes" },
        { ...validBanner, id: "bad-date", updatedAt: "not-a-date" },
        null,
      ]),
    ).toEqual([]);
  });

  it("caps the collection and removes unsafe media", () => {
    const unsafeScheme = ["java", "script:alert(1)"].join("");
    const banners = Array.from({ length: 510 }, (_, index) => ({
      ...validBanner,
      id: `banner-${index + 1}`,
      imageUrl: index === 0 ? unsafeScheme : "/admin/cms/banner-cover",
    }));
    const normalized = normalizeAdminBanners(banners);

    expect(normalized).toHaveLength(500);
    expect(normalized[0]?.imageUrl).toBeNull();
    expect(normalized[1]?.imageUrl).toBe("/admin/cms/banner-cover");
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminBanners({ data: [validBanner] })).toEqual([]);
  });
});

const validConfig = {
  id: "config-1",
  key: "community_requests_enabled",
  value: "true",
  description: "Controls the community request queue.",
  country: "RW",
  updatedAt: "2026-07-29T12:00:00.000Z",
  secretValue: "private-secret",
  actorEmail: "private@example.com",
};

describe("admin app-config response normalization", () => {
  it("keeps only bounded configuration fields and drops private extras", () => {
    const [result] = normalizeAdminAppConfig([validConfig]);

    expect(result).toEqual({
      id: "config-1",
      key: "community_requests_enabled",
      value: "true",
      description: "Controls the community request queue.",
      country: "RW",
      updatedAt: "2026-07-29T12:00:00.000Z",
    });
    expect(JSON.stringify(result)).not.toContain("private-secret");
    expect(JSON.stringify(result)).not.toContain("private@example.com");
  });

  it("rejects invalid identity, key, field bounds, dates, and rows", () => {
    expect(
      normalizeAdminAppConfig([
        { ...validConfig, id: "" },
        { ...validConfig, id: "bad-key", key: "" },
        { ...validConfig, id: "long-value", value: "x".repeat(4_001) },
        { ...validConfig, id: "bad-date", updatedAt: "not-a-date" },
        null,
      ]),
    ).toEqual([]);
  });

  it("caps the collection at 500 entries and preserves empty values", () => {
    const normalized = normalizeAdminAppConfig(
      Array.from({ length: 510 }, (_, index) => ({
        ...validConfig,
        id: `config-${index + 1}`,
        key: `controlled_key_${index + 1}`,
        value: index === 0 ? "" : "enabled",
      })),
    );

    expect(normalized).toHaveLength(500);
    expect(normalized[0]?.value).toBe("");
    expect(normalized.at(-1)?.id).toBe("config-500");
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminAppConfig({ data: [validConfig] })).toEqual([]);
  });
});

const validContentBlock = {
  id: "content-1",
  contentType: "matchday_service",
  title: "Matchday support",
  subtitle: "Plan your stadium visit",
  body: "Use the official supporter channels for current matchday guidance.",
  rationale: "Approved operational copy.",
  iconEmoji: "⚽",
  ctaAction: "/fixtures",
  ctaLabel: "View fixtures",
  sortOrder: 10,
  isActive: true,
  distribution: "both",
  updatedAt: "2026-07-29T12:00:00.000Z",
  actorEmail: "private@example.com",
  accessToken: "private-token",
};

describe("admin CMS content response normalization", () => {
  it("keeps only bounded content presentation fields", () => {
    const [result] = normalizeAdminContentBlocks([validContentBlock]);

    expect(result).toEqual({
      id: "content-1",
      contentType: "matchday_service",
      title: "Matchday support",
      subtitle: "Plan your stadium visit",
      body: "Use the official supporter channels for current matchday guidance.",
      rationale: "Approved operational copy.",
      iconEmoji: "⚽",
      ctaAction: "/fixtures",
      ctaLabel: "View fixtures",
      sortOrder: 10,
      isActive: true,
      distribution: "both",
      updatedAt: "2026-07-29T12:00:00.000Z",
    });
    expect(JSON.stringify(result)).not.toContain("private@example.com");
    expect(JSON.stringify(result)).not.toContain("private-token");
  });

  it("rejects invalid required, bounded, enum, flag, and date fields", () => {
    expect(
      normalizeAdminContentBlocks([
        { ...validContentBlock, id: "" },
        { ...validContentBlock, id: "no-title", title: "" },
        { ...validContentBlock, id: "long-body", body: "x".repeat(12_001) },
        { ...validContentBlock, id: "bad-distribution", distribution: "all" },
        { ...validContentBlock, id: "bad-flag", isActive: "yes" },
        { ...validContentBlock, id: "bad-date", updatedAt: "not-a-date" },
      ]),
    ).toEqual([]);
  });

  it("caps content blocks at 500 and fails closed for non-arrays", () => {
    expect(
      normalizeAdminContentBlocks(
        Array.from({ length: 510 }, (_, index) => ({
          ...validContentBlock,
          id: `content-${index + 1}`,
        })),
      ),
    ).toHaveLength(500);
    expect(normalizeAdminContentBlocks({ data: [validContentBlock] })).toEqual(
      [],
    );
  });
});

const validContentType = {
  contentType: "matchday_service",
  label: "Matchday service",
  description: "Matchday operational information.",
  defaultDistribution: "both",
  sortOrder: 10,
  isActive: true,
  internalPolicy: "private",
};

describe("admin CMS content-type response normalization", () => {
  it("keeps only bounded content-type fields", () => {
    const [result] = normalizeAdminContentTypes([validContentType]);

    expect(result).toEqual({
      contentType: "matchday_service",
      label: "Matchday service",
      description: "Matchday operational information.",
      defaultDistribution: "both",
      sortOrder: 10,
      isActive: true,
    });
    expect(JSON.stringify(result)).not.toContain("internalPolicy");
  });

  it("rejects malformed rows and caps the collection", () => {
    expect(
      normalizeAdminContentTypes([
        { ...validContentType, contentType: "" },
        { ...validContentType, label: "" },
        { ...validContentType, defaultDistribution: "all" },
        { ...validContentType, isActive: "yes" },
        null,
      ]),
    ).toEqual([]);
    expect(
      normalizeAdminContentTypes(
        Array.from({ length: 110 }, (_, index) => ({
          ...validContentType,
          contentType: `type_${index + 1}`,
        })),
      ),
    ).toHaveLength(100);
    expect(normalizeAdminContentTypes({ data: [validContentType] })).toEqual(
      [],
    );
  });
});
