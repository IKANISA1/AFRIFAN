"use client";

import Image from "next/image";
import Link from "next/link";
import {
  type PointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  ArrowLeft,
  ArrowRight,
  BadgeCheck,
  PackageCheck,
  RefreshCw,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  WifiOff,
} from "lucide-react";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const SHOP_TIMEOUT_MS = 8_000;

export type PublicShopProduct = {
  id: string;
  name: string;
  subtitle: string;
  description: string;
  category: string;
  collection: string | null;
  price: number;
  imageUrl: string | null;
  sizes: string[];
  isAvailable: boolean;
};

type ShopInteraction = "idle" | "focused" | "pressed" | "selected";

type ShopSurfaceProps = {
  locale: string;
  clubShortName: string;
  clubId?: number;
  currencyCode?: string;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
};

type ShopProductSurfaceProps = ShopSurfaceProps & {
  productId: string;
};

type ShopCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  eyebrow: string;
  title: (club: string) => string;
  description: string;
  app: string;
  appPending: string;
  membership: string;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  products: string;
  categories: string;
  selected: string;
  selectedProduct: string;
  price: string;
  sizes: string;
  availability: string;
  available: string;
  unavailable: string;
  catalogue: string;
  catalogueDetail: string;
  noProducts: string;
  noProductsDetail: string;
  viewProduct: string;
  productDetail: string;
  chooseSize: string;
  selectedSize: string;
  backToShop: string;
  boundaryEyebrow: string;
  boundaryTitle: string;
  boundaryDetail: string;
};

const en: ShopCopy = {
  status: {
    loading: {
      label: "Loading official products",
      detail: "Waiting for the first confirmed public shop catalog.",
    },
    ready: {
      label: "Official products confirmed",
      detail: "Public product details come from the latest confirmed catalog.",
    },
    empty: {
      label: "No public products",
      detail: "No product is currently confirmed for public display.",
    },
    error: {
      label: "Shop catalog unavailable",
      detail: "Confirmed products remain visible. Retry when service recovers.",
    },
    offline: {
      label: "You are offline",
      detail: "Confirmed products remain visible until the connection returns.",
    },
    permission_denied: {
      label: "Shop access denied",
      detail: "Previously loaded public products have been cleared.",
    },
    syncing: {
      label: "Refreshing official products",
      detail: "Confirmed products remain visible during refresh.",
    },
    conflict: {
      label: "Shop catalog changed",
      detail: "Refresh to load the current confirmed public catalog.",
    },
    security_timeout: {
      label: "Shop request timed out",
      detail: "No order or payment is assumed. Confirmed products remain visible.",
    },
  },
  eyebrow: "Official club shop",
  title: (club) => `${club} supporter shop`,
  description:
    "Explore confirmed public merchandise. Availability shown here is informational; orders, customer identity, delivery, receipts, and payments remain in approved club channels.",
  app: "Open supporter app",
  appPending: "App shop coming soon",
  membership: "Member benefits",
  refresh: "Refresh products",
  retry: "Try again",
  refreshDisabled: "Refresh is unavailable while products are loading.",
  products: "Products",
  categories: "Categories",
  selected: "Selected",
  selectedProduct: "Selected product",
  price: "Public price",
  sizes: "Sizes",
  availability: "Availability",
  available: "Available in approved channels",
  unavailable: "Currently unavailable",
  catalogue: "Confirmed merchandise catalog",
  catalogueDetail:
    "Choose a product to review its approved public description, price, and size options.",
  noProducts: "No public products",
  noProductsDetail: "Products appear only after club confirmation.",
  viewProduct: "View product",
  productDetail: "Product details",
  chooseSize: "Choose a size to compare",
  selectedSize: "Selected size",
  backToShop: "Back to shop",
  boundaryEyebrow: "Public shop boundary",
  boundaryTitle: "Explore here. Complete purchases in an approved channel.",
  boundaryDetail:
    "Public web does not expose stock counts, supplier costs, customer identity, carts, orders, delivery addresses, payment details, or receipts. Confirm current availability, final price, delivery, returns, and payment inside the official supporter app or another club-approved sales channel.",
};

function localizedCopy(_locale: string): ShopCopy {
  const _language = "en";
  return en;
}

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

export function normalizeShopProduct(value: unknown): PublicShopProduct | null {
  if (typeof value !== "object" || value == null) return null;
  const row = value as Record<string, unknown>;
  const id = boundedString(row.id, 200);
  const name = boundedString(row.name, 160);
  const subtitle = boundedString(row.subtitle, 500);
  const description = boundedString(row.description, 2_000);
  const category = boundedString(row.category, 100);
  const collection = boundedString(row.collection, 100) || null;
  const price = Number(row.price);
  const imageCandidate = boundedString(row.imageUrl, 2_000);
  const imageUrl =
    imageCandidate.startsWith("/") ||
    /^https:\/\/[^/]+\.supabase\.co(?:\/|$)/i.test(imageCandidate)
      ? imageCandidate
      : null;
  const sizes = Array.isArray(row.sizes)
    ? Array.from(
        new Set(
          row.sizes
            .map((size) => boundedString(size, 40))
            .filter(Boolean),
        ),
      ).slice(0, 8)
    : [];
  if (
    !id ||
    !name ||
    !subtitle ||
    !description ||
    !category ||
    !Number.isFinite(price) ||
    price < 0 ||
    price > 1_000_000_000_000 ||
    sizes.length === 0 ||
    typeof row.isAvailable !== "boolean"
  ) {
    return null;
  }
  return {
    id,
    name,
    subtitle,
    description,
    category,
    collection,
    price,
    imageUrl,
    sizes,
    isAvailable: row.isAvailable,
  };
}

export function normalizeShopSnapshot(value: unknown) {
  if (typeof value !== "object" || value == null) return [];
  const payload = value as Record<string, unknown>;
  if (!Array.isArray(payload.items)) return [];
  const ids = new Set<string>();
  const result: PublicShopProduct[] = [];
  for (const entry of payload.items) {
    const product = normalizeShopProduct(entry);
    if (product == null || ids.has(product.id)) continue;
    ids.add(product.id);
    result.push(product);
    if (result.length === 12) break;
  }
  return result;
}

export function resolveShopCopy(locale: string) {
  return localizedCopy(locale);
}

function formatPrice(value: number, currencyCode: string) {
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency: currencyCode,
      maximumFractionDigits: 0,
    }).format(value);
  } catch {
    return `${value.toLocaleString("en")} ${currencyCode}`;
  }
}

function useShopResource(productId?: string) {
  const [products, setProducts] = useState<PublicShopProduct[]>([]);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const hasConfirmed = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const load = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }
    activeRequest.current?.abort();
    const controller = new AbortController();
    activeRequest.current = controller;
    setStatus(hasConfirmed.current ? "syncing" : "loading");
    let timedOut = false;
    const timeout = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
      if (isMounted.current && activeRequest.current === controller) setStatus("security_timeout");
    }, SHOP_TIMEOUT_MS);
    const query =
      productId == null
        ? "resource=shop"
        : `resource=shop-product&productId=${encodeURIComponent(productId)}`;
    try {
      const response = await fetch(`/api/public-content?${query}`, {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!isMounted.current || activeRequest.current !== controller || controller.signal.aborted) return;
      if (!response.ok) {
        if (!isMounted.current) return;
        if (response.status === 403) {
          setProducts([]);
          hasConfirmed.current = false;
        }
        setStatus(resolveFixturesFailureStatus(response.status));
        return;
      }
      if (typeof payload !== "object" || payload == null) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const next =
        productId == null
          ? normalizeShopSnapshot(payload)
          : (() => {
              const item = normalizeShopProduct(
                (payload as Record<string, unknown>).item,
              );
              return item == null ? [] : [item];
            })();
      if (!isMounted.current) return;
      setProducts(next);
      hasConfirmed.current = next.length > 0;
      setStatus(next.length > 0 ? "ready" : "empty");
    } catch {
      if (!isMounted.current || activeRequest.current !== controller || (controller.signal.aborted && !timedOut))
        return;
      if (typeof navigator !== "undefined" && !navigator.onLine) {
        setStatus("offline");
      } else {
        setStatus(timedOut ? "security_timeout" : "error");
      }
    } finally {
      window.clearTimeout(timeout);
      if (activeRequest.current === controller) activeRequest.current = null;
    }
  }, [productId]);

  useEffect(() => {
    isMounted.current = true;
    void load();
    const offline = () => setStatus("offline");
    const online = () => void load();
    window.addEventListener("offline", offline);
    window.addEventListener("online", online);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", offline);
      window.removeEventListener("online", online);
    };
  }, [load]);

  return { products, status, load };
}

function ShopStatus({
  status,
  copy,
}: {
  status: FixturesSurfaceStatus;
  copy: ShopCopy;
}) {
  const message = copy.status[status];
  return (
    <aside
      className="shop-status circles-status"
      data-shop-status={status}
      role={status === "permission_denied" ? "alert" : "status"}
      aria-live="polite"
    >
      {status === "offline" ? (
        <WifiOff aria-hidden="true" />
      ) : (
        <PackageCheck aria-hidden="true" />
      )}
      <div>
        <p>{message.label}</p>
        <span>{message.detail}</span>
      </div>
    </aside>
  );
}

function ShopBoundary({ copy }: { copy: ShopCopy }) {
  return (
    <aside className="circles-boundary">
      <ShieldCheck aria-hidden="true" />
      <div>
        <p className="circles-eyebrow">{copy.boundaryEyebrow}</p>
        <h2>{copy.boundaryTitle}</h2>
        <p>{copy.boundaryDetail}</p>
      </div>
    </aside>
  );
}

function AppShopAction({
  copy,
  fanAppHref,
  hasExternalAppUrl,
  onFocus,
  onBlur,
  onPointerDown,
  onPointerUp,
}: {
  copy: ShopCopy;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
  onFocus: () => void;
  onBlur: () => void;
  onPointerDown: (event: PointerEvent<HTMLElement>) => void;
  onPointerUp: () => void;
}) {
  if (!hasExternalAppUrl) {
    return (
      <span
        className="shop-action circles-action circles-action-primary"
        aria-disabled="true"
        data-shop-app-link="pending"
      >
        <Smartphone aria-hidden="true" /> {copy.appPending}
      </span>
    );
  }
  return (
    <Link
      href={fanAppHref}
      className="shop-action circles-action circles-action-primary"
      onFocus={onFocus}
      onBlur={onBlur}
      onPointerDown={onPointerDown}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      <Smartphone aria-hidden="true" /> {copy.app}
    </Link>
  );
}

export function ShopSurface(props: ShopSurfaceProps) {
  return <ClubShopSurface key={`${props.clubId ?? props.clubShortName}:${props.currencyCode ?? "RWF"}`} {...props} />;
}

function ClubShopSurface({
  locale,
  clubShortName,
  currencyCode = "RWF",
  fanAppHref,
  hasExternalAppUrl,
}: ShopSurfaceProps) {
  const copy = useMemo(() => localizedCopy(locale), [locale]);
  const { products, status, load } = useShopResource();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [interaction, setInteraction] = useState<ShopInteraction>("idle");
  const selected =
    products.find(({ id }) => id === selectedId) ?? products[0] ?? null;
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = copy.status[status];

  const press = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled)
      return;
    setInteraction("pressed");
  };

  return (
    <section
      className="shop-surface circles-surface"
      data-shop-status={status}
      data-shop-interaction={interaction}
      data-shop-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="circles-hero">
          <div>
            <p className="circles-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title(clubShortName)}</h1>
            <p className="circles-description">{copy.description}</p>
          </div>
          <ShopStatus status={status} copy={copy} />
          <div className="circles-actions">
            <AppShopAction
              copy={copy}
              fanAppHref={fanAppHref}
              hasExternalAppUrl={hasExternalAppUrl}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
            />
            <Link
              href="/membership"
              className="shop-action circles-action circles-action-secondary"
            >
              <BadgeCheck aria-hidden="true" /> {copy.membership}
            </Link>
            <button
              type="button"
              className="shop-action circles-action circles-action-secondary"
              disabled={isBusy}
              aria-describedby={isBusy ? "shop-refresh-disabled" : undefined}
              onClick={() => void load()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? copy.retry : copy.refresh}
            </button>
            <span id="shop-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
          <dl className="circles-stats">
            <div>
              <dt>{copy.products}</dt>
              <dd>{products.length}</dd>
            </div>
            <div>
              <dt>{copy.categories}</dt>
              <dd>{new Set(products.map(({ category }) => category)).size}</dd>
            </div>
            <div>
              <dt>{copy.selected}</dt>
              <dd>{selected?.name ?? "—"}</dd>
            </div>
          </dl>
        </header>

        {isRecovery ? (
          <aside className="circles-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="circles-content" aria-busy={isBusy}>
          {selected ? (
            <article className="shop-featured circles-featured">
              <div className="shop-product-image">
                <Image
                  src={selected.imageUrl ?? "/brand-surface.svg"}
                  alt={selected.name}
                  width={1200}
                  height={840}
                  sizes="(min-width: 832px) 40vw, 100vw"
                />
              </div>
              <div>
                <p className="circles-eyebrow">{copy.selectedProduct}</p>
                <h2>{selected.name}</h2>
                <p>{selected.description}</p>
                <dl className="circles-featured-stats">
                  <div>
                    <dt>{copy.price}</dt>
                    <dd>{formatPrice(selected.price, currencyCode)}</dd>
                  </div>
                  <div>
                    <dt>{copy.sizes}</dt>
                    <dd>{selected.sizes.length}</dd>
                  </div>
                  <div>
                    <dt>{copy.availability}</dt>
                    <dd>
                      {selected.isAvailable ? copy.available : copy.unavailable}
                    </dd>
                  </div>
                </dl>
                <Link
                  href={`/shop/${encodeURIComponent(selected.id)}`}
                  className="shop-action circles-action circles-action-primary"
                >
                  {copy.viewProduct} <ArrowRight aria-hidden="true" />
                </Link>
              </div>
            </article>
          ) : status === "loading" ? (
            <div
              className="circles-skeleton"
              role="status"
              aria-label={message.label}
            >
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="circles-empty">
              <ShoppingBag aria-hidden="true" />
              <h2>{copy.noProducts}</h2>
              <p>{copy.noProductsDetail}</p>
            </div>
          )}

          {products.length > 0 ? (
            <section className="circles-campaigns">
              <header>
                <div>
                  <p className="circles-eyebrow">{copy.products}</p>
                  <h2>{copy.catalogue}</h2>
                </div>
                <p>{copy.catalogueDetail}</p>
              </header>
              <div className="circles-grid">
                {products.map((product) => (
                  <button
                    type="button"
                    key={product.id}
                    className="shop-card circles-card"
                    aria-pressed={product.id === selected?.id}
                    onClick={() => {
                      setSelectedId(product.id);
                      setInteraction("selected");
                    }}
                    onFocus={() => setInteraction("focused")}
                    onBlur={() =>
                      setInteraction((current) =>
                        current === "focused" ? "idle" : current,
                      )
                    }
                    onPointerDown={press}
                    onPointerUp={() => setInteraction("selected")}
                    onPointerCancel={() => setInteraction("idle")}
                  >
                    <span className="circles-card-icon" aria-hidden="true">
                      <ShoppingBag />
                    </span>
                    <span>
                      <strong>{product.name}</strong>
                      <small>
                        {formatPrice(product.price, currencyCode)}
                        {" · "}
                        {product.isAvailable ? copy.available : copy.unavailable}
                      </small>
                    </span>
                    <ArrowRight aria-hidden="true" />
                  </button>
                ))}
              </div>
            </section>
          ) : null}
        </section>
        <ShopBoundary copy={copy} />
      </div>
    </section>
  );
}

export function ShopProductSurface(props: ShopProductSurfaceProps) {
  return <ClubShopProductSurface key={`${props.clubId ?? props.clubShortName}:${props.currencyCode ?? "RWF"}:${props.productId}`} {...props} />;
}

function ClubShopProductSurface({
  locale,
  clubShortName,
  currencyCode = "RWF",
  fanAppHref,
  hasExternalAppUrl,
  productId,
}: ShopProductSurfaceProps) {
  const copy = useMemo(() => localizedCopy(locale), [locale]);
  const { products, status, load } = useShopResource(productId);
  const product = products[0] ?? null;
  const [selectedSize, setSelectedSize] = useState<string | null>(null);
  const effectiveSelectedSize =
    product?.sizes.includes(selectedSize ?? "")
      ? selectedSize
      : (product?.sizes[0] ?? null);
  const [interaction, setInteraction] = useState<ShopInteraction>("idle");
  const isBusy = status === "loading" || status === "syncing";
  const isRecovery = [
    "error",
    "offline",
    "permission_denied",
    "conflict",
    "security_timeout",
  ].includes(status);
  const message = copy.status[status];

  const press = (event: PointerEvent<HTMLElement>) => {
    if ("disabled" in event.currentTarget && event.currentTarget.disabled)
      return;
    setInteraction("pressed");
  };

  return (
    <section
      className="shop-product-surface shop-surface circles-surface"
      data-shop-product-status={status}
      data-shop-product-interaction={interaction}
      data-shop-product-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="circles-hero">
          <div>
            <p className="circles-eyebrow">{copy.productDetail}</p>
            <h1>{product?.name ?? copy.title(clubShortName)}</h1>
            <p className="circles-description">
              {product?.subtitle ?? copy.description}
            </p>
          </div>
          <ShopStatus status={status} copy={copy} />
          <div className="circles-actions">
            <Link
              href="/shop"
              className="shop-product-action circles-action circles-action-secondary"
            >
              <ArrowLeft aria-hidden="true" /> {copy.backToShop}
            </Link>
            <AppShopAction
              copy={copy}
              fanAppHref={fanAppHref}
              hasExternalAppUrl={hasExternalAppUrl}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
            />
            <button
              type="button"
              className="shop-product-action circles-action circles-action-secondary"
              disabled={isBusy}
              aria-describedby={
                isBusy ? "shop-product-refresh-disabled" : undefined
              }
              onClick={() => void load()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? copy.retry : copy.refresh}
            </button>
            <span id="shop-product-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
        </header>

        {isRecovery ? (
          <aside className="circles-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="circles-content" aria-busy={isBusy}>
          {product ? (
            <article className="shop-featured circles-featured">
              <div className="shop-product-image">
                <Image
                  src={product.imageUrl ?? "/brand-surface.svg"}
                  alt={product.name}
                  width={1200}
                  height={840}
                  sizes="(min-width: 832px) 40vw, 100vw"
                />
              </div>
              <div>
                <p className="circles-eyebrow">
                  {product.collection ?? product.category}
                </p>
                <h2>{product.name}</h2>
                <p>{product.description}</p>
                <dl className="circles-featured-stats">
                  <div>
                    <dt>{copy.price}</dt>
                    <dd>{formatPrice(product.price, currencyCode)}</dd>
                  </div>
                  <div>
                    <dt>{copy.availability}</dt>
                    <dd>
                      {product.isAvailable ? copy.available : copy.unavailable}
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.selectedSize}</dt>
                    <dd>{effectiveSelectedSize ?? "—"}</dd>
                  </div>
                </dl>
                <fieldset
                  className="shop-size-picker"
                  disabled={!product.isAvailable}
                >
                  <legend>{copy.chooseSize}</legend>
                  <div>
                    {product.sizes.map((size) => (
                      <button
                        type="button"
                        key={size}
                        className="shop-product-action shop-size-action"
                        aria-pressed={size === effectiveSelectedSize}
                        onClick={() => {
                          setSelectedSize(size);
                          setInteraction("selected");
                        }}
                        onFocus={() => setInteraction("focused")}
                        onBlur={() =>
                          setInteraction((current) =>
                            current === "focused" ? "idle" : current,
                          )
                        }
                        onPointerDown={press}
                        onPointerUp={() => setInteraction("selected")}
                        onPointerCancel={() => setInteraction("idle")}
                      >
                        {size}
                      </button>
                    ))}
                  </div>
                </fieldset>
                {!product.isAvailable ? (
                  <p className="shop-unavailable" role="status">
                    {copy.unavailable}
                  </p>
                ) : null}
              </div>
            </article>
          ) : status === "loading" ? (
            <div
              className="circles-skeleton"
              role="status"
              aria-label={message.label}
            >
              <span />
              <span />
              <span />
            </div>
          ) : (
            <div className="circles-empty">
              <ShoppingBag aria-hidden="true" />
              <h2>{copy.noProducts}</h2>
              <p>{copy.noProductsDetail}</p>
              <Link
                href="/shop"
                className="shop-product-action circles-action circles-action-secondary"
              >
                <ArrowLeft aria-hidden="true" /> {copy.backToShop}
              </Link>
            </div>
          )}
        </section>
        <ShopBoundary copy={copy} />
      </div>
    </section>
  );
}
