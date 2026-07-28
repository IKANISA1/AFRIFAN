import {
  AdminMutationConflictError,
  deleteAdminRecordWithAuditIfUnchanged,
  deleteRecordWithMatchersIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireExpectedUpdatedAt,
} from "./helpers";
import {
  AdminApiError,
  isAdminMutationConflict,
} from "./http";

describe("admin optimistic concurrency contract", () => {
  it("requires a loaded updated_at token before editing", () => {
    expect(() => requireExpectedUpdatedAt(null)).toThrow(
      AdminMutationConflictError,
    );
    expect(requireExpectedUpdatedAt("2026-07-24T18:00:00Z")).toBe(
      "2026-07-24T18:00:00Z",
    );
  });

  it("classifies HTTP 409 and STALE_RECORD responses as conflicts", () => {
    expect(
      isAdminMutationConflict(
        new AdminMutationConflictError("Refresh required."),
      ),
    ).toBe(true);
    expect(
      isAdminMutationConflict(
        new AdminApiError("Refresh required.", 409, "STALE_RECORD"),
      ),
    ).toBe(true);
    expect(
      isAdminMutationConflict(
        new AdminApiError("Access denied.", 403, null),
      ),
    ).toBe(false);
  });

  it("rejects a zero-row compare-and-set update as stale", async () => {
    const query = {
      update: vi.fn(),
      eq: vi.fn(),
      select: vi.fn(),
      maybeSingle: vi.fn().mockResolvedValue({
        data: null,
        error: null,
      }),
    };
    query.update.mockReturnValue(query);
    query.eq.mockReturnValue(query);
    query.select.mockReturnValue(query);
    const client = {
      from: vi.fn().mockReturnValue(query),
    };

    await expect(
      mutateRecordWithVariantsIfUnchanged(
        client as never,
        "groups",
        "group-1",
        "2026-07-24T18:00:00Z",
        [{ name: "Latest draft" }],
        { club_id: 24 },
      ),
    ).rejects.toBeInstanceOf(AdminMutationConflictError);
    expect(query.eq).toHaveBeenCalledWith(
      "updated_at",
      "2026-07-24T18:00:00Z",
    );
  });

  it("rejects a zero-row conditional delete as stale", async () => {
    const query = {
      delete: vi.fn(),
      eq: vi.fn(),
      select: vi.fn(),
      maybeSingle: vi.fn().mockResolvedValue({
        data: null,
        error: null,
      }),
    };
    query.delete.mockReturnValue(query);
    query.eq.mockReturnValue(query);
    query.select.mockReturnValue(query);
    const client = {
      from: vi.fn().mockReturnValue(query),
    };

    await expect(
      deleteRecordWithMatchersIfUnchanged(
        client as never,
        "groups",
        "group-1",
        "2026-07-24T18:00:00Z",
        { club_id: 24 },
      ),
    ).rejects.toBeInstanceOf(AdminMutationConflictError);
  });

  it("passes actor, active-club scope, loaded version, and audit metadata to the atomic delete RPC", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: {}, error: null });
    const client = { rpc };

    await deleteAdminRecordWithAuditIfUnchanged(
      client as never,
      "groups",
      "group-1",
      "2026-07-24T18:00:00Z",
      { club_id: 24 },
      {
        actorId: "00000000-0000-4000-8000-000000000024",
        clubId: 24,
        action: "delete_contribution_group",
        source: "admin_contributions",
      },
    );

    expect(rpc).toHaveBeenCalledWith(
      "admin_delete_mutable_record_if_unchanged",
      {
        p_table_name: "groups",
        p_record_id: "group-1",
        p_expected_updated_at: "2026-07-24T18:00:00Z",
        p_actor_id: "00000000-0000-4000-8000-000000000024",
        p_club_id: 24,
        p_enforce_club_scope: true,
        p_requires_platform_admin: false,
        p_action: "delete_contribution_group",
        p_source: "admin_contributions",
      },
    );
  });

  it("maps atomic delete conflicts to the shared stale-record error", async () => {
    const client = {
      rpc: vi.fn().mockResolvedValue({
        data: null,
        error: {
          message: "Record changed after it was loaded.",
        },
      }),
    };

    await expect(
      deleteAdminRecordWithAuditIfUnchanged(
        client as never,
        "matches",
        "match-1",
        "2026-07-24T18:00:00Z",
        { club_id: 24 },
        {
          actorId: "00000000-0000-4000-8000-000000000024",
          clubId: 24,
          action: "delete_match",
          source: "admin_matches",
        },
      ),
    ).rejects.toBeInstanceOf(AdminMutationConflictError);
  });
});
