"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import type { FormEvent, ReactNode } from "react";
import { KeyRound, MessageCircle, ShieldCheck } from "lucide-react";
import { formatAdminPhoneForDisplay } from "@/lib/admin-auth";
import { adminNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import { cn } from "@/lib/utils";
import { formatAdminRoleLabel } from "@/lib/data/admin";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";

function AdminAuthCard() {
  const {
    requestWhatsAppCode,
    verifyWhatsAppCode,
    pendingPhone,
    resetPendingPhone,
    error,
    notice,
    loading,
  } = useAdminPortal();
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [status, setStatus] = useState<string | null>(null);

  async function handlePhoneSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("Sending WhatsApp code...");

    try {
      await requestWhatsAppCode(phone);
      setCode("");
      setStatus("Open WhatsApp, copy the code, then verify below.");
    } catch (caught) {
      setStatus(
        caught instanceof Error
          ? caught.message
          : "Could not send the WhatsApp code.",
      );
    }
  }

  async function handleCodeSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("Verifying code...");

    try {
      await verifyWhatsAppCode(code);
      setStatus("Verification complete. Loading the admin workspace...");
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not verify the code.",
      );
    }
  }

  const activePhone = pendingPhone ?? (phone.trim() || null);

  return (
    <div className="page-shell py-8 sm:py-14">
      <div className="glass-panel mx-auto grid max-w-3xl gap-6 rounded-[32px] p-6 sm:p-8">
        <div className="space-y-3">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Club admin access
          </p>
          <h1 className="font-display text-4xl font-bold uppercase leading-none sm:text-5xl">
            Manage Rayon Sports from phone, tablet, or desktop.
          </h1>
          <p className="max-w-2xl text-base leading-7 text-slate-300">
            The admin workspace is club-scoped by Supabase role assignments. Use
            your approved WhatsApp number and continue with the verification code.
          </p>
        </div>

        <div className="grid gap-4 rounded-[28px] border border-border-soft bg-white/5 p-5 sm:p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-[#25d366]/30 bg-[#25d366]/15 text-[#25d366]">
              <MessageCircle className="h-5 w-5" />
            </div>
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                Step 1
              </p>
              <p className="text-sm text-slate-300">
                Send a one-time code to the admin WhatsApp number.
              </p>
            </div>
          </div>

          <form
            className="grid gap-4 sm:grid-cols-[1fr_auto]"
            onSubmit={handlePhoneSubmit}
          >
            <label className="grid gap-2 text-sm">
              Admin WhatsApp number
              <input
                type="tel"
                name="phone"
                required
                value={phone}
                onChange={(event) => setPhone(event.target.value)}
                placeholder="+250 7xx xxx xxx"
                autoComplete="tel"
                className="dashboard-input"
              />
            </label>
            <button
              type="submit"
              disabled={loading}
              className="mt-6 rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60 sm:mt-7"
            >
              Send code
            </button>
          </form>
        </div>

        {activePhone ? (
          <div className="grid gap-4 rounded-[28px] border border-border-soft bg-white/5 p-5 sm:p-6">
            <div className="flex items-center gap-3">
              <div className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-border-soft bg-white/8 text-club-accent">
                <KeyRound className="h-5 w-5" />
              </div>
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                  Step 2
                </p>
                <p className="text-sm text-slate-300">
                  Enter the 6-digit code sent to{" "}
                  <span className="font-semibold text-white">
                    {formatAdminPhoneForDisplay(activePhone)}
                  </span>
                  .
                </p>
              </div>
            </div>

            <form
              className="grid gap-4 sm:grid-cols-[1fr_auto_auto]"
              onSubmit={handleCodeSubmit}
            >
              <label className="grid gap-2 text-sm">
                Verification code
                <input
                  type="text"
                  name="otp"
                  required
                  value={code}
                  onChange={(event) =>
                    setCode(event.target.value.replace(/[^\d]/g, "").slice(0, 6))
                  }
                  inputMode="numeric"
                  pattern="[0-9]{6}"
                  autoComplete="one-time-code"
                  placeholder="123456"
                  className="dashboard-input tracking-[0.5em]"
                />
              </label>
              <button
                type="submit"
                disabled={loading}
                className="mt-6 rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60 sm:mt-7"
              >
                Verify code
              </button>
              <button
                type="button"
                onClick={() => {
                  setCode("");
                  setStatus(null);
                  resetPendingPhone();
                }}
                className="mt-6 rounded-full border border-border-soft px-5 py-3 font-semibold text-slate-100 transition hover:bg-white/6 sm:mt-7"
              >
                Use another number
              </button>
            </form>
          </div>
        ) : null}

        {status || notice || error ? (
          <div className="rounded-3xl border border-border-soft bg-white/5 px-4 py-4 text-sm leading-6 text-slate-200">
            {status ?? notice ?? error}
          </div>
        ) : null}

        {/* Test credentials hint */}
        <div className="rounded-[28px] border border-amber-500/20 bg-amber-500/5 p-5 sm:p-6">
          <div className="flex items-start gap-3">
            <div className="inline-flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full border border-amber-500/30 bg-amber-500/10 text-amber-400 text-sm">
              🔑
            </div>
            <div className="space-y-2">
              <p className="font-mono text-xs uppercase tracking-[0.24em] text-amber-400">
                Admin test credentials
              </p>
              <div className="grid gap-1.5 text-sm">
                <p className="text-slate-200">
                  <span className="text-slate-400">Number: </span>
                  <button
                    type="button"
                    onClick={() => setPhone("+250788767816")}
                    className="font-mono font-semibold text-white underline decoration-amber-500/40 underline-offset-2 transition hover:text-amber-300"
                  >
                    +250 788 767 816
                  </button>
                </p>
                <p className="text-slate-200">
                  <span className="text-slate-400">OTP: </span>
                  <span className="font-mono font-semibold tracking-[0.3em] text-white">123456</span>
                </p>
              </div>
              <p className="text-xs leading-5 text-slate-400">
                Tap the number above to auto-fill, then click &ldquo;Send code&rdquo; and enter the OTP.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function AdminUnauthorizedCard() {
  const { user, signOut } = useAdminPortal();

  return (
    <div className="page-shell py-8 sm:py-14">
      <div className="glass-panel mx-auto grid max-w-3xl gap-5 rounded-[32px] p-6 sm:p-8">
        <div className="inline-flex h-14 w-14 items-center justify-center rounded-full border border-border-soft bg-white/6">
          <ShieldCheck className="h-6 w-6 text-club-accent" />
        </div>
        <div className="space-y-3">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Access blocked
          </p>
          <h1 className="font-display text-4xl font-bold uppercase leading-none sm:text-5xl">
            This account is not assigned to the Rayon Sports admin workspace.
          </h1>
          <p className="text-base leading-7 text-slate-300">
            Signed in as{" "}
            <span className="font-semibold text-white">
              {user?.phone ?? user?.email ?? user?.id}
            </span>
            . Add a valid `admin_role_assignments` record in Supabase or sign in
            with a different approved admin number.
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            onClick={() => signOut().catch(() => {})}
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            Sign out
          </button>
          <Link
            href={siteConfig.siteUrl}
            className="rounded-full border border-border-soft px-5 py-3 font-semibold text-slate-100 transition hover:bg-white/6"
          >
            Return to website
          </Link>
        </div>
      </div>
    </div>
  );
}

export function AdminShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const { access, error, loading, notice, signOut, user } = useAdminPortal();

  if (loading) {
    return (
      <div className="page-shell py-8 sm:py-14">
        <div className="glass-panel mx-auto max-w-md rounded-[32px] p-8">
          <div className="flex flex-col items-center gap-4 text-center">
            <Image
              src="/media/rayon-crest.png"
              alt="Rayon Sports"
              width={64}
              height={64}
              className="animate-pulse"
            />
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Admin workspace
            </p>
            <p className="text-lg text-slate-200">
              Preparing the club command center…
            </p>
            <div className="mt-2 h-1 w-32 overflow-hidden rounded-full bg-white/10">
              <div className="h-full w-1/2 animate-pulse rounded-full bg-club-accent" />
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!access.isAuthenticated) {
    return <AdminAuthCard />;
  }

  if (!access.hasAccess) {
    return <AdminUnauthorizedCard />;
  }

  const roleColors: Record<string, string> = {
    super_admin: "bg-amber-500/15 text-amber-400 border-amber-500/30",
    admin: "bg-amber-500/15 text-amber-400 border-amber-500/30",
    club_admin: "bg-club-accent/15 text-club-accent border-club-accent/30",
    club_moderator: "bg-violet-500/15 text-violet-400 border-violet-500/30",
    fan: "bg-white/8 text-slate-300 border-border-soft",
  };
  const roleColor = roleColors[access.role ?? "fan"] ?? roleColors.fan;

  const navIcons: Record<string, string> = {
    "/admin": "📊",
    "/admin/settings": "⚙️",
    "/admin/cms": "📝",
    "/admin/matches": "⚽",
    "/admin/squad": "👥",
    "/admin/shop": "🛍️",
    "/admin/membership": "🏅",
    "/admin/community": "🤝",
    "/admin/standings": "🏆",
    "/admin/contributions": "💰",
    "/admin/notifications": "🔔",
    "/admin/sms-monitor": "📱",
  };

  return (
    <div className="page-shell pb-28 pt-6 lg:py-8">
      <div className="grid gap-6 xl:grid-cols-[300px_minmax(0,1fr)]">
        <aside className="glass-panel hidden h-fit rounded-[32px] p-5 xl:block">
          {/* Crest + branding */}
          <div className="flex items-center gap-4 border-b border-border-soft pb-5">
            <Image
              src="/media/rayon-crest.png"
              alt="Rayon Sports"
              width={48}
              height={48}
              className="flex-shrink-0"
            />
            <div>
              <p className="font-display text-2xl font-bold uppercase leading-none">
                Club admin
              </p>
              <p className="mt-1 text-xs leading-5 text-slate-400">
                Command center
              </p>
            </div>
          </div>

          {/* Session card */}
          <div className="mt-4 rounded-[22px] border border-border-soft bg-white/[0.03] p-4 text-sm text-slate-200">
            <div className="flex items-center justify-between gap-2">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-club-accent">
                Signed in
              </p>
              <span className={cn("rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.16em]", roleColor)}>
                {formatAdminRoleLabel(access.role)}
              </span>
            </div>
            <p className="mt-2 break-all text-sm text-slate-300">
              {user?.phone ?? user?.email ?? user?.id}
            </p>
          </div>

          {notice ? (
            <p className="mt-3 rounded-[18px] border border-border-soft bg-white/5 px-4 py-3 text-sm text-slate-200">
              {notice}
            </p>
          ) : null}
          {error ? (
            <p className="mt-3 rounded-[18px] border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
              {error}
            </p>
          ) : null}

          {/* Navigation */}
          <nav className="mt-5 flex flex-col gap-1.5">
            {adminNavigation.map((item) => {
              const active =
                pathname === item.href ||
                (item.href !== "/admin" && pathname.startsWith(item.href));
              const icon = navIcons[item.href] ?? "•";

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-semibold transition",
                    active
                      ? "bg-club-primary text-white shadow-lg shadow-club-primary/20"
                      : "text-slate-200 hover:bg-white/8",
                  )}
                >
                  <span className="text-base">{icon}</span>
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <button
            type="button"
            onClick={() => signOut().catch(() => {})}
            className="mt-5 w-full rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-slate-100 transition hover:bg-white/6 hover:border-rose-400/30 hover:text-rose-200"
          >
            Sign out
          </button>
        </aside>

        <div className="space-y-6">{children}</div>
      </div>

      {/* Mobile bottom nav */}
      <nav className="glass-panel fixed inset-x-4 bottom-4 z-30 flex gap-2 overflow-x-auto rounded-[28px] p-3 xl:hidden">
        {adminNavigation.map((item) => {
          const active =
            pathname === item.href ||
            (item.href !== "/admin" && pathname.startsWith(item.href));
          const icon = navIcons[item.href] ?? "•";

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex min-w-max items-center gap-1.5 rounded-full px-4 py-2.5 text-sm font-semibold transition",
                active
                  ? "bg-club-primary text-white shadow-lg shadow-club-primary/20"
                  : "border border-border-soft text-slate-200",
              )}
            >
              <span className="text-xs">{icon}</span>
              {item.label}
            </Link>
          );
        })}
        <button
          type="button"
          onClick={() => signOut().catch(() => {})}
          className="min-w-max rounded-full border border-border-soft px-4 py-2.5 text-sm font-semibold text-slate-100"
        >
          Exit
        </button>
      </nav>
    </div>
  );
}
