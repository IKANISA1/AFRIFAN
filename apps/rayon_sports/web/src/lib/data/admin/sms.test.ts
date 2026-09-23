// @vitest-environment node

import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  MAX_ADMIN_SMS_MANUAL_REVIEWS,
  MAX_ADMIN_SMS_SYNC_RUNS,
  allocateAdminSmsManualReview,
  normalizeAdminSmsManualReviewWorkspace,
  normalizeAdminSmsSnapshot,
} from "./sms";

const timestamp = "2026-07-30T09:00:00.000Z";
const superAdminAccess: AdminAccess = {
  hasAccess: true,
  isAuthenticated: true,
  isSuperAdmin: true,
  userId: "super-admin-1",
  role: "super_admin",
  clubId: "24",
  availableClubIds: ["24"],
  canSelectClub: true,
  assignmentCount: 1,
};

const validRun = {
  id: "run-1",
  status: "completed",
  trigger: "scheduled",
  scannedMessages: 12,
  uploadedMessages: 10,
  startedAt: timestamp,
};

const validReview = {
  reviewId: "review-1",
  rawSmsId: "raw-1",
  parsedSmsId: "parsed-1",
  userId: "user-1",
  sender: "+250700000000",
  txType: "payment",
  txCategory: "contribution",
  cashflowBucket: "inflow",
  amount: 25_000,
  currency: "RWF",
  momoTxId: "tx-1",
  payerName: "Verified Supporter",
  payeeName: "AFRICLUB",
  payeeNumberOrCode: "123456",
  merchantCode: "123456",
  smsReceivedAt: timestamp,
  reviewCreatedAt: timestamp,
  updatedAt: timestamp,
  reviewKind: "needs_review",
  reason: "intent_match_required",
  notes: null,
  smsPreview: "Payment received and awaiting allocation.",
};

const validIntent = {
  id: "intent-1",
  userId: "user-1",
  userName: "Verified Supporter",
  expectedAmount: 25_000,
  currency: "RWF",
  status: "pending",
  targetTable: "contribution_intents",
  targetRecordId: "target-1",
  createdAt: timestamp,
  expiresAt: null,
  summaryLabel: "contribution intents",
};

describe("admin SMS monitor", () => {
  it("accepts a bounded strict pipeline snapshot", () => {
    expect(
      normalizeAdminSmsSnapshot({
        metrics: {
          "SMS captured": 12,
          "SMS parsed": 10,
          "Ledger entries": 8,
        },
        syncRuns: [validRun],
        internal_secret: "ignored",
      }),
    ).toEqual({
      metrics: {
        "SMS captured": 12,
        "SMS parsed": 10,
        "Ledger entries": 8,
      },
      syncRuns: [validRun],
    });
  });

  it.each([
    [
      "negative metrics",
      { metrics: { "SMS captured": -1 }, syncRuns: [] },
    ],
    [
      "duplicate runs",
      { metrics: {}, syncRuns: [validRun, validRun] },
    ],
    [
      "invalid timestamp",
      {
        metrics: {},
        syncRuns: [{ ...validRun, startedAt: "not-a-time" }],
      },
    ],
  ])("rejects %s instead of returning a partial snapshot", (_label, value) => {
    expect(() => normalizeAdminSmsSnapshot(value)).toThrow();
  });

  it("rejects an oversized sync-run list", () => {
    expect(() =>
      normalizeAdminSmsSnapshot({
        metrics: {},
        syncRuns: Array.from(
          { length: MAX_ADMIN_SMS_SYNC_RUNS + 1 },
          (_, index) => ({ ...validRun, id: `run-${index}` }),
        ),
      }),
    ).toThrow("safe limit");
  });

  it("accepts a strict, bounded manual-review workspace", () => {
    expect(
      normalizeAdminSmsManualReviewWorkspace({
        reviews: [validReview],
        pendingIntents: [validIntent],
      }),
    ).toEqual({
      reviews: [validReview],
      pendingIntents: [validIntent],
    });
  });

  it("rejects oversized or duplicate private review data", () => {
    expect(() =>
      normalizeAdminSmsManualReviewWorkspace({
        reviews: Array.from(
          { length: MAX_ADMIN_SMS_MANUAL_REVIEWS + 1 },
          (_, index) => ({ ...validReview, reviewId: `review-${index}` }),
        ),
        pendingIntents: [],
      }),
    ).toThrow("safe limit");

    expect(() =>
      normalizeAdminSmsManualReviewWorkspace({
        reviews: [validReview, validReview],
        pendingIntents: [validIntent],
      }),
    ).toThrow("duplicate");
  });

  it("keeps non-platform administrators out of review mutations", async () => {
    const rpc = vi.fn();
    await expect(
      allocateAdminSmsManualReview(
        { rpc } as unknown as SupabaseClient,
        { ...superAdminAccess, isSuperAdmin: false, role: "club_admin" },
        { reviewId: "review-1", intentId: "intent-1" },
      ),
    ).rejects.toThrow("Platform administrator access is required");
    expect(rpc).not.toHaveBeenCalled();
  });

  it("rejects unsupported review-action fields before invoking storage", async () => {
    const rpc = vi.fn();
    await expect(
      allocateAdminSmsManualReview(
        { rpc } as unknown as SupabaseClient,
        superAdminAccess,
        {
          reviewId: "review-1",
          intentId: "intent-1",
          actorToken: "private",
        },
      ),
    ).rejects.toThrow("unsupported");
    expect(rpc).not.toHaveBeenCalled();
  });
});
