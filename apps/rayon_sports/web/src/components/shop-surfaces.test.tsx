import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import {
  normalizeShopProduct,
  normalizeShopSnapshot,
  resolveShopCopy,
  ShopProductSurface,
  ShopSurface,
  type PublicShopProduct,
} from "./shop-surfaces";

const products: PublicShopProduct[] = [
  {
    id: "home-shirt",
    name: "Home shirt",
    subtitle: "Official home shirt.",
    description: "Confirmed public home shirt description.",
    category: "Jerseys",
    collection: "2026",
    price: 35_000,
    imageUrl: "/brand-surface.svg",
    sizes: ["S", "M", "L"],
    isAvailable: true,
  },
  {
    id: "club-scarf",
    name: "Club scarf",
    subtitle: "Official supporter scarf.",
    description: "Confirmed public scarf description.",
    category: "Accessories",
    collection: null,
    price: 12_000,
    imageUrl: "/brand-surface.svg",
    sizes: ["One size"],
    isAvailable: false,
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

function readyCatalog() {
  return response(200, { code: "PUBLIC_SHOP_READY", items: products });
}

function readyProduct(product = products[0]) {
  return response(200, { code: "PUBLIC_SHOP_PRODUCT_READY", item: product });
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(accept => { resolve = accept; });
  return { promise, resolve };
}

function renderShop(locale = "en") {
  return render(
    <ShopSurface
      locale={locale}
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
    />,
  );
}

function renderProduct(productId = "home-shirt") {
  return render(
    <ShopProductSurface
      locale="en"
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
      productId={productId}
    />,
  );
}

describe("shop helpers", () => {
  it("bounds, validates, deduplicates, and strips private fields", () => {
    const normalized = normalizeShopSnapshot({
      items: [
        ...products,
        products[0],
        {
          ...products[0],
          id: "unsafe",
          price: -1,
          imageUrl: "https://tracker.invalid/private.jpg",
          customerId: "private-user",
        },
      ],
    });
    expect(normalized).toHaveLength(2);
    expect(normalized[0].sizes).toEqual(["S", "M", "L"]);
    expect(normalized[0]).not.toHaveProperty("customerId");
    expect(normalized.some(({ id }) => id === "unsafe")).toBe(false);
    expect(normalizeShopProduct({ ...products[0], isAvailable: "yes" })).toBeNull();
  });

  it("provides draft state parity and English fallback", () => {
    expect(resolveShopCopy("en").refresh).toBe("Refresh products");
    expect(resolveShopCopy("en").products).toBe("Products");
    expect(resolveShopCopy("en").categories).toBe("Categories");
    expect(resolveShopCopy("unknown").refresh).toBe("Refresh products");
  });
});

describe("ShopSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  afterEach(() => vi.useRealTimers());

  it.each(["RWF", "BIF", "ZMW", "CDF", "MZN"])("uses %s for catalog prices and product details", async (currencyCode) => {
    const expected = new Intl.NumberFormat("en", { style: "currency", currency: currencyCode, maximumFractionDigits: 0 }).format(products[0].price);
    vi.spyOn(globalThis, "fetch").mockImplementation(readyCatalog);
    const catalog = render(<ShopSurface locale="en" clubShortName="Selected club" currencyCode={currencyCode} fanAppHref="/app" hasExternalAppUrl={false} />);
    expect((await screen.findAllByText(expected.replace(/\s+/g, " "))).length).toBeGreaterThan(0);
    catalog.unmount();
    vi.spyOn(globalThis, "fetch").mockImplementation(() => readyProduct());
    render(<ShopProductSurface locale="en" clubShortName="Selected club" currencyCode={currencyCode} fanAppHref="/app" hasExternalAppUrl={false} productId="home-shirt" />);
    expect(await screen.findByText(expected.replace(/\s+/g, " "))).toBeVisible();
    if (currencyCode !== "RWF") expect(screen.queryByText(/RWF/)).not.toBeInTheDocument();
  });

  it("renders confirmed products and supports real selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyCatalog);
    const { container } = renderShop();
    await screen.findAllByText("Home shirt");
    expect(container.querySelector(".shop-surface")).toHaveAttribute(
      "data-shop-status",
      "ready",
    );
    fireEvent.click(screen.getByRole("button", { name: /club scarf/i }));
    expect(screen.getByRole("button", { name: /club scarf/i })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(container.querySelector(".shop-surface")).toHaveAttribute(
      "data-shop-interaction",
      "selected",
    );
  });

  it("clears the previous club catalog and ignores its late denied response", async () => {
    const previous = deferred<unknown>();
    const next = deferred<Response>();
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyCatalog)
      .mockResolvedValueOnce({ ok: false, status: 403, json: () => previous.promise } as Response)
      .mockReturnValueOnce(next.promise);
    const view = renderShop();
    await screen.findAllByText("Home shirt");
    fireEvent.click(screen.getByRole("button", { name: "Refresh products" }));
    view.rerender(<ShopSurface locale="en" clubShortName="Nkana" clubId={26} currencyCode="ZMW" fanAppHref="/app" hasExternalAppUrl={false} />);
    expect(screen.queryByText("Home shirt")).not.toBeInTheDocument();
    expect(view.container.querySelector(".shop-surface")).toHaveAttribute("data-shop-status", "loading");
    await act(async () => { next.resolve(await response(200, { items: [{ ...products[0], name: "Nkana shirt" }] })); });
    await screen.findAllByText("Nkana shirt");
    await act(async () => { previous.resolve({ items: products }); });
    expect(view.container.querySelector(".shop-surface")).toHaveAttribute("data-shop-status", "ready");
    expect(screen.queryByText("Home shirt")).not.toBeInTheDocument();
    expect(screen.getAllByText("Nkana shirt").length).toBeGreaterThan(0);
  });

  it("ignores an aborted refresh body after a newer catalog arrives", async () => {
    const previous = deferred<unknown>();
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyCatalog)
      .mockResolvedValueOnce({ ok: false, status: 403, json: () => previous.promise } as Response)
      .mockImplementationOnce(() => response(200, { items: [{ ...products[0], name: "Latest shirt" }] }));
    const view = renderShop();
    await screen.findAllByText("Home shirt");
    fireEvent.click(screen.getByRole("button", { name: "Refresh products" }));
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Latest shirt");
    await act(async () => { previous.resolve({ items: products }); });
    expect(view.container.querySelector(".shop-surface")).toHaveAttribute("data-shop-status", "ready");
    expect(screen.getAllByText("Latest shirt").length).toBeGreaterThan(0);
    expect(screen.queryByText("Home shirt")).not.toBeInTheDocument();
  });

  it("renders the controlled empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_SHOP_EMPTY", items: [] }),
    );
    const { container } = renderShop();
    await screen.findByRole("heading", { name: "No public products" });
    expect(container.querySelector(".shop-surface")).toHaveAttribute(
      "data-shop-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Shop access denied"],
    [409, "conflict", "Shop catalog changed"],
    [502, "error", "Shop catalog unavailable"],
    [504, "security_timeout", "Shop request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, { error: "database.internal password=private" }),
      );
      const { container } = renderShop();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".shop-surface")).toHaveAttribute(
        "data-shop-status",
        expectedStatus,
      );
      expect(screen.queryByText(/database\.internal/i)).toBeNull();
    },
  );

  it("retains confirmed products during syncing and conflict", async () => {
    let release:
      ((value: Response | PromiseLike<Response>) => void) | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyCatalog)
      .mockImplementationOnce(
        () => new Promise<Response>((resolve) => (release = resolve)),
      );
    const { container } = renderShop();
    await screen.findAllByText("Home shirt");
    fireEvent.click(screen.getByRole("button", { name: /refresh products/i }));
    await waitFor(() =>
      expect(container.querySelector(".shop-surface")).toHaveAttribute(
        "data-shop-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Home shirt").length).toBeGreaterThan(0);
    release?.(
      new Response(JSON.stringify({ code: "PUBLIC_SHOP_CONFLICT" }), {
        status: 409,
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".shop-surface")).toHaveAttribute(
        "data-shop-status",
        "conflict",
      ),
    );
    expect(screen.getAllByText("Home shirt").length).toBeGreaterThan(0);
  });

  it("clears confirmed products when access is denied", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyCatalog)
      .mockImplementationOnce(() =>
        response(403, { code: "PUBLIC_SHOP_ACCESS_DENIED" }),
      );
    const { container } = renderShop();
    await screen.findAllByText("Home shirt");
    fireEvent.click(screen.getByRole("button", { name: /refresh products/i }));
    await waitFor(() =>
      expect(container.querySelector(".shop-surface")).toHaveAttribute(
        "data-shop-status",
        "permission_denied",
      ),
    );
    expect(screen.queryByText("Home shirt")).toBeNull();
  });

  it("records real focus and held-pointer states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyCatalog);
    const { container } = renderShop();
    await screen.findAllByText("Home shirt");
    const action = screen.getByRole("button", { name: /refresh products/i });
    fireEvent.focus(action);
    expect(container.querySelector(".shop-surface")).toHaveAttribute(
      "data-shop-interaction",
      "focused",
    );
    fireEvent.pointerDown(action);
    expect(container.querySelector(".shop-surface")).toHaveAttribute(
      "data-shop-interaction",
      "pressed",
    );
  });

  it("times out without assuming an order or payment", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    const { container } = renderShop();
    await act(async () => vi.advanceTimersByTimeAsync(8_000));
    expect(container.querySelector(".shop-surface")).toHaveAttribute(
      "data-shop-status",
      "security_timeout",
    );
    expect(screen.queryByText("Home shirt")).toBeNull();
  });
});

describe("ShopProductSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  it("loads the encoded product resource and supports real size selection", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() => readyProduct());
    const { container } = renderProduct("home shirt");
    await screen.findAllByText("Home shirt");
    expect(fetchMock).toHaveBeenCalledWith(
      "/api/public-content?resource=shop-product&productId=home%20shirt",
      expect.objectContaining({ cache: "no-store" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "M" }));
    expect(screen.getByRole("button", { name: "M" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(container.querySelector(".shop-product-surface")).toHaveAttribute(
      "data-shop-product-interaction",
      "selected",
    );
  });

  it("clears the previous product and ignores its late refresh after the route changed", async () => {
    const previous = deferred<unknown>();
    const next = deferred<Response>();
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() => readyProduct())
      .mockResolvedValueOnce({ ok: true, status: 200, json: () => previous.promise } as Response)
      .mockReturnValueOnce(next.promise);
    const view = renderProduct();
    await screen.findAllByText("Home shirt");
    fireEvent.click(screen.getByRole("button", { name: "Refresh products" }));
    view.rerender(<ShopProductSurface locale="en" clubShortName="Rayon Sports" fanAppHref="/app" hasExternalAppUrl={false} productId="club-scarf" />);
    expect(screen.queryByText("Home shirt")).not.toBeInTheDocument();
    await act(async () => { next.resolve(await readyProduct(products[1])); });
    await screen.findAllByText("Club scarf");
    await act(async () => { previous.resolve({ item: products[0] }); });
    expect(screen.queryByText("Home shirt")).not.toBeInTheDocument();
    expect(screen.getAllByText("Club scarf").length).toBeGreaterThan(0);
  });

  it("renders a truthful unavailable product with disabled size choices", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      readyProduct(products[1]),
    );
    renderProduct("club-scarf");
    await screen.findAllByText("Club scarf");
    expect(screen.getAllByText("Currently unavailable").length).toBeGreaterThan(
      0,
    );
    expect(
      screen.getByRole("group", { name: /choose a size/i }),
    ).toBeDisabled();
    expect(screen.queryByRole("button", { name: /buy|checkout|pay/i })).toBeNull();
  });

  it("renders an explicit empty detail instead of claiming a product exists", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_SHOP_PRODUCT_EMPTY", item: null }),
    );
    const { container } = renderProduct("missing");
    await screen.findByRole("heading", { name: "No public products" });
    expect(container.querySelector(".shop-product-surface")).toHaveAttribute(
      "data-shop-product-status",
      "empty",
    );
  });
});
