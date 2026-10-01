"use client";

import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { ShieldCheck } from "lucide-react";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { withAdminOperationTimeout } from "@/lib/admin-operation-timeout";
import { inspectStaffAssurance } from "@/lib/staff-assurance";
import { ui } from "@/ui-kit";

type StaffFactor = { id: string; friendly_name?: string; status: string; factor_type: string };
const factorName = "AFRICLUB staff";

/** A browser task gate. The API and database remain the authorization boundaries. */
export function AdminStaffStepUpGate({ children }: { children: ReactNode }) {
  const { client, session, user, controlledEvidence, accessUnavailable, refresh, signOut } = useAdminPortal();
  const owner = user?.id ?? "";
  const token = session?.access_token ?? "";
  const generation = useRef(0);
  const busyRef = useRef(false);
  const pendingEnrollment = useRef<{ owner: string; settled: boolean } | null>(null);
  const identity = useRef({ owner, token });
  identity.current = { owner, token };
  const [busy, setBusy] = useState(false);
  const [checking, setChecking] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [factors, setFactors] = useState<StaffFactor[]>([]);
  const [factorId, setFactorId] = useState("");
  const [secret, setSecret] = useState<string | null>(null);
  const [showSecret, setShowSecret] = useState(false);
  const [code, setCode] = useState("");
  const [assurance, setAssurance] = useState<{ expiresAt: number; token: string } | null>(null);
  const [everUnlocked, setEverUnlocked] = useState(false);

  const load = useCallback(async () => {
    if (controlledEvidence) return;
    const attempt = ++generation.current;
    const current = () => generation.current === attempt && identity.current.owner === owner;
    setChecking(true);
    setAssurance(null);
    setError(null);
    setSecret(null);
    setShowSecret(false);
    setFactors([]);
    setFactorId("");
    setCode("");
    busyRef.current = false;
    setBusy(false);
    if (accessUnavailable) {
      setError("Staff access could not be checked. Your draft is kept. Check status to continue.");
      setChecking(false);
      return;
    }
    try {
      if (!client || !owner || !token) throw new Error("Staff session unavailable");
      const claims = await withAdminOperationTimeout(client.auth.getClaims(), "Staff authentication check");
      if (!current()) return;
      if (claims.error || !claims.data?.claims || claims.data.claims.sub !== owner) throw new Error("Staff session unavailable");
      const next = inspectStaffAssurance(claims.data.claims, owner);
      if (next.allowed && next.expiresAt) {
        setAssurance({ expiresAt: next.expiresAt, token: identity.current.token });
        setEverUnlocked(true);
        return;
      }
      const result = await withAdminOperationTimeout(client.auth.mfa.listFactors(), "Authenticator loading");
      if (!current()) return;
      if (result.error || !result.data) throw new Error("Authenticator unavailable");
      const available = result.data.all.filter((factor) => factor.factor_type === "totp");
      setFactors(available);
      setFactorId(available.find((factor) => factor.status === "verified")?.id ?? "");
      if (!available.length && pendingEnrollment.current?.owner === owner && !pendingEnrollment.current.settled) {
        setError("Authenticator setup is still awaiting a response. Check its status before starting another setup.");
      }
    } catch {
      if (current()) setError("Staff authentication could not be checked. Try again or sign out.");
    } finally {
      if (current()) setChecking(false);
    }
  }, [client, controlledEvidence, accessUnavailable, owner, token]);

  useEffect(() => {
    const ownedGeneration = generation;
    void load();
    return () => { ++ownedGeneration.current; };
  }, [load]);

  useEffect(() => {
    if (!assurance) return;
    const expire = () => {
      if (Date.now() / 1000 >= assurance.expiresAt) {
        setAssurance(null);
        setCode("");
        void load();
      }
    };
    const timer = window.setTimeout(expire, Math.max(0, assurance.expiresAt * 1000 - Date.now()));
    window.addEventListener("focus", expire);
    document.addEventListener("visibilitychange", expire);
    return () => {
      window.clearTimeout(timer);
      window.removeEventListener("focus", expire);
      document.removeEventListener("visibilitychange", expire);
    };
  }, [assurance, load]);

  async function perform(action: "enroll" | "verify" | "remove", removeId?: string) {
    if (busyRef.current || checking || accessUnavailable || !client) return;
    if (action === "verify" && !/^\d{6}$/.test(code)) {
      setError("Enter the 6-digit code from your authenticator app.");
      return;
    }
    busyRef.current = true;
    setBusy(true);
    setError(null);
    const attempt = generation.current;
    const current = () => generation.current === attempt && identity.current.owner === owner;
    try {
      const verified = await withAdminOperationTimeout(client.auth.getUser(), "Staff identity check");
      if (!current()) return;
      if (verified.error || verified.data.user?.id !== owner) throw new Error("Staff identity changed");
      if (action === "enroll" || action === "remove") {
        // Reconcile unfinished enrollment before another write, including a
        // previous request whose response was lost. Never delete a verified factor.
        const existing = await withAdminOperationTimeout(client.auth.mfa.listFactors(), "Authenticator status check");
        if (!current()) return;
        if (existing.error || !existing.data) throw new Error("Authenticator unavailable");
        const pending = existing.data.all.filter((factor) => factor.factor_type === "totp" && factor.status === "unverified" && factor.friendly_name === factorName);
        if (action === "remove") {
          if (!pending.some((factor) => factor.id === removeId)) throw new Error("Enrollment changed");
          const removed = await withAdminOperationTimeout(client.auth.mfa.unenroll({ factorId: removeId! }), "Unfinished enrollment removal");
          if (!current()) return;
          if (removed.error) throw removed.error;
          await load();
          return;
        }
        if (pending.length || existing.data.totp.length) {
          setFactors(existing.data.all.filter((factor) => factor.factor_type === "totp"));
          setFactorId(existing.data.totp[0]?.id ?? "");
          setError("An authenticator already exists. Verify it or remove the unfinished setup before starting again.");
          return;
        }
        if (pendingEnrollment.current?.owner === owner && !pendingEnrollment.current.settled) {
          throw new Error("Original setup is still pending");
        }
        const original = { owner, settled: false };
        pendingEnrollment.current = original;
        const enrollment = client.auth.mfa.enroll({ factorType: "totp", issuer: "AFRICLUB", friendlyName: factorName });
        // A UI timeout does not cancel an Auth write. Status checks cannot
        // authorize a second setup while the original SDK request is in flight.
        void enrollment.then(() => { original.settled = true; }, () => { original.settled = true; });
        const enrolled = await withAdminOperationTimeout(enrollment, "Authenticator setup");
        if (!current()) return;
        if (enrolled.error || enrolled.data?.type !== "totp" || !enrolled.data.totp.secret) throw new Error("Enrollment unavailable");
        setFactorId(enrolled.data.id);
        setSecret(enrolled.data.totp.secret);
      } else {
        if (!factorId) throw new Error("Choose an authenticator");
        const result = await withAdminOperationTimeout(client.auth.mfa.challengeAndVerify({ factorId, code }), "Authenticator verification");
        if (!current()) return;
        if (result.error) throw result.error;
        const claims = await withAdminOperationTimeout(client.auth.getClaims(), "Staff authentication check");
        if (!current()) return;
        const next = inspectStaffAssurance(claims.error ? null : claims.data?.claims ?? null, owner);
        if (!next.allowed || !next.expiresAt) throw new Error("Fresh staff authentication unavailable");
        setCode("");
        setSecret(null);
        setAssurance({ expiresAt: next.expiresAt, token: identity.current.token });
        setEverUnlocked(true);
        await refresh();
      }
    } catch {
      if (current()) {
        setCode("");
        setError(action === "verify" ? "The code could not be verified. Check your authenticator and try again." : "Setup could not be confirmed. Check its status before trying again.");
      }
    } finally {
      if (current()) { busyRef.current = false; setBusy(false); }
    }
  }

  // This flag is provided only by the existing localhost-only, server-validated
  // evidence bootstrap. It supplies no API/database authorization or provider token.
  if (controlledEvidence) return <>{children}</>;
  const allowed = !accessUnavailable && assurance != null && assurance.token === token && assurance.expiresAt > Date.now() / 1000;
  const verifiedFactors = factors.filter((factor) => factor.status === "verified");
  const unfinished = factors.filter((factor) => factor.status === "unverified" && factor.friendly_name === factorName);
  return <>
    {(allowed || everUnlocked) && <div hidden={!allowed} inert={!allowed || undefined}>{children}</div>}
    {!allowed && <main className="flex min-h-screen items-center justify-center px-4 py-12">
      <section aria-labelledby="staff-step-up-title" aria-busy={busy || checking} className={`${ui.panelElevated} w-full max-w-md space-y-6 rounded-[32px] p-8`}>
        <ShieldCheck aria-hidden="true" className="h-8 w-8 text-[var(--admin-accent)]" />
        <div className="space-y-2">
          <p className="text-sm text-[var(--admin-secondary)]">AFRICLUB staff</p>
          <h1 id="staff-step-up-title" className="text-2xl font-semibold text-[var(--admin-foreground)]">Verify your authenticator</h1>
          <p className="text-sm text-[var(--admin-secondary)]">Staff access needs a recent authenticator code. Verification lasts five minutes.</p>
        </div>
        {checking ? <p role="status">Checking staff authentication…</p> : <>
          {secret && <div className="space-y-2">
            <p className="text-sm">In your authenticator app, add a time-based code using this setup key. Keep it private.</p>
            <label htmlFor="staff-setup-key" className="text-sm">Setup key</label>
            <input id="staff-setup-key" type={showSecret ? "text" : "password"} readOnly value={secret} autoComplete="off" className={`${ui.input} w-full`} />
            <button type="button" disabled={busy} aria-pressed={showSecret} onClick={() => setShowSecret((value) => !value)} className={ui.buttonSecondary}>{showSecret ? "Hide setup key" : "Show setup key"}</button>
          </div>}
          {(verifiedFactors.length > 0 || secret) && <form className="space-y-4" onSubmit={(event: FormEvent) => { event.preventDefault(); void perform("verify"); }}>
            {verifiedFactors.length > 1 && <div className="space-y-2">
              <label htmlFor="staff-factor" className="text-sm">Authenticator</label>
              <select id="staff-factor" value={factorId} disabled={busy} onChange={(event) => { setFactorId(event.target.value); setCode(""); }} className={`${ui.input} w-full`}>
                {verifiedFactors.map((factor, index) => <option key={factor.id} value={factor.id}>{factor.friendly_name || `Authenticator ${index + 1}`}</option>)}
              </select>
            </div>}
            <div className="space-y-2">
              <label htmlFor="staff-code" className="text-sm">Authenticator code</label>
              <input id="staff-code" type="text" inputMode="numeric" autoComplete="one-time-code" value={code} maxLength={6} disabled={busy} aria-describedby={error ? "staff-step-up-error" : undefined} onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))} className={`${ui.input} w-full`} />
            </div>
            <button type="submit" disabled={busy} className={`${ui.buttonPrimary} w-full`}>{busy ? "Verifying…" : "Verify and continue"}</button>
          </form>}
          {!verifiedFactors.length && !secret && !unfinished.length && !error && <button type="button" disabled={busy} onClick={() => void perform("enroll")} className={`${ui.buttonPrimary} w-full`}>Set up authenticator</button>}
          {!secret && unfinished.map((factor) => <div key={factor.id} className="space-y-2">
            <p className="text-sm">An unfinished setup exists. Its key cannot be recovered. Remove it to start again.</p>
            <button type="button" disabled={busy} onClick={() => void perform("remove", factor.id)} className={ui.buttonSecondary}>Remove unfinished setup</button>
          </div>)}
        </>}
        {error && <p id="staff-step-up-error" role="alert" className="text-sm text-[var(--admin-danger)]">{error}</p>}
        <div className="flex flex-wrap gap-3">
          <button type="button" disabled={busy || checking} onClick={() => { if (accessUnavailable) void refresh(); else void load(); }} className={ui.buttonSecondary}>Check status</button>
          <button type="button" disabled={busy} onClick={() => void signOut().catch(() => setError("Sign-out could not be confirmed. Try again."))} className={ui.buttonSecondary}>Sign out</button>
        </div>
      </section>
    </main>}
  </>;
}
