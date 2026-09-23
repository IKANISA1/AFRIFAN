import {
  ControlledApiTimeoutError,
  controlledApiFailureResponse,
  controlledApiJson,
  withControlledApiTimeout,
} from "./controlled-api-response";

describe("controlled API responses", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("keeps successful responses uncached", async () => {
    const response = controlledApiJson({ ok: true }, 201);

    expect(response.status).toBe(201);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({ ok: true });
  });

  it("settles an operation before its deadline", async () => {
    await expect(
      withControlledApiTimeout(Promise.resolve("complete"), 10),
    ).resolves.toBe("complete");
  });

  it("returns a stable security-timeout response", async () => {
    vi.useFakeTimers();
    const operation = withControlledApiTimeout(
      new Promise<never>(() => {}),
      10,
    );
    const expectation = expect(operation).rejects.toBeInstanceOf(
      ControlledApiTimeoutError,
    );

    await vi.advanceTimersByTimeAsync(10);
    await expectation;

    const response = controlledApiFailureResponse(
      new ControlledApiTimeoutError(),
      "PWA_EVENT",
    );
    expect(response.status).toBe(504);
    await expect(response.json()).resolves.toEqual({
      code: "PWA_EVENT_TIMEOUT",
      error: "The operation timed out. Check current data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
  });

  it("maps a data conflict without exposing provider diagnostics", async () => {
    const response = controlledApiFailureResponse(
      { code: "23505", message: "duplicate endpoint secret" },
      "PWA_PUSH",
    );

    expect(response.status).toBe(409);
    expect(JSON.stringify(await response.json())).not.toContain("endpoint secret");
  });

  it("maps permission denial without exposing policy diagnostics", async () => {
    const response = controlledApiFailureResponse(
      {
        status: 403,
        message: "policy=private_internal user=user-private-id",
      },
      "SEARCH_INDEX",
    );
    const body = await response.json();

    expect(response.status).toBe(403);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(body).toEqual({
      code: "SEARCH_INDEX_ACCESS_DENIED",
      error: "Access denied.",
      retryable: false,
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("private_internal");
    expect(JSON.stringify(body)).not.toContain("user-private-id");
  });

  it("sanitizes ordinary provider failures", async () => {
    const response = controlledApiFailureResponse(
      new Error("database.internal:5432 password=secret"),
      "PUBLIC_SEARCH",
    );

    expect(response.status).toBe(502);
    const text = JSON.stringify(await response.json());
    expect(text).toContain("PUBLIC_SEARCH_FAILED");
    expect(text).not.toContain("database.internal");
    expect(text).not.toContain("password");
  });
});
