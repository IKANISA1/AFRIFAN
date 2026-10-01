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

const paymentMocks = vi.hoisted(() => ({ prepare: vi.fn(), confirm: vi.fn(), client: {} }));
vi.mock("@/lib/supabase/browser", () => ({ getBrowserSupabase: () => paymentMocks.client }));
vi.mock("@/lib/membership-payment", async (original) => ({ ...await original<typeof import("@/lib/membership-payment")>(), preparePaidMembership: paymentMocks.prepare, confirmPaidMembership: paymentMocks.confirm }));
vi.mock("./member-portal", () => ({ MemberPortal: () => <div>Member account</div> }));

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

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(accept => { resolve = accept; });
  return { promise, resolve };
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
    expect(resolveMembershipCopy("en").refresh).toBe(
      "Refresh tiers",
    );
    expect(resolveMembershipCopy("en").tiers).toBe("Tiers");
    expect(resolveMembershipCopy("en").paidPlans).toBe("Paid plans");
    expect(resolveMembershipCopy("unknown").refresh).toBe("Refresh tiers");
  });
});

describe("MembershipSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    paymentMocks.prepare.mockReset().mockResolvedValue({ id: "99590000-0000-4000-8000-000000000101", clubId: 24, tier: "gold", amount: 52000, currency: "RWF", recipientCode: "123456", country: "RW", ussdCode: "*182*8*1*52000*123456#", userId: "supporter" });
    paymentMocks.confirm.mockReset().mockResolvedValue(true);
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
    fireEvent.click(screen.getByRole("button", { name: /^blue gold/i }));
    expect(screen.getByRole("button", { name: /^blue gold/i })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(paymentMocks.prepare).not.toHaveBeenCalled();
    expect(paymentMocks.confirm).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Review payment for Blue Gold" }));
    expect(await screen.findByRole("heading", { name: "Review membership payment" })).toHaveFocus();
    expect(screen.getByText(/The payment amount changed from the catalog price of RWF 50,000 to RWF 52,000/)).toBeVisible();
    expect(screen.getByText("*182*8*1*52000*123456#")).toBeVisible();
    expect(screen.getByText("123456")).toBeVisible();
    expect(paymentMocks.confirm).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Confirm and open MoMo" }));
    await waitFor(() => expect(paymentMocks.confirm).toHaveBeenCalledTimes(1));
    expect(await screen.findByText(/MoMo was opened. Payment is not confirmed/)).toBeVisible();
    expect(screen.getAllByText("Blue Gold").length).toBeGreaterThan(1);
    expect(screen.getByText("Member events")).toBeInTheDocument();
  });

  it("does not launch twice while a tier payment is preparing", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    paymentMocks.prepare.mockReturnValue(new Promise(() => {}));
    renderMembership(); await screen.findAllByText("Blue Bronze");
    const tier = screen.getByRole("button", {name: "Review payment for Blue Bronze"});
    fireEvent.click(tier); fireEvent.click(tier);
    expect(paymentMocks.prepare).toHaveBeenCalledTimes(1);
    expect(tier).toBeDisabled();
  });
  it("excludes free and fractional catalog prices", () => {
    expect(normalizeMembershipSnapshot({packages: packages.map((p, i) => ({...p, annualPrice: i === 0 ? 0 : 1.5}))})).toEqual([]);
  });

  it("cancels review without opening payment and requires explicit confirmation after a server change", async () => {
    const { MembershipPaymentChangedError } = await import("@/lib/membership-payment");
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    renderMembership(); await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: "Review payment for Blue Bronze" }));
    await screen.findByRole("heading", { name: "Review membership payment" });
    fireEvent.click(screen.getByRole("button", { name: "Cancel payment review" }));
    expect(paymentMocks.confirm).not.toHaveBeenCalled();
    expect(screen.queryByRole("heading", { name: "Review membership payment" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Review payment for Blue Bronze" }));
    await screen.findByRole("heading", { name: "Review membership payment" });
    paymentMocks.confirm.mockRejectedValueOnce(new MembershipPaymentChangedError({ ...await paymentMocks.prepare(), amount: 55000, recipientCode: "987654" }));
    fireEvent.click(screen.getByRole("button", { name: "Confirm and open MoMo" }));
    await screen.findByText(/Payment instructions changed/);
    expect(screen.getByText(/The payment amount changed from the catalog price of RWF 10,000 to RWF 55,000/)).toBeVisible();
    expect(screen.getByText("987654")).toBeVisible();
    expect(paymentMocks.confirm).toHaveBeenCalledTimes(1);
    expect(screen.getByRole("button", { name: "Confirm and open MoMo" })).toBeEnabled();
  });

  it("does not show fabricated payment facts when preparation fails", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    paymentMocks.prepare.mockRejectedValue(new Error("route unavailable"));
    renderMembership(); await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: "Review payment for Blue Bronze" }));
    await screen.findByText(/Payment instructions could not be verified/);
    expect(screen.queryByRole("button", { name: "Confirm and open MoMo" })).not.toBeInTheDocument();
    expect(paymentMocks.confirm).not.toHaveBeenCalled();
  });

  it("clears the previous club catalog and review before accepting the next club", async () => {
    const next = deferred<Response>();
    vi.spyOn(globalThis, "fetch").mockImplementationOnce(readyResponse).mockReturnValueOnce(next.promise);
    const view = renderMembership();
    await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: "Review payment for Blue Bronze" }));
    await screen.findByRole("heading", { name: "Review membership payment" });
    view.rerender(<MembershipSurface locale="en" clubShortName="Nkana" clubId={26} countryCode="ZM" currencyCode="ZMW" fanAppHref="/app" hasExternalAppUrl={false} />);
    expect(screen.queryByText("Blue Bronze")).not.toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Review membership payment" })).not.toBeInTheDocument();
    expect(view.container.querySelector(".membership-surface")).toHaveAttribute("data-membership-status", "loading");
    await act(async () => { next.resolve(await response(200, { packages: [{ ...packages[0], title: "Nkana Bronze" }] })); });
    expect((await screen.findAllByText("Nkana Bronze")).length).toBeGreaterThan(0);
    expect(paymentMocks.confirm).not.toHaveBeenCalled();
  });

  it("ignores an old club catalog body and preparation completing after the club changed", async () => {
    const oldCatalog = deferred<unknown>();
    const oldPayment = deferred<Awaited<ReturnType<typeof import("@/lib/membership-payment").preparePaidMembership>>>();
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockResolvedValueOnce({ ok: false, status: 403, json: () => oldCatalog.promise } as Response)
      .mockImplementationOnce(() => response(200, { packages: [{ ...packages[0], title: "Nkana Bronze" }] }));
    paymentMocks.prepare.mockReturnValueOnce(oldPayment.promise);
    const view = renderMembership();
    await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: "Review payment for Blue Bronze" }));
    fireEvent.click(screen.getByRole("button", { name: "Refresh tiers" }));
    view.rerender(<MembershipSurface locale="en" clubShortName="Nkana" clubId={26} countryCode="ZM" currencyCode="ZMW" fanAppHref="/app" hasExternalAppUrl={false} />);
    await screen.findAllByText("Nkana Bronze");
    await act(async () => {
      oldCatalog.resolve({ packages });
      oldPayment.resolve({ id: "99590000-0000-4000-8000-000000000101", clubId: 24, tier: "bronze", amount: 10000, currency: "RWF", recipientCode: "123456", country: "RW", ussdCode: "*182*8*1*10000*123456#", userId: "supporter" });
    });
    expect(screen.queryByText("Blue Bronze")).not.toBeInTheDocument();
    expect(view.container.querySelector(".membership-surface")).toHaveAttribute("data-membership-status", "ready");
    expect(screen.queryByRole("heading", { name: "Review membership payment" })).not.toBeInTheDocument();
    expect(paymentMocks.confirm).not.toHaveBeenCalled();
  });

  it("ignores an aborted catalog refresh after a newer refresh succeeds", async () => {
    const older = deferred<unknown>();
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockResolvedValueOnce({ ok: false, status: 403, json: () => older.promise } as Response)
      .mockImplementationOnce(() => response(200, { packages: [{ ...packages[0], title: "Latest Bronze" }] }));
    const view = renderMembership();
    await screen.findAllByText("Blue Bronze");
    fireEvent.click(screen.getByRole("button", { name: "Refresh tiers" }));
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Latest Bronze");
    await act(async () => { older.resolve({ packages }); });
    expect(view.container.querySelector(".membership-surface")).toHaveAttribute("data-membership-status", "ready");
    expect(screen.queryByText("Blue Bronze")).not.toBeInTheDocument();
    expect(screen.getAllByText("Latest Bronze").length).toBeGreaterThan(0);
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
