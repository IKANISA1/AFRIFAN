import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  filterSearchItems,
  isSafeSearchHref,
  normalizeSearchIndexItems,
  resolveSearchFailureStatus,
  resolveSearchPageStateCopy,
  SearchPageClient,
} from "./search-page-client";
import type { SearchIndexItem } from "@/lib/types";

const copy = {
  search: "Search",
  title: "Find it fast.",
  intro: "Fixtures, news, membership, and club information.",
  placeholder: "Search the club",
  noResults: "No results",
  trySearchHint: "Try fixtures, tickets, or membership.",
};

const items: SearchIndexItem[] = [
  {
    id: "fixture-1",
    title: "Next fixture",
    description: "See the next league match.",
    href: "/fixtures",
    category: "Match",
    meta: "Saturday",
  },
  {
    id: "membership-1",
    title: "Membership",
    description: "Compare supporter tiers.",
    href: "/membership",
    category: "Membership",
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

describe("search page state helpers", () => {
  it("accepts only bounded, unique, same-origin search results", () => {
    expect(isSafeSearchHref("/fixtures?q=next")).toBe(true);
    expect(isSafeSearchHref("//attacker.example/path")).toBe(false);
    expect(isSafeSearchHref("/\\attacker.example/path")).toBe(false);
    expect(isSafeSearchHref("javascript:alert(1)")).toBe(false);

    expect(
      normalizeSearchIndexItems([
        items[0],
        items[0],
        { ...items[1], href: "https://attacker.example" },
        { ...items[1], id: "membership-safe" },
        { ...items[1], id: "wrong-category", category: "Private" },
      ]),
    ).toEqual([items[0], { ...items[1], id: "membership-safe" }]);
  });

  it("filters confirmed results without mutating them", () => {
    expect(filterSearchItems(items, "supporter")).toEqual([items[1]]);
    expect(filterSearchItems(items, "missing")).toEqual([]);
    expect(filterSearchItems(items, "")).toEqual(items);
  });

  it("maps controlled failures without exposing response details", () => {
    expect(resolveSearchFailureStatus(403)).toBe("permission_denied");
    expect(resolveSearchFailureStatus(409)).toBe("conflict");
    expect(resolveSearchFailureStatus(504)).toBe("security_timeout");
    expect(resolveSearchFailureStatus(502)).toBe("error");
  });

  it("provides a complete state vocabulary for every supported locale", () => {
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

    for (const locale of ["en", "fr-FR", "rw", "sw", "unsupported"]) {
      expect(Object.keys(resolveSearchPageStateCopy(locale).status)).toEqual(
        expectedStates,
      );
      expect(resolveSearchPageStateCopy(locale).suggestionValues).toHaveLength(3);
    }
  });
});

describe("SearchPageClient", () => {
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

  it("moves from loading to a confirmed, filterable result set", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "SEARCH_INDEX_READY", items }),
    );

    const { container } = render(
      <SearchPageClient initialQuery="" locale="en" copy={copy} />,
    );

    expect(
      container.querySelector("[data-search-page-status]"),
    ).toHaveAttribute("data-search-page-status", "loading");
    expect(screen.getByRole("button", { name: /refresh results/i })).toBeDisabled();

    await screen.findByRole("heading", { name: "Next fixture" });
    expect(
      container.querySelector("[data-search-page-status]"),
    ).toHaveAttribute("data-search-page-status", "ready");

    fireEvent.change(screen.getByRole("searchbox"), {
      target: { value: "supporter" },
    });
    expect(
      screen.getByRole("heading", { name: "Membership" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Next fixture" }),
    ).not.toBeInTheDocument();
  });

  it.each([
    [403, "permission_denied", /search access denied/i],
    [409, "conflict", /search index changed/i],
    [504, "security_timeout", /search timed out/i],
    [502, "error", /search unavailable/i],
  ])(
    "renders the controlled %s response as %s",
    async (httpStatus, expectedStatus, label) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          code: "SANITIZED_FAILURE",
          error: "Safe public message.",
        }),
      );

      const { container } = render(
        <SearchPageClient initialQuery="" locale="en" copy={copy} />,
      );

      await screen.findAllByText(label);
      expect(
        container.querySelector("[data-search-page-status]"),
      ).toHaveAttribute("data-search-page-status", expectedStatus);
      expect(container).not.toHaveTextContent("SANITIZED_FAILURE");
    },
  );

  it("retains confirmed results during a disabled syncing state", async () => {
    let releaseRefresh: ((value: Response) => void) | undefined;
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "SEARCH_INDEX_READY", items }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = render(
      <SearchPageClient initialQuery="" locale="en" copy={copy} />,
    );
    await screen.findByRole("heading", { name: "Next fixture" });

    fireEvent.click(screen.getByRole("button", { name: /refresh results/i }));

    await waitFor(() =>
      expect(
        container.querySelector("[data-search-page-status]"),
      ).toHaveAttribute("data-search-page-status", "syncing"),
    );
    expect(screen.getByRole("heading", { name: "Next fixture" })).toBeVisible();
    expect(screen.getByRole("button", { name: /refresh results/i })).toBeDisabled();
    expect(fetchMock).toHaveBeenCalledTimes(2);

    await act(async () => {
      releaseRefresh?.(
        new Response(
          JSON.stringify({ code: "SEARCH_INDEX_READY", items }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    });
  });

  it("exposes focus and selected suggestion states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "SEARCH_INDEX_READY", items }),
    );
    const { container } = render(
      <SearchPageClient initialQuery="" locale="en" copy={copy} />,
    );
    await screen.findByRole("heading", { name: "Next fixture" });

    fireEvent.focus(screen.getByRole("searchbox"));
    expect(
      container.querySelector("[data-search-interaction]"),
    ).toHaveAttribute("data-search-interaction", "focused");

    fireEvent.click(screen.getByRole("button", { name: "Membership" }));
    expect(
      screen.getByRole("button", { name: "Membership" }),
    ).toHaveAttribute("aria-pressed", "true");
    expect(
      container.querySelector("[data-search-interaction]"),
    ).toHaveAttribute("data-search-interaction", "selected");
  });

  it("shows offline immediately and refreshes after reconnecting", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "SEARCH_INDEX_READY", items }),
    );
    const { container } = render(
      <SearchPageClient initialQuery="" locale="en" copy={copy} />,
    );
    await screen.findByRole("heading", { name: "Next fixture" });

    act(() => window.dispatchEvent(new Event("offline")));
    expect(
      container.querySelector("[data-search-page-status]"),
    ).toHaveAttribute("data-search-page-status", "offline");
    expect(screen.getByRole("heading", { name: "Next fixture" })).toBeVisible();
  });

  it("bounds a stalled browser request with a security timeout", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            reject(new DOMException("Aborted", "AbortError"));
          });
        }),
    );

    const { container } = render(
      <SearchPageClient initialQuery="" locale="en" copy={copy} />,
    );
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });

    expect(
      container.querySelector("[data-search-page-status]"),
    ).toHaveAttribute("data-search-page-status", "security_timeout");
    expect(container).not.toHaveTextContent("Aborted");
  });
});
