import { NextRequest, NextResponse } from "next/server";

const mocks = vi.hoisted(() => ({
  getActiveClubReference: vi.fn(),
  getAdminSupabase: vi.fn(),
  getServerSupabase: vi.fn(),
  rejectInsecureMutation: vi.fn(),
  rejectRateLimitedRequest: vi.fn(),
  sendNotification: vi.fn(),
  setVapidDetails: vi.fn(),
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
vi.mock("web-push", () => ({
  default: {
    sendNotification: mocks.sendNotification,
    setVapidDetails: mocks.setVapidDetails,
  },
}));

import { POST } from "./route";

const subscription = {
  endpoint: "https://push.example.test/subscription/123",
  keys: {
    auth: "auth-key-value",
    p256dh: "p256dh-key-value-with-at-least-thirty-two-characters",
  },
};

function request(body: unknown) {
  return new NextRequest("https://gikundiro.com/api/pwa/push", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      cookie: "sb-access-token=must-never-be-persisted",
      "x-africlub-csrf": "1",
    },
    body: JSON.stringify(body),
  });
}

function createAdminClient({
  upsertResult = Promise.resolve({ error: null }),
  updateResult = Promise.resolve({ error: null }),
}: {
  upsertResult?: Promise<{
    error: { code?: string; message: string } | null;
  }>;
  updateResult?: Promise<{
    error: { code?: string; message: string } | null;
  }>;
} = {}) {
  const upsert = vi.fn(() => upsertResult);
  const eq = vi.fn(() => updateResult);
  const update = vi.fn(() => ({ eq }));
  return {
    client: {
      from: vi.fn(() => ({ upsert, update })),
    },
    upsert,
    update,
    eq,
  };
}

describe("POST /api/pwa/push", () => {
  const originalEnvironment = { ...process.env };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
    process.env = { ...originalEnvironment };
    delete process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    delete process.env.VAPID_PUBLIC_KEY;
    delete process.env.VAPID_PRIVATE_KEY;
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
    mocks.getAdminSupabase.mockReturnValue(createAdminClient().client);
  });

  afterEach(() => {
    vi.useRealTimers();
    process.env = { ...originalEnvironment };
  });

  it("returns the controlled empty state for malformed input", async () => {
    const response = await POST(request({ action: "subscribe" }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      code: "PWA_PUSH_EMPTY",
    });
  });

  it("honors the permission boundary before accessing storage", async () => {
    mocks.rejectInsecureMutation.mockReturnValue(
      NextResponse.json(
        { code: "PWA_PUSH_ACCESS_DENIED", error: "Mutation blocked." },
        { status: 403 },
      ),
    );

    const response = await POST(
      request({ action: "subscribe", subscription }),
    );

    expect(response.status).toBe(403);
    expect(mocks.getAdminSupabase).not.toHaveBeenCalled();
  });

  it("stores a subscription without persisting the access-token cookie", async () => {
    const store = createAdminClient();
    mocks.getAdminSupabase.mockReturnValue(store.client);

    const response = await POST(
      request({
        action: "subscribe",
        subscription,
        surface: "site",
        path: "/supporters",
      }),
    );

    expect(response.status).toBe(201);
    expect(store.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        session_id: null,
        user_id: "user-1",
      }),
      { onConflict: "endpoint" },
    );
    expect(JSON.stringify(store.upsert.mock.calls)).not.toContain(
      "must-never-be-persisted",
    );
  });

  it("returns a controlled syncing response while delivery is unconfigured", async () => {
    const response = await POST(
      request({ action: "test", subscription }),
    );

    expect(response.status).toBe(202);
    await expect(response.json()).resolves.toMatchObject({
      code: "PWA_PUSH_SYNCING",
      retryable: true,
    });
  });

  it("maps a storage conflict without exposing database diagnostics", async () => {
    const store = createAdminClient({
      upsertResult: Promise.resolve({
        error: { code: "23505", message: "duplicate endpoint raw diagnostic" },
      }),
    });
    mocks.getAdminSupabase.mockReturnValue(store.client);

    const response = await POST(
      request({ action: "subscribe", subscription }),
    );

    expect(response.status).toBe(409);
    expect(JSON.stringify(await response.json())).not.toContain("raw diagnostic");
  });

  it("uses a fixed non-phishing preview payload", async () => {
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = "public-key";
    process.env.VAPID_PRIVATE_KEY = "private-key";
    mocks.sendNotification.mockResolvedValue({ statusCode: 201 });

    const response = await POST(
      request({
        action: "test",
        subscription,
        title: "Reset your password",
        body: "Send credentials to an attacker",
        url: "https://evil.example",
      }),
    );

    expect(response.status).toBe(200);
    const payload = String(mocks.sendNotification.mock.calls[0]?.[1]);
    expect(payload).toContain("Official club alerts");
    expect(payload).not.toContain("Reset your password");
    expect(payload).not.toContain("evil.example");
  });

  it("returns a stable timeout for stalled delivery", async () => {
    vi.useFakeTimers();
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = "public-key";
    process.env.VAPID_PRIVATE_KEY = "private-key";
    mocks.sendNotification.mockReturnValue(new Promise(() => {}));

    const responsePromise = POST(
      request({ action: "test", subscription }),
    );
    const expectation = expect(responsePromise).resolves.toMatchObject({
      status: 504,
    });
    await vi.advanceTimersByTimeAsync(8_000);
    await expectation;
  });

  it("sanitizes push-provider failures", async () => {
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = "public-key";
    process.env.VAPID_PRIVATE_KEY = "private-key";
    mocks.sendNotification.mockRejectedValue(
      new Error("push-provider secret endpoint diagnostic"),
    );

    const response = await POST(
      request({ action: "test", subscription }),
    );

    expect(response.status).toBe(502);
    expect(JSON.stringify(await response.json())).not.toContain("secret endpoint");
  });
});
