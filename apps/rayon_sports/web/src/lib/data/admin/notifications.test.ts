import { describe, expect, it } from "vitest";
import { normalizeAdminNotificationContext } from "./notifications";

const validRecord = {
  id: "notification-1",
  title: "Kickoff update",
  body: "The match begins at 18:00.",
  audience_type: "all_fans",
  audience_tier: null,
  audience_group_id: null,
  audience_group_name: null,
  delivery_mode: "send_now",
  status: "delivered",
  scheduled_at: null,
  sent_at: "2026-07-30T16:00:00Z",
  requested_recipient_count: 200,
  sent_count: 198,
  failed_count: 2,
  created_at: "2026-07-30T15:55:00Z",
  last_error: "provider token=private recipient=private@example.com",
  private_recipient_ids: ["private-1"],
};

describe("normalizeAdminNotificationContext", () => {
  it("strictly projects records and replaces provider diagnostics", () => {
    expect(
      normalizeAdminNotificationContext({
        groups: [{ id: "group-1", name: "Kigali supporters", secret: "x" }],
        history: [validRecord],
      }),
    ).toEqual({
      groups: [{ id: "group-1", name: "Kigali supporters" }],
      history: [
        {
          id: "notification-1",
          title: "Kickoff update",
          body: "The match begins at 18:00.",
          audienceType: "all_fans",
          audienceTier: null,
          audienceGroupId: null,
          audienceGroupName: null,
          deliveryMode: "send_now",
          status: "delivered",
          scheduledAt: null,
          sentAt: "2026-07-30T16:00:00Z",
          requestedRecipientCount: 200,
          sentCount: 198,
          failedCount: 2,
          createdAt: "2026-07-30T15:55:00Z",
          lastError: "Delivery requires operator review.",
        },
      ],
    });
  });

  it("rejects malformed, duplicate, and incomplete audience records", () => {
    expect(
      normalizeAdminNotificationContext({
        groups: [
          { id: "group-1", name: "Kigali supporters" },
          { id: "group-1", name: "Duplicate" },
          { id: "", name: "Invalid" },
        ],
        history: [
          validRecord,
          { ...validRecord, title: "Duplicate" },
          { ...validRecord, id: "notification-2", audience_type: "by_group" },
          { ...validRecord, id: "notification-3", status: "unsupported-status" },
          { ...validRecord, id: "notification-4", created_at: "not-a-date" },
        ],
      }),
    ).toEqual({
      groups: [{ id: "group-1", name: "Kigali supporters" }],
      history: [
        expect.objectContaining({
          id: "notification-1",
          title: "Kickoff update",
        }),
      ],
    });
  });
  it.each(["unknown", "processing", "partial"])("retains the authoritative %s state and sanitized diagnostics", status => {
    const result = normalizeAdminNotificationContext({ groups: [], history: [{ ...validRecord, status }] });
    expect(result.history).toHaveLength(1);
    expect(result.history[0]).toMatchObject({ status, lastError: "Delivery requires operator review." });
    expect(JSON.stringify(result)).not.toContain(validRecord.last_error);
  });

  it("caps groups at 50 and history at 100 before projection", () => {
    const result = normalizeAdminNotificationContext({
      groups: Array.from({ length: 70 }, (_, index) => ({
        id: `group-${index}`,
        name: `Group ${index}`,
      })),
      history: Array.from({ length: 120 }, (_, index) => ({
        ...validRecord,
        id: `notification-${index}`,
      })),
    });
    expect(result.groups).toHaveLength(50);
    expect(result.history).toHaveLength(100);
  });

  it("returns an empty controlled context for non-object input", () => {
    expect(normalizeAdminNotificationContext(null)).toEqual({
      groups: [],
      history: [],
    });
  });
});
