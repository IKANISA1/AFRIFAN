import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  FixturesSurface,
  normalizeFixtures,
  resolveFixturesFailureStatus,
  resolveFixturesStateCopy,
  type PublicFixture,
} from "./fixtures-surface";

const copy = {
  eyebrow: "Fixtures",
  title: "Live, next, and recent fixtures.",
  description: "Track the current match and next kickoff.",
  buyTickets: "Buy tickets",
  recentResults: "Recent results",
};

const fixtures: PublicFixture[] = [
  {
    id: "opening-day",
    homeTeam: "Rayon Sports",
    awayTeam: "APR FC",
    competition: "Premier League",
    venue: "Kigali Pelé Stadium",
    matchDate: "2026-08-01T15:00:00.000Z",
    kickoffTime: "17:00",
    isOnSale: true,
    generalPrice: 5000,
    matchStatus: "scheduled",
    homeScore: 0,
    awayScore: 0,
    liveMinute: null,
    matchSummary: "The opening fixture is confirmed.",
  },
  {
    id: "live-derby",
    homeTeam: "Rayon Sports",
    awayTeam: "Police FC",
    competition: "Premier League",
    venue: "Amahoro Stadium",
    matchDate: "2026-07-29T12:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "live",
    homeScore: 2,
    awayScore: 1,
    liveMinute: 64,
    matchSummary: "The derby is live.",
  },
];

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderFixtures(locale = "en") {
  return render(
    <FixturesSurface
      locale={locale}
      currencyCode="RWF"
      copy={copy}
    />,
  );
}

describe("fixtures surface state helpers", () => {
  it("accepts only bounded, unique, complete public fixture records", () => {
    const oversized = Array.from({ length: 22 }, (_, index) => ({
      ...fixtures[0],
      id: `fixture-${index}`,
      awayTeam: `Opponent ${index}`,
    }));

    expect(
      normalizeFixtures([
        fixtures[0],
        fixtures[0],
        { ...fixtures[0], id: "" },
        { ...fixtures[0], id: "bad-date", matchDate: "not-a-date" },
        { ...fixtures[0], id: "bad-price", generalPrice: -1 },
        ...oversized,
      ]),
    ).toEqual([fixtures[0], ...oversized.slice(0, 19)]);
  });

  it("maps controlled failures without exposing response diagnostics", () => {
    expect(resolveFixturesFailureStatus(403)).toBe("permission_denied");
    expect(resolveFixturesFailureStatus(409)).toBe("conflict");
    expect(resolveFixturesFailureStatus(504)).toBe("security_timeout");
    expect(resolveFixturesFailureStatus(502)).toBe("error");
  });

  it("provides the complete state vocabulary for every supported locale", () => {
    const expectedStates = [
      "loading",
      "ready",
      "empty",
      "error",
      "offline",
      "permission_denied",
      "syncing",
      "conflict",
      "security_timeout",
    ];

    for (const locale of ["en", "en", "en", "en", "unsupported"]) {
      expect(Object.keys(resolveFixturesStateCopy(locale).status)).toEqual(
        expectedStates,
      );
      expect(resolveFixturesStateCopy(locale).viewFixture).not.toBe("");
    }
  });
});

describe("FixturesSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("moves from loading to a confirmed schedule and exposes selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
    );

    const { container } = renderFixtures();
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-status",
      "loading",
    );
    expect(
      screen.getByRole("button", { name: /refresh fixtures/i }),
    ).toBeDisabled();

    await screen.findByText("Rayon Sports vs APR FC");
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-status",
      "ready",
    );
    const liveFixture = screen.getByRole("button", {
      name: /premier league\s*rayon sports vs police fc/i,
    });
    fireEvent.click(liveFixture);
    expect(liveFixture).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByText("2–1")).toBeInTheDocument();
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-interaction",
      "selected",
    );
  });

  it("renders an explicit confirmed empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURES_EMPTY", items: [] }),
    );

    const { container } = renderFixtures();
    await screen.findByText("No club fixtures are listed yet.");
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Fixture access denied"],
    [409, "conflict", "Fixture list changed"],
    [502, "error", "Fixtures unavailable"],
    [504, "security_timeout", "Fixture request timed out"],
  ] as const)(
    "maps HTTP %s to %s without rendering raw diagnostics",
    async (httpStatus, expectedState, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderFixtures();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
        "data-fixtures-status",
        expectedState,
      );
      expect(screen.queryByText(/database\.internal/i)).not.toBeInTheDocument();
    },
  );

  it("reports offline immediately and recovers when the browser reconnects", async () => {
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() =>
        response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
      );

    const { container } = renderFixtures();
    await waitFor(() =>
      expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
        "data-fixtures-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();

    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findByText("Rayon Sports vs APR FC");
  });

  it("retains confirmed fixtures while a refresh is syncing", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderFixtures();
    await screen.findByText("Rayon Sports vs APR FC");
    fireEvent.click(
      screen.getByRole("button", { name: /refresh fixtures/i }),
    );

    await waitFor(() =>
      expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
        "data-fixtures-status",
        "syncing",
      ),
    );
    expect(screen.getByText("Rayon Sports vs APR FC")).toBeInTheDocument();
    releaseRefresh?.(
      new Response(
        JSON.stringify({ code: "PUBLIC_FIXTURES_READY", items: fixtures }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
    await waitFor(() =>
      expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
        "data-fixtures-status",
        "ready",
      ),
    );
  });

  it("retains confirmed fixtures during recoverable refresh failures", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
      )
      .mockImplementationOnce(() =>
        response(409, { code: "PUBLIC_FIXTURES_CONFLICT" }),
      );

    const { container } = renderFixtures();
    await screen.findByText("Rayon Sports vs APR FC");
    fireEvent.click(
      screen.getByRole("button", { name: /refresh fixtures/i }),
    );

    await waitFor(() =>
      expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
        "data-fixtures-status",
        "conflict",
      ),
    );
    expect(screen.getByText("Rayon Sports vs APR FC")).toBeInTheDocument();
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
    );

    const { container } = renderFixtures();
    await screen.findByText("Rayon Sports vs APR FC");
    const tickets = screen.getByRole("link", { name: /buy tickets/i });
    fireEvent.focus(tickets);
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-interaction",
      "focused",
    );
    fireEvent.pointerDown(tickets);
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-interaction",
      "pressed",
    );
  });

  it("times out after the bounded client deadline without assuming content", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderFixtures();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".fixtures-surface")).toHaveAttribute(
      "data-fixtures-status",
      "security_timeout",
    );
    expect(screen.queryByText("Rayon Sports vs APR FC")).toBeNull();
  });
});
