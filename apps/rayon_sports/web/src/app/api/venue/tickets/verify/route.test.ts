import { NextRequest, NextResponse } from "next/server";
import { describe, expect, it, vi } from "vitest";
import { createVerifyTicketRouteHandler } from "./route";

const credentialId = "11111111-1111-4111-8111-111111111111";
const operationId = "22222222-2222-4222-8222-222222222222";
const body = {
  ticket_code: `AFC1.${credentialId}.1.1800000000.12345678`,
  operation_id: operationId,
  gate_code: "north_1",
};

function request(value: unknown) {
  return new NextRequest("https://venue.example.com/api/venue/tickets/verify", {
    method: "POST",
    headers: {
      origin: "https://venue.example.com",
      "content-type": "application/json",
    },
    body: JSON.stringify(value),
  });
}

describe("venue ticket verification route", () => {
  it("forwards a normalized scan using the server session", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: { result: { status: "admitted", code: "admitted" } },
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );
    const handler = createVerifyTicketRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken: async () => "staff-session-token",
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(body));
    expect(response.status).toBe(200);
    expect(fetcher).toHaveBeenCalledWith(
      "https://example.supabase.co/functions/v1/verify-ticket",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Bearer staff-session-token",
          apikey: "anon-key",
        }),
        body: JSON.stringify({ ...body, gate_code: "NORTH_1" }),
      }),
    );
  });

  it("rejects malformed payloads before authentication or upstream work", async () => {
    const fetcher = vi.fn();
    const getAccessToken = vi.fn();
    const handler = createVerifyTicketRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });
    const response = await handler(request({ ticket_code: "bad" }));
    expect(response.status).toBe(400);
    expect(getAccessToken).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("requires a server-authenticated staff session", async () => {
    const fetcher = vi.fn();
    const handler = createVerifyTicketRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken: async () => null,
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });
    const response = await handler(request(body));
    expect(response.status).toBe(401);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("blocks cross-site mutation before reading the scan", async () => {
    const fetcher = vi.fn();
    const handler = createVerifyTicketRouteHandler({
      fetcher,
      rejectInsecureMutation: () =>
        NextResponse.json(
          { code: "MUTATION_ACCESS_DENIED", error: "blocked" },
          { status: 403 },
        ),
      rejectRateLimitedRequest: async () => null,
      getAccessToken: async () => "token",
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });
    const response = await handler(request(body));
    expect(response.status).toBe(403);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("keeps the request pending until authoritative verification settles", async () => {
    let resolveUpstream: ((response: Response) => void) | undefined;
    const fetcher = vi.fn().mockReturnValue(
      new Promise<Response>((resolve) => {
        resolveUpstream = resolve;
      }),
    );
    const handler = createVerifyTicketRouteHandler({
      fetcher,
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken: async () => "staff-session-token",
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    let settled = false;
    const operation = handler(request(body)).then((response) => {
      settled = true;
      return response;
    });
    await Promise.resolve();
    await Promise.resolve();
    expect(settled).toBe(false);

    resolveUpstream?.(
      new Response(
        JSON.stringify({
          success: true,
          data: { result: { status: "admitted", code: "admitted" } },
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );
    expect((await operation).status).toBe(200);
  });

  it("maps an authoritative collision to a sanitized unconfirmed conflict", async () => {
    const handler = createVerifyTicketRouteHandler({
      fetcher: vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ secret: "must-not-pass-through" }), {
          status: 409,
          headers: { "content-type": "application/json" },
        }),
      ),
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken: async () => "staff-session-token",
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(body));
    expect(response.status).toBe(409);
    await expect(response.json()).resolves.toEqual({
      code: "EDGE_FUNCTION_CONFLICT",
      error:
        "The operation conflicts with current data. Refresh before retrying.",
      retryable: true,
      change_confirmed: false,
    });
  });

  it("sanitizes an unavailable upstream without confirming a change", async () => {
    const handler = createVerifyTicketRouteHandler({
      fetcher: vi.fn().mockRejectedValue(new Error("private upstream detail")),
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken: async () => "staff-session-token",
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
    });

    const response = await handler(request(body));
    expect(response.status).toBe(502);
    const payload = await response.json();
    expect(payload).toEqual({
      code: "EDGE_FUNCTION_UNAVAILABLE",
      error: "The operation could not be completed.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(payload)).not.toContain("private upstream detail");
  });

  it("fails a stalled authorization lookup closed with a bounded timeout", async () => {
    const handler = createVerifyTicketRouteHandler({
      fetcher: vi.fn(),
      rejectInsecureMutation: () => null,
      rejectRateLimitedRequest: async () => null,
      getAccessToken: () => new Promise<string | null>(() => {}),
      supabaseUrl: "https://example.supabase.co",
      supabaseAnonKey: "anon-key",
      operationTimeoutMs: 1,
    });

    const response = await handler(request(body));
    expect(response.status).toBe(504);
    await expect(response.json()).resolves.toEqual({
      code: "EDGE_FUNCTION_TIMEOUT",
      error: "The operation timed out. Check current data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
  });
});
