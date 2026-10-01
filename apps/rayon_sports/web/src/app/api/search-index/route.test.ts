import { registerLocalHttpAssertions } from "../../../../e2e/fixtures/local-http-route-assertions";
const mocks = vi.hoisted(() => ({
  getSiteSearchIndex: vi.fn(),
}));

vi.mock("@/lib/data/public", () => ({
  getSiteSearchIndex: mocks.getSiteSearchIndex,
}));

import { GET } from "./route";

describe("GET /api/search-index", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns the controlled empty state", async () => {
    mocks.getSiteSearchIndex.mockResolvedValue([]);

    const response = await GET();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=300");
    await expect(response.json()).resolves.toEqual({
      code: "SEARCH_INDEX_EMPTY",
      items: [],
    });
  });

  it("returns a bounded cacheable search index", async () => {
    const items = [{ title: "Rayon", href: "/history" }];
    mocks.getSiteSearchIndex.mockResolvedValue(items);

    const response = await GET();

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      code: "SEARCH_INDEX_READY",
      items,
    });
  });

  it("does not send a response while the index is still syncing", async () => {
    let release: ((items: unknown[]) => void) | undefined;
    mocks.getSiteSearchIndex.mockReturnValue(
      new Promise((resolve) => {
        release = resolve;
      }),
    );

    let settled = false;
    const responsePromise = GET().finally(() => {
      settled = true;
    });
    await Promise.resolve();

    expect(settled).toBe(false);
    release?.([]);
    expect((await responsePromise).status).toBe(200);
  });

  it("returns a stable security timeout", async () => {
    vi.useFakeTimers();
    mocks.getSiteSearchIndex.mockReturnValue(new Promise(() => {}));

    const responsePromise = GET();
    const expectation = expect(responsePromise).resolves.toMatchObject({
      status: 504,
    });
    await vi.advanceTimersByTimeAsync(8_000);
    await expectation;
  });

  it("sanitizes search-provider failures", async () => {
    mocks.getSiteSearchIndex.mockRejectedValue(
      new Error("database.internal password=secret"),
    );

    const response = await GET();

    expect(response.status).toBe(502);
    const text = JSON.stringify(await response.json());
    expect(text).toContain("SEARCH_INDEX_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a stable permission-denied response", async () => {
    mocks.getSiteSearchIndex.mockRejectedValue({
      status: 403,
      message: "policy=private_search_index",
    });

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(403);
    expect(body).toEqual({
      code: "SEARCH_INDEX_ACCESS_DENIED",
      error: "Access denied.",
      retryable: false,
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("private_search_index");
  });

  it("returns a stable conflict response for a stale index snapshot", async () => {
    mocks.getSiteSearchIndex.mockRejectedValue({
      status: 409,
      message: "snapshot=private-version",
    });

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(409);
    expect(body).toEqual({
      code: "SEARCH_INDEX_CONFLICT",
      error:
        "The operation conflicts with current data. Refresh before retrying.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("private-version");
  });
});

registerLocalHttpAssertions([
  {
    "name": "returns the controlled empty state",
    "route": "/api/search-index",
    "state": "empty"
  },
  {
    "name": "does not send a response while the index is still syncing",
    "route": "/api/search-index",
    "state": "syncing"
  },
  {
    "name": "returns a stable security timeout",
    "route": "/api/search-index",
    "state": "security_timeout"
  },
  {
    "name": "sanitizes search-provider failures",
    "route": "/api/search-index",
    "state": "error"
  },
  {
    "name": "returns a stable permission-denied response",
    "route": "/api/search-index",
    "state": "permission_denied"
  },
  {
    "name": "returns a stable conflict response for a stale index snapshot",
    "route": "/api/search-index",
    "state": "conflict"
  }
]);
