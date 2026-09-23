import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import {
  CirclesSurface,
  normalizeCirclesSnapshot,
  resolveCirclesCopy,
  resolveFanClubsCopy,
  type PublicChapter,
  type PublicCircle,
} from "./circles-surface";

const groups: PublicCircle[] = [
  {
    id: "circle-tifo",
    name: "Blue wall tifo",
    description: "A confirmed campaign for matchday choreography.",
    groupType: "project",
    targetAmount: 5_000_000,
    currentTotal: 2_500_000,
    currency: "RWF",
    memberCount: 240,
  },
  {
    id: "circle-community",
    name: "Community kit drive",
    description: "A confirmed community equipment campaign.",
    groupType: "community",
    targetAmount: 2_000_000,
    currentTotal: 800_000,
    currency: "RWF",
    memberCount: 120,
  },
];

const chapters: PublicChapter[] = [
  {
    id: "chapter-kigali",
    name: "Kigali Blue Family",
    region: "Kigali",
    description: "An official public supporter FanClubs.",
    memberCount: 900,
    eventCount: 12,
  },
  {
    id: "chapter-huye",
    name: "Huye Gikundiro",
    region: "Southern Province",
    description: "An official public supporter FanClubs.",
    memberCount: 320,
    eventCount: 6,
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

function readyResponse() {
  return response(200, {
    code: "PUBLIC_CIRCLES_READY",
    groups,
    chapters,
  });
}

function renderCircles(locale = "en") {
  return render(
    <CirclesSurface
      locale={locale}
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
    />,
  );
}

describe("circles helpers", () => {
  it("bounds, validates, and deduplicates public campaigns and FanClubs", () => {
    const normalized = normalizeCirclesSnapshot({
      groups: [
        ...Array.from({ length: 10 }, (_, index) => ({
          id: `circle-${index}`,
          name: `Campaign ${index}`,
          description: `Confirmed campaign ${index}.`,
          groupType: index % 2 === 0 ? "project" : "community",
          targetAmount: 1_000_000,
          currentTotal: 500_000,
          currency: "RWF",
          memberCount: 100,
          contributorIds: ["private"],
        })),
        {
          id: "circle-0",
          name: "Duplicate",
          description: "Duplicate",
          groupType: "project",
          targetAmount: 1,
          currentTotal: 1,
          currency: "RWF",
          memberCount: 1,
        },
        {
          id: "unsafe",
          name: "Unsafe",
          description: "Unsafe",
          groupType: "project",
          targetAmount: 0,
          currentTotal: 1,
          currency: "RWF",
          memberCount: 1,
        },
      ],
      chapters: [
        ...Array.from({ length: 14 }, (_, index) => ({
          id: `chapter-${index}`,
          name: `FanClubs ${index}`,
          region: "Kigali",
          description: "Official FanClubs.",
          memberCount: 20,
          eventCount: 2,
          moderatorContact: "private",
        })),
        {
          id: "chapter-0",
          name: "Duplicate",
          region: "Private",
          description: "Duplicate",
          memberCount: 1,
          eventCount: 1,
        },
      ],
    });

    expect(normalized.groups).toHaveLength(8);
    expect(normalized.chapters).toHaveLength(12);
    expect(normalized.groups[0]).not.toHaveProperty("contributorIds");
    expect(normalized.chapters[0]).not.toHaveProperty("moderatorContact");
    expect(normalized.groups.some(({ id }) => id === "unsafe")).toBe(false);
  });

  it("resolves all supported locales and falls back to English", () => {
    expect(resolveCirclesCopy("en").refresh).toBe("Refresh circles");
    expect(resolveCirclesCopy("en").campaigns).toBe("Campaigns");
    expect(resolveCirclesCopy("en").chapters).toBe("fan clubs");
    expect(resolveCirclesCopy("unknown").refresh).toBe("Refresh circles");
    expect(resolveFanClubsCopy("en").refresh).toBe(
      "Refresh fan clubs",
    );
    expect(resolveFanClubsCopy("en").chapters).toBe("fan clubs");
    expect(resolveFanClubsCopy("en").title("Rayon")).toContain("fan clubs");
    expect(resolveFanClubsCopy("unknown").refresh).toBe("Refresh fan clubs");
  });
});

describe("CirclesSurface", () => {
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
    window.history.replaceState(null, "", window.location.pathname);
  });

  it("renders each project once with totals, participants, progress, and inline detail", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderCircles();

    await screen.findByRole("heading", { name: "Blue wall tifo" });
    expect(container.querySelector(".circles-surface")).toHaveAttribute(
      "data-circles-status",
      "ready",
    );
    expect(screen.queryByText("Kigali Blue Family")).not.toBeInTheDocument();
    expect(screen.getByRole("progressbar", { name: "Blue wall tifo Progress" })).toHaveAttribute(
      "aria-valuenow",
      "50",
    );
    fireEvent.click(
      screen.getByRole("button", { name: /community kit drive/i }),
    );
    expect(
      screen.getByRole("button", { name: /community kit drive/i }),
    ).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".circles-surface")).toHaveAttribute(
      "data-circles-interaction",
      "selected",
    );
    expect(screen.getByRole("progressbar", { name: "Community kit drive Progress" })).toHaveAttribute(
      "aria-valuenow",
      "40",
    );
    expect(screen.getAllByText("Community kit drive").length).toBe(1);
  });

  it("renders the fan-club variant and requests the dedicated controlled resource", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(readyResponse);
    render(
      <CirclesSurface
        locale="en"
        clubShortName="Rayon Sports"
        fanAppHref="/supporters"
        hasExternalAppUrl={false}
        variant="fan-clubs"
      />,
    );

    await screen.findByRole("heading", {
      name: "Rayon Sports official fan clubs",
    });
    expect(screen.getByText("Official fan-club directory")).toBeInTheDocument();
    expect(fetchSpy).toHaveBeenCalledWith(
      "/api/public-content?resource=fan-clubs",
      expect.objectContaining({ cache: "no-store" }),
    );
  });

  it("reveals a shared fan club after the directory loads", async () => {
    const scrollIntoView = vi.fn();
    Object.defineProperty(Element.prototype, "scrollIntoView", { configurable: true, value: scrollIntoView });
    window.history.replaceState(null, "", "#fan-club-chapter-huye");
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    render(<CirclesSurface locale="en" clubShortName="Rayon Sports" fanAppHref="/supporters" hasExternalAppUrl={false} variant="fan-clubs" />);
    await screen.findByText("Huye Gikundiro");
    await waitFor(() => expect(scrollIntoView).toHaveBeenCalledWith({ block: "center", behavior: "instant" }));
    expect(document.getElementById("fan-club-chapter-huye")).toHaveTextContent("Huye Gikundiro");
  });

  it("renders the controlled empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, {
        code: "PUBLIC_CIRCLES_EMPTY",
        groups: [],
        chapters: [],
      }),
    );
    const { container } = renderCircles();

    await screen.findByRole("heading", { name: "No public campaigns listed" });
    expect(container.querySelector(".circles-surface")).toHaveAttribute(
      "data-circles-status",
      "empty",
    );
    expect(
      screen.queryByRole("heading", { name: "No public FanClubs listed" }),
    ).not.toBeInTheDocument();
  });

  it.each([
    [403, "permission_denied", "Support-circle access denied"],
    [409, "conflict", "Support circles changed"],
    [502, "error", "Support circles unavailable"],
    [504, "security_timeout", "Support-circle request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing provider diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderCircles();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".circles-surface")).toHaveAttribute(
        "data-circles-status",
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
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(readyResponse);
    const { container } = renderCircles();

    await waitFor(() =>
      expect(container.querySelector(".circles-surface")).toHaveAttribute(
        "data-circles-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Blue wall tifo");
  });

  it("retains confirmed data during syncing and recoverable conflict", async () => {
    let releaseRefresh:
      ((value: Response | PromiseLike<Response>) => void) | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderCircles();
    await screen.findAllByText("Blue wall tifo");
    fireEvent.click(screen.getByRole("button", { name: /refresh circles/i }));
    await waitFor(() =>
      expect(container.querySelector(".circles-surface")).toHaveAttribute(
        "data-circles-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Blue wall tifo").length).toBeGreaterThan(0);
    expect(screen.queryByText("Kigali Blue Family")).not.toBeInTheDocument();
    releaseRefresh?.(
      new Response(JSON.stringify({ code: "PUBLIC_CIRCLES_CONFLICT" }), {
        status: 409,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".circles-surface")).toHaveAttribute(
        "data-circles-status",
        "conflict",
      ),
    );
    expect(screen.queryByText("Kigali Blue Family")).not.toBeInTheDocument();
  });

  it("clears previously confirmed public data when access is denied", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockImplementationOnce(() =>
        response(403, { code: "PUBLIC_CIRCLES_ACCESS_DENIED" }),
      );

    const { container } = renderCircles();
    await screen.findAllByText("Blue wall tifo");
    fireEvent.click(screen.getByRole("button", { name: /refresh circles/i }));
    await waitFor(() =>
      expect(container.querySelector(".circles-surface")).toHaveAttribute(
        "data-circles-status",
        "permission_denied",
      ),
    );
    expect(screen.queryByText("Kigali Blue Family")).toBeNull();
    expect(
      screen.queryByRole("button", { name: /blue wall tifo/i }),
    ).toBeNull();
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderCircles();
    await screen.findAllByText("Blue wall tifo");

    const primary = screen.getAllByRole("link", {
      name: /app links coming soon/i,
    })[0];
    fireEvent.focus(primary);
    expect(container.querySelector(".circles-surface")).toHaveAttribute(
      "data-circles-interaction",
      "focused",
    );
    fireEvent.pointerDown(primary);
    expect(container.querySelector(".circles-surface")).toHaveAttribute(
      "data-circles-interaction",
      "pressed",
    );
  });

  it("times out at the bounded deadline without assuming public data", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    const { container } = renderCircles();

    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".circles-surface")).toHaveAttribute(
      "data-circles-status",
      "security_timeout",
    );
    expect(screen.queryByText("Kigali Blue Family")).toBeNull();
  });
});
