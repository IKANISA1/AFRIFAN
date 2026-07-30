import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  normalizeVenues,
  resolveVenuesCopy,
  VenuesSurface,
  type PublicVenue,
} from "./venues-surface";

const venues: PublicVenue[] = [
  {
    id: "venue-kimironko",
    displayName: "Kimironko Matchday House",
    slug: "kimironko-matchday-house",
    city: "Kigali",
    summary: "An approved public profile for supporter matchday discovery.",
  },
  {
    id: "venue-musanze",
    displayName: "Musanze Blue Corner",
    slug: "musanze-blue-corner",
    city: "Musanze",
    summary: "An approved northern partner profile.",
  },
  {
    id: "venue-nyamirambo",
    displayName: "Nyamirambo Club Lounge",
    slug: "nyamirambo-club-lounge",
    city: "Kigali",
    summary: "An approved public profile near the matchday route.",
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

function renderVenues(locale = "en") {
  return render(
    <VenuesSurface
      locale={locale}
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
    />,
  );
}

describe("venues helpers", () => {
  it("normalizes, bounds, sorts, and deduplicates public venue profiles", () => {
    const input = [
      ...Array.from({ length: 14 }, (_, index) => ({
        id: `venue-${index}`,
        displayName: `Venue ${index}`,
        slug: `venue-${index}`,
        city: index % 2 === 0 ? "Musanze" : "Kigali",
        summary: `Approved public venue ${index}.`,
        preciseCoordinates: "-1.0,30.0",
      })),
      {
        id: "venue-1",
        displayName: "Duplicate identity",
        slug: "duplicate-identity",
        city: "Kigali",
        summary: "Duplicate.",
      },
      {
        id: "invalid",
        displayName: "",
        slug: "invalid",
        city: "Kigali",
        summary: "Invalid.",
      },
    ];

    const normalized = normalizeVenues(input);
    expect(normalized).toHaveLength(12);
    expect(new Set(normalized.map(({ id }) => id)).size).toBe(12);
    expect(new Set(normalized.map(({ slug }) => slug)).size).toBe(12);
    expect(normalized[0].city).toBe("Kigali");
    expect(normalized[0]).not.toHaveProperty("preciseCoordinates");
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
      const localized = resolveVenuesCopy(locale);
      expect(Object.keys(localized.status)).toEqual(expected);
      expect(localized.refresh).not.toBe("");
      expect(localized.privacyDetail).not.toBe("");
    }
  });
});

describe("VenuesSurface", () => {
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

  it("loads confirmed profiles and supports real venue selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_VENUES_READY", items: venues }),
    );

    const { container } = renderVenues();
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-status",
      "loading",
    );
    await screen.findAllByText("Kimironko Matchday House");
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-status",
      "ready",
    );
    const musanze = screen.getByRole("button", { name: /musanze blue corner/i });
    fireEvent.click(musanze);
    expect(musanze).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-interaction",
      "selected",
    );
    expect(screen.getAllByText("Musanze").length).toBeGreaterThan(0);
  });

  it("renders a confirmed empty directory without implying provider failure", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_VENUES_EMPTY", items: [] }),
    );

    const { container } = renderVenues();
    await screen.findByRole("heading", {
      name: "No approved venues listed",
    });
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Venue access denied"],
    [409, "conflict", "Venue directory changed"],
    [502, "error", "Venue directory unavailable"],
    [504, "security_timeout", "Venue request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing provider diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderVenues();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".venues-surface")).toHaveAttribute(
        "data-venues-status",
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
      response(200, { code: "PUBLIC_VENUES_READY", items: venues }),
    );

    const { container } = renderVenues();
    await waitFor(() =>
      expect(container.querySelector(".venues-surface")).toHaveAttribute(
        "data-venues-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Kimironko Matchday House");
  });

  it("retains confirmed profiles during syncing and recoverable conflict", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_VENUES_READY", items: venues }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderVenues();
    await screen.findAllByText("Kimironko Matchday House");
    fireEvent.click(screen.getByRole("button", { name: /refresh venues/i }));
    await waitFor(() =>
      expect(container.querySelector(".venues-surface")).toHaveAttribute(
        "data-venues-status",
        "syncing",
      ),
    );
    expect(
      screen.getAllByText("Kimironko Matchday House").length,
    ).toBeGreaterThan(0);
    releaseRefresh?.(
      new Response(JSON.stringify({ code: "PUBLIC_VENUES_CONFLICT" }), {
        status: 409,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".venues-surface")).toHaveAttribute(
        "data-venues-status",
        "conflict",
      ),
    );
    expect(
      screen.getAllByText("Kimironko Matchday House").length,
    ).toBeGreaterThan(0);
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_VENUES_READY", items: venues }),
    );

    const { container } = renderVenues();
    await screen.findAllByText("Kimironko Matchday House");
    const primary = screen.getAllByRole("link", {
      name: /app links coming soon/i,
    })[0];
    fireEvent.focus(primary);
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-interaction",
      "focused",
    );
    fireEvent.pointerDown(primary);
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-interaction",
      "pressed",
    );
  });

  it("times out at the bounded deadline without assuming a venue", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderVenues();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".venues-surface")).toHaveAttribute(
      "data-venues-status",
      "security_timeout",
    );
    expect(screen.queryByText("Kimironko Matchday House")).toBeNull();
  });
});
