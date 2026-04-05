"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import type { FormEvent, ReactNode } from "react";
import {
  Award,
  Bell,
  FileText,
  HandHeart,
  Handshake,
  LayoutDashboard,
  ListOrdered,
  MessageCircle,
  MoreHorizontal,
  Settings,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  Trophy,
  Users,
  X,
} from "lucide-react";
import { formatAdminPhoneForDisplay } from "@/lib/admin-auth";
import { adminNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { formatAdminRoleLabel } from "@/lib/data/admin/access";
import { cn } from "@/lib/utils";

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
      setStatus("Code sent. Check WhatsApp.");
    } catch (caught) {
      setStatus(
        caught instanceof Error
          ? caught.message
          : "Could not send code.",
      );
    }
  }

  async function handleCodeSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("Verifying code...");

    try {
      await verifyWhatsAppCode(code);
      setStatus("Verified. Loading...");
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Verification failed.",
      );
    }
  }

  const activePhone = pendingPhone ?? (phone.trim() || null);

  return (
    <div className="page-shell py-8 sm:py-14">
      <div className="glass-panel mx-auto grid max-w-xl gap-6 rounded-[32px] p-6 sm:p-8">
        <div className="flex flex-col items-center text-center space-y-4">
          <Image
            src="/icons/icon-192x192.png"
            alt="Rayon Sports"
            width={56}
            height={56}
            priority
          />
          <div className="space-y-1">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Admin workspace
            </p>
            <h1 className="font-display text-4xl font-bold uppercase leading-none">
              Sign in
            </h1>
          </div>
        </div>

        <div className="grid gap-4 rounded-[24px] border border-border-soft bg-white/5 p-5">
          <div className="flex items-center gap-3">
            <div className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#25d366]/30 bg-[#25d366]/12 text-[#25d366]">
              <MessageCircle className="h-4 w-4" />
            </div>
            <p className="text-sm text-slate-300">
              {activePhone
                ? "6-digit code:"
                : "Phone number"}
            </p>
          </div>

          {!activePhone ? (
            <form
              className="grid gap-4"
              onSubmit={handlePhoneSubmit}
            >
              <label className="grid gap-1.5 text-sm text-slate-300">
                WhatsApp number
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
                className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
              >
                {loading ? "Sending\u2026" : "Send code"}
              </button>
            </form>
          ) : (
            <form
              className="grid gap-4"
              onSubmit={handleCodeSubmit}
            >
              <p className="text-sm text-slate-400">
                Code sent to{" "}
                <span className="font-semibold text-white">
                  {formatAdminPhoneForDisplay(activePhone)}
                </span>
              </p>
              <label className="grid gap-1.5 text-sm text-slate-300">
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
                  placeholder="000000"
                  className="dashboard-input text-center tracking-[0.5em] text-lg"
                />
              </label>
              <button
                type="submit"
                disabled={loading || code.length < 6}
                className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
              >
                {loading ? "Verifying\u2026" : "Verify"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setCode("");
                  setStatus(null);
                  resetPendingPhone();
                }}
                className="rounded-full border border-border-soft px-5 py-2.5 text-sm font-semibold text-slate-300 transition hover:bg-white/6"
              >
                Use a different number
              </button>
            </form>
          )}
        </div>

        {status || notice || error ? (
          <div
            className={cn(
              "rounded-2xl border px-4 py-3 text-sm leading-6",
              error && !status
                ? "border-rose-400/30 bg-rose-500/10 text-rose-200"
                : "border-border-soft bg-white/5 text-slate-200",
            )}
          >
            {status ?? notice ?? error}
          </div>
        ) : null}
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
            Access restricted.
          </h1>
          <p className="text-base leading-7 text-slate-300">
            <span className="font-semibold text-white">
              {user?.phone ?? user?.email ?? user?.id}
            </span>{" "}
            is not an admin.
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
              src="/icons/icon-192x192.png"
              alt="Rayon Sports"
              width={64}
              height={64}
              className="animate-pulse"
              priority
            />
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Admin workspace
            </p>
            <p className="text-lg text-slate-200">
              Loading workspace...
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

  const navIcons: Record<string, typeof LayoutDashboard> = {
    "/admin": LayoutDashboard,
    "/admin/settings": Settings,
    "/admin/cms": FileText,
    "/admin/matches": Trophy,
    "/admin/squad": Users,
    "/admin/shop": ShoppingBag,
    "/admin/membership": Award,
    "/admin/community": Handshake,
    "/admin/standings": ListOrdered,
    "/admin/contributions": HandHeart,
    "/admin/notifications": Bell,
    "/admin/sms-monitor": Smartphone,
  };

  return (
    <div className="page-shell pb-28 pt-6 lg:py-8">
      {/* Skip to main content link for keyboard nav */}
      <a
        href="#admin-main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-club-primary focus:px-4 focus:py-2 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to main content
      </a>
      <div className="grid gap-6 xl:grid-cols-[300px_minmax(0,1fr)]">
        <aside className="glass-panel hidden h-fit rounded-[32px] p-5 xl:block">
          {/* Crest + branding */}
          <div className="flex items-center gap-4 border-b border-border-soft pb-5">
            <Image
              src="/icons/icon-192x192.png"
              alt="Rayon Sports"
              width={48}
              height={48}
              className="flex-shrink-0"
            />
            <div>
              <p className="font-display text-2xl font-bold uppercase leading-none">
                Club admin
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
          <nav className="mt-5 flex flex-col gap-1.5" aria-label="Admin sidebar">
            {adminNavigation.map((item) => {
              const active =
                pathname === item.href ||
                (item.href !== "/admin" && pathname.startsWith(item.href));
              const IconComponent = navIcons[item.href] ?? LayoutDashboard;

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-semibold transition",
                    active
                      ? "bg-club-primary text-white shadow-lg shadow-club-primary/20"
                      : "text-slate-200 hover:bg-white/8",
                  )}
                >
                  <IconComponent size={18} className="text-club-accent" />
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

        <main id="admin-main-content" className="space-y-6">{children}</main>
      </div>

      {/* Mobile bottom nav — 5 primary + More overflow */}
      <AdminMobileNav
        adminNavigation={adminNavigation}
        navIcons={navIcons}
        pathname={pathname}
        onSignOut={() => signOut().catch(() => {})}
      />
    </div>
  );
}

/* ── Admin mobile bottom nav ─────────────────────────────── */

/** Primary mobile tabs — 4 key destinations + More overflow */
const PRIMARY_ADMIN_TABS = ["/admin", "/admin/matches", "/admin/cms", "/admin/notifications"];

interface AdminMobileNavProps {
  adminNavigation: { href: string; label: string }[];
  navIcons: Record<string, typeof LayoutDashboard>;
  pathname: string;
  onSignOut: () => void;
}

function AdminMobileNav({ adminNavigation, navIcons, pathname, onSignOut }: AdminMobileNavProps) {
  const [sheetOpen, setSheetOpen] = useState(false);

  const primaryItems = adminNavigation.filter((item) => PRIMARY_ADMIN_TABS.includes(item.href));
  const overflowItems = adminNavigation.filter((item) => !PRIMARY_ADMIN_TABS.includes(item.href));

  return (
    <>
      <nav
        className="fixed inset-x-0 bottom-0 z-30 border-t border-border-soft bg-surface-strong/95 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl xl:hidden"
        aria-label="Admin mobile navigation"
      >
        <div className="mx-auto flex max-w-md items-stretch justify-around">
          {primaryItems.map((item) => {
            const active =
              pathname === item.href ||
              (item.href !== "/admin" && pathname.startsWith(item.href));
            const IconComponent = navIcons[item.href] ?? LayoutDashboard;

            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "relative flex flex-1 flex-col items-center gap-1 py-2.5 text-[11px] font-medium transition-colors",
                  active
                    ? "text-club-accent"
                    : "text-slate-400 active:text-slate-200",
                )}
              >
                <IconComponent
                  size={22}
                  strokeWidth={active ? 2.2 : 1.6}
                  className="transition-transform active:scale-90"
                />
                <span className="leading-none">{item.label}</span>
                {active ? (
                  <span className="absolute top-0 left-1/2 h-[2.5px] w-5 -translate-x-1/2 rounded-full bg-club-accent" />
                ) : null}
              </Link>
            );
          })}

          {/* More button */}
          <button
            type="button"
            onClick={() => setSheetOpen(true)}
            className={cn(
              "relative flex flex-1 flex-col items-center gap-1 py-2.5 text-[11px] font-medium transition-colors",
              sheetOpen ? "text-club-accent" : "text-slate-400 active:text-slate-200",
            )}
            aria-label="Show more admin options"
          >
            <MoreHorizontal size={22} strokeWidth={1.6} />
            <span className="leading-none">More</span>
          </button>
        </div>
      </nav>

      {/* More bottom sheet */}
      {sheetOpen ? (
        <div
          className="fixed inset-0 z-40 xl:hidden"
          role="dialog"
          aria-modal="true"
          aria-label="More admin options"
        >
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/50 backdrop-blur-sm"
            onClick={() => setSheetOpen(false)}
            onKeyDown={(event) => event.key === "Escape" && setSheetOpen(false)}
          />
          {/* Sheet */}
          <div className="absolute inset-x-0 bottom-0 rounded-t-[28px] border-t border-border-soft bg-surface-strong p-5 pb-[calc(env(safe-area-inset-bottom)+1rem)]">
            <div className="flex items-center justify-between pb-4">
              <p className="font-display text-lg font-bold uppercase text-white">More</p>
              <button
                type="button"
                onClick={() => setSheetOpen(false)}
                className="rounded-full p-2 text-slate-300 hover:bg-white/8"
                aria-label="Close"
              >
                <X size={20} />
              </button>
            </div>
            <nav className="grid gap-1.5" aria-label="Additional admin navigation">
              {overflowItems.map((item) => {
                const active =
                  pathname === item.href ||
                  (item.href !== "/admin" && pathname.startsWith(item.href));
                const IconComponent = navIcons[item.href] ?? LayoutDashboard;

                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setSheetOpen(false)}
                    aria-current={active ? "page" : undefined}
                    className={cn(
                      "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-semibold transition",
                      active
                        ? "bg-club-primary text-white"
                        : "text-slate-200 hover:bg-white/8",
                    )}
                  >
                    <IconComponent size={18} className="text-club-accent" />
                    {item.label}
                  </Link>
                );
              })}
            </nav>
            <button
              type="button"
              onClick={() => {
                setSheetOpen(false);
                onSignOut();
              }}
              className="mt-4 w-full rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-slate-100 transition hover:border-rose-400/30 hover:text-rose-200"
            >
              Sign out
            </button>
          </div>
        </div>
      ) : null}
    </>
  );
}
