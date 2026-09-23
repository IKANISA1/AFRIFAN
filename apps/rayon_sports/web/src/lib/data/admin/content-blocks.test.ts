import { afterEach, describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  deleteAdminContentBlock,
  normalizeAdminContentBlockFeatureOptions,
  normalizeAdminContentBlocks,
  saveAdminContentBlock,
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

describe("content-block mutation scope and copy safety", () => {
  afterEach(() => vi.unstubAllGlobals());

  const sourceVersion = "2026-07-29T12:30:00.000Z";
  const access: AdminAccess = {
    hasAccess: true, isAuthenticated: true, isSuperAdmin: false,
    userId: "local-admin", role: "club_admin", clubId: "24",
    availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1,
  };
  const input = {
    id: "source-block", updatedAt: sourceVersion, blockKey: "shared_block",
    blockType: "section", placementKey: "home_mid", title: "Local content",
    content: { heading: "Local heading" }, isActive: false,
  };

  function clientFor(sourceClub: number | null, insertError: { code: string; message: string } | null = null) {
    vi.stubGlobal("window", undefined);
    const source = {
      id: "source-block", club_id: sourceClub, block_key: "shared_block",
      block_type: "section", placement_key: "home_mid", target_channel: "both",
      title: "Source content", subtitle: null, content: { heading: "Source heading" },
      feature_id: null, is_active: true, sort_order: 1, metadata: {},
      updated_at: sourceVersion,
    };
    const read = {
      eq: vi.fn(() => read),
      single: vi.fn(async () => ({ data: source, error: null })),
      maybeSingle: vi.fn(async () => ({ data: null, error: null })),
    };
    const updated = {
      eq: vi.fn(() => updated),
      select: vi.fn(() => updated),
      maybeSingle: vi.fn(async () => ({ data: { id: source.id }, error: null })),
    };
    const inserted = {
      select: vi.fn(() => inserted),
      single: vi.fn(async () => ({ data: { id: "local-copy", updated_at: sourceVersion }, error: insertError })),
      then: (resolve: (value: { error: typeof insertError }) => unknown) => Promise.resolve({ error: insertError }).then(resolve),
    };
    const insert = vi.fn(() => inserted);
    const update = vi.fn(() => updated);
    const rpc = vi.fn(async () => ({ data: null, error: null }));
    const client = { from: vi.fn(() => ({ select: vi.fn(() => read), insert, update })), rpc } as unknown as SupabaseClient;
    return { client, insert, update, rpc, updated };
  }

  it.each([false, true])("rejects another club's source before save, including platform=%s", async (isSuperAdmin) => {
    const mock = clientFor(3);
    await expect(saveAdminContentBlock(mock.client, { ...access, isSuperAdmin }, input))
      .rejects.toMatchObject({ name: "AdminMutationAuthorizationError" });
    expect(mock.insert).not.toHaveBeenCalled();
    expect(mock.update).not.toHaveBeenCalled();
  });

  it("rejects another club's source before delete or audit mutation", async () => {
    const mock = clientFor(3);
    await expect(deleteAdminContentBlock(mock.client, access, input.id, sourceVersion))
      .rejects.toMatchObject({ name: "AdminMutationAuthorizationError" });
    expect(mock.insert).not.toHaveBeenCalled();
    expect(mock.rpc).not.toHaveBeenCalled();
  });

  it("inserts a complete global override without committing an intermediate clone", async () => {
    const mock = clientFor(null);
    await saveAdminContentBlock(mock.client, access, input);
    expect(mock.insert).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({
      club_id: 24, block_key: "shared_block", title: "Local content",
      content: { heading: "Local heading" }, is_active: false,
    }));
    expect(mock.update).not.toHaveBeenCalled();
  });

  it("disables a shared global block with one already-disabled local insert", async () => {
    const mock = clientFor(null);
    await deleteAdminContentBlock(mock.client, access, input.id, sourceVersion);
    expect(mock.insert).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({ club_id: 24, is_active: false }));
    expect(mock.update).not.toHaveBeenCalled();
    expect(mock.rpc).not.toHaveBeenCalled();
  });

  it("treats a concurrently created override as a conflict without overwriting it", async () => {
    const mock = clientFor(null, { code: "23505", message: "An override already exists" });
    await expect(saveAdminContentBlock(mock.client, access, input))
      .rejects.toMatchObject({ name: "AdminMutationConflictError" });
    expect(mock.update).not.toHaveBeenCalled();
  });

  it("preserves the loaded version check for an existing local block", async () => {
    const mock = clientFor(24);
    await saveAdminContentBlock(mock.client, access, input);
    expect(mock.insert).not.toHaveBeenCalled();
    expect(mock.update).toHaveBeenCalledOnce();
    expect(mock.updated.eq).toHaveBeenCalledWith("updated_at", sourceVersion);
  });
});

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
