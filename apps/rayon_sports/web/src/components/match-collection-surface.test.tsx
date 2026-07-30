import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  filterMatchCollection,
  MatchCollectionSurface,
  resolveMatchCollectionStateCopy,
} from "./match-collection-surface";
import type { PublicFixture } from "./fixtures-surface";

const fixtures: PublicFixture[] = [
  {
    id: "ticket-on-sale",
    homeTeam: "Rayon Sports",
    awayTeam: "APR FC",
    competition: "Premier League",
    venue: "Amahoro Stadium",
    matchDate: "2026-08-02T15:00:00.000Z",
    kickoffTime: "17:00",
    isOnSale: true,
    generalPrice: 5_000,
    matchStatus: "scheduled",
    homeScore: 0,
    awayScore: 0,
    liveMinute: null,
    matchSummary: "Confirmed ticket availability.",
  },
  {
    id: "result-win",
    homeTeam: "Rayon Sports",
    awayTeam: "Police FC",
    competition: "Premier League",
    venue: "Kigali Pelé Stadium",
    matchDate: "2026-07-20T13:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "fulltime",
    homeScore: 3,
    awayScore: 1,
    liveMinute: null,
    matchSummary: "Confirmed home win.",
  },
  {
    id: "result-loss",
    homeTeam: "APR FC",
    awayTeam: "Rayon Sports",
    competition: "Peace Cup",
    venue: "Huye Stadium",
    matchDate: "2026-07-13T13:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "finished",
    homeScore: 2,
    awayScore: 1,
    liveMinute: null,
    matchSummary: "Confirmed away result.",
  },
  {
    id: "future-not-on-sale",
    homeTeam: "Rayon Sports",
    awayTeam: "Mukura VS",
    competition: "Premier League",
    venue: "Amahoro Stadium",
    matchDate: "2026-08-16T15:00:00.000Z",
    kickoffTime: "17:00",
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "scheduled",
    homeScore: 0,
    awayScore: 0,
    liveMinute: null,
    matchSummary: null,
  },
];

const ticketCopy = {
  eyebrow: "Tickets",
  title: "Matchday access.",
  description: "Confirmed public ticket availability.",
  primaryAction: "Continue in fan app",
  secondaryAction: "Unlock priority access",
  selectedLabel: "Matchday essentials",
  viewDetails: "View details",
  emptyTitle: "No tickets are currently on sale.",
  emptyDetail: "Return later for confirmed matchday availability.",
  supportingTitle: "Buy with confidence",
  supportingPoints: ["Confirmed prices", "Secure fan app handoff"],
};

const resultCopy = {
  eyebrow: "Results",
  title: "Confirmed results.",
  description: "The latest public scoreline record.",
  primaryAction: "Back to fixtures",
  secondaryAction: "League table",
  selectedLabel: "Recent form",
  viewDetails: "View details",
  emptyTitle: "No completed results are confirmed yet.",
  emptyDetail: "Return later for the confirmed public scoreline record.",
  supportingTitle: "Results with context",
  supportingPoints: ["Confirmed scores", "Public match summaries"],
};

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderCollection(mode: "tickets" | "results", locale = "en") {
  return render(
    <MatchCollectionSurface
      mode={mode}
      locale={locale}
      currencyCode="RWF"
      clubName="Rayon"
      copy={mode === "tickets" ? ticketCopy : resultCopy}
    />,
  );
}

describe("match collection helpers", () => {
  it("separates ticket availability from completed results", () => {
    expect(filterMatchCollection(fixtures, "tickets").map(({ id }) => id)).toEqual([
      "ticket-on-sale",
    ]);
    expect(filterMatchCollection(fixtures, "results").map(({ id }) => id)).toEqual([
      "result-win",
      "result-loss",
    ]);
  });

  it("provides every controlled state in each supported locale", () => {
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
      expect(Object.keys(resolveMatchCollectionStateCopy(locale).status)).toEqual(
        expected,
      );
      expect(resolveMatchCollectionStateCopy(locale).refresh).not.toBe("");
    }
  });
});

describe("MatchCollectionSurface", () => {
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

  it("renders only confirmed ticket inventory with its price and detail route", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
    );

    const { container } = renderCollection("tickets");
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-status",
      "loading",
    );
    await screen.findAllByText("Rayon Sports vs APR FC");
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-status",
      "ready",
    );
    expect(screen.getAllByText(/RWF\s*5,000/)).toHaveLength(2);
    expect(screen.queryByText("Rayon Sports vs Police FC")).toBeNull();
    expect(screen.getByRole("link", { name: /view details/i })).toHaveAttribute(
      "href",
      "/tickets/ticket-on-sale",
    );
  });

  it("renders completed results, aggregate form, and selected scoreline", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
    );

    const { container } = renderCollection("results");
    await screen.findAllByText("Rayon Sports vs Police FC");
    expect(screen.getAllByText("3–1")).toHaveLength(2);
    expect(screen.getByText("4")).toBeInTheDocument();
    const loss = screen.getByRole("button", {
      name: /peace cup\s*apr fc vs rayon sports/i,
    });
    fireEvent.click(loss);
    expect(loss).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-interaction",
      "selected",
    );
    expect(screen.getByRole("link", { name: /view details/i })).toHaveAttribute(
      "href",
      "/fixtures/result-loss",
    );
  });

  it("renders an explicit filtered empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, {
        code: "PUBLIC_FIXTURES_READY",
        items: [fixtures[3]],
      }),
    );

    const { container } = renderCollection("tickets");
    await screen.findByRole("heading", {
      name: "No tickets are currently on sale.",
    });
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Match access denied"],
    [409, "conflict", "Match information changed"],
    [502, "error", "Match information unavailable"],
    [504, "security_timeout", "Match request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing raw diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderCollection("tickets");
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
        "data-collection-status",
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
      response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
    );

    const { container } = renderCollection("tickets");
    await waitFor(() =>
      expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
        "data-collection-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Rayon Sports vs APR FC");
  });

  it("retains confirmed data during syncing and a recoverable conflict", async () => {
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

    const { container } = renderCollection("tickets");
    await screen.findAllByText("Rayon Sports vs APR FC");
    fireEvent.click(screen.getByRole("button", { name: /refresh matches/i }));
    await waitFor(() =>
      expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
        "data-collection-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Rayon Sports vs APR FC").length).toBeGreaterThan(0);
    releaseRefresh?.(
      new Response(JSON.stringify({ code: "PUBLIC_FIXTURES_CONFLICT" }), {
        status: 409,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
        "data-collection-status",
        "conflict",
      ),
    );
    expect(screen.getAllByText("Rayon Sports vs APR FC").length).toBeGreaterThan(0);
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURES_READY", items: fixtures }),
    );

    const { container } = renderCollection("tickets");
    await screen.findAllByText("Rayon Sports vs APR FC");
    const primary = screen.getByRole("link", { name: /continue in fan app/i });
    fireEvent.focus(primary);
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-interaction",
      "focused",
    );
    fireEvent.pointerDown(primary);
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-interaction",
      "pressed",
    );
  });

  it("times out at the bounded deadline without assuming content", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderCollection("results");
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".match-collection-surface")).toHaveAttribute(
      "data-collection-status",
      "security_timeout",
    );
    expect(screen.queryByText("Rayon Sports vs Police FC")).toBeNull();
  });
});
