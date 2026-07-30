import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import {
  MembershipSurface,
  normalizeMembershipSnapshot,
  resolveMembershipCopy,
  type PublicMembershipTier,
} from "./membership-surface";

const packages: PublicMembershipTier[] = [
  {
    id: "bronze",
    tier: "bronze",
    title: "Blue Bronze",
    description: "Confirmed entry membership.",
    sortOrder: 1,
    annualPrice: 10_000,
    perks: ["Ticket priority", "Club updates"],
  },
  {
    id: "gold",
    tier: "gold",
    title: "Blue Gold",
    description: "Confirmed premium membership.",
    sortOrder: 2,
    annualPrice: 50_000,
    perks: ["Priority access", "Member events"],
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
  return response(200, { code: "PUBLIC_MEMBERSHIP_READY", packages });
}

function renderMembership(locale = "en") {
  return render(
    <MembershipSurface
      locale={locale}
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
    />,
  );
}

describe("membership helpers", () => {
  it("bounds, validates, sorts, and deduplicates public tiers", () => {
    const normalized = normalizeMembershipSnapshot({
      packages: [
        ...Array.from({ length: 8 }, (_, index) => ({
          id: `tier-${index}`,
          tier: [
            "bronze",
            "silver",
            "gold",
            "imena",
            "inyamibwa",
            "ingenzi-imanzi",
          ][index % 6],
          title: `Tier ${index}`,
          description: "Confirmed tier.",
          sortOrder: 7 - index,
          annualPrice: 10_000,
          perks: ["Benefit"],
          applicantId: "private",
        })),
        {
          id: "unsafe",
          tier: "private",
          title: "Unsafe",
          description: "Unsafe",
          sortOrder: 0,
          annualPrice: -1,
          perks: [],
        },
      ],
    });
    expect(normalized).toHaveLength(6);
    expect(normalized[0].sortOrder).toBeLessThan(normalized[1].sortOrder);
    expect(normalized[0]).not.toHaveProperty("applicantId");
    expect(normalized.some(({ id }) => id === "unsafe")).toBe(false);
  });

  it("provides draft state parity and English fallback", () => {
    expect(resolveMembershipCopy("fr-FR").refresh).toBe(
      "Actualiser les formules",
    );
    expect(resolveMembershipCopy("rw").tiers).toBe("Ibyiciro");
    expect(resolveMembershipCopy("sw").paidPlans).toBe("Mipango ya malipo");
    expect(resolveMembershipCopy("unknown").refresh).toBe("Refresh tiers");
  });
});

describe("MembershipSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  afterEach(() => vi.useRealTimers());

  it("renders confirmed tiers, benefits, and real selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderMembership();
    await screen.findAllByText("Blue Bronze");
    expect(container.querySelector(".membership-surface")).toHaveAttribute(
      "data-membership-status",
      "ready",
    );
    fireEvent.click(screen.getByRole("button", { name: /blue gold/i }));
    expect(screen.getByRole("button", { name: /blue gold/i })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(screen.getAllByText("Blue Gold").length).toBeGreaterThan(1);
    expect(screen.getByText("Member events")).toBeInTheDocument();
  });

  it("renders the controlled empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_MEMBERSHIP_EMPTY", packages: [] }),
    );
    const { container } = renderMembership();
    await screen.findByRole("heading", {
      name: "No public membership tiers",
    });
    expect(container.querySelector(".membership-surface")).toHaveAttribute(
      "data-membership-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Membership access denied"],
    [409, "conflict", "Membership catalog changed"],
    [502, "error", "Membership catalog unavailable"],
    [504, "security_timeout", "Membership request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, { error: "database.internal password=private" }),
      );
      const { container } = renderMembership();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".membership-surface")).toHaveAttribute(
        "data-membership-status",
        expectedStatus,
      );
      expect(screen.queryByText(/database\.internal/i)).toBeNull();
    },
  );

  it("retains confirmed tiers during syncing and conflict", async () => {
    let release:
      ((value: Response | PromiseLike<Response>) => void) | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockImplementationOnce(
        () => new Promise<Response>((resolve) => (release = resolve)),
      );
    const { container } = renderMembership();
    await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: /refresh tiers/i }));
    await waitFor(() =>
      expect(container.querySelector(".membership-surface")).toHaveAttribute(
        "data-membership-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Blue Bronze").length).toBeGreaterThan(0);
    release?.(
      new Response(JSON.stringify({ code: "PUBLIC_MEMBERSHIP_CONFLICT" }), {
        status: 409,
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".membership-surface")).toHaveAttribute(
        "data-membership-status",
        "conflict",
      ),
    );
    expect(screen.getAllByText("Blue Bronze").length).toBeGreaterThan(0);
  });

  it("clears confirmed tiers when access is denied", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockImplementationOnce(() =>
        response(403, { code: "PUBLIC_MEMBERSHIP_ACCESS_DENIED" }),
      );
    const { container } = renderMembership();
    await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: /refresh tiers/i }));
    await waitFor(() =>
      expect(container.querySelector(".membership-surface")).toHaveAttribute(
        "data-membership-status",
        "permission_denied",
      ),
    );
    expect(screen.queryByText("Blue Bronze")).toBeNull();
  });

  it("records real focus and held pointer states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderMembership();
    await screen.findAllByText("Blue Bronze");
    const action = screen.getAllByRole("link", {
      name: /app links coming soon/i,
    })[0];
    fireEvent.focus(action);
    expect(container.querySelector(".membership-surface")).toHaveAttribute(
      "data-membership-interaction",
      "focused",
    );
    fireEvent.pointerDown(action);
    expect(container.querySelector(".membership-surface")).toHaveAttribute(
      "data-membership-interaction",
      "pressed",
    );
  });

  it("times out without assuming activation or payment", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    const { container } = renderMembership();
    await act(async () => vi.advanceTimersByTimeAsync(8_000));
    expect(container.querySelector(".membership-surface")).toHaveAttribute(
      "data-membership-status",
      "security_timeout",
    );
    expect(screen.queryByText("Blue Bronze")).toBeNull();
  });
});
