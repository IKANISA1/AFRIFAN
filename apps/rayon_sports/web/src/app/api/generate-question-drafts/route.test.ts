import { NextRequest, NextResponse } from "next/server";
import { describe, expect, it, vi } from "vitest";
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
        NextResponse.json({ error: "Cross-site mutation blocked." }, { status: 403 }),
      rejectRateLimitedRequest: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(validBody));

    expect(response.status).toBe(403);
    expect(fetcher).not.toHaveBeenCalled();
  });
});
