import { describe, expect, it } from "vitest";
import {
  normalizeAdminGameAudit,
  normalizeAdminGameDrafts,
  normalizeAdminGameSnapshot,
} from "./games";

describe("Admin game operations projections", () => {
  it("admits strict bounded draft fields and drops malformed/private extras", () => {
    const rows = normalizeAdminGameDrafts([
      {
        id: "draft-1",
        sourceId: "source-1",
        prompt: "Which verified result belongs to Rayon Sports?",
        category: "club_knowledge",
        difficulty: "medium",
        language: "en",
        validationStatus: "pending_review",
        validationNotes: "Review the date.",
        duplicatePromptCount: 2,
        hasDuplicatePrompt: true,
        similarPromptCount: 3,
        hasSimilarPrompt: true,
        duplicateRiskLevel: "exact",
        normalizedPromptSignature: "which verified result belongs",
        sourceTitle: "Official report",
        sourceUrl: "https://example.com/report#private",
        sourceTrustTier: "official",
        citationFragment: "Verified club-history fact from the report.",
        schemaVersion: "2026-08-01",
        generationMode: "ai_assisted",
        modelName: "reviewed-model",
        reviewedAt: "2026-07-29T12:10:00Z",
        reviewerName: "Authorized Editor",
        qaChecks: {
          sourcePresent: true,
          citationPresent: true,
          sourceTrusted: true,
          schemaVersionPresent: true,
          modelMetadataPresent: true,
          promptLengthValid: true,
          exactDuplicateFree: false,
          normalizedDuplicateFree: false,
          ambiguitySignalsAbsent: true,
          answerConsistent: true,
          languageSupported: true,
          policyCompliant: true,
        },
        createdAt: "2026-07-29T12:00:00Z",
        accessToken: "private",
      },
      { id: "", prompt: "Malformed" },
    ]);

    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      id: "draft-1",
      sourceUrl: "https://example.com/report",
      duplicatePromptCount: 2,
      duplicateRiskLevel: "exact",
      generationMode: "ai_assisted",
      modelName: "reviewed-model",
      citationFragment: "Verified club-history fact from the report.",
      schemaVersion: "2026-08-01",
      reviewerName: "Authorized Editor",
      qaChecks: {
        sourcePresent: true,
        citationPresent: true,
        sourceTrusted: true,
        schemaVersionPresent: true,
        modelMetadataPresent: true,
        promptLengthValid: true,
        exactDuplicateFree: false,
        normalizedDuplicateFree: false,
        ambiguitySignalsAbsent: true,
        answerConsistent: true,
        languageSupported: true,
        policyCompliant: true,
      },
    });
    expect(rows[0]).not.toHaveProperty("accessToken");
  });

  it("fails every authoritative QA field closed when the server omits checks", () => {
    const [row] = normalizeAdminGameDrafts([
      {
        id: "draft-unverified",
        prompt: "Which club fact still needs server-side checks?",
        validationStatus: "pending_review",
        createdAt: "2026-08-01T10:00:00Z",
        sourceTitle: "Visible title is not proof",
        sourceTrustTier: "official",
      },
    ]);

    expect(row).toBeDefined();
    expect(Object.values(row!.qaChecks)).toEqual(
      Array(Object.keys(row!.qaChecks).length).fill(false),
    );
  });

  it("redacts actors and restricts audit details to operational allow-list fields", () => {
    const rows = normalizeAdminGameAudit([
      {
        id: "audit-1",
        action: "game_session_created",
        entityType: "game_session",
        entityId: "session-1",
        actorId: "private-user-id",
        createdAt: "2026-07-29T12:00:00Z",
        after: {
          status: "live",
          question_count: 20,
          access_token: "private",
          nested: { secret: true },
        },
      },
    ]);

    expect(rows).toEqual([
      {
        id: "audit-1",
        action: "game_session_created",
        entityType: "game_session",
        entityId: "session-1",
        actorId: null,
        createdAt: "2026-07-29T12:00:00Z",
        after: { status: "live", question_count: 20 },
      },
    ]);
  });

  it("caps both snapshot collections at 100 rows", () => {
    const draft = {
      id: "draft",
      prompt: "Prompt",
      validationStatus: "approved",
      createdAt: "2026-07-29T12:00:00Z",
    };
    const audit = {
      id: "audit",
      action: "reviewed",
      entityType: "question",
      createdAt: "2026-07-29T12:00:00Z",
    };
    const snapshot = normalizeAdminGameSnapshot({
      drafts: Array.from({ length: 130 }, (_, index) => ({
        ...draft,
        id: `draft-${index}`,
      })),
      audit: Array.from({ length: 130 }, (_, index) => ({
        ...audit,
        id: `audit-${index}`,
      })),
    });

    expect(snapshot.drafts).toHaveLength(100);
    expect(snapshot.audit).toHaveLength(100);
  });
});
