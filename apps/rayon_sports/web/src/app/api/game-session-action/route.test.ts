import { NextRequest, NextResponse } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createGameSessionActionRouteHandler } from "./route";

function request(body: unknown, headers: Record<string, string> = {}) {
  return new NextRequest(
    "https://admin.gikundiro.com/api/game-session-action",
    {
      method: "POST",
      headers: {
        origin: "https://admin.gikundiro.com",
        "content-type": "application/json",
        ...headers,
      },
      body: JSON.stringify(body),
    },
  );
}

const sessionId = "00000000-0000-4000-8000-000000000001";
const sessionQuestionId = "00000000-0000-4000-8000-000000000101";
const sessionPlayerId = "00000000-0000-4000-8000-000000000201";
const draftId = "00000000-0000-4000-8000-000000000301";
const packId = "00000000-0000-4000-8000-000000000501";
const displayId = "00000000-0000-4000-8000-000000000601";

describe("game session action route", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

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
    await expect(response.json()).resolves.toMatchObject({
      code: "EDGE_FUNCTION_EMPTY",
      retryable: false,
      change_confirmed: false,
    });
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("forwards valid game actions to the Supabase Edge Function", async () => {
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
    expect(await response.json()).toEqual({
      success: true,
      data: { ok: true },
    });
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

  it("accepts authorized planner, managed-session, and versioned transition payloads", async () => {
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

    const optionsResponse = await handler(
      request({ action: "get_planner_options" }),
    );
    const sessionsResponse = await handler(
      request({ action: "get_managed_sessions" }),
    );
    const createResponse = await handler(
      request({
        action: "create_managed_session",
        pack_id: packId,
        scheduled_start_at: "2026-07-31T17:30:00.000Z",
        eligibility_scope: "club_membership",
        display_ids: [displayId],
        organizer_user_ids: [],
        idempotency_key: "planner-create-001",
      }),
    );
    const transitionResponse = await handler(
      request({
        action: "transition_managed_session",
        session_id: sessionId,
        requested_phase: "activated_lobby",
        expected_session_version: 3,
        idempotency_key: "planner-transition-001",
      }),
    );

    expect([
      optionsResponse.status,
      sessionsResponse.status,
      createResponse.status,
      transitionResponse.status,
    ]).toEqual([200, 200, 200, 200]);
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("rejects duplicate display selectors and weak managed idempotency keys", async () => {
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const duplicateDisplays = await handler(
      request({
        action: "create_managed_session",
        pack_id: packId,
        scheduled_start_at: "2026-07-31T17:30:00.000Z",
        eligibility_scope: "venue",
        display_ids: [displayId, displayId],
        organizer_user_ids: [],
        idempotency_key: "planner-create-002",
      }),
    );
    const weakTransition = await handler(
      request({
        action: "transition_managed_session",
        session_id: sessionId,
        requested_phase: "paused",
        expected_session_version: 3,
        idempotency_key: "short",
      }),
    );

    expect(duplicateDisplays.status).toBe(400);
    expect(weakTransition.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("accepts join-session payloads only with a session UUID", async () => {
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
        session_id: sessionId,
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
          session_id: sessionId,
          display_name: "Supporter",
        }),
      }),
    );
  });

  it("accepts admin session creation without join or pairing codes", async () => {
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

    const createResponse = await handler(
      request({
        action: "create_session",
        club_id: 24,
        title: "Rayon quiz",
      }),
    );

    expect(createResponse.status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it("rejects retired join-code and admin pairing-code payloads", async () => {
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const joinResponse = await handler(
      request({
        action: "join_session",
        join_code: "RAYON24",
      }),
    );
    const pairingResponse = await handler(
      request({
        action: "pair_tv_device",
        club_id: 24,
        pairing_code: "SCREEN24",
      }),
    );

    expect(joinResponse.status).toBe(400);
    expect(pairingResponse.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
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
        question_ids: Array.from(
          { length: 20 },
          (_, index) =>
            `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
        ),
        preview_fingerprint: "a".repeat(64),
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

  it("rejects pack publication without an exact preview fingerprint", async () => {
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request({
        action: "publish_question_pack",
        club_id: 24,
        title: "Matchday pack",
        question_ids: Array.from(
          { length: 20 },
          (_, index) =>
            `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
        ),
      }),
    );

    expect(response.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
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

  it("sanitizes upstream permission denial for a protected action", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          error: "role=user-private-id policy=club_admin_internal",
        }),
        {
          status: 403,
          headers: { "content-type": "application/json" },
        },
      ),
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
        action: "create_session",
        club_id: 24,
        title: "Rayon quiz",
      }),
    );
    const payload = await response.json();

    expect(response.status).toBe(403);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(payload).toEqual({
      code: "EDGE_FUNCTION_ACCESS_DENIED",
      error: "Access denied.",
    });
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
    expect(JSON.stringify(payload)).not.toContain("club_admin_internal");
  });

  it("maps an upstream answer collision to a safe conflict contract", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          error: "already answered row=user-private-id",
        }),
        {
          status: 409,
          headers: { "content-type": "application/json" },
        },
      ),
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
    const payload = await response.json();

    expect(response.status).toBe(409);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(payload).toEqual({
      code: "EDGE_FUNCTION_CONFLICT",
      error:
        "The operation conflicts with current data. Refresh before retrying.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
  });

  it("does not confirm an action while the upstream write is still syncing", async () => {
    let resolveUpstream: ((response: Response) => void) | undefined;
    const fetcher = vi.fn(
      () =>
        new Promise<Response>((resolve) => {
          resolveUpstream = resolve;
        }),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });
    let settled = false;
    const responsePromise = handler(
      request({ action: "get_tv_state", session_id: sessionId }),
    ).then((response) => {
      settled = true;
      return response;
    });

    await vi.waitFor(() => {
      expect(resolveUpstream).toBeTypeOf("function");
    });
    expect(settled).toBe(false);

    resolveUpstream?.(
      new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
    const response = await responsePromise;
    expect(response.status).toBe(200);
    expect(settled).toBe(true);
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
        NextResponse.json(
          {
            code: "MUTATION_ACCESS_DENIED",
            error: "Cross-site mutation blocked.",
          },
          { status: 403 },
        ),
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

  it("aborts a stalled upstream request with an unconfirmed timeout response", async () => {
    vi.useFakeTimers();
    const fetcher = vi.fn(
      async (_input: RequestInfo | URL, init?: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            reject(new DOMException("Aborted", "AbortError"));
          });
        }),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
      operationTimeoutMs: 25,
    });
    const responsePromise = handler(
      request({ action: "get_tv_state", session_id: sessionId }),
    );

    await vi.advanceTimersByTimeAsync(25);
    const response = await responsePromise;

    expect(response.status).toBe(504);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(fetcher.mock.calls[0]?.[1]?.signal?.aborted).toBe(true);
    await expect(response.json()).resolves.toEqual({
      code: "EDGE_FUNCTION_TIMEOUT",
      error: "The operation timed out. Check current data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
  });

  it("bounds rate-limit evaluation before calling upstream", async () => {
    vi.useFakeTimers();
    const fetcher = vi.fn();
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => new Promise<never>(() => {}),
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
      operationTimeoutMs: 25,
    });
    const responsePromise = handler(
      request({ action: "get_tv_state", session_id: sessionId }),
    );

    await vi.advanceTimersByTimeAsync(25);
    const response = await responsePromise;

    expect(response.status).toBe(504);
    expect(fetcher).not.toHaveBeenCalled();
    await expect(response.json()).resolves.toMatchObject({
      code: "EDGE_FUNCTION_TIMEOUT",
      change_confirmed: false,
    });
  });

  it("sanitizes upstream transport failures", async () => {
    const fetcher = vi
      .fn()
      .mockRejectedValue(
        new Error("service_role=secret-value session=user-private-id"),
      );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request({ action: "get_tv_state", session_id: sessionId }),
    );
    const payload = await response.json();

    expect(response.status).toBe(502);
    expect(payload).toEqual({
      code: "EDGE_FUNCTION_UNAVAILABLE",
      error: "The operation could not be completed.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(payload)).not.toContain("secret-value");
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
  });

  it("sanitizes upstream server response bodies", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          error: "service_role=secret-value row=user-private-id",
        }),
        {
          status: 500,
          headers: { "content-type": "application/json" },
        },
      ),
    );
    const handler = createGameSessionActionRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request({ action: "get_tv_state", session_id: sessionId }),
    );
    const payload = await response.json();

    expect(response.status).toBe(502);
    expect(payload.code).toBe("EDGE_FUNCTION_UNAVAILABLE");
    expect(JSON.stringify(payload)).not.toContain("secret-value");
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
  });
});
