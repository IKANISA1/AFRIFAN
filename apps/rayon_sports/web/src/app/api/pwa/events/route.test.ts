import { NextRequest, NextResponse } from "next/server";

const mocks = vi.hoisted(() => ({
  getActiveClubReference: vi.fn(),
  getAdminSupabase: vi.fn(),
  getServerSupabase: vi.fn(),
  rejectInsecureMutation: vi.fn(),
  rejectRateLimitedRequest: vi.fn(),
}));

vi.mock("@/lib/club-context", () => ({
  getActiveClubReference: mocks.getActiveClubReference,
}));
vi.mock("@/lib/supabase/admin", () => ({
  getAdminSupabase: mocks.getAdminSupabase,
}));
vi.mock("@/lib/supabase/server", () => ({
  getServerSupabase: mocks.getServerSupabase,
}));
vi.mock("@/lib/security", () => ({
  rejectInsecureMutation: mocks.rejectInsecureMutation,
  rejectRateLimitedRequest: mocks.rejectRateLimitedRequest,
}));

import { POST } from "./route";

function request(body: unknown) {
  return new NextRequest("https://gikundiro.com/api/pwa/events", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "user-agent": "test-agent",
      "x-africlub-csrf": "1",
    },
    body: JSON.stringify(body),
  });
}

function adminClient(
  result: Promise<{ error: { code?: string; message: string } | null }>,
) {
  return {
    from: vi.fn(() => ({
      insert: vi.fn(() => result),
    })),
  };
}

describe("POST /api/pwa/events", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
    mocks.rejectInsecureMutation.mockReturnValue(null);
    mocks.rejectRateLimitedRequest.mockResolvedValue(null);
    mocks.getActiveClubReference.mockResolvedValue({ slug: "rayon-sports" });
    mocks.getServerSupabase.mockResolvedValue({
      auth: {
        getUser: vi.fn().mockResolvedValue({
          data: { user: { id: "user-1" } },
        }),
      },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns a controlled empty-state response for invalid input", async () => {
    const response = await POST(request({}));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      code: "PWA_EVENT_EMPTY",
    });
    expect(mocks.getAdminSupabase).not.toHaveBeenCalled();
  });

  it("honors the permission boundary before reading the body", async () => {
    mocks.rejectInsecureMutation.mockReturnValue(
      NextResponse.json(
        { code: "PWA_EVENT_ACCESS_DENIED", error: "Mutation blocked." },
        { status: 403 },
      ),
    );

    const response = await POST(
      request({ eventType: "push-subscribed", surface: "site" }),
    );

    expect(response.status).toBe(403);
    expect(mocks.getAdminSupabase).not.toHaveBeenCalled();
  });

  it("stores a bounded privacy-sanitized event", async () => {
    const insert = vi.fn().mockResolvedValue({ error: null });
    mocks.getAdminSupabase.mockReturnValue({
      from: vi.fn(() => ({ insert })),
    });

    const response = await POST(
      request({
        eventType: "push-preview-sent",
        surface: "site",
        displayMode: "standalone",
        path: "/supporters",
        payload: {
          success: true,
          phone: "+250788000000",
          accessToken: "secret-token",
        },
      }),
    );

    expect(response.status).toBe(201);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: { success: true },
        user_id: "user-1",
      }),
    );
    expect(JSON.stringify(insert.mock.calls)).not.toContain("+250788000000");
    expect(JSON.stringify(insert.mock.calls)).not.toContain("secret-token");
  });

  it("does not report completion while storage is still syncing", async () => {
    let release: ((value: { error: null }) => void) | undefined;
    const pending = new Promise<{ error: null }>((resolve) => {
      release = resolve;
    });
    mocks.getAdminSupabase.mockReturnValue(adminClient(pending));

    let settled = false;
    const responsePromise = POST(
      request({ eventType: "install-completed", surface: "site" }),
    ).finally(() => {
      settled = true;
    });
    await Promise.resolve();

    expect(settled).toBe(false);
    release?.({ error: null });
    expect((await responsePromise).status).toBe(201);
  });

  it("returns a stable conflict response", async () => {
    mocks.getAdminSupabase.mockReturnValue(
      adminClient(
        Promise.resolve({
          error: { code: "23505", message: "raw duplicate data" },
        }),
      ),
    );

    const response = await POST(
      request({ eventType: "install-completed", surface: "site" }),
    );

    expect(response.status).toBe(409);
    expect(JSON.stringify(await response.json())).not.toContain("raw duplicate");
  });

  it("returns a sanitized provider-error response", async () => {
    mocks.getAdminSupabase.mockReturnValue(
      adminClient(
        Promise.resolve({
          error: { message: "database.internal password=secret" },
        }),
      ),
    );

    const response = await POST(
      request({ eventType: "install-completed", surface: "site" }),
    );

    expect(response.status).toBe(502);
    expect(JSON.stringify(await response.json())).not.toContain("database.internal");
  });

  it("returns a stable timeout when storage does not settle", async () => {
    vi.useFakeTimers();
    mocks.getAdminSupabase.mockReturnValue(
      adminClient(new Promise(() => {})),
    );

    const responsePromise = POST(
      request({ eventType: "install-completed", surface: "site" }),
    );
    const expectation = expect(responsePromise).resolves.toMatchObject({
      status: 504,
    });
    await vi.advanceTimersByTimeAsync(8_000);
    await expectation;
  });
});
