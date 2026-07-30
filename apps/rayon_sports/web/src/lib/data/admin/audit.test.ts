import { describe, expect, it } from "vitest";
import { normalizeAdminAuditLogs } from "./audit";

const timestamp = "2026-07-30T09:00:00.000Z";

function row(id: string) {
  return {
    id,
    user_id: "private-user-id",
    action: "settings.update",
    target_table: "african_football_clubs",
    target_id: "24",
    old_data: {
      club_name: "Rayon Sports",
      access_token: "private-token",
    },
    new_data: {
      club_name: "Verified Rayon Sports FC",
      nested: {
        password: "private-password",
        enabled: true,
      },
    },
    metadata: {
      request_id: "request-1",
      authorization: "Bearer private",
    },
    notes: "Confirmed operator change.",
    created_at: timestamp,
    profiles: { full_name: "Verified Administrator" },
    actor_phone: "+250700000000",
    internal_trace: "private-trace",
  };
}

describe("admin audit normalization", () => {
  it("projects strict fields, redacts sensitive values, and omits actor identity", () => {
    const normalized = normalizeAdminAuditLogs([row("audit-1")]);

    expect(normalized).toEqual([
      {
        id: "audit-1",
        actorKind: "administrator",
        userName: "Verified Administrator",
        action: "settings.update",
        targetTable: "african_football_clubs",
        targetId: "24",
        oldData: {
          club_name: "Rayon Sports",
          access_token: "[redacted]",
        },
        newData: {
          club_name: "Verified Rayon Sports FC",
          nested: {
            password: "[redacted]",
            enabled: true,
          },
        },
        metadata: {
          request_id: "request-1",
          authorization: "[redacted]",
        },
        notes: "Confirmed operator change.",
        createdAt: timestamp,
      },
    ]);
    expect(JSON.stringify(normalized)).not.toContain("private-user-id");
    expect(JSON.stringify(normalized)).not.toContain("+250700000000");
    expect(JSON.stringify(normalized)).not.toContain("private-trace");
    expect(JSON.stringify(normalized)).not.toContain("private-token");
    expect(JSON.stringify(normalized)).not.toContain("private-password");
  });

  it("drops malformed and duplicate records without generating identities or dates", () => {
    const normalized = normalizeAdminAuditLogs([
      row("audit-1"),
      row("audit-1"),
      { ...row("audit-2"), created_at: "not-a-date" },
      { ...row("audit-3"), id: "" },
      { ...row("audit-4"), action: "" },
    ]);

    expect(normalized).toHaveLength(1);
    expect(normalized[0]?.id).toBe("audit-1");
    expect(normalized[0]?.createdAt).toBe(timestamp);
  });

  it("accepts explicit system actions without inventing an administrator", () => {
    const [normalized] = normalizeAdminAuditLogs([
      {
        ...row("audit-system"),
        user_id: null,
        profiles: null,
      },
    ]);

    expect(normalized?.actorKind).toBe("system");
    expect(normalized?.userName).toBe("System action");
  });

  it("caps the browser-visible collection at 500 records", () => {
    const normalized = normalizeAdminAuditLogs(
      Array.from({ length: 550 }, (_, index) => row(`audit-${index}`)),
    );

    expect(normalized).toHaveLength(500);
    expect(normalized.at(-1)?.id).toBe("audit-499");
  });
});
