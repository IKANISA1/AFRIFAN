import { describe, expect, it, vi } from "vitest";
import {
  assertTvPayloadIsSafe,
  buildTvDisplayViewModel,
  createDemoTvSessionState,
  createGameRuntimeClient,
  findTvPayloadLeakKeys,
  resolveTvSessionId,
} from "./game-runtime";

describe("game runtime contract", () => {
  it("rejects TV payloads that leak correct-answer fields", () => {
    const payload = {
      currentQuestion: {
        prompt: "Question",
        correct_option_key: "a",
      },
    };

    expect(findTvPayloadLeakKeys(payload)).toEqual([
      "currentQuestion.correct_option_key",
    ]);
    expect(() => assertTvPayloadIsSafe(payload)).toThrow(/answer-only field/i);
  });

  it("builds a display view model from TV-safe state", () => {
    const state = createDemoTvSessionState();
    const model = buildTvDisplayViewModel(state);

    expect(model.questionLabel).toBe("Question 4 of 20");
    expect(model.options).toHaveLength(4);
    expect(model.claimLabel).toBe("Waiting for answer");
  });

  it("posts get-tv-state through the game action endpoint", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: createDemoTvSessionState(),
      }),
    });
    const client = createGameRuntimeClient({
      endpoint: "/api/game-session-action",
      fetcher,
    });

    await client.getTvState("session-1");

    expect(fetcher).toHaveBeenCalledWith(
      "/api/game-session-action",
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        body: JSON.stringify({
          action: "get_tv_state",
          session_id: "session-1",
        }),
      }),
    );
  });

  it("posts join-session through the game action endpoint", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          sessionId: "session-1",
          sessionPlayerId: "player-1",
          displayName: "Supporter",
          joinCode: "RAYON24",
          score: 0,
          teamId: null,
          teamName: null,
        },
      }),
    });
    const client = createGameRuntimeClient({
      endpoint: "/api/game-session-action",
      fetcher,
    });

    await client.joinSession({
      joinCode: "RAYON24",
      displayName: "Supporter",
    });

    expect(fetcher).toHaveBeenCalledWith(
      "/api/game-session-action",
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        body: JSON.stringify({
          action: "join_session",
          join_code: "RAYON24",
          display_name: "Supporter",
        }),
      }),
    );
  });

  it("defaults game actions to the same-origin API route", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: createDemoTvSessionState(),
      }),
    });
    const client = createGameRuntimeClient({ fetcher });

    await client.getTvState("session-1");

    expect(fetcher).toHaveBeenCalledWith(
      "/api/game-session-action",
      expect.objectContaining({ method: "POST" }),
    );
  });

  it("resolves TV session ids from supported query parameter names", () => {
    expect(resolveTvSessionId({ session_id: " one " })).toBe("one");
    expect(resolveTvSessionId({ sessionId: ["two"] })).toBe("two");
    expect(resolveTvSessionId(new URLSearchParams("session=three"))).toBe(
      "three",
    );
    expect(resolveTvSessionId({})).toBeNull();
  });

  it("maps failed action responses to recoverable errors", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: false,
      json: async () => ({ error: "Question is not open." }),
    });
    const client = createGameRuntimeClient({
      endpoint: "/api/game-session-action",
      fetcher,
    });

    await expect(
      client.submitAnswer({
        sessionQuestionId: "question-1",
        sessionPlayerId: "player-1",
        selectedOptionKey: "a",
      }),
    ).rejects.toThrow("Question is not open.");
  });

  it("posts create-session and pair-TV actions through the game action endpoint", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: { ok: true },
      }),
    });
    const client = createGameRuntimeClient({
      endpoint: "/api/game-session-action",
      fetcher,
    });

    await client.createSession({
      clubId: 24,
      title: "Rayon quiz",
      packId: "pack-1",
      joinCode: "RAYON24",
    });
    await client.pairTvDevice({
      clubId: 24,
      deviceLabel: "Main TV",
      pairingCode: "SCREEN24",
      sessionId: "session-1",
    });

    expect(fetcher).toHaveBeenNthCalledWith(
      1,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "create_session",
          club_id: 24,
          title: "Rayon quiz",
          pack_id: "pack-1",
          join_code: "RAYON24",
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      2,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "pair_tv_device",
          club_id: 24,
          device_label: "Main TV",
          pairing_code: "SCREEN24",
          session_id: "session-1",
        }),
      }),
    );
  });

  it("posts moderation and audit actions through the game action endpoint", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: [],
      }),
    });
    const client = createGameRuntimeClient({
      endpoint: "/api/game-session-action",
      fetcher,
    });

    await client.reviewQuestionDraft({
      clubId: 24,
      draftId: "00000000-0000-4000-8000-000000000111",
      decision: "approved",
      notes: "Ready.",
    });
    await client.listQuestionDrafts({
      clubId: 24,
      status: "pending_review",
      search: "Rayon",
      limit: 25,
      offset: 25,
    });
    await client.publishQuestionPack({
      clubId: 24,
      title: "Matchday pack",
      questionIds: ["00000000-0000-4000-8000-000000000001"],
    });
    await client.listAuditLog({
      clubId: 24,
      limit: 25,
      offset: 50,
      actionFilter: "game_session_created",
      entityType: "game_session",
    });

    expect(fetcher).toHaveBeenNthCalledWith(
      1,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "review_question_draft",
          club_id: 24,
          draft_id: "00000000-0000-4000-8000-000000000111",
          decision: "approved",
          notes: "Ready.",
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      2,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "list_question_drafts",
          club_id: 24,
          status: "pending_review",
          search: "Rayon",
          limit: 25,
          offset: 25,
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      3,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "publish_question_pack",
          club_id: 24,
          title: "Matchday pack",
          question_ids: ["00000000-0000-4000-8000-000000000001"],
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      4,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "list_audit_log",
          club_id: 24,
          limit: 25,
          offset: 50,
          action_filter: "game_session_created",
          entity_type: "game_session",
        }),
      }),
    );
  });

  it("posts host lifecycle actions through the game action endpoint", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          sessionId: "00000000-0000-4000-8000-000000000001",
          previousSessionQuestionId: "00000000-0000-4000-8000-000000000101",
          nextSessionQuestionId: "00000000-0000-4000-8000-000000000102",
          status: "live",
          isComplete: false,
          closedQuestionCount: 3,
        },
      }),
    });
    const client = createGameRuntimeClient({
      endpoint: "/api/game-session-action",
      fetcher,
    });

    await client.openQuestion({
      clubId: 24,
      sessionQuestionId: "00000000-0000-4000-8000-000000000101",
    });
    await client.revealQuestion({
      clubId: 24,
      sessionQuestionId: "00000000-0000-4000-8000-000000000101",
    });
    await client.advanceQuestion({
      clubId: 24,
      sessionQuestionId: "00000000-0000-4000-8000-000000000101",
    });
    await client.closeSession({
      clubId: 24,
      sessionId: "00000000-0000-4000-8000-000000000001",
    });

    expect(fetcher).toHaveBeenNthCalledWith(
      1,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "open_question",
          club_id: 24,
          session_question_id: "00000000-0000-4000-8000-000000000101",
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      2,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "reveal_question",
          club_id: 24,
          session_question_id: "00000000-0000-4000-8000-000000000101",
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      3,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "advance_question",
          club_id: 24,
          session_question_id: "00000000-0000-4000-8000-000000000101",
        }),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      4,
      "/api/game-session-action",
      expect.objectContaining({
        body: JSON.stringify({
          action: "close_session",
          club_id: 24,
          session_id: "00000000-0000-4000-8000-000000000001",
        }),
      }),
    );
  });

  it("posts draft generation through the generation endpoint", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          sourceId: "source-1",
          draftIds: ["draft-1"],
          mode: "ai_assisted",
          count: 1,
        },
      }),
    });
    const client = createGameRuntimeClient({
      draftGenerationEndpoint: "/api/generate-question-drafts",
      fetcher,
    });

    await client.generateQuestionDrafts({
      clubId: 24,
      sourceTitle: "Rayon source",
      extractedFact: "Rayon Sports has a verified club-history fact.",
      sourceUrl: "https://example.com/source",
      sourceDate: "2026-07-02",
      count: 1,
      language: "en",
      category: "club_knowledge",
    });

    expect(fetcher).toHaveBeenCalledWith(
      "/api/generate-question-drafts",
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        body: JSON.stringify({
          club_id: 24,
          source: {
            source_title: "Rayon source",
            extracted_fact: "Rayon Sports has a verified club-history fact.",
            source_url: "https://example.com/source",
            source_date: "2026-07-02",
            trust_tier: undefined,
          },
          count: 1,
          language: "en",
          category: "club_knowledge",
        }),
      }),
    );
  });
});
