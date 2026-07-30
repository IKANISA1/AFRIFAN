import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import {
  HomeSurface,
  normalizeHomeSnapshot,
  resolveHomeCopy,
  type PublicHomeSnapshot,
} from "./home-surface";

const snapshot: PublicHomeSnapshot = {
  matches: [
    {
      id: "opening-day",
      homeTeam: "Rayon Sports",
      awayTeam: "APR FC",
      competition: "Premier League",
      venue: "Amahoro Stadium",
      matchDate: "2026-08-02T15:00:00.000Z",
      kickoffTime: "17:00",
      matchStatus: "scheduled",
    },
  ],
  news: [
    {
      id: "club-update",
      title: "Confirmed club update",
      excerpt: "A confirmed public update for supporters.",
      category: "Club",
      publishedAt: "2026-07-29T12:00:00.000Z",
      author: "Club Media",
    },
  ],
  products: [
    {
      id: "home-shirt",
      name: "Home shirt",
      subtitle: "Official confirmed home shirt.",
      category: "Jerseys",
      price: 35_000,
      isAvailable: true,
    },
  ],
  memberships: [
    {
      id: "bronze",
      tier: "bronze",
      title: "Bronze",
      description: "Confirmed public membership tier.",
      annualPrice: 10_000,
      perks: ["Ticket priority"],
    },
  ],
};

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function readyHome() {
  return response(200, { code: "PUBLIC_HOME_READY", ...snapshot });
}

function renderHome(locale = "en") {
  return render(
    <HomeSurface
      locale={locale}
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
    />,
  );
}

describe("home helpers", () => {
  it("bounds, validates, deduplicates, and strips private fields", () => {
    const normalized = normalizeHomeSnapshot({
      matches: [
        ...snapshot.matches,
        snapshot.matches[0],
        { id: "", privateLineup: "private" },
      ],
      news: [...snapshot.news, { id: "unsafe", title: "" }],
      products: [
        ...snapshot.products,
        { ...snapshot.products[0], id: "unsafe", price: -1 },
      ],
      memberships: [
        ...snapshot.memberships,
        { ...snapshot.memberships[0], id: "unsafe", perks: [] },
      ],
      supporterId: "private-user",
      paymentReference: "private-payment",
    });
    expect(normalized.matches).toHaveLength(1);
    expect(normalized.news).toHaveLength(1);
    expect(normalized.products).toHaveLength(1);
    expect(normalized.memberships).toHaveLength(1);
    expect(normalized).not.toHaveProperty("supporterId");
    expect(JSON.stringify(normalized)).not.toContain("private");
  });

  it("provides draft state parity and English fallback", () => {
    expect(resolveHomeCopy("fr-FR").refresh).toBe(
      "Actualiser les temps forts",
    );
    expect(resolveHomeCopy("rw").fixtures).toBe("Imikino");
    expect(resolveHomeCopy("sw").tickets).toBe("Tiketi");
    expect(resolveHomeCopy("unknown").refresh).toBe("Refresh highlights");
  });
});

describe("HomeSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  afterEach(() => vi.useRealTimers());

  it("renders confirmed highlights and supports real action selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyHome);
    const { container } = renderHome();
    await screen.findByText("Confirmed club update");
    expect(container.querySelector(".home-surface")).toHaveAttribute(
      "data-home-status",
      "ready",
    );
    const shop = screen.getByRole("button", { name: "Shop preview" });
    fireEvent.click(shop);
    expect(shop).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".home-surface")).toHaveAttribute(
      "data-home-interaction",
      "selected",
    );
    expect(
      screen.getByRole("link", { name: /open selected: shop preview/i }),
    ).toHaveAttribute("href", "/shop");
  });

  it("renders the controlled empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, {
        code: "PUBLIC_HOME_EMPTY",
        matches: [],
        news: [],
        products: [],
        memberships: [],
      }),
    );
    const { container } = renderHome();
    await screen.findByRole("heading", { name: "No public highlights" });
    expect(container.querySelector(".home-surface")).toHaveAttribute(
      "data-home-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Home access denied"],
    [409, "conflict", "Club highlights changed"],
    [502, "error", "Club home unavailable"],
    [504, "security_timeout", "Home request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, { error: "database.internal password=private" }),
      );
      const { container } = renderHome();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".home-surface")).toHaveAttribute(
        "data-home-status",
        expectedStatus,
      );
      expect(screen.queryByText(/database\.internal/i)).toBeNull();
    },
  );

  it("retains confirmed highlights during syncing and conflict", async () => {
    let release:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyHome)
      .mockImplementationOnce(
        () => new Promise<Response>((resolve) => (release = resolve)),
      );
    const { container } = renderHome();
    await screen.findByText("Confirmed club update");
    fireEvent.click(screen.getByRole("button", { name: /refresh highlights/i }));
    await waitFor(() =>
      expect(container.querySelector(".home-surface")).toHaveAttribute(
        "data-home-status",
        "syncing",
      ),
    );
    expect(screen.getByText("Confirmed club update")).toBeVisible();
    release?.(
      new Response(JSON.stringify({ code: "PUBLIC_HOME_CONFLICT" }), {
        status: 409,
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".home-surface")).toHaveAttribute(
        "data-home-status",
        "conflict",
      ),
    );
    expect(screen.getByText("Confirmed club update")).toBeVisible();
  });

  it("clears confirmed highlights when access is denied", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyHome)
      .mockImplementationOnce(() =>
        response(403, { code: "PUBLIC_HOME_ACCESS_DENIED" }),
      );
    const { container } = renderHome();
    await screen.findByText("Confirmed club update");
    fireEvent.click(screen.getByRole("button", { name: /refresh highlights/i }));
    await waitFor(() =>
      expect(container.querySelector(".home-surface")).toHaveAttribute(
        "data-home-status",
        "permission_denied",
      ),
    );
    expect(screen.queryByText("Confirmed club update")).toBeNull();
  });

  it("records real focus and held-pointer states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyHome);
    const { container } = renderHome();
    await screen.findByText("Confirmed club update");
    const refresh = screen.getByRole("button", { name: /refresh highlights/i });
    fireEvent.focus(refresh);
    expect(container.querySelector(".home-surface")).toHaveAttribute(
      "data-home-interaction",
      "focused",
    );
    fireEvent.pointerDown(refresh);
    expect(container.querySelector(".home-surface")).toHaveAttribute(
      "data-home-interaction",
      "pressed",
    );
  });

  it("times out without assuming a protected action", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    const { container } = renderHome();
    await act(async () => vi.advanceTimersByTimeAsync(8_000));
    expect(container.querySelector(".home-surface")).toHaveAttribute(
      "data-home-status",
      "security_timeout",
    );
    expect(screen.queryByText("Confirmed club update")).toBeNull();
  });
});
