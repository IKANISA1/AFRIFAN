"use client";

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
  ArrowRight,
  BadgeCheck,
  RefreshCw,
  ShieldCheck,
  Smartphone,
  Ticket,
  WifiOff,
} from "lucide-react";
import { MemberPortal } from "./member-portal";
import { getBrowserSupabase } from "@/lib/supabase/browser";
import { confirmPaidMembership, MembershipPaymentChangedError, preparePaidMembership, type MembershipPaymentReview } from "@/lib/membership-payment";
import {
  resolveFixturesFailureStatus,
  type FixturesSurfaceStatus,
} from "./fixtures-surface";

const MEMBERSHIP_TIMEOUT_MS = 8_000;

export type PublicMembershipTier = {
  id: string;
  tier: "ingenzi-imanzi" | "inyamibwa" | "imena" | "bronze" | "silver" | "gold";
  title: string;
  description: string;
  sortOrder: number;
  annualPrice: number;
  perks: string[];
};

type MembershipInteraction = "idle" | "focused" | "pressed" | "selected";

type MembershipSurfaceProps = {
  locale: string;
  clubShortName: string;
  clubId?: number;
  countryCode?: string;
  currencyCode?: string;
  fanAppHref: string;
  hasExternalAppUrl: boolean;
};

type CatalogPaymentReview = MembershipPaymentReview & {
  catalogTitle: string;
  catalogPrice: number;
};

type MembershipCopy = {
  status: Record<FixturesSurfaceStatus, { label: string; detail: string }>;
  eyebrow: string;
  title: (club: string) => string;
  description: (club: string) => string;
  openApp: string;
  appPending: string;
  tickets: string;
  refresh: string;
  retry: string;
  refreshDisabled: string;
  tiers: string;
  paidPlans: string;
  selected: string;
  selectedTier: string;
  annualPrice: string;
  included: string;
  directory: string;
  directoryDetail: string;
  noTiers: string;
  noTiersDetail: string;
  boundaryEyebrow: string;
  boundaryTitle: string;
  boundaryDetail: string;
};

const en: MembershipCopy = {
  status: {
    loading: {
      label: "Loading membership tiers",
      detail: "Waiting for the first confirmed public membership catalog.",
    },
    ready: {
      label: "Membership tiers confirmed",
      detail: "Prices and benefits come from the latest public catalog.",
    },
    empty: {
      label: "No public membership tiers",
      detail: "No membership tier is currently confirmed for public display.",
    },
    error: {
      label: "Membership catalog unavailable",
      detail: "Confirmed tiers remain visible. Retry when service recovers.",
    },
    offline: {
      label: "You are offline",
      detail: "Confirmed tiers remain visible until the connection returns.",
    },
    permission_denied: {
      label: "Membership access denied",
      detail:
        "Previously loaded public tiers have been cleared for this visitor.",
    },
    syncing: {
      label: "Refreshing membership tiers",
      detail: "Confirmed prices and benefits remain visible during refresh.",
    },
    conflict: {
      label: "Membership catalog changed",
      detail: "Refresh to load the current confirmed public catalog.",
    },
    security_timeout: {
      label: "Membership request timed out",
      detail:
        "No activation or payment is assumed. Confirmed tiers remain visible.",
    },
  },
  eyebrow: "Supporter membership",
  title: () => "Own the belonging.",
  description: (club) =>
    `Join ${club} with WhatsApp-secured access, a private member number, confirmed contribution history, and an available club-approved payment route.`,
  openApp: "Open supporter app",
  appPending: "App links coming soon",
  tickets: "Browse tickets",
  refresh: "Refresh tiers",
  retry: "Try again",
  refreshDisabled: "Refresh is unavailable while membership tiers are loading.",
  tiers: "Tiers",
  paidPlans: "Paid plans",
  selected: "Selected",
  selectedTier: "Selected tier",
  annualPrice: "Annual price",
  included: "Included benefits",
  directory: "Confirmed membership catalog",
  directoryDetail:
    "Select a tier, then review the current amount and recipient before opening payment.",
  noTiers: "No public membership tiers",
  noTiersDetail: "Tiers appear only after club confirmation.",
  boundaryEyebrow: "Paid membership",
  boundaryTitle: "Choose. Review. Confirm your payment route.",
  boundaryDetail:
    "Sign in to your club account and choose a paid tier. Review the server-confirmed amount, currency and recipient before opening MoMo. Opening the dialer does not confirm payment; your membership updates only after a matched payment.",
};

function localizedCopy(_locale: string): MembershipCopy {
  const _language = "en";
  return en;
}

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

export function normalizeMembershipSnapshot(value: unknown) {
  if (typeof value !== "object" || value == null) return [];
  const payload = value as Record<string, unknown>;
  if (!Array.isArray(payload.packages)) return [];
  const ids = new Set<string>();
  const tiers = new Set<string>();
  const result: PublicMembershipTier[] = [];
  for (const entry of payload.packages) {
    if (typeof entry !== "object" || entry == null) continue;
    const row = entry as Record<string, unknown>;
    const id = boundedString(row.id, 200);
    const tier = boundedString(row.tier, 40) as PublicMembershipTier["tier"];
    const title = boundedString(row.title, 160);
    const description = boundedString(row.description, 1_000);
    const sortOrder = Number(row.sortOrder);
    const annualPrice = Number(row.annualPrice);
    const perks = Array.isArray(row.perks)
      ? row.perks
          .map((perk) => boundedString(perk, 200))
          .filter(Boolean)
          .slice(0, 4)
      : [];
    if (
      !id ||
      ![
        "ingenzi-imanzi",
        "inyamibwa",
        "imena",
        "bronze",
        "silver",
        "gold",
      ].includes(tier) ||
      !title ||
      !description ||
      !Number.isInteger(sortOrder) ||
      sortOrder < 0 ||
      sortOrder > 1_000_000 ||
      !Number.isSafeInteger(annualPrice) ||
      annualPrice <= 0 ||
      annualPrice > 1_000_000_000_000 ||
      perks.length === 0 ||
      ids.has(id) ||
      tiers.has(tier)
    ) {
      continue;
    }
    ids.add(id);
    tiers.add(tier);
    result.push({
      id,
      tier,
      title,
      description,
      sortOrder,
      annualPrice,
      perks,
    });
    if (result.length === 6) break;
  }
  return result.sort((a, b) => a.sortOrder - b.sortOrder);
}

export function resolveMembershipCopy(locale: string) {
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
    return `${value.toLocaleString()} ${currencyCode}`;
  }
}

export function MembershipSurface(props: MembershipSurfaceProps) {
  return (
    <ClubMembershipSurface
      key={`${props.clubId ?? 24}:${props.countryCode ?? "RW"}:${props.currencyCode ?? "RWF"}`}
      {...props}
    />
  );
}

function ClubMembershipSurface({
  locale,
  clubShortName,
  clubId = 24,
  countryCode = "RW",
  currencyCode = "RWF",
  fanAppHref,
  hasExternalAppUrl,
}: MembershipSurfaceProps) {
  const [paymentBusy, setPaymentBusy] = useState(false);
  const [paymentMessage, setPaymentMessage] = useState<string | null>(null);
  const [paymentReview, setPaymentReview] = useState<CatalogPaymentReview | null>(null);
  const reviewHeading = useRef<HTMLHeadingElement>(null);
  const [memberRefresh, setMemberRefresh] = useState(0);
  const paymentRequest = useRef(0);
  const paymentInFlight = useRef<number | null>(null);
  const paymentPolling = useRef<ReturnType<typeof setInterval> | null>(null);
  useEffect(() => {
    const lifecycle = paymentRequest;
    const refresh = () => { if (document.visibilityState === "visible") setMemberRefresh(value => value + 1); };
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      lifecycle.current++;
      paymentInFlight.current = null;
      setPaymentBusy(false);
      if (paymentPolling.current) clearInterval(paymentPolling.current);
      window.removeEventListener("focus", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, [clubId]);
  useEffect(() => {
    if (paymentReview) reviewHeading.current?.focus();
  }, [paymentReview]);
  function selectTier(tier: PublicMembershipTier) {
    paymentRequest.current++;
    setPaymentReview(null);
    setPaymentMessage(null);
    setSelectedId(tier.id);
    setInteraction("selected");
  }
  async function reviewTier(tier: PublicMembershipTier) {
    if (paymentInFlight.current === paymentRequest.current) return;
    setSelectedId(tier.id);
    setInteraction("selected");
    const client = getBrowserSupabase();
    if (!client) { setPaymentMessage("Member payments are unavailable. Try again when connected."); return; }
    const request = ++paymentRequest.current;
    paymentInFlight.current = request;
    setPaymentBusy(true);
    setPaymentMessage(null);
    try {
      const review = await preparePaidMembership(client, tier.tier, clubId, currencyCode, () => request === paymentRequest.current);
      if (request !== paymentRequest.current || !review) return;
      setPaymentReview({ ...review, catalogTitle: tier.title, catalogPrice: tier.annualPrice });
    } catch (error) {
      if (request !== paymentRequest.current) return;
      setPaymentMessage(error instanceof Error && error.message === "MEMBER_AUTH_REQUIRED"
        ? "Sign in above, then review your selected tier."
        : "Payment instructions could not be verified. No dialer was opened. Refresh the tiers or try again when connected.");
    } finally {
      if (paymentInFlight.current === request) paymentInFlight.current = null;
      if (request === paymentRequest.current) setPaymentBusy(false);
    }
  }
  async function confirmPayment() {
    if (!paymentReview || paymentInFlight.current === paymentRequest.current) return;
    const client = getBrowserSupabase();
    if (!client) { setPaymentMessage("Member payments are unavailable. Try again when connected."); return; }
    const request = ++paymentRequest.current;
    paymentInFlight.current = request;
    setPaymentBusy(true);
    setPaymentMessage(null);
    try {
      const launched = await confirmPaidMembership(client, paymentReview,
        href => window.location.assign(href), () => request === paymentRequest.current);
      if (request !== paymentRequest.current || !launched) return;
      setPaymentReview(null);
      setPaymentMessage("MoMo was opened. Payment is not confirmed. Check your member area for the matched result before paying again.");
      if (paymentPolling.current) clearInterval(paymentPolling.current);
      let checks = 0;
      paymentPolling.current = setInterval(() => {
        if (document.visibilityState === "visible") setMemberRefresh(value => value + 1);
        if (++checks >= 60 && paymentPolling.current) clearInterval(paymentPolling.current);
      }, 5000);
    } catch (error) {
      if (request !== paymentRequest.current) return;
      if (error instanceof MembershipPaymentChangedError) {
        setPaymentReview({ ...error.review, catalogTitle: paymentReview.catalogTitle, catalogPrice: paymentReview.catalogPrice });
        setPaymentMessage("Payment instructions changed. Review the updated details and confirm again. No dialer was opened.");
        return;
      }
      setPaymentReview(null);
      setPaymentMessage(error instanceof Error && error.message === "MEMBER_AUTH_REQUIRED"
        ? "Your account changed or signed out. Sign in above and review the tier again."
        : "Payment could not be opened. No payment is confirmed. Check your member area before reviewing the tier again.");
    } finally {
      if (paymentInFlight.current === request) paymentInFlight.current = null;
      if (request === paymentRequest.current) setPaymentBusy(false);
    }
  }
  const copy = useMemo(() => localizedCopy(locale), [locale]);
  const [packages, setPackages] = useState<PublicMembershipTier[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState<FixturesSurfaceStatus>("loading");
  const [interaction, setInteraction] = useState<MembershipInteraction>("idle");
  const hasConfirmed = useRef(false);
  const activeRequest = useRef<AbortController | null>(null);
  const isMounted = useRef(true);

  const loadMembership = useCallback(async () => {
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
    }, MEMBERSHIP_TIMEOUT_MS);
    try {
      const response = await fetch("/api/public-content?resource=membership", {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      const payload: unknown = await response.json().catch(() => null);
      if (!isMounted.current || activeRequest.current !== controller || controller.signal.aborted) return;
      if (!response.ok) {
        if (!isMounted.current) return;
        if (response.status === 403) {
          paymentRequest.current++;
          setPaymentReview(null);
          setPackages([]);
          setSelectedId(null);
          hasConfirmed.current = false;
        }
        setStatus(resolveFixturesFailureStatus(response.status));
        return;
      }
      if (
        typeof payload !== "object" ||
        payload == null ||
        !("packages" in payload)
      ) {
        if (isMounted.current) setStatus("error");
        return;
      }
      const next = normalizeMembershipSnapshot(payload);
      if (!isMounted.current) return;
      setPackages(next);
      setSelectedId((current) =>
        next.some(({ id }) => id === current) ? current : (next[0]?.id ?? null),
      );
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
  }, []);

  useEffect(() => {
    isMounted.current = true;
    void loadMembership();
    const offline = () => setStatus("offline");
    const online = () => void loadMembership();
    window.addEventListener("offline", offline);
    window.addEventListener("online", online);
    return () => {
      isMounted.current = false;
      activeRequest.current?.abort();
      window.removeEventListener("offline", offline);
      window.removeEventListener("online", online);
    };
  }, [loadMembership]);

  const selected =
    packages.find(({ id }) => id === selectedId) ?? packages[0] ?? null;
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
      className="membership-surface circles-surface"
      data-membership-status={status}
      data-membership-interaction={interaction}
      data-membership-refresh-disabled={isBusy ? "true" : "false"}
    >
      <div className="page-shell section-grid pb-20">
        <header className="circles-hero">
          <div>
            <p className="circles-eyebrow">{copy.eyebrow}</p>
            <h1>{copy.title(clubShortName)}</h1>
            <p className="circles-description">{copy.description(clubShortName)}</p>
          </div>
          <aside
            className="membership-status circles-status"
            data-membership-status={status}
            role={status === "permission_denied" ? "alert" : "status"}
            aria-live="polite"
          >
            {status === "offline" ? (
              <WifiOff aria-hidden="true" />
            ) : (
              <BadgeCheck aria-hidden="true" />
            )}
            <div>
              <p>{message.label}</p>
              <span>{message.detail}</span>
            </div>
          </aside>
          <div className="circles-actions">
            <Link
              href={fanAppHref}
              className="membership-action circles-action circles-action-primary"
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <Smartphone aria-hidden="true" />
              {hasExternalAppUrl ? copy.openApp : copy.appPending}
            </Link>
            <Link
              href="/tickets"
              className="membership-action circles-action circles-action-secondary"
            >
              <Ticket aria-hidden="true" /> {copy.tickets}
            </Link>
            <button
              type="button"
              className="membership-action circles-action circles-action-secondary"
              disabled={isBusy}
              aria-describedby={
                isBusy ? "membership-refresh-disabled" : undefined
              }
              onClick={() => void loadMembership()}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("idle")}
              onPointerDown={press}
              onPointerUp={() => setInteraction("idle")}
              onPointerCancel={() => setInteraction("idle")}
            >
              <RefreshCw aria-hidden="true" />
              {isRecovery ? copy.retry : copy.refresh}
            </button>
            <span id="membership-refresh-disabled" className="sr-only">
              {copy.refreshDisabled}
            </span>
          </div>
          <dl className="circles-stats">
            <div>
              <dt>{copy.tiers}</dt>
              <dd>{packages.length}</dd>
            </div>
            <div>
              <dt>{copy.paidPlans}</dt>
              <dd>
                {packages.filter(({ annualPrice }) => annualPrice > 0).length}
              </dd>
            </div>
            <div>
              <dt>{copy.selected}</dt>
              <dd>{selected?.title ?? "—"}</dd>
            </div>
          </dl>
        </header>

        <MemberPortal refreshKey={memberRefresh} clubId={clubId} clubShortName={clubShortName} countryCode={countryCode} currencyCode={currencyCode} />

        {paymentMessage ? <p role="status">{paymentMessage}</p> : null}
        {isRecovery ? (
          <aside className="circles-recovery" role="status">
            <strong>{message.label}</strong>
            <span>{message.detail}</span>
          </aside>
        ) : null}

        <section className="circles-content" aria-busy={isBusy}>
          <h2 id="membership-tiers" tabIndex={-1}>{copy.directory}</h2>
          {paymentReview && paymentReview.clubId === clubId ? (
            <section className="circles-featured" aria-labelledby="membership-payment-review-title">
              <div>
                <h3 id="membership-payment-review-title" ref={reviewHeading} tabIndex={-1}>Review membership payment</h3>
                <p>{paymentReview.catalogTitle} · {clubShortName}</p>
                {paymentReview.amount !== paymentReview.catalogPrice ? (
                  <p role="status">The payment amount changed from the catalog price of {formatPrice(paymentReview.catalogPrice, paymentReview.currency)} to {formatPrice(paymentReview.amount, paymentReview.currency)}. Confirm only if you agree to the updated amount.</p>
                ) : null}
                <dl className="circles-featured-stats">
                  <div><dt>Amount</dt><dd>{formatPrice(paymentReview.amount, paymentReview.currency)}</dd></div>
                  <div><dt>Currency</dt><dd>{paymentReview.currency}</dd></div>
                  <div><dt>Recipient code</dt><dd>{paymentReview.recipientCode}</dd></div>
                  <div><dt>Payment country</dt><dd>{paymentReview.country}</dd></div>
                  <div><dt>Dialer instruction</dt><dd>{paymentReview.ussdCode}</dd></div>
                </dl>
                <p>Payment request: {paymentReview.id}</p>
                <p>Opening MoMo does not confirm payment. Your membership updates only after the payment is matched.</p>
                <button type="button" disabled={paymentBusy} onClick={() => void confirmPayment()} className="membership-action circles-action circles-action-primary">
                  {paymentBusy ? "Checking payment instructions…" : "Confirm and open MoMo"}
                </button>
                <button type="button" disabled={paymentBusy} className="membership-action circles-action circles-action-secondary" onClick={() => {
                  paymentRequest.current++; setPaymentReview(null); setPaymentMessage("Payment review closed. No dialer was opened. A prepared request does not confirm payment.");
                }}>Cancel payment review</button>
              </div>
            </section>
          ) : null}
          {selected ? (
            <article className="circles-featured">
              <span className="circles-featured-mark" aria-hidden="true">
                <BadgeCheck />
              </span>
              <div>
                <p className="circles-eyebrow">{copy.selectedTier}</p>
                <h2>{selected.title}</h2>
                <p>{selected.description}</p>
                <dl className="circles-featured-stats">
                  <div>
                    <dt>{copy.annualPrice}</dt>
                    <dd>{formatPrice(selected.annualPrice, currencyCode)}</dd>
                  </div>
                  <div>
                    <dt>{copy.included}</dt>
                    <dd>{selected.perks.length}</dd>
                  </div>
                  <div>
                    <dt>{copy.tiers}</dt>
                    <dd>{selected.tier}</dd>
                  </div>
                </dl>
                <ul className="circles-membership-perks">
                  {selected.perks.map((perk) => (
                    <li key={perk}>
                      <ShieldCheck aria-hidden="true" />
                      {perk}
                    </li>
                  ))}
                </ul>
                <button type="button" disabled={isBusy || paymentBusy}
                  onClick={() => void reviewTier(selected)}
                  className="membership-action circles-action circles-action-primary">
                  {paymentBusy ? "Preparing payment review…" : `Review payment for ${selected.title}`}
                  <ArrowRight aria-hidden="true" />
                </button>
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
              <BadgeCheck aria-hidden="true" />
              <h2>{copy.noTiers}</h2>
              <p>{copy.noTiersDetail}</p>
            </div>
          )}

          {packages.length > 0 ? (
            <section className="circles-campaigns">
              <header>
                <div>
                  <p className="circles-eyebrow">{copy.tiers}</p>
                  <h2>{copy.directory}</h2>
                </div>
                <p>{copy.directoryDetail}</p>
              </header>
              <div className="circles-grid">
                {packages.map((membershipPackage) => (
                  <button
                    type="button"
                    key={membershipPackage.id}
                    className="membership-card circles-card"
                    aria-pressed={membershipPackage.id === selected?.id}
                    disabled={isBusy || paymentBusy}
                    onClick={() => selectTier(membershipPackage)}
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
                      <BadgeCheck />
                    </span>
                    <span>
                      <strong>{membershipPackage.title}</strong>
                      <small>
                        {formatPrice(membershipPackage.annualPrice, currencyCode)}
                        {" · "}
                        {membershipPackage.perks.length} {copy.included}
                      </small>
                    </span>
                    <ArrowRight aria-hidden="true" />
                  </button>
                ))}
              </div>
            </section>
          ) : null}
        </section>

        <aside className="circles-boundary">
          <ShieldCheck aria-hidden="true" />
          <div>
            <p className="circles-eyebrow">{copy.boundaryEyebrow}</p>
            <h2>{copy.boundaryTitle}</h2>
            <p>{copy.boundaryDetail}</p>
          </div>
        </aside>
      </div>
    </section>
  );
}
