"use client";

import {
  ArrowRight,
  BadgeCheck,
  Check,
  Copy,
  LoaderCircle,
  LockKeyhole,
  LogOut,
  Phone,
  RefreshCw,
  ShieldCheck,
  Smartphone,
  WalletCards,
} from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
import { getBrowserSupabase } from "@/lib/supabase/browser";
import {
  boundedMemberRequest,
  isMemberSignOutPending,
  memberSignOutStorageKey,
  setMemberSignOutPending,
} from "@/lib/member-session";

type AuthStep = "loading" | "unavailable" | "signout" | "phone" | "otp" | "join" | "member";

type MemberRecord = {
  club_id: number;
  member_code: string;
  membership_number: string;
  tier: string;
  status: string;
  joined_at: string;
};

type Initiative = {
  id: string;
  title: string;
  description: string | null;
  raised_amount: number;
  goal_amount: number;
};

type Contribution = {
  id: string;
  initiative_id: string;
  amount: number;
  status: "pending" | "confirmed" | "failed" | "cancelled";
  momo_reference: string | null;
  created_at: string;
  confirmed_at: string | null;
};

type ContributionIntent = {
  contribution_id: string;
  amount: number;
  status: string;
  momo_reference: string;
  created_at: string;
  ussd_code: string;
};

type MemberPortalProps = {
  refreshKey?: number;
  clubShortName: string;
  clubId?: number;
  countryCode?: string;
  currencyCode?: string;
};

const amountPresets = [1_000, 5_000, 10_000, 25_000];

export function normalizeRwandaPhone(value: string) {
  const digits = value.replace(/\D/g, "");
  if (/^2507\d{8}$/.test(digits)) return `+${digits}`;
  if (/^07\d{8}$/.test(digits)) return `+250${digits.slice(1)}`;
  if (/^7\d{8}$/.test(digits)) return `+250${digits}`;
  return null;
}

export function normalizeMemberPhone(value: string, countryCode: string) {
  if (countryCode === "RW") {
    const national = normalizeRwandaPhone(value);
    if (national) return national;
  }
  // International access also supports supporters living outside the club's
  // country. Auth verifies ownership; the phone prefix never selects a club.
  const normalized = value.trim().replace(/[ ()-]/g, "").replace(/^00/, "+");
  return /^\+[1-9]\d{7,14}$/.test(normalized) ? normalized : null;
}

export function buildUssdTelHref(ussdCode: string) {
  if (!/^\*[0-9*]+#$/.test(ussdCode)) return null;
  return `tel:${ussdCode.replace(/#/g, "%23")}`;
}

type HistoryCursor = { created_at: string; id: string };
type ContributionHistory = {
  confirmedTotal: bigint;
  entries: Contribution[];
  nextCursor: HistoryCursor | null;
};

export function parseContributionHistory(value: unknown): ContributionHistory {
  if (!value || typeof value !== "object") throw new Error("Invalid contribution history.");
  const raw = value as Record<string, unknown>;
  if (typeof raw.confirmed_total !== "string" || !/^-?\d{1,19}$/.test(raw.confirmed_total) ||
      !Array.isArray(raw.entries) || raw.entries.length > 20) {
    throw new Error("Invalid contribution total or page.");
  }
  const validDate = (date: unknown): date is string =>
    typeof date === "string" && Number.isFinite(Date.parse(date));
  const validId = (id: unknown): id is string =>
    typeof id === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
  const ids = new Set<string>();
  for (const entry of raw.entries) {
    if (!entry || typeof entry !== "object" || !validId(entry.id) || ids.has(entry.id) ||
        !validId(entry.initiative_id) || !Number.isSafeInteger(entry.amount) ||
        !["pending", "confirmed", "failed", "cancelled"].includes(entry.status) ||
        !validDate(entry.created_at) || (entry.confirmed_at !== null && !validDate(entry.confirmed_at)) ||
        (entry.momo_reference !== null && typeof entry.momo_reference !== "string")) {
      throw new Error("Invalid contribution entry.");
    }
    ids.add(entry.id);
  }
  if (raw.next_cursor !== null) {
    const cursor = raw.next_cursor as HistoryCursor | undefined;
    const last = raw.entries.at(-1);
    if (!cursor || !validId(cursor.id) || !validDate(cursor.created_at) ||
        !last || cursor.id !== last.id || cursor.created_at !== last.created_at) {
      throw new Error("Invalid contribution cursor.");
    }
  }
  return {
    confirmedTotal: BigInt(raw.confirmed_total),
    entries: raw.entries as Contribution[],
    nextCursor: raw.next_cursor as HistoryCursor | null,
  };
}

function formatMemberAmount(value: number | bigint, currencyCode: string) {
  return new Intl.NumberFormat("en", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 0,
  }).format(value);
}

function cleanError(message: string | undefined) {
  const normalized = message?.toLowerCase() ?? "";
  if (normalized.includes("rate") || normalized.includes("seconds")) {
    return "Please wait before requesting another code.";
  }
  if (normalized.includes("member_club_mismatch")) {
    return "This account belongs to another club. Sign out and use an account for this club.";
  }
  if (normalized.includes("momo route")) {
    return "The official club MoMo route is not available yet. No payment intent was created.";
  }
  if (normalized.includes("expired") || normalized.includes("invalid")) {
    return "That code is invalid or expired. Request a new one and try again.";
  }
  if (normalized.includes("initiative")) {
    return "This contribution campaign is not accepting payments right now.";
  }
  return "We could not complete that request. Please try again.";
}

export function MemberPortal({ refreshKey = 0, clubShortName, clubId = 24, countryCode = "RW", currencyCode = "RWF" }: MemberPortalProps) {
  const initialPhone = countryCode === "RW" ? "+250 " : "";
  const [step, setStep] = useState<AuthStep>("loading");
  const [phone, setPhone] = useState(initialPhone);
  const [verifiedPhone, setVerifiedPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [member, setMember] = useState<MemberRecord | null>(null);
  const [initiatives, setInitiatives] = useState<Initiative[]>([]);
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [total, setTotal] = useState(() => BigInt(0));
  const [historyCursor, setHistoryCursor] = useState<HistoryCursor | null>(null);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const historyRequest = useRef(false);
  const [selectedInitiative, setSelectedInitiative] = useState("");
  const [amount, setAmount] = useState("5000");
  const [intent, setIntent] = useState<ContributionIntent | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const identity = useRef<string | null>(null);
  const identityVersion = useRef(0);
  const loadVersion = useRef(0);

  const clearPrivateState = useCallback(() => {
    identityVersion.current += 1;
    loadVersion.current += 1;
    setMember(null);
    setContributions([]);
    setTotal(BigInt(0));
    setHistoryCursor(null);
    setLoadingHistory(false);
    historyRequest.current = false;
    setInitiatives([]);
    setSelectedInitiative("");
    setIntent(null);
    setOtp("");
    setVerifiedPhone("");
    setCopied(false);
    setBusy(false);
    setMessage(null);
  }, []);

  const loadMemberArea = useCallback(async () => {
    if (isMemberSignOutPending()) {
      setStep("signout");
      setMessage("Sign-out is not confirmed. Retry when connected to finish signing out.");
      return;
    }
    const version = ++loadVersion.current;
    historyRequest.current = false;
    setLoadingHistory(false);
    const isCurrent = () => version === loadVersion.current;
    const supabase = getBrowserSupabase();
    if (!supabase) {
      setStep("unavailable");
      setMessage("Secure member access is not configured in this preview.");
      return;
    }

    setBusy(true);
    setMessage(null);
    try {
      const { data: userResult, error: userError } = await boundedMemberRequest(supabase.auth.getUser());
      if (!isCurrent()) return;
      if (userError && userError.name !== "AuthSessionMissingError" &&
          userError.status !== 401 && userError.status !== 403) throw userError;
      if (userError || !userResult.user) {
        identity.current = null;
        clearPrivateState();
        setStep("phone");
        return;
      }
      identity.current = userResult.user.id;

      const membershipResult = await boundedMemberRequest(supabase
        .from("fan_memberships")
        .select("club_id,member_code,membership_number,tier,status,joined_at,updated_at")
        .eq("user_id", userResult.user.id)
        .eq("club_id", clubId)
        .eq("status", "active")
        .eq("payment_status", "verified")
        .neq("tier", "fan")
        .gt("expires_at", new Date().toISOString())
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle());
      if (!isCurrent()) return;
      if (membershipResult.error) throw membershipResult.error;
      if (!membershipResult.data) {
        clearPrivateState();
        setStep("join");
        return;
      }
      const confirmedMember = membershipResult.data as MemberRecord;
      if (!Number.isSafeInteger(confirmedMember.club_id)) {
        throw new Error("Membership club is unavailable.");
      }

      if (confirmedMember.club_id !== clubId) {
        clearPrivateState();
        setStep("unavailable");
        setMessage("This membership belongs to another club. Sign out and use an account for this club.");
        return;
      }

      const [initiativeResult, contributionResult] = await boundedMemberRequest(Promise.all([
        supabase
          .from("initiatives")
          .select("id,title,description,raised_amount,goal_amount")
          .eq("club_id", confirmedMember.club_id)
          .eq("is_active", true)
          .eq("status", "active")
          .order("created_at", { ascending: false })
          .limit(6),
        supabase.rpc("member_contribution_history"),
      ]));
      if (!isCurrent()) return;
      if (initiativeResult.error) throw initiativeResult.error;
      if (contributionResult.error) throw contributionResult.error;

      const history = parseContributionHistory(contributionResult.data);
      const confirmedInitiatives = (initiativeResult.data ?? []) as Initiative[];
      setMember(confirmedMember);
      setInitiatives(confirmedInitiatives);
      setContributions(history.entries);
      setTotal(history.confirmedTotal);
      setHistoryCursor(history.nextCursor);
      setSelectedInitiative((current) =>
        confirmedInitiatives.some((initiative) => initiative.id === current)
          ? current
          : confirmedInitiatives[0]?.id ?? "",
      );
      setStep("member");
    } catch (error) {
      if (!isCurrent()) return;
      const code = error && typeof error === "object" && "message" in error ? String(error.message) : "";
      setMessage(code.includes("MEMBER_CLUB_MISMATCH") ? cleanError(code) : "Member information could not be refreshed. Previously confirmed information is unchanged. Please retry.");
      setStep((current) => current === "member" ? current : "unavailable");
    } finally {
      if (isCurrent()) setBusy(false);
    }
  }, [clearPrivateState, clubId]);

  useEffect(() => {
    if (refreshKey > 0) void loadMemberArea();
  }, [refreshKey, loadMemberArea]);

  useEffect(() => {
    const supabase = getBrowserSupabase();
    let reload: ReturnType<typeof setTimeout> | undefined;
    const subscription = supabase?.auth.onAuthStateChange((event: AuthChangeEvent, session: Session | null) => {
      if (event === "INITIAL_SESSION") return;
      if (event === "SIGNED_OUT") setMemberSignOutPending(false);
      else if (isMemberSignOutPending()) return;
      const nextIdentity = session?.user.id ?? null;
      if (event !== "SIGNED_OUT" && nextIdentity === identity.current) return;
      identity.current = nextIdentity;
      clearPrivateState();
      clearTimeout(reload);
      setStep(nextIdentity ? "loading" : "phone");
      // Auth callbacks run under the client's session lock. Load after it releases.
      if (nextIdentity) reload = setTimeout(() => void loadMemberArea(), 0);
    }).data.subscription;
    const onStorage = (event: StorageEvent) => {
      if (event.key !== memberSignOutStorageKey) return;
      identity.current = null;
      clearPrivateState();
      setStep(isMemberSignOutPending() ? "signout" : "phone");
    };
    window.addEventListener("storage", onStorage);
    void loadMemberArea();
    return () => {
      window.removeEventListener("storage", onStorage);
      clearTimeout(reload);
      loadVersion.current += 1;
      identityVersion.current += 1;
      subscription?.unsubscribe();
    };
  }, [clearPrivateState, loadMemberArea]);

  async function loadOlderContributions() {
    const supabase = getBrowserSupabase();
    if (!supabase || !historyCursor || historyRequest.current) return;
    const version = loadVersion.current;
    historyRequest.current = true;
    setLoadingHistory(true);
    setMessage(null);
    try {
      const result = await boundedMemberRequest(supabase.rpc("member_contribution_history", {
        p_before_created_at: historyCursor.created_at,
        p_before_id: historyCursor.id,
      }));
      if (version !== loadVersion.current) return;
      if (result.error) throw result.error;
      const history = parseContributionHistory(result.data);
      setContributions((current) => {
        const ids = new Set(current.map((entry) => entry.id));
        return [...current, ...history.entries.filter((entry) => !ids.has(entry.id))];
      });
      setTotal(history.confirmedTotal);
      setHistoryCursor(history.nextCursor);
    } catch {
      if (version === loadVersion.current) {
        setMessage("Older contributions could not be loaded. Your confirmed information is unchanged. Please retry.");
      }
    } finally {
      if (version === loadVersion.current) {
        historyRequest.current = false;
        setLoadingHistory(false);
      }
    }
  }

  async function requestOtp() {
    const normalizedPhone = normalizeMemberPhone(phone, countryCode);
    if (!normalizedPhone) {
      setMessage("Enter your WhatsApp number in international format, including + and the country code.");
      return;
    }

    const supabase = getBrowserSupabase();
    if (!supabase) {
      setMessage("Secure WhatsApp sign-in is not configured in this preview.");
      return;
    }

    setBusy(true);
    setMessage(null);
    const version = identityVersion.current;
    try {
      const { error } = await boundedMemberRequest(supabase.auth.signInWithOtp({
        phone: normalizedPhone,
        options: { channel: "whatsapp", shouldCreateUser: true },
      }));
      if (version !== identityVersion.current) return;
      if (error) {
        setMessage(cleanError(error.message));
        return;
      }
      setVerifiedPhone(normalizedPhone);
      setStep("otp");
    } catch {
      if (version === identityVersion.current) {
        setMessage("The code request could not be confirmed. Please retry when connected.");
      }
    } finally {
      if (version === identityVersion.current) setBusy(false);
    }
  }

  async function verifyOtp() {
    if (!/^\d{6}$/.test(otp)) {
      setMessage("Enter the six-digit code sent to WhatsApp.");
      return;
    }
    const supabase = getBrowserSupabase();
    if (!supabase) return;

    setBusy(true);
    setMessage(null);
    const version = identityVersion.current;
    try {
      const { error } = await boundedMemberRequest(supabase.auth.verifyOtp({
        phone: verifiedPhone,
        token: otp,
        type: "sms",
      }));
      if (version !== identityVersion.current) return;
      if (error) {
        setMessage(cleanError(error.message));
        return;
      }
      await loadMemberArea();
    } catch {
      if (version === identityVersion.current) {
        setMessage("Verification could not be confirmed. Please retry when connected.");
      }
    } finally {
      if (version === identityVersion.current) setBusy(false);
    }
  }

  async function createContribution() {
    const parsedAmount = /^\d+$/.test(amount.trim()) ? Number(amount) : Number.NaN;
    if (!selectedInitiative || !Number.isSafeInteger(parsedAmount)) {
      setMessage("Choose a club campaign and enter a contribution amount.");
      return;
    }
    if (parsedAmount < 100 || parsedAmount > 5_000_000) {
      setMessage(`Choose an amount between 100 and 5,000,000 ${currencyCode}.`);
      return;
    }

    const supabase = getBrowserSupabase();
    if (!supabase) return;
    setBusy(true);
    setMessage(null);
    setIntent(null);
    const version = identityVersion.current;
    try {
      const { data, error } = await boundedMemberRequest(supabase.rpc(
        "create_member_contribution_intent",
        {
          p_initiative_id: selectedInitiative,
          p_amount: parsedAmount,
        },
      ));
      if (version !== identityVersion.current) return;
      if (error || !data?.[0]) {
        setMessage(cleanError(error?.message));
        return;
      }

      const nextIntent = data[0] as ContributionIntent;
      const telHref = buildUssdTelHref(nextIntent.ussd_code);
      if (!telHref) {
        setMessage("The official club MoMo route could not be validated.");
        return;
      }
      setIntent(nextIntent);
      window.location.assign(telHref);
    } catch {
      if (version === identityVersion.current) {
        setMessage("The contribution request could not be confirmed. Check your history, then retry the same amount when connected.");
      }
    } finally {
      if (version === identityVersion.current) setBusy(false);
    }
  }

  async function signOut() {
    setMemberSignOutPending(true);
    identity.current = null;
    clearPrivateState();
    setPhone(initialPhone);
    setStep("signout");
    setBusy(true);
    const version = identityVersion.current;
    try {
      const supabase = getBrowserSupabase();
      if (!supabase) throw new Error("Member access is unavailable.");
      const { error } = await boundedMemberRequest(supabase.auth.signOut());
      if (error) throw error;
      setMemberSignOutPending(false);
      if (version === identityVersion.current) setStep("phone");
    } catch {
      if (version === identityVersion.current) {
        setMessage("Sign-out is not confirmed. Your member area remains locked. Retry when connected.");
      }
    } finally {
      if (version === identityVersion.current) setBusy(false);
    }
  }

  async function copyMemberCode() {
    if (!member?.member_code || !navigator.clipboard) return;
    await navigator.clipboard.writeText(member.member_code);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1_600);
  }

  return (
    <section className="member-portal" aria-labelledby="member-portal-title">
      <div className="member-portal-intro">
        <p className="member-portal-kicker">{clubId === 24 ? "Gikundiro" : clubShortName} member area</p>
        <h2 id="member-portal-title">{clubId === 24 ? "Your place in the Blue Wall." : `Your place at ${clubShortName}.`}</h2>
        <p>
          WhatsApp is your key. Sign in once to receive a private six-digit
          member number, see confirmed contributions, and support {clubShortName}{" "}
          through the official MoMo route.
        </p>
        <div className="member-trust-row" aria-label="Member portal safeguards">
          <span><ShieldCheck aria-hidden="true" /> WhatsApp OTP</span>
          <span><LockKeyhole aria-hidden="true" /> Private record</span>
          <span><BadgeCheck aria-hidden="true" /> External confirmation</span>
        </div>
      </div>

      <div className="member-portal-panel">
        {step === "loading" ? <p role="status">Loading your member area…</p> : null}
        {step === "signout" ? (
          <div className="member-auth-form">
            <h3>Finish signing out</h3>
            <p>Your private member information is hidden while sign-out is pending.</p>
            <button className="member-primary-action" type="button" disabled={busy} onClick={() => void signOut()}>
              {busy ? "Signing out…" : "Retry sign out"}
            </button>
          </div>
        ) : null}
        {step === "unavailable" ? (
          <div className="member-auth-form">
            <h3>Member area unavailable</h3>
            <button className="member-primary-action" type="button" disabled={busy} onClick={() => void loadMemberArea()}>
              Retry member area
            </button>
            <button className="member-text-action" type="button" onClick={() => void signOut()}>
              Sign out
            </button>
          </div>
        ) : null}
        {step === "phone" ? (
          <form
            className="member-auth-form"
            onSubmit={(event) => {
              event.preventDefault();
              void requestOtp();
            }}
          >
            <span className="member-step">01 / Secure access</span>
            <h3>Enter your WhatsApp number</h3>
            <p>We’ll send a one-time code via WhatsApp.</p>
            <label htmlFor="member-phone">WhatsApp number</label>
            <div className="member-input-shell">
              <Phone aria-hidden="true" />
              <input
                id="member-phone"
                type="tel"
                inputMode="tel"
                autoComplete="tel"
                value={phone}
                onChange={(event) => setPhone(event.target.value.slice(0, 24))}
                placeholder={countryCode === "RW" ? "+250 788 123 456" : "+country code and number"}
                required
              />
            </div>
            <button className="member-primary-action" type="submit" disabled={busy}>
              {busy ? <LoaderCircle className="member-spinner" aria-hidden="true" /> : <Smartphone aria-hidden="true" />}
              Send code on WhatsApp
              <ArrowRight aria-hidden="true" />
            </button>
          </form>
        ) : null}

        {step === "otp" ? (
          <form
            className="member-auth-form"
            onSubmit={(event) => {
              event.preventDefault();
              void verifyOtp();
            }}
          >
            <span className="member-step">02 / Verification</span>
            <h3>Enter your WhatsApp code</h3>
            <p>We sent a six-digit code via WhatsApp to {verifiedPhone}.</p>
            <label htmlFor="member-otp">WhatsApp verification code</label>
            <input
              id="member-otp"
              className="member-otp-input"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6}"
              maxLength={6}
              value={otp}
              onChange={(event) => setOtp(event.target.value.replace(/\D/g, ""))}
              placeholder="000000"
              required
            />
            <button className="member-primary-action" type="submit" disabled={busy}>
              {busy ? <LoaderCircle className="member-spinner" aria-hidden="true" /> : <LockKeyhole aria-hidden="true" />}
              Verify code
            </button>
            <button className="member-text-action" type="button" onClick={() => setStep("phone")}>
              Use another number
            </button>
          </form>
        ) : null}

        {step === "join" ? (
          <div className="member-auth-form">
            <span className="member-step">02 / Membership activation</span>
            <h3>{clubId === 24 ? "Join the Blue Wall" : `Join ${clubShortName}`}</h3>
            <p>
              Choose a paid {clubShortName} membership tier. Your membership
              activates automatically when your payment is matched.
            </p>
            <a className="member-primary-action" href="/membership">
              Choose a membership tier
              <ArrowRight aria-hidden="true" />
            </a>
            <button className="member-text-action" type="button" onClick={() => void signOut()}>
              Sign out instead
            </button>
          </div>
        ) : null}

        {step === "member" && member ? (
          <div className="member-dashboard">
            <header className="member-dashboard-header">
              <div>
                <span className="member-step">Active member</span>
                <h3>Welcome.</h3>
              </div>
              <button type="button" className="member-icon-action" onClick={() => void signOut()} aria-label="Sign out of member area">
                <LogOut aria-hidden="true" />
              </button>
            </header>

            <div className="member-code-card">
              <div>
                <span>Membership number</span>
                <strong>{member.member_code}</strong>
              </div>
              <button type="button" onClick={() => void copyMemberCode()}>
                {copied ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
                {copied ? "Copied" : "Copy"}
              </button>
            </div>

            <dl className="member-metrics">
              <div><dt>Status</dt><dd>{member.status}</dd></div>
              <div><dt>Tier</dt><dd>{member.tier}</dd></div>
              <div><dt>Total confirmed</dt><dd>{formatMemberAmount(total, currencyCode)}</dd></div>
            </dl>

            <div className="member-contribution-card">
              <div className="member-contribution-heading">
                <div>
                  <span className="member-step">Support the team</span>
                  <h4>Contribute with MoMo</h4>
                </div>
                <WalletCards aria-hidden="true" />
              </div>
              <label htmlFor="member-initiative">Club campaign</label>
              <select
                id="member-initiative"
                value={selectedInitiative}
                onChange={(event) => setSelectedInitiative(event.target.value)}
                disabled={initiatives.length === 0}
              >
                {initiatives.length === 0 ? <option value="">No active campaign confirmed</option> : null}
                {initiatives.map((initiative) => (
                  <option value={initiative.id} key={initiative.id}>{initiative.title}</option>
                ))}
              </select>
              <label htmlFor="member-amount">Amount in {currencyCode}</label>
              <input
                id="member-amount"
                type="number"
                inputMode="numeric"
                min={100}
                max={5_000_000}
                step={1}
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
              />
              <div className="member-amount-presets" aria-label="Contribution amount presets">
                {amountPresets.map((preset) => (
                  <button type="button" key={preset} aria-pressed={amount === String(preset)} onClick={() => setAmount(String(preset))}>
                    {formatMemberAmount(preset, currencyCode)}
                  </button>
                ))}
              </div>
              <button
                type="button"
                className="member-primary-action"
                disabled={busy || initiatives.length === 0}
                onClick={() => void createContribution()}
              >
                {busy ? <LoaderCircle className="member-spinner" aria-hidden="true" /> : <Phone aria-hidden="true" />}
                Open official MoMo dialer
                <ArrowRight aria-hidden="true" />
              </button>
              <p className="member-payment-note">
                The payment happens in your phone dialer. This website records a
                pending intent only; your total changes after independent club
                confirmation.
              </p>
            </div>

            {intent ? (
              <aside className="member-pending-state" role="status">
                <LoaderCircle className="member-spinner" aria-hidden="true" />
                <div>
                  <strong>Waiting for external confirmation</strong>
                  <span>Reference {intent.momo_reference}</span>
                </div>
                <button type="button" onClick={() => void loadMemberArea()}>
                  <RefreshCw aria-hidden="true" /> Refresh
                </button>
              </aside>
            ) : null}

            <section className="member-history" aria-labelledby="member-history-title">
              <div className="member-history-heading">
                <div>
                  <span className="member-step">Your record</span>
                  <h4 id="member-history-title">Contribution history</h4>
                </div>
                <button type="button" className="member-icon-action" onClick={() => void loadMemberArea()} aria-label="Refresh contribution history">
                  <RefreshCw aria-hidden="true" />
                </button>
              </div>
              {contributions.length === 0 ? (
                <p className="member-empty-history">No contribution intents recorded yet.</p>
              ) : (
                <ul>
                  {contributions.map((entry) => (
                    <li key={entry.id}>
                      <span className={`member-status-dot member-status-${entry.status}`} aria-hidden="true" />
                      <div>
                        <strong>{formatMemberAmount(entry.amount, currencyCode)}</strong>
                        <span>{entry.momo_reference ?? "Reference pending"}</span>
                      </div>
                      <em>{entry.status}</em>
                    </li>
                  ))}
                </ul>
              )}
              <p className="member-payment-note" role="status">
                Showing {contributions.length} contribution records.
              </p>
              {historyCursor ? (
                <button type="button" className="member-text-action" disabled={busy || loadingHistory} onClick={() => void loadOlderContributions()}>
                  {loadingHistory ? "Loading older contributions…" : "Load older contributions"}
                </button>
              ) : null}
            </section>
          </div>
        ) : null}

        {message ? <p className="member-message" role="alert">{message}</p> : null}
      </div>
    </section>
  );
}
