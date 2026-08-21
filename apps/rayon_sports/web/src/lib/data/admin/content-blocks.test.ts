import { describe, expect, it } from "vitest";
import {
  normalizeAdminContentBlockFeatureOptions,
  normalizeAdminContentBlocks,
} from "./content-blocks";

const validBlock = {
  id: "block-1",
  clubId: null,
  scope: "global",
  blockKey: "home_matchday",
  blockType: "section",
  title: "Matchday",
  subtitle: "Confirmed matchday services",
  content: {
    heading: "Next match",
    secretToken: "private-secret",
    nested: { actorEmail: "private@example.com", label: "Fixture" },
  },
  targetChannel: "both",
  placementKey: "home_mid",
  featureId: "feature-1",
  featureKey: "matchday",
  isActive: true,
  sortOrder: 1,
  metadata: {
    theme: "matchday",
    sessionToken: "private-session",
  },
  createdAt: "2026-07-29T12:00:00.000Z",
  updatedAt: "2026-07-29T12:30:00.000Z",
  actorEmail: "private@example.com",
};

describe("admin content-block response normalization", () => {
  it("projects bounded public fields and removes private extras recursively", () => {
    const [result] = normalizeAdminContentBlocks([validBlock]);

    expect(result).toMatchObject({
      id: "block-1",
      clubId: null,
      scope: "global",
      blockKey: "home_matchday",
      blockType: "section",
      title: "Matchday",
      subtitle: "Confirmed matchday services",
      targetChannel: "both",
      placementKey: "home_mid",
      featureId: "feature-1",
      featureKey: "matchday",
      isActive: true,
      sortOrder: 1,
      createdAt: "2026-07-29T12:00:00.000Z",
      updatedAt: "2026-07-29T12:30:00.000Z",
    });
    expect(result.content).toEqual({
      heading: "Next match",
      nested: { label: "Fixture" },
    });
    expect(result.metadata).toEqual({ theme: "matchday" });
    expect(JSON.stringify(result)).not.toContain("private");
  });

  it("rejects malformed identity, scope, channel, flags, dates, and rows", () => {
    expect(
      normalizeAdminContentBlocks([
        { ...validBlock, id: "" },
        { ...validBlock, id: "bad-key", blockKey: "" },
        { ...validBlock, id: "bad-scope", scope: "private" },
        { ...validBlock, id: "bad-channel", targetChannel: "unsupported" },
        { ...validBlock, id: "bad-flag", isActive: "yes" },
        { ...validBlock, id: "bad-date", updatedAt: "not-a-date" },
        null,
      ]),
    ).toEqual([]);
  });

  it("caps blocks at 500 and bounds JSON payloads", () => {
    const result = normalizeAdminContentBlocks(
      Array.from({ length: 510 }, (_, index) => ({
        ...validBlock,
        id: `block-${index + 1}`,
        content: index === 0 ? { body: "x".repeat(13_000) } : {},
        sortOrder: null,
      })),
    );

    expect(result).toHaveLength(500);
    expect(result[0]?.content).toEqual({});
    expect(result[0]?.sortOrder).toBe(0);
  });

  it("fails closed for a non-array block response", () => {
    expect(normalizeAdminContentBlocks({ data: [validBlock] })).toEqual([]);
  });
});

describe("admin content-block feature option normalization", () => {
  it("keeps only bounded option fields and caps the collection", () => {
    const options = normalizeAdminContentBlockFeatureOptions(
      Array.from({ length: 510 }, (_, index) => ({
        id: `feature-${index + 1}`,
        displayName: `Feature ${index + 1}`,
        secretValue: "private",
      })),
    );

    expect(options).toHaveLength(500);
    expect(options[0]).toEqual({
      id: "feature-1",
      displayName: "Feature 1",
    });
    expect(JSON.stringify(options)).not.toContain("secretValue");
  });

  it("rejects malformed and non-array option responses", () => {
    expect(
      normalizeAdminContentBlockFeatureOptions([
        { id: "", displayName: "Missing id" },
        { id: "feature-1", displayName: 42 },
        null,
      ]),
    ).toEqual([]);
    expect(normalizeAdminContentBlockFeatureOptions({ data: [] })).toEqual([]);
  });
});
