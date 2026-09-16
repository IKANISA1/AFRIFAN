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
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
import { getBrowserSupabase } from "@/lib/supabase/browser";

type AuthStep = "loading" | "unavailable" | "phone" | "otp" | "join" | "member";

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
  clubShortName: string;
};

const amountPresets = [1_000, 5_000, 10_000, 25_000];

export function normalizeRwandaPhone(value: string) {
  const digits = value.replace(/\D/g, "");
  if (/^2507\d{8}$/.test(digits)) return `+${digits}`;
  if (/^07\d{8}$/.test(digits)) return `+250${digits.slice(1)}`;
  if (/^7\d{8}$/.test(digits)) return `+250${digits}`;
  return null;
}

export function buildUssdTelHref(ussdCode: string) {
  if (!/^\*[0-9*]+#$/.test(ussdCode)) return null;
  return `tel:${ussdCode.replace(/#/g, "%23")}`;
}

export function confirmedContributionTotal(contributions: Contribution[]) {
  return contributions
    .filter((entry) => entry.status === "confirmed")
    .reduce((total, entry) => total + entry.amount, 0);
}

function formatRwf(value: number) {
  return new Intl.NumberFormat("en-RW", {
    style: "currency",
    currency: "RWF",
    maximumFractionDigits: 0,
  }).format(value);
}

function cleanError(message: string | undefined) {
  const normalized = message?.toLowerCase() ?? "";
  if (normalized.includes("rate") || normalized.includes("seconds")) {
    return "Please wait before requesting another code.";
  }
  if (normalized.includes("expired") || normalized.includes("invalid")) {
    return "That code is invalid or expired. Request a new one and try again.";
  }
  if (normalized.includes("momo route")) {
    return "The official club MoMo route is not available yet. No payment intent was created.";
  }
  if (normalized.includes("initiative")) {
    return "This contribution campaign is not accepting payments right now.";
  }
  return "We could not complete that request. Please try again.";
}

export function MemberPortal({ clubShortName }: MemberPortalProps) {
  const [step, setStep] = useState<AuthStep>("loading");
  const [phone, setPhone] = useState("+250 ");
  const [verifiedPhone, setVerifiedPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [member, setMember] = useState<MemberRecord | null>(null);
  const [initiatives, setInitiatives] = useState<Initiative[]>([]);
  const [contributions, setContributions] = useState<Contribution[]>([]);
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
    setInitiatives([]);
    setSelectedInitiative("");
    setIntent(null);
    setOtp("");
    setVerifiedPhone("");
    setCopied(false);
    setBusy(false);
    setMessage(null);
  }, []);

  const total = useMemo(
    () => confirmedContributionTotal(contributions),
    [contributions],
  );

  const loadMemberArea = useCallback(async (activateMembership = false) => {
    const version = ++loadVersion.current;
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
      const { data: userResult, error: userError } = await supabase.auth.getUser();
      if (!isCurrent()) return;
      if (userError || !userResult.user) {
        identity.current = null;
        clearPrivateState();
        setStep("phone");
        return;
      }
      identity.current = userResult.user.id;

      if (activateMembership) {
        const activation = await supabase.rpc("activate_free_fan_membership");
        if (!isCurrent()) return;
        if (activation.error) throw activation.error;
      }

      const membershipResult = await supabase
        .from("fan_memberships")
        .select("club_id,member_code,membership_number,tier,status,joined_at,updated_at")
        .eq("user_id", userResult.user.id)
        .eq("status", "active")
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle();
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

      const [initiativeResult, contributionResult] = await Promise.all([
        supabase
          .from("initiatives")
          .select("id,title,description,raised_amount,goal_amount")
          .eq("club_id", confirmedMember.club_id)
          .eq("is_active", true)
          .eq("status", "active")
          .order("created_at", { ascending: false })
          .limit(6),
        supabase
          .from("initiative_contributions")
          .select("id,initiative_id,amount,status,momo_reference,created_at,confirmed_at")
          .eq("club_id", confirmedMember.club_id)
          .eq("user_id", userResult.user.id)
          .order("created_at", { ascending: false })
          .limit(20),
      ]);
      if (!isCurrent()) return;
      if (initiativeResult.error) throw initiativeResult.error;
      if (contributionResult.error) throw contributionResult.error;

      const confirmedInitiatives = (initiativeResult.data ?? []) as Initiative[];
      setMember(confirmedMember);
      setInitiatives(confirmedInitiatives);
      setContributions((contributionResult.data ?? []) as Contribution[]);
      setSelectedInitiative((current) =>
        confirmedInitiatives.some((initiative) => initiative.id === current)
          ? current
          : confirmedInitiatives[0]?.id ?? "",
      );
      setStep("member");
    } catch {
      if (!isCurrent()) return;
      setMessage("Member information could not be refreshed. Previously confirmed information is unchanged. Please retry.");
      setStep((current) => current === "member" ? current : "unavailable");
    } finally {
      if (isCurrent()) setBusy(false);
    }
  }, [clearPrivateState]);

  useEffect(() => {
    const supabase = getBrowserSupabase();
    let reload: ReturnType<typeof setTimeout> | undefined;
    const subscription = supabase?.auth.onAuthStateChange((event: AuthChangeEvent, session: Session | null) => {
      if (event === "INITIAL_SESSION") return;
      const nextIdentity = session?.user.id ?? null;
      if (event !== "SIGNED_OUT" && nextIdentity === identity.current) return;
      identity.current = nextIdentity;
      clearPrivateState();
      clearTimeout(reload);
      setStep(nextIdentity ? "loading" : "phone");
      // Auth callbacks run under the client's session lock. Load after it releases.
      if (nextIdentity) reload = setTimeout(() => void loadMemberArea(false), 0);
    }).data.subscription;
    void loadMemberArea(false);
    return () => {
      clearTimeout(reload);
      loadVersion.current += 1;
      identityVersion.current += 1;
      subscription?.unsubscribe();
    };
  }, [clearPrivateState, loadMemberArea]);

  async function requestOtp() {
    const normalizedPhone = normalizeRwandaPhone(phone);
    if (!normalizedPhone) {
      setMessage("Enter a valid Rwanda WhatsApp number, for example +250 788 123 456.");
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
    const { error } = await supabase.auth.signInWithOtp({
      phone: normalizedPhone,
      options: { channel: "whatsapp", shouldCreateUser: true },
    });
    if (version !== identityVersion.current) return;
    setBusy(false);
    if (error) {
      setMessage(cleanError(error.message));
      return;
    }
    setVerifiedPhone(normalizedPhone);
    setStep("otp");
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
    const { error } = await supabase.auth.verifyOtp({
      phone: verifiedPhone,
      token: otp,
      type: "sms",
    });
    if (version !== identityVersion.current) return;
    if (error) {
      setBusy(false);
      setMessage(cleanError(error.message));
      return;
    }
    await loadMemberArea(false);
  }

  async function createContribution() {
    const parsedAmount = Number.parseInt(amount, 10);
    if (!selectedInitiative || !Number.isInteger(parsedAmount)) {
      setMessage("Choose a club campaign and enter a contribution amount.");
      return;
    }
    if (parsedAmount < 100 || parsedAmount > 5_000_000) {
      setMessage("Choose an amount between 100 and 5,000,000 RWF.");
      return;
    }

    const supabase = getBrowserSupabase();
    if (!supabase) return;
    setBusy(true);
    setMessage(null);
    setIntent(null);
    const version = identityVersion.current;
    const { data, error } = await supabase.rpc(
      "create_member_contribution_intent",
      {
        p_initiative_id: selectedInitiative,
        p_amount: parsedAmount,
      },
    );
    if (version !== identityVersion.current) return;
    setBusy(false);
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
  }

  async function signOut() {
    identity.current = null;
    clearPrivateState();
    setPhone("+250 ");
    setStep("phone");
    const supabase = getBrowserSupabase();
    if (!supabase) return;
    const { error } = await supabase.auth.signOut();
    if (error) setMessage("Secure sign-out could not be confirmed. Please retry signing out.");
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
        <p className="member-portal-kicker">Gikundiro member area</p>
        <h2 id="member-portal-title">Your place in the Blue Wall.</h2>
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
        {step === "unavailable" ? (
          <div className="member-auth-form">
            <h3>Member area unavailable</h3>
            <button className="member-primary-action" type="button" disabled={busy} onClick={() => void loadMemberArea(false)}>
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
            <h3>Continue with WhatsApp</h3>
            <p>No password, email, or public profile required.</p>
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
                placeholder="+250 788 123 456"
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
            <h3>Enter your six-digit code</h3>
            <p>Sent privately to {verifiedPhone}.</p>
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
            <h3>Join the Blue Wall</h3>
            <p>
              Create or reactivate your free {clubShortName} fan membership.
              This action is separate from signing in.
            </p>
            <button
              className="member-primary-action"
              type="button"
              disabled={busy}
              onClick={() => void loadMemberArea(true)}
            >
              {busy ? <LoaderCircle className="member-spinner" aria-hidden="true" /> : <BadgeCheck aria-hidden="true" />}
              Activate my membership
              <ArrowRight aria-hidden="true" />
            </button>
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
              <div><dt>Total confirmed</dt><dd>{formatRwf(total)}</dd></div>
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
              <label htmlFor="member-amount">Amount in RWF</label>
              <input
                id="member-amount"
                type="number"
                inputMode="numeric"
                min={100}
                max={5_000_000}
                step={100}
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
              />
              <div className="member-amount-presets" aria-label="Contribution amount presets">
                {amountPresets.map((preset) => (
                  <button type="button" key={preset} aria-pressed={amount === String(preset)} onClick={() => setAmount(String(preset))}>
                    {formatRwf(preset)}
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
                <button type="button" onClick={() => void loadMemberArea(false)}>
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
                <button type="button" className="member-icon-action" onClick={() => void loadMemberArea(false)} aria-label="Refresh contribution history">
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
                        <strong>{formatRwf(entry.amount)}</strong>
                        <span>{entry.momo_reference ?? "Reference pending"}</span>
                      </div>
                      <em>{entry.status}</em>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </div>
        ) : null}

        {message ? <p className="member-message" role="alert">{message}</p> : null}
      </div>
    </section>
  );
}
