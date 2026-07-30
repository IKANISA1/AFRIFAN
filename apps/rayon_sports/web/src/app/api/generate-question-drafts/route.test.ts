import { NextRequest, NextResponse } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createGenerateQuestionDraftsRouteHandler } from "./route";

function request(body: unknown, headers: Record<string, string> = {}) {
  return new NextRequest("https://admin.gikundiro.com/api/generate-question-drafts", {
    method: "POST",
    headers: {
      origin: "https://admin.gikundiro.com",
      "content-type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

const validBody = {
  club_id: 24,
  source: {
    source_title: "Rayon source",
    extracted_fact: "Rayon Sports has a verified club-history fact.",
    source_url: "https://example.com/source",
    source_date: "2026-07-02",
    trust_tier: "review_required",
  },
  count: 3,
  language: "en",
  category: "club_knowledge",
};

describe("generate question drafts route", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("rejects invalid payloads before calling the Edge Function", async () => {
    const fetcher = vi.fn();
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request({ club_id: 24 }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      code: "EDGE_FUNCTION_EMPTY",
      retryable: false,
      change_confirmed: false,
    });
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("forwards valid draft-generation payloads to the Supabase Edge Function", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            sourceId: "source-1",
            draftIds: ["draft-1"],
            mode: "ai_assisted",
            count: 1,
          },
        }),
        {
          status: 200,
          headers: { "content-type": "application/json" },
        },
      ),
    );
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(
      request(validBody, { authorization: "Bearer admin-token" }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      success: true,
      data: {
        sourceId: "source-1",
        draftIds: ["draft-1"],
        mode: "ai_assisted",
        count: 1,
      },
    });
    expect(fetcher).toHaveBeenCalledWith(
      "https://example.supabase.co/functions/v1/generate-question-drafts",
      expect.objectContaining({
        method: "POST",
        cache: "no-store",
        body: JSON.stringify(validBody),
        headers: expect.objectContaining({
          Authorization: "Bearer admin-token",
          apikey: "anon-key",
        }),
      }),
    );
  });

  it("returns a same-origin rejection without calling upstream", async () => {
    const fetcher = vi.fn();
    const handler = createGenerateQuestionDraftsRouteHandler({
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

    const response = await handler(request(validBody));

    expect(response.status).toBe(403);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("sanitizes upstream permission denial", async () => {
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
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(validBody));
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

  it("maps an upstream draft collision to a safe conflict response", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ error: "row=user-private-id already exists" }),
        {
          status: 409,
          headers: { "content-type": "application/json" },
        },
      ),
    );
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(validBody));
    const payload = await response.json();

    expect(response.status).toBe(409);
    expect(payload).toEqual({
      code: "EDGE_FUNCTION_CONFLICT",
      error:
        "The operation conflicts with current data. Refresh before retrying.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
  });

  it("does not confirm draft generation while upstream remains syncing", async () => {
    let resolveUpstream: ((response: Response) => void) | undefined;
    const fetcher = vi.fn(
      () =>
        new Promise<Response>((resolve) => {
          resolveUpstream = resolve;
        }),
    );
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });
    let settled = false;
    const responsePromise = handler(request(validBody)).then((response) => {
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
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
      operationTimeoutMs: 25,
    });
    const responsePromise = handler(request(validBody));

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
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => new Promise<never>(() => {}),
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
      operationTimeoutMs: 25,
    });
    const responsePromise = handler(request(validBody));

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
    const fetcher = vi.fn().mockRejectedValue(
      new Error("service_role=secret-value source=user-private-id"),
    );
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(validBody));
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
    const handler = createGenerateQuestionDraftsRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(validBody));
    const payload = await response.json();

    expect(response.status).toBe(502);
    expect(payload.code).toBe("EDGE_FUNCTION_UNAVAILABLE");
    expect(JSON.stringify(payload)).not.toContain("secret-value");
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
  });
});
