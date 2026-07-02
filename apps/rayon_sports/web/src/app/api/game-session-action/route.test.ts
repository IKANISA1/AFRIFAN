import { NextRequest, NextResponse } from "next/server";
import { describe, expect, it, vi } from "vitest";
import { createGameSessionActionRouteHandler } from "./route";

function request(body: unknown, headers: Record<string, string> = {}) {
  return new NextRequest("https://admin.gikundiro.com/api/game-session-action", {
    method: "POST",
    headers: {
      origin: "https://admin.gikundiro.com",
      "content-type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

const sessionId = "00000000-0000-4000-8000-000000000001";
const sessionQuestionId = "00000000-0000-4000-8000-000000000101";
const sessionPlayerId = "00000000-0000-4000-8000-000000000201";
const draftId = "00000000-0000-4000-8000-000000000301";
const questionId = "00000000-0000-4000-8000-000000000401";

describe("game session action route", () => {
  it("rejects invalid payloads before calling the Edge Function", async () => {
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request({ action: "submit_answer" }));

    expect(response.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("forwards valid game actions to the Supabase Edge Function", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ success: true, data: { ok: true } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request(
        {
          action: "get_tv_state",
          session_id: sessionId,
        },
        { authorization: "Bearer user-token" },
      ),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ success: true, data: { ok: true } });
    expect(fetcher).toHaveBeenCalledWith(
      "https://example.supabase.co/functions/v1/game-session-action",
      expect.objectContaining({
        method: "POST",
        cache: "no-store",
        headers: expect.objectContaining({
          Authorization: "Bearer user-token",
          apikey: "anon-key",
        }),
      }),
    );
  });

  it("accepts join-session payloads with a join code", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ success: true, data: { ok: true } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request({
        action: "join_session",
        join_code: "RAYON24",
        display_name: "Supporter",
      }),
    );

    expect(response.status).toBe(200);
    expect(fetcher).toHaveBeenCalledWith(
      "https://example.supabase.co/functions/v1/game-session-action",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({
          action: "join_session",
          join_code: "RAYON24",
          display_name: "Supporter",
        }),
      }),
    );
  });

  it("accepts admin session and TV pairing payloads", async () => {
    const fetcher = vi.fn().mockImplementation(() =>
      Promise.resolve(new Response(JSON.stringify({ success: true, data: { ok: true } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      })),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const createResponse = await handler(
      request({
        action: "create_session",
        club_id: 24,
        title: "Rayon quiz",
        join_code: "RAYON24",
      }),
    );
    const pairResponse = await handler(
      request({
        action: "pair_tv_device",
        club_id: 24,
        device_label: "Main TV",
        pairing_code: "SCREEN24",
        session_id: sessionId,
      }),
    );

    expect(createResponse.status).toBe(200);
    expect(pairResponse.status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it("accepts moderation, pack publishing, and audit payloads", async () => {
    const fetcher = vi.fn().mockImplementation(() =>
      Promise.resolve(
        new Response(JSON.stringify({ success: true, data: { ok: true } }), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
      ),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const reviewResponse = await handler(
      request({
        action: "review_question_draft",
        club_id: 24,
        draft_id: draftId,
        decision: "approved",
      }),
    );
    const publishResponse = await handler(
      request({
        action: "publish_question_pack",
        club_id: 24,
        title: "Matchday pack",
        question_ids: [questionId],
      }),
    );
    const draftsResponse = await handler(
      request({
        action: "list_question_drafts",
        club_id: 24,
        status: "pending_review",
        search: "Rayon",
        limit: 25,
        offset: 25,
      }),
    );
    const auditResponse = await handler(
      request({
        action: "list_audit_log",
        club_id: 24,
        limit: 25,
        offset: 50,
        action_filter: "game_session_created",
        entity_type: "game_session",
      }),
    );

    expect(reviewResponse.status).toBe(200);
    expect(publishResponse.status).toBe(200);
    expect(draftsResponse.status).toBe(200);
    expect(auditResponse.status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("accepts admin host lifecycle payloads", async () => {
    const fetcher = vi.fn().mockImplementation(() =>
      Promise.resolve(
        new Response(JSON.stringify({ success: true, data: { ok: true } }), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
      ),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const openResponse = await handler(
      request({
        action: "open_question",
        club_id: 24,
        session_question_id: sessionQuestionId,
      }),
    );
    const revealResponse = await handler(
      request({
        action: "reveal_question",
        club_id: 24,
        session_question_id: sessionQuestionId,
      }),
    );
    const advanceResponse = await handler(
      request({
        action: "advance_question",
        club_id: 24,
        session_question_id: sessionQuestionId,
      }),
    );
    const closeResponse = await handler(
      request({
        action: "close_session",
        club_id: 24,
        session_id: sessionId,
      }),
    );

    expect(openResponse.status).toBe(200);
    expect(revealResponse.status).toBe(200);
    expect(advanceResponse.status).toBe(200);
    expect(closeResponse.status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("preserves upstream action errors", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: "Question is not open." }), {
        status: 400,
        headers: { "content-type": "application/json" },
      }),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request({
        action: "submit_answer",
        session_question_id: sessionQuestionId,
        session_player_id: sessionPlayerId,
        selected_option_key: "a",
      }),
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "Question is not open." });
  });

  it("rejects invalid UUID action ids before calling upstream", async () => {
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const invalidLifecycle = await handler(
      request({
        action: "open_question",
        club_id: 24,
        session_question_id: "question-1",
      }),
    );
    const invalidSubmit = await handler(
      request({
        action: "submit_answer",
        session_question_id: sessionQuestionId,
        session_player_id: "player-1",
        selected_option_key: "a",
      }),
    );

    expect(invalidLifecycle.status).toBe(400);
    expect(invalidSubmit.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("returns a same-origin rejection without calling upstream", async () => {
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () =>
        NextResponse.json({ error: "Cross-site mutation blocked." }, { status: 403 }),
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request({
        action: "get_tv_state",
        session_id: "session-1",
      }),
    );

    expect(response.status).toBe(403);
    expect(fetcher).not.toHaveBeenCalled();
  });
});
