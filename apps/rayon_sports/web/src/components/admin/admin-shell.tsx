"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useMemo, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import {
  Award,
  Bell,
  Command,
  Crown,
  FileImage,
  FileText,
  HandHeart,
  Handshake,
  LayoutDashboard,
  ListOrdered,
  MoreHorizontal,
  Newspaper,
  PanelLeftClose,
  PanelLeftOpen,
  Search,
  Settings,
  Settings2,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  Sparkles,
  Trophy,
  Users,
  Wallet,
  X,
} from "lucide-react";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { formatAdminPhoneForDisplay } from "@/lib/admin-auth";
import { withAdminClubScope } from "@/lib/admin-club-scope";
import { adminNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { formatAdminRoleLabel } from "@/lib/data/admin/access";
import { cn } from "@/lib/utils";
import { ui } from "@/design-system";

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
  "/admin/membership": Crown,
  "/admin/gamification": Award,
  "/admin/gamification/wallet": Wallet,
  "/admin/community": Handshake,
  "/admin/standings": ListOrdered,
  "/admin/contributions": HandHeart,
  "/admin/notifications": Bell,
  "/admin/sms-monitor": Smartphone,
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

function AdminAuthCard() {
  const {
    requestPhoneCode,
    verifyPhoneCode,
    pendingPhone,
    resetPendingPhone,
    error,
    notice,
    loading,
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

  const activePhone = pendingPhone ?? (phone.trim() || null);

  return (
    <div className="flex min-h-screen items-center justify-center px-4 py-12 relative">
      {showContactPopup && (
        <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4">
          <div className={`${ui.panelElevated} w-full max-w-sm rounded-[32px] border-[1.2px] p-6 sm:p-8 text-center`}>
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-[#25D366]/10 text-[#25D366]">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M12.031 0C5.405 0 0 5.413 0 12.046C0 14.167 0.553 16.236 1.583 18.056L0.519 21.93L4.492 20.887C6.262 21.83 8.248 22.33 12.029 22.33C18.653 22.33 24.058 16.917 24.058 10.286C24.058 3.654 18.653 0 12.031 0ZM18.423 15.65C18.158 16.398 17.126 17.067 16.326 17.228C15.776 17.337 14.982 17.433 12.185 16.268C8.611 14.779 6.275 11.134 6.061 10.85C5.847 10.566 4.3 8.016 4.3 5.385C4.3 2.753 5.568 1.488 5.86 1.189C6.151 0.89 6.643 0.767 7.108 0.767C7.257 0.767 7.391 0.774 7.51 0.781C7.868 0.8 8.077 0.831 8.314 1.408C8.611 2.128 9.336 3.916 9.426 4.103C9.515 4.29 9.605 4.526 9.485 4.764C9.366 5.002 9.277 5.111 9.098 5.321C8.919 5.532 8.75 5.679 8.571 5.903C8.402 6.113 8.213 6.34 8.421 6.699C8.63 7.058 9.348 8.23 10.347 9.135C11.635 10.302 12.748 10.67 13.14 10.835C13.531 11 13.784 10.971 14.004 10.742C14.223 10.513 14.862 9.771 15.113 9.422C15.364 9.073 15.602 9.117 15.96 9.251C16.318 9.385 18.218 10.323 18.576 10.502C18.934 10.681 19.172 10.771 19.261 10.92C19.351 11.069 19.351 11.758 19.086 12.506H18.423Z" />
              </svg>
            </div>
            <h2 className="text-xl font-bold text-white mb-2">Access Denied</h2>
            <p className="text-slate-300 text-sm mb-6">
              This number is not registered as an admin. Contact the system administrator via WhatsApp to request access.
            </p>
            <div className="flex flex-col gap-3">
              <a
                href="https://wa.me/250788767816"
                target="_blank"
                rel="norenoopener"
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-[#25D366] px-4 py-3 text-sm font-bold text-white transition-opacity hover:bg-[#20bd5a]"
              >
                Message +250 788 767 816
              </a>
              <button
                type="button"
                onClick={() => setShowContactPopup(false)}
                className="text-sm font-semibold text-slate-400 hover:text-white transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
      <div className="w-full max-w-xl">
        <div
          className={`${ui.panelElevated} overflow-hidden rounded-[36px] border-[1.2px] p-6 sm:p-8`}
        >
          <div className="space-y-6">
            <div className="flex items-center gap-4">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl border border-white/10 bg-white/6">
                <Image
                  src="/icons/icon-192x192.png"
                  alt={`${siteConfig.shortTitle} emblem`}
                  width={34}
                  height={34}
                  priority
                />
              </div>
              <div className="space-y-1">
                <p className="admin-page-eyebrow">Central admin</p>
                <h1 className="admin-page-title text-[2rem] sm:text-[2.4rem]">
                  Secure sign in
                </h1>
              </div>
            </div>

            <div
              className={`${ui.panelInset} grid gap-4 rounded-[28px] p-5 sm:p-6`}
            >
              <div className="flex items-center gap-3">
                <div className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-club-accent/30 bg-club-accent/12 text-club-accent">
                  <Smartphone className="h-4 w-4" />
                </div>
                <p className="text-sm text-slate-300">
                  {activePhone
                    ? "Enter the 6-digit code"
                    : "Use your approved admin phone number"}
                </p>
              </div>

              {!activePhone ? (
                <form className="grid gap-4" onSubmit={handlePhoneSubmit}>
                  <label className="grid gap-2 text-sm text-slate-300">
                    Admin phone number
                    <input
                      type="tel"
                      name="phone"
                      required
                      value={phone}
                      onChange={(event) => setPhone(event.target.value)}
                      placeholder="+250 7xx xxx xxx"
                      autoComplete="tel"
                      className={ui.input}
                    />
                  </label>
                  <button
                    type="submit"
                    disabled={loading}
                    className={`${ui.buttonPrimary} disabled:opacity-60`}
                  >
                    {loading ? "Sending…" : "Send code"}
                  </button>
                </form>
              ) : (
                <form className="grid gap-4" onSubmit={handleCodeSubmit}>
                  <p className="text-sm text-slate-400">
                    Verification code sent to{" "}
                    <span className="font-semibold text-white">
                      {formatAdminPhoneForDisplay(activePhone)}
                    </span>
                  </p>
                  <label className="grid gap-2 text-sm text-slate-300">
                    Verification code
                    <input
                      type="text"
                      name="otp"
                      required
                      value={code}
                      onChange={(event) =>
                        setCode(
                          event.target.value.replace(/[^\d]/g, "").slice(0, 6),
                        )
                      }
                      inputMode="numeric"
                      pattern="[0-9]{6}"
                      autoComplete="one-time-code"
                      placeholder="000000"
                      className={`${ui.input} text-center tracking-[0.45em] text-lg`}
                    />
                  </label>
                  <button
                    type="submit"
                    disabled={loading || code.length < 6}
                    className={`${ui.buttonPrimary} disabled:opacity-60`}
                  >
                    {loading ? "Verifying…" : "Verify"}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setCode("");
                      setStatus(null);
                      resetPendingPhone();
                    }}
                    className={ui.buttonSecondary}
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
                    : "border-white/10 bg-white/6 text-slate-200",
                )}
              >
                {status ?? notice ?? error}
              </div>
            ) : null}
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
            <p className="admin-page-eyebrow">Central admin</p>
            <p className="text-lg text-slate-200">Loading workspace</p>
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
                  className="hidden xl:block text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-100)]"
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
                    className="bg-[var(--admin-zinc-900)] border border-[var(--admin-border)] rounded-md px-3 py-1.5 text-xs font-semibold text-[var(--admin-zinc-100)] outline-none"
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
          </header>

          <main id="admin-main-content" className="p-4 sm:p-6 lg:p-8">
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

      {sheetOpen ? (
        <div
          className="fixed inset-0 z-40 xl:hidden"
          role="dialog"
          aria-modal="true"
          aria-label="More admin options"
        >
          <div
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={() => setSheetOpen(false)}
          />
          <div
            className="absolute inset-x-0 bottom-0 max-h-[80vh] overflow-y-auto rounded-t-xl bg-[var(--admin-zinc-900)] p-5 pb-[calc(env(safe-area-inset-bottom)+1rem)] border-t border-[var(--admin-border)]"
          >
            <div className="flex items-center justify-between pb-4 border-b border-[var(--admin-border)] mb-4">
              <p className="text-sm font-bold uppercase tracking-widest text-[var(--admin-zinc-400)]">Menu</p>
              <button
                type="button"
                onClick={() => setSheetOpen(false)}
                className="text-[var(--admin-zinc-500)]"
              >
                <X size={20} />
              </button>
            </div>

            <div className="space-y-6">
              {overflowSections.map((section) => (
                <div key={section.title}>
                  <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--admin-zinc-600)] mb-3">{section.title}</p>
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
                            active ? "bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-100)]" : "text-[var(--admin-zinc-400)] hover:bg-[var(--admin-zinc-800)]"
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
            </div>

            <button
              type="button"
              onClick={() => {
                setSheetOpen(false);
                onSignOut();
              }}
              className="mt-8 w-full rounded-lg border border-rose-500/20 bg-rose-500/5 py-3 text-sm font-bold uppercase tracking-wider text-rose-500"
            >
              Sign out
            </button>
          </div>
        </div>
      ) : null}
    </>
  );
}
