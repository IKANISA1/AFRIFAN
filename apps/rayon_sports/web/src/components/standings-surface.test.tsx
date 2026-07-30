import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  normalizeStandings,
  resolveStandingsStateCopy,
  StandingsSurface,
  type PublicStanding,
} from "./standings-surface";

const standings: PublicStanding[] = [
  {
    position: 1,
    club: "APR FC",
    played: 24,
    goalDifference: 28,
    points: 58,
    form: ["W", "W", "D", "W", "L"],
    highlight: false,
  },
  {
    position: 2,
    club: "Rayon Sports",
    played: 24,
    goalDifference: 23,
    points: 55,
    form: ["W", "D", "W", "W", "W"],
    highlight: true,
  },
  {
    position: 3,
    club: "Police FC",
    played: 24,
    goalDifference: 16,
    points: 48,
    form: ["L", "W", "D"],
    highlight: false,
  },
];

const copy = {
  eyebrow: "League table",
  title: "League table and form.",
  description: "Track Rayon Sports in the confirmed table.",
  fixtureHub: "Fixture hub",
  recentResults: "Recent results",
  positionInRace: "Position in the race",
  highlightedClub: "Highlighted club",
  summaryPoints: ["The full table keeps the race readable."],
  clubsShown: "Clubs shown",
  clubPosition: "Rayon position",
  points: "Points",
  position: "Position",
  club: "Club",
  played: "Played",
  goalDifference: "Goal difference",
  form: "Form",
  recentScorelines: "Recent scorelines",
  upcomingMatches: "Upcoming matches",
};

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderStandings(locale = "en") {
  return render(
    <StandingsSurface
      locale={locale}
      clubName="Rayon"
      copy={copy}
    />,
  );
}

describe("standings helpers", () => {
  it("normalizes, sorts, deduplicates, and bounds public rows", () => {
    const input = [
      ...Array.from({ length: 30 }, (_, index) => ({
        position: 30 - index,
        club: `Club ${index}`,
        played: 20,
        goalDifference: index - 10,
        points: index,
        form: ["w", "D", "bad", "L", "W", "D"],
        highlight: index === 2,
      })),
      {
        position: 30,
        club: "Club 0",
        played: 20,
        goalDifference: 0,
        points: 1,
      },
      { position: 0, club: "Invalid", played: 1, goalDifference: 0, points: 1 },
    ];

    const normalized = normalizeStandings(input);
    expect(normalized).toHaveLength(24);
    expect(normalized.map(({ position }) => position)).toEqual(
      [...normalized.map(({ position }) => position)].sort((a, b) => a - b),
    );
    expect(normalized[0]?.form).toEqual(["W", "D", "L", "W", "D"]);
    expect(new Set(normalized.map(({ club }) => club)).size).toBe(24);
  });

  it("provides all controlled states in every supported locale", () => {
    const expected = [
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
    for (const locale of ["en", "fr-FR", "rw", "sw", "unsupported"]) {
      const localized = resolveStandingsStateCopy(locale);
      expect(Object.keys(localized.status)).toEqual(expected);
      expect(localized.refresh).not.toBe("");
      expect(localized.selected).not.toBe("");
    }
  });
});

describe("StandingsSurface", () => {
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

  it("loads confirmed standings, selects the highlighted club, and supports selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_STANDINGS_READY", items: standings }),
    );

    const { container } = renderStandings();
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-status",
      "loading",
    );
    await screen.findAllByText("Rayon Sports");
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-status",
      "ready",
    );
    expect(
      screen.getByRole("button", { name: /rayon sports/i }),
    ).toHaveAttribute("aria-pressed", "true");
    const police = screen.getByRole("button", { name: /police fc/i });
    fireEvent.click(police);
    expect(police).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-interaction",
      "selected",
    );
  });

  it("renders an explicit confirmed empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_STANDINGS_EMPTY", items: [] }),
    );

    const { container } = renderStandings();
    await screen.findByRole("heading", { name: "No standings listed" });
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Standings access denied"],
    [409, "conflict", "League table changed"],
    [502, "error", "League table unavailable"],
    [504, "security_timeout", "Standings request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing provider diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderStandings();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".standings-surface")).toHaveAttribute(
        "data-standings-status",
        expectedStatus,
      );
      expect(screen.queryByText(/database\.internal/i)).toBeNull();
    },
  );

  it("reports offline before fetching and reloads after reconnect", async () => {
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_STANDINGS_READY", items: standings }),
    );

    const { container } = renderStandings();
    await waitFor(() =>
      expect(container.querySelector(".standings-surface")).toHaveAttribute(
        "data-standings-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Rayon Sports");
  });

  it("retains confirmed rows during syncing and recoverable conflict", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_STANDINGS_READY", items: standings }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderStandings();
    await screen.findAllByText("Rayon Sports");
    fireEvent.click(
      screen.getByRole("button", { name: /refresh standings/i }),
    );
    await waitFor(() =>
      expect(container.querySelector(".standings-surface")).toHaveAttribute(
        "data-standings-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Rayon Sports").length).toBeGreaterThan(0);
    releaseRefresh?.(
      new Response(JSON.stringify({ code: "PUBLIC_STANDINGS_CONFLICT" }), {
        status: 409,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".standings-surface")).toHaveAttribute(
        "data-standings-status",
        "conflict",
      ),
    );
    expect(screen.getAllByText("Rayon Sports").length).toBeGreaterThan(0);
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_STANDINGS_READY", items: standings }),
    );

    const { container } = renderStandings();
    await screen.findAllByText("Rayon Sports");
    const primary = screen.getByRole("link", { name: /fixture hub/i });
    fireEvent.focus(primary);
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-interaction",
      "focused",
    );
    fireEvent.pointerDown(primary);
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-interaction",
      "pressed",
    );
  });

  it("times out at the bounded deadline without assuming standings", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderStandings();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".standings-surface")).toHaveAttribute(
      "data-standings-status",
      "security_timeout",
    );
    expect(screen.queryByText("Rayon Sports")).toBeNull();
  });
});
