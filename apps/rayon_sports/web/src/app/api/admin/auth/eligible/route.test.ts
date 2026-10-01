import { registerLocalHttpAssertions, httpFixtureOrigin } from "../../../../../../e2e/fixtures/local-http-route-assertions";
import { NextRequest, NextResponse } from "next/server";

const mocks = vi.hoisted(() => ({
  findEligibleAdminPhoneCandidate: vi.fn(),
  getAdminSupabase: vi.fn(),
  getServerSupabase: vi.fn(),
  rejectInsecureMutation: vi.fn(),
  rejectRateLimitedRequest: vi.fn(),
}));

vi.mock("@/lib/admin-phone-access", () => ({
  findEligibleAdminPhoneCandidate: mocks.findEligibleAdminPhoneCandidate,
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

function request(phone: string) {
  return new NextRequest(
    `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/auth/eligible`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-africlub-csrf": "1",
      },
      body: JSON.stringify({ phone }),
    },
  );
}

describe("POST /api/admin/auth/eligible", () => {
  const signInWithOtp = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
    mocks.rejectInsecureMutation.mockReturnValue(null);
    mocks.rejectRateLimitedRequest.mockResolvedValue(null);
    mocks.getAdminSupabase.mockReturnValue({ admin: true });
    mocks.getServerSupabase.mockResolvedValue({
      auth: { signInWithOtp },
    });
    signInWithOtp.mockResolvedValue({ error: null });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns the controlled empty state for an invalid phone", async () => {
    const response = await POST(request("not-a-phone"));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      code: "ADMIN_OTP_EMPTY",
    });
    expect(mocks.findEligibleAdminPhoneCandidate).not.toHaveBeenCalled();
  });

  it("honors the permission boundary before checking eligibility", async () => {
    mocks.rejectInsecureMutation.mockReturnValue(
      NextResponse.json(
        { code: "ADMIN_OTP_ACCESS_DENIED", error: "Mutation blocked." },
        { status: 403 },
      ),
    );

    const response = await POST(request("+250788123456"));

    expect(response.status).toBe(403);
    expect(mocks.findEligibleAdminPhoneCandidate).not.toHaveBeenCalled();
  });

  it("returns the same accepted response for an unapproved phone", async () => {
    mocks.findEligibleAdminPhoneCandidate.mockResolvedValue(null);

    const response = await POST(request("+250788123456"));
    const body = await response.json();

    expect(response.status).toBe(202);
    expect(body).toMatchObject({
      code: "ADMIN_OTP_REQUEST_ACCEPTED",
      accepted: true,
    });
    expect(JSON.stringify(body)).not.toContain("+250788123456");
    expect(signInWithOtp).not.toHaveBeenCalled();
  });

  it("requests OTP server-side without revealing allowlist membership", async () => {
    mocks.findEligibleAdminPhoneCandidate.mockResolvedValue({
      phone: "+250788123456",
      userId: "admin-1",
      clubIds: [1],
    });

    const response = await POST(request("+250788123456"));
    const body = await response.json();

    expect(response.status).toBe(202);
    expect(signInWithOtp).toHaveBeenCalledWith({
      phone: "+250788123456",
      options: {
        shouldCreateUser: false,
        channel: "whatsapp",
      },
    });
    expect(JSON.stringify(body)).not.toContain("+250788123456");
    expect(JSON.stringify(body)).not.toContain("admin-1");
  });

  it("returns a stable timeout while eligibility lookup is stalled", async () => {
    vi.useFakeTimers();
    mocks.findEligibleAdminPhoneCandidate.mockReturnValue(
      new Promise(() => {}),
    );

    const responsePromise = POST(request("+250788123456"));
    const expectation = expect(responsePromise).resolves.toMatchObject({
      status: 504,
    });
    await vi.advanceTimersByTimeAsync(8_000);
    await expectation;
  });

  it("sanitizes OTP-provider failures", async () => {
    mocks.findEligibleAdminPhoneCandidate.mockResolvedValue({
      phone: "+250788123456",
      userId: "admin-1",
      clubIds: [1],
    });
    signInWithOtp.mockResolvedValue({
      error: new Error("provider.internal token=secret"),
    });

    const response = await POST(request("+250788123456"));

    expect(response.status).toBe(502);
    const text = JSON.stringify(await response.json());
    expect(text).toContain("ADMIN_OTP_FAILED");
    expect(text).not.toContain("provider.internal");
    expect(text).not.toContain("secret");
  });

  it("does not confirm OTP readiness while eligibility is unsettled", async () => {
    let release: ((value: null) => void) | undefined;
    mocks.findEligibleAdminPhoneCandidate.mockReturnValue(new Promise((resolve) => { release = resolve; }));
    let settled = false;
    const pending = POST(request("+250788123456")).then((response) => { settled = true; return response; });
    for (let i = 0; i < 12; i++) await Promise.resolve();
    expect(mocks.findEligibleAdminPhoneCandidate).toHaveBeenCalledTimes(1);
    expect(settled).toBe(false);
    expect(signInWithOtp).not.toHaveBeenCalled();
    release?.(null);
    const response = await pending;
    expect(response.status).toBe(202);
    expect(await response.json()).toMatchObject({ code: "ADMIN_OTP_REQUEST_ACCEPTED", accepted: true });
  });

  it("returns a controlled conflict without revealing candidate details", async () => {
    mocks.findEligibleAdminPhoneCandidate.mockRejectedValue({
      status: 409,
      message: "candidate=user-private-id phone=+250788123456",
    });

    const response = await POST(request("+250788123456"));
    const body = await response.json();

    expect(response.status).toBe(409);
    expect(body).toEqual({
      code: "ADMIN_OTP_CONFLICT",
      error:
        "The operation conflicts with current data. Refresh before retrying.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("user-private-id");
    expect(JSON.stringify(body)).not.toContain("+250788123456");
  });
});

registerLocalHttpAssertions([
  {
    "name": "returns the controlled empty state for an invalid phone",
    "route": "/api/admin/auth/eligible",
    "state": "empty"
  },
  {
    "name": "honors the permission boundary before checking eligibility",
    "route": "/api/admin/auth/eligible",
    "state": "permission_denied"
  },
  {
    "name": "returns a stable timeout while eligibility lookup is stalled",
    "route": "/api/admin/auth/eligible",
    "state": "security_timeout"
  },
  {
    "name": "sanitizes OTP-provider failures",
    "route": "/api/admin/auth/eligible",
    "state": "error"
  },
  {
    "name": "returns a controlled conflict without revealing candidate details",
    "route": "/api/admin/auth/eligible",
    "state": "conflict"
  },
  {
    "name": "does not confirm OTP readiness while eligibility is unsettled",
    "route": "/api/admin/auth/eligible",
    "state": "syncing"
  }
]);
