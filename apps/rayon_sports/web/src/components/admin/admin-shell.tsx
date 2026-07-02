"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useMemo, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import {
  Award,
  AlertTriangle,
  Bell,
  Crown,
  Database,
  FileImage,
  FileText,
  Gift,
  HandHeart,
  Handshake,
  LayoutDashboard,
  ListOrdered,
  MoreHorizontal,
  Newspaper,
  PanelLeftClose,
  PanelLeftOpen,
  Settings,
  Settings2,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  Target,
  Trophy,
  Users,
  Wallet,
  X,
} from "lucide-react";
import { AdminDialogFrame } from "@/components/admin/admin-dialog-frame";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { formatAdminPhoneForDisplay } from "@/lib/admin-auth";
import { withAdminClubScope } from "@/lib/admin-club-scope";
import { adminNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { formatAdminRoleLabel } from "@/lib/data/admin/access";
import { cn } from "@/lib/utils";
import { ui } from "@/ui-kit";

const navIcons: Record<string, LucideIcon> = {
  "/admin": LayoutDashboard,
  "/admin/access": ShieldCheck,
  "/admin/settings": Settings,
  "/admin/cms": FileText,
  "/admin/cms/banners": FileImage,
  "/admin/cms/content": Newspaper,
  "/admin/cms/config": Settings2,
  "/admin/matches": Trophy,
  "/admin/squad": Users,
  "/admin/shop": ShoppingBag,
  "/admin/offers": Gift,
  "/admin/membership": Crown,
  "/admin/gamification": Award,
  "/admin/gamification/wallet": Wallet,
  "/admin/predictions": Target,
  "/admin/community": Handshake,
  "/admin/standings": ListOrdered,
  "/admin/contributions": HandHeart,
  "/admin/notifications": Bell,
  "/admin/sms-monitor": Smartphone,
  "/admin/football-sync": Database,
};

const sidebarSections = [
  {
    title: "Control",
    items: [
      "/admin",
      "/admin/access",
      "/admin/matches",
      "/admin/notifications",
      "/admin/sms-monitor",
    ],
  },
  {
    title: "Supporters",
    items: [
      "/admin/membership",
      "/admin/tickets",
      "/admin/community",
      "/admin/shop",
      "/admin/offers",
    ],
  },
  {
    title: "Content",
    items: ["/admin/cms", "/admin/squad", "/admin/standings"],
  },
  {
    title: "Platform",
    items: [
      "/admin/gamification",
      "/admin/gamification/wallet",
      "/admin/predictions",
      "/admin/football-sync",
      "/admin/settings",
      "/admin/settings/features",
      "/admin/settings/audit",
    ],
  },
];

const cmsViews = [
  "/admin/cms/banners",
  "/admin/cms/content",
  "/admin/cms/content-blocks",
  "/admin/cms/config",
];
const primaryMobileTabs = [
  "/admin",
  "/admin/matches",
  "/admin/cms",
  "/admin/notifications",
];

function resolveNavItem(href: string) {
  return (
    adminNavigation.find((item) => item.href === href) ?? { href, label: href }
  );
}

function isActivePath(href: string, pathname: string) {
  return pathname === href || (href !== "/admin" && pathname.startsWith(href));
}

function roleTone(role: string | null) {
  switch (role) {
    case "super_admin":
    case "admin":
      return "accent" as const;
    case "club_admin":
      return "info" as const;
    case "club_moderator":
      return "warning" as const;
    default:
      return "neutral" as const;
  }
}

function WhatsAppIcon({ size = 24 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
    </svg>
  );
}

function OtpDigitInput({
  value,
  length = 6,
  onChange,
}: {
  value: string;
  length?: number;
  onChange: (val: string) => void;
}) {
  // Build a fixed-length array of single characters for each OTP box.
  // Array.from guarantees exactly `length` entries regardless of input.
  const digits = Array.from({ length }, (_, i) => value[i] ?? "");

  function handleKeyDown(event: React.KeyboardEvent<HTMLInputElement>, index: number) {
    if (event.key === "Backspace") {
      event.preventDefault();
      const currentDigit = digits[index] ?? "";

      if (currentDigit) {
        // Clear the current digit
        const next = value.slice(0, index) + value.slice(index + 1);
        onChange(next.slice(0, length));
      } else if (index > 0) {
        // Current cell is already empty — clear the previous digit and focus it
        const next = value.slice(0, index - 1) + value.slice(index);
        onChange(next.slice(0, length));
        document.getElementById(`otp-${index - 1}`)?.focus();
      }
    }

    if (event.key === "ArrowLeft" && index > 0) {
      event.preventDefault();
      document.getElementById(`otp-${index - 1}`)?.focus();
    }

    if (event.key === "ArrowRight" && index < length - 1) {
      event.preventDefault();
      document.getElementById(`otp-${index + 1}`)?.focus();
    }
  }

  function handleInput(char: string, index: number) {
    const cleaned = char.replace(/[^\d]/g, "");
    if (!cleaned) return;
    // Replace the digit at `index` with the new character
    const before = value.padEnd(index, " ").slice(0, index);
    const after = value.slice(index + 1);
    const next = (before + cleaned[0] + after).replace(/[^\d]/g, "").slice(0, length);
    onChange(next);
    if (index < length - 1) {
      document.getElementById(`otp-${index + 1}`)?.focus();
    }
  }

  function handlePaste(event: React.ClipboardEvent) {
    event.preventDefault();
    const pasted = event.clipboardData.getData("text").replace(/[^\d]/g, "").slice(0, length);
    if (pasted) {
      onChange(pasted);
      const lastIndex = Math.min(pasted.length, length) - 1;
      document.getElementById(`otp-${lastIndex}`)?.focus();
    }
  }

  return (
    <div className="flex items-center justify-center gap-2 sm:gap-3" onPaste={handlePaste}>
      {digits.map((digit, i) => (
        <input
          key={i}
          id={`otp-${i}`}
          type="text"
          inputMode="numeric"
          autoComplete={i === 0 ? "one-time-code" : "off"}
          maxLength={1}
          value={digit}
          onChange={(e) => handleInput(e.target.value, i)}
          onKeyDown={(e) => handleKeyDown(e, i)}
          onFocus={(e) => e.target.select()}
          className={cn(
            "h-14 w-11 sm:h-16 sm:w-13 rounded-xl border-[1.2px] bg-transparent text-center font-display text-2xl font-bold text-white transition-all duration-200 outline-none",
            digit
              ? "border-[#25D366]/60 shadow-[0_0_20px_rgba(37,211,102,0.15)]"
              : "border-white/12 hover:border-white/20",
            "focus:border-[#25D366] focus:shadow-[0_0_24px_rgba(37,211,102,0.2)]",
          )}
        />
      ))}
    </div>
  );
}

function AdminAuthCard() {
  const {
    requestPhoneCode,
    verifyPhoneCode,
    pendingPhone,
    resetPendingPhone,
    authBusy,
    error,
    notice,
  } = useAdminPortal();
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [showContactPopup, setShowContactPopup] = useState(false);

  async function handlePhoneSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("Sending code via WhatsApp...");
    setShowContactPopup(false);

    try {
      await requestPhoneCode(phone);
      setCode("");
      setStatus("WhatsApp code sent");
    } catch (caught) {
      const errorMessage = caught instanceof Error ? caught.message : "Could not send code.";
      setStatus(errorMessage);
      if (errorMessage.toLowerCase().includes("access denied") || errorMessage.toLowerCase().includes("not recognized")) {
        setShowContactPopup(true);
      }
    }
  }

  async function handleCodeSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("Verifying");

    try {
      await verifyPhoneCode(code);
      setStatus("Verified");
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Verification failed.",
      );
    }
  }

  const activePhone = pendingPhone;

  return (
    <div className="flex min-h-screen items-center justify-center px-4 py-12 relative">
      {/* Background glow effects */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute left-1/2 top-1/3 -translate-x-1/2 -translate-y-1/2 h-[600px] w-[600px] rounded-full bg-[#25D366]/4 blur-[120px]" />
        <div className="absolute left-1/4 top-2/3 h-[300px] w-[300px] rounded-full bg-club-primary/6 blur-[100px]" />
      </div>

      <AdminDialogFrame
        open={showContactPopup}
        onClose={() => setShowContactPopup(false)}
        title="Access denied"
        description="This number is not registered as an admin. Contact the system administrator via WhatsApp to request access."
        closeLabel="Close access denied dialog"
      >
        <div className="space-y-6 text-center">
          <div className="mx-auto flex h-18 w-18 items-center justify-center rounded-full bg-[#25D366]/10 text-[#25D366]">
            <WhatsAppIcon size={36} />
          </div>
          <a
            href="https://wa.me/250788767816"
            target="_blank"
            rel="noopener"
            className="flex w-full items-center justify-center gap-2.5 rounded-2xl bg-gradient-to-r from-[#25D366] to-[#128C7E] px-5 py-4 text-sm font-extrabold uppercase tracking-wider text-white transition-all hover:shadow-[0_8px_32px_rgba(37,211,102,0.3)] active:scale-[0.98]"
          >
            <WhatsAppIcon size={18} />
            Message +250 788 767 816
          </a>
        </div>
      </AdminDialogFrame>

      <div className="relative w-full max-w-lg">
        <div
          className={`${ui.panelElevated} overflow-hidden rounded-[36px] border-[1.2px] p-7 sm:p-10`}
        >
          <div className="space-y-8">
            {/* Header with WhatsApp branding */}
            <div className="flex items-start gap-5">
              <div className="relative flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-white/10 bg-white/6">
                <Image
                  src="/icons/icon-192x192.png"
                  alt={`${siteConfig.shortTitle} emblem`}
                  width={40}
                  height={40}
                  priority
                />
              </div>
              <div className="space-y-1.5">
                <p className="text-[10px] font-extrabold uppercase tracking-[0.3em] text-[#25D366]">
                  Central admin
                </p>
                <h1 className="font-display text-[2rem] font-extrabold leading-[1.05] text-white sm:text-[2.6rem]">
                  Secure sign in
                </h1>
              </div>
            </div>

            {/* Auth form card */}
            <div
              className={`${ui.panelInset} grid gap-5 rounded-[28px] p-5 sm:p-7`}
            >
              {/* Status indicator */}
              <div className="flex items-center gap-3.5">
                <div className={cn(
                  "relative inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-full transition-all duration-500",
                  activePhone
                    ? "bg-[#25D366]/12 text-[#25D366]"
                    : "border border-white/12 bg-white/5 text-white/60",
                )}>
                  {activePhone ? (
                    <WhatsAppIcon size={22} />
                  ) : (
                    <Smartphone className="h-5 w-5" />
                  )}
                  {activePhone && (
                    <span className="absolute inset-0 animate-ping rounded-full bg-[#25D366]/20" style={{ animationDuration: "2s" }} />
                  )}
                </div>
                <div>
                  <p className="text-sm font-bold text-white">
                    {activePhone
                      ? "Enter verification code"
                      : "WhatsApp authentication"}
                  </p>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {activePhone
                      ? "6-digit code sent to your WhatsApp"
                      : "Use your approved admin phone number"}
                  </p>
                </div>
              </div>

              {/* Phone input state */}
              {!activePhone ? (
                <form className="grid gap-5" onSubmit={handlePhoneSubmit} aria-busy={authBusy}>
                  <label className="grid gap-2.5">
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                      Admin phone number
                    </span>
                    <div className="relative">
                      <div className="pointer-events-none absolute left-0 top-0 flex h-full items-center pl-4">
                        <span className="flex items-center gap-1.5 rounded-lg bg-white/8 px-2.5 py-1 text-xs font-bold text-white/70">
                          🇷🇼 +250
                        </span>
                      </div>
                      <input
                        type="tel"
                        name="phone"
                        required
                        value={phone}
                        onChange={(event) => setPhone(event.target.value)}
                        placeholder="+250 7xx xxx xxx"
                        autoComplete="tel"
                        disabled={authBusy}
                        className={cn(
                          ui.input,
                          "!pl-[100px] !h-14 !text-base !font-semibold !tracking-wide",
                        )}
                      />
                    </div>
                  </label>
                  <button
                    type="submit"
                    disabled={authBusy}
                    aria-label="Send code via WhatsApp"
                    className="flex h-14 w-full items-center justify-center gap-2.5 rounded-2xl bg-gradient-to-r from-[#25D366] to-[#128C7E] text-sm font-extrabold uppercase tracking-wider text-white transition-all hover:shadow-[0_8px_32px_rgba(37,211,102,0.3)] active:scale-[0.98] disabled:opacity-50 disabled:hover:shadow-none"
                  >
                    {authBusy ? (
                      <>
                        <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                        Sending…
                      </>
                    ) : (
                      <>
                        <WhatsAppIcon size={18} />
                        Send WhatsApp code
                      </>
                    )}
                  </button>
                </form>
              ) : (
                /* OTP input state */
                <form className="grid gap-5" onSubmit={handleCodeSubmit} aria-busy={authBusy}>
                  <div className="flex items-center justify-between">
                    <p className="text-sm text-slate-400">
                      Code sent to{" "}
                      <span className="font-bold text-white">
                        {formatAdminPhoneForDisplay(activePhone)}
                      </span>
                    </p>
                    <div className="flex h-6 w-6 items-center justify-center rounded-full bg-[#25D366]/15 text-[#25D366]">
                      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                        <path d="M2 6L5 9L10 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </div>
                  </div>

                  <OtpDigitInput
                    value={code}
                    length={6}
                    onChange={setCode}
                  />

                  <button
                    type="submit"
                    disabled={authBusy || code.length < 6}
                    className="flex h-14 w-full items-center justify-center gap-2.5 rounded-2xl bg-gradient-to-r from-[#25D366] to-[#128C7E] text-sm font-extrabold uppercase tracking-wider text-white transition-all hover:shadow-[0_8px_32px_rgba(37,211,102,0.3)] active:scale-[0.98] disabled:opacity-50 disabled:hover:shadow-none"
                  >
                    {authBusy ? (
                      <>
                        <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                        Verifying…
                      </>
                    ) : (
                      "Verify & sign in"
                    )}
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setCode("");
                      setStatus(null);
                      resetPendingPhone();
                    }}
                    disabled={authBusy}
                    className="text-sm font-bold text-slate-400 hover:text-white transition-colors py-1"
                  >
                    ← Use a different number
                  </button>
                </form>
              )}
            </div>

            {/* Status messages */}
            {status || notice || error ? (
              <div
                role={error && !status ? "alert" : "status"}
                aria-live={error && !status ? "assertive" : "polite"}
                className={cn(
                  "flex items-center gap-3 rounded-2xl border px-5 py-3.5 text-sm leading-6",
                  error && !status
                    ? "border-rose-400/30 bg-rose-500/10 text-rose-200"
                    : status?.toLowerCase().includes("sent")
                      ? "border-[#25D366]/30 bg-[#25D366]/8 text-[#25D366]"
                      : "border-white/10 bg-white/5 text-slate-200",
                )}
              >
                {status?.toLowerCase().includes("sent") && (
                  <div className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[#25D366]/20 text-[#25D366]">
                    <svg width="10" height="10" viewBox="0 0 12 12" fill="none">
                      <path d="M2 6L5 9L10 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                  </div>
                )}
                {status ?? notice ?? error}
              </div>
            ) : null}

            {/* Footer */}
            <p className="text-center text-[10px] font-medium uppercase tracking-[0.2em] text-slate-500">
              Secured by WhatsApp OTP · {siteConfig.shortTitle} admin
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

function AdminUnauthorizedCard() {
  const { user, signOut } = useAdminPortal();

  return (
    <div className="flex min-h-screen items-center justify-center px-4 py-12">
      <div
        className={`${ui.panelElevated} w-full max-w-3xl rounded-[34px] border-[1.2px] p-6 sm:p-8`}
      >
        <div className="grid gap-5">
          <div className="flex h-14 w-14 items-center justify-center rounded-full border border-white/10 bg-white/6 text-club-accent">
            <ShieldCheck className="h-6 w-6" />
          </div>
          <div className="space-y-3">
            <p className="admin-page-eyebrow">Access blocked</p>
            <h1 className="admin-page-title">Admin access restricted</h1>
            <p className="admin-page-copy">
              <span className="font-semibold text-white">
                {user?.phone ?? user?.email ?? user?.id}
              </span>{" "}
              does not have an active admin assignment.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => signOut().catch(() => {})}
              className={ui.buttonPrimary}
            >
              Sign out
            </button>
            <Link href={siteConfig.siteUrl} className={ui.buttonSecondary}>
              Return to website
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

function AdminWorkspaceSignal({
  error,
  notice,
  switchingClub,
}: {
  error: string | null;
  notice: string | null;
  switchingClub: boolean;
}) {
  const message = error ?? (switchingClub ? "Switching club scope..." : notice);
  if (!message) {
    return null;
  }

  const isError = error != null;
  return (
    <div
      role={isError ? "alert" : "status"}
      aria-live={isError ? "assertive" : "polite"}
      className={cn(
        "mt-4 flex items-start gap-3 rounded-2xl border px-4 py-3 text-sm",
        isError
          ? "border-rose-500/25 bg-rose-500/10 text-rose-100"
          : "border-[var(--admin-border)] bg-[var(--admin-zinc-900)] text-[var(--admin-text)]",
      )}
    >
      <span className="mt-0.5 shrink-0 text-[var(--admin-text-muted)]">
        {isError ? <AlertTriangle size={16} /> : "i"}
      </span>
      <span className="min-w-0">{message}</span>
    </div>
  );
}

function SidebarNavigation({
  pathname,
  selectedClubId,
  collapsed,
}: {
  pathname: string;
  selectedClubId: string | null;
  collapsed: boolean;
}) {
  const contextualSections = pathname.startsWith("/admin/cms")
    ? [{ title: "CMS views", items: cmsViews }]
      : [];

  const renderSection = (title: string, items: string[]) => (
    <div key={title}>
      {!collapsed ? <p className="admin-nav-section-label">{title}</p> : null}
      <div className="grid gap-1.5">
        {items.map((href) => {
          const item = resolveNavItem(href);
          const Icon = navIcons[href] ?? LayoutDashboard;
          const active = isActivePath(href, pathname);

          return (
            <Link
              key={href}
              href={withAdminClubScope(href, selectedClubId)}
              aria-current={active ? "page" : undefined}
              title={collapsed ? item.label : undefined}
              className={cn(
                "admin-nav-link",
                collapsed && "justify-center px-0",
                active && "admin-nav-link-active",
              )}
            >
              <Icon size={18} className="shrink-0 text-club-accent" />
              {!collapsed ? (
                <span className="text-sm font-semibold">{item.label}</span>
              ) : null}
            </Link>
          );
        })}
      </div>
    </div>
  );

  return (
    <div className="space-y-5">
      {sidebarSections.map((section) =>
        renderSection(section.title, section.items),
      )}
      {contextualSections.map((section) =>
        renderSection(section.title, section.items),
      )}
    </div>
  );
}

export function AdminShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const {
    access,
    activeClub,
    clubOptions,
    error,
    loading,
    notice,
    setClubScope,
    signOut,
    switchingClub,
    user,
  } = useAdminPortal();
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const activeItem = useMemo(() => {
    return [...adminNavigation]
      .sort((left, right) => right.href.length - left.href.length)
      .find((item) => isActivePath(item.href, pathname));
  }, [pathname]);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center px-4 py-12">
        <div
          className={`${ui.panelElevated} w-full max-w-md rounded-[32px] border-[1.2px] p-8 text-center`}
        >
          <div className="flex flex-col items-center gap-4">
            <Image
              src="/icons/icon-192x192.png"
              alt={`${siteConfig.shortTitle} emblem`}
              width={56}
              height={56}
              className="animate-pulse"
              priority
            />
            <p className="text-[11px] font-bold uppercase tracking-[0.26em] text-slate-200">
              Central admin
            </p>
            <p className="text-lg text-white">Loading workspace</p>
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

  const sessionIdentity = user?.phone ?? user?.email ?? user?.id ?? "Admin";
  const selectedClubId =
    activeClub?.id ?? access.clubId ?? clubOptions[0]?.id ?? null;
  const activeClubLabel =
    activeClub?.shortName ||
    activeClub?.clubName ||
    (access.clubId ? `Club ${access.clubId}` : "Club scope");
  const formattedDate = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date());

  return (
    <div className="min-h-screen">
      <a
        href="#admin-main-content"
        className={`sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 ${ui.buttonPrimary} focus:px-4 focus:py-2 focus:text-sm`}
      >
        Skip to main content
      </a>

      <div className="flex min-h-screen">
        <aside
          className={cn(
            "hidden shrink-0 xl:block",
            sidebarCollapsed ? "w-[64px]" : "w-[260px]",
            "transition-all duration-300"
          )}
        >
          <div className="sticky top-0 flex h-screen flex-col border-r border-[var(--admin-border)] bg-[var(--admin-zinc-950)] px-3 py-4">
            <div className="flex items-center justify-between gap-3 border-b border-[var(--admin-border)] pb-4 mb-4">
              {!sidebarCollapsed ? (
                <div className="flex items-center gap-2 px-1">
                  <div className="flex h-8 w-8 items-center justify-center rounded bg-[var(--admin-zinc-100)] text-xs font-bold text-[var(--admin-zinc-950)]">
                    AC
                  </div>
                  <p className="font-bold text-sm tracking-tight text-[var(--admin-zinc-100)]">
                    AFRICLUB
                  </p>
                </div>
              ) : (
                <div className="flex h-8 w-8 mx-auto items-center justify-center rounded bg-[var(--admin-zinc-100)] text-[10px] font-bold text-[var(--admin-zinc-950)]">
                  AC
                </div>
              )}
            </div>

            <div className="flex-1 overflow-y-auto custom-scrollbar">
              <SidebarNavigation
                pathname={pathname}
                selectedClubId={selectedClubId}
                collapsed={sidebarCollapsed}
              />
            </div>

            <div className="mt-4 border-t border-[var(--admin-border)] pt-4">
              {!sidebarCollapsed ? (
                <div className="space-y-3">
                  <div className="px-2">
                    <p className="text-[11px] font-medium text-[var(--admin-zinc-100)] truncate">
                      {sessionIdentity}
                    </p>
                    <p className="text-[10px] text-[var(--admin-zinc-500)] mt-0.5">
                      {formatAdminRoleLabel(access.role)}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => signOut().catch(() => {})}
                    className="w-full text-left px-2 py-1.5 text-[10px] font-bold uppercase tracking-wider text-rose-500 hover:text-rose-400 transition-colors"
                  >
                    Sign out
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => signOut().catch(() => {})}
                  className="w-full flex justify-center text-rose-500 hover:text-rose-400"
                  aria-label="Sign out"
                >
                  <X size={18} />
                </button>
              )}
            </div>
          </div>
        </aside>

        <div className="min-w-0 flex-1">
          <header className="sticky top-0 z-20 border-b border-[var(--admin-border)] bg-[var(--admin-zinc-950)/80] backdrop-blur-md px-4 py-3 sm:px-6 lg:px-8">
            <div className="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
              <div className="flex items-center gap-4">
                <button
                  type="button"
                  onClick={() => setSidebarCollapsed((v) => !v)}
                  className="hidden rounded-lg p-2 text-[var(--admin-zinc-500)] transition hover:bg-[var(--admin-zinc-900)] hover:text-[var(--admin-zinc-100)] xl:block"
                  aria-label={sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"}
                >
                  {sidebarCollapsed ? <PanelLeftOpen size={18} /> : <PanelLeftClose size={18} />}
                </button>
                <div className="flex items-center gap-2">
                  <h1 className="text-sm font-bold text-[var(--admin-zinc-100)] uppercase tracking-wider">
                    {activeItem?.label ?? "Workspace"}
                  </h1>
                  <span className="text-[10px] text-[var(--admin-zinc-500)] font-medium">
                    / {formattedDate}
                  </span>
                </div>
              </div>

              <div className="flex items-center gap-3">
                {access.canSelectClub && clubOptions.length > 1 ? (
                  <select
                    value={selectedClubId ?? ""}
                    onChange={(e) => setClubScope(e.target.value).catch(() => {})}
                    disabled={switchingClub}
                    aria-busy={switchingClub}
                    className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-zinc-900)] px-3 py-1.5 text-xs font-semibold text-[var(--admin-zinc-100)] outline-none"
                  >
                    {clubOptions.map((club) => (
                      <option key={club.id} value={club.id}>{club.clubName}</option>
                    ))}
                  </select>
                ) : (
                  <span className="text-xs font-semibold text-[var(--admin-zinc-400)]">
                    {activeClubLabel}
                  </span>
                )}
                <AdminStatusBadge
                  label={formatAdminRoleLabel(access.role)}
                  tone={roleTone(access.role)}
                />
              </div>
            </div>
            <AdminWorkspaceSignal
              error={error}
              notice={notice}
              switchingClub={switchingClub}
            />
          </header>

          <main
            id="admin-main-content"
            className="p-4 sm:p-6 lg:p-8"
            aria-busy={switchingClub || undefined}
          >
            <div className="mx-auto max-w-full">
              {children}
            </div>
          </main>
        </div>
      </div>


      <AdminMobileNav
        pathname={pathname}
        onSignOut={() => signOut().catch(() => {})}
        selectedClubId={selectedClubId}
      />
    </div>
  );
}

interface AdminMobileNavProps {
  pathname: string;
  onSignOut: () => void;
  selectedClubId: string | null;
}

function AdminMobileNav({
  pathname,
  onSignOut,
  selectedClubId,
}: AdminMobileNavProps) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const primaryItems = primaryMobileTabs.map(resolveNavItem);
  const overflowSections = [
    ...sidebarSections
      .map((section) => ({
        ...section,
        items: section.items.filter(
          (href) => !primaryMobileTabs.includes(href),
        ),
      }))
      .filter((section) => section.items.length > 0),
    ...(pathname.startsWith("/admin/cms")
      ? [{ title: "CMS views", items: cmsViews }]
      : []),
  ];

  return (
    <>
      <nav
        className="fixed inset-x-0 bottom-0 z-30 border-t border-[var(--admin-border)] bg-[var(--admin-zinc-950)] pb-[env(safe-area-inset-bottom)] xl:hidden"
        aria-label="Admin mobile navigation"
      >
        <div className="mx-auto flex max-w-md items-stretch justify-around px-3 pt-2">
          {primaryItems.map((item) => {
            const active = isActivePath(item.href, pathname);
            const Icon = navIcons[item.href] ?? LayoutDashboard;

            return (
              <Link
                key={item.href}
                href={withAdminClubScope(item.href, selectedClubId)}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "flex flex-col items-center gap-1 p-2 transition-colors",
                  active ? "text-[var(--admin-zinc-100)]" : "text-[var(--admin-zinc-500)]"
                )}
              >
                <Icon size={20} />
                <span className="text-[9px] font-bold uppercase tracking-wider">{item.label}</span>
              </Link>
            );
          })}

          <button
            type="button"
            onClick={() => setSheetOpen(true)}
            className={cn(
              "flex flex-col items-center gap-1 p-2",
              sheetOpen ? "text-[var(--admin-zinc-100)]" : "text-[var(--admin-zinc-500)]"
            )}
            aria-label="Show more admin options"
          >
            <MoreHorizontal size={20} />
            <span className="text-[9px] font-bold uppercase tracking-wider">More</span>
          </button>
        </div>
      </nav>

      <AdminDialogFrame
        open={sheetOpen}
        onClose={() => setSheetOpen(false)}
        title="More admin options"
        layout="sheet"
        panelClassName="xl:hidden"
        bodyClassName="space-y-6 pb-[calc(env(safe-area-inset-bottom)+1rem)]"
        closeLabel="Close admin menu"
      >
        {overflowSections.map((section) => (
          <div key={section.title}>
            <p className="mb-3 text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--admin-zinc-600)]">
              {section.title}
            </p>
            <div className="grid gap-1">
              {section.items.map((href) => {
                const item = resolveNavItem(href);
                const Icon = navIcons[href] ?? LayoutDashboard;
                const active = isActivePath(href, pathname);

                return (
                  <Link
                    key={href}
                    href={withAdminClubScope(href, selectedClubId)}
                    onClick={() => setSheetOpen(false)}
                    className={cn(
                      "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                      active
                        ? "bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-100)]"
                        : "text-[var(--admin-zinc-400)] hover:bg-[var(--admin-zinc-800)]",
                    )}
                  >
                    <Icon size={18} className="text-[var(--admin-zinc-500)]" />
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}

        <button
          type="button"
          onClick={() => {
            setSheetOpen(false);
            onSignOut();
          }}
          className="mt-2 w-full rounded-lg border border-rose-500/20 bg-rose-500/5 py-3 text-sm font-bold uppercase tracking-wider text-rose-500"
        >
          Sign out
        </button>
      </AdminDialogFrame>
    </>
  );
}
