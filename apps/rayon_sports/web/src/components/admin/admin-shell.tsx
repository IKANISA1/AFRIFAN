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
      "/admin/community",
      "/admin/contributions",
      "/admin/membership",
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
    ],
  },
];

const cmsViews = [
  "/admin/cms/banners",
  "/admin/cms/content",
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

  async function handlePhoneSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("Sending code");

    try {
      await requestPhoneCode(phone);
      setCode("");
      setStatus("Code sent");
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not send code.",
      );
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
    <div className="flex min-h-screen items-center justify-center px-4 py-12">
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
            sidebarCollapsed ? "w-[96px]" : "w-[304px]",
          )}
        >
          <div className="sticky top-0 flex h-screen flex-col border-r border-[var(--admin-border)] bg-[linear-gradient(180deg,rgba(22,18,56,0.98),rgba(13,10,39,0.99))] px-4 py-5 shadow-[20px_0_60px_-42px_rgba(5,4,16,0.96)]">
            <div className="flex items-center justify-between gap-3 border-b border-white/8 pb-5">
              <div className="flex min-w-0 items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-2xl border border-white/10 bg-[linear-gradient(135deg,#6C63FF,#8781FF)] text-base font-bold text-white">
                  AC
                </div>
                {!sidebarCollapsed ? (
                  <div className="min-w-0">
                    <p className="font-display text-xl font-bold uppercase tracking-[-0.05em] text-white">
                      AFRICLUB
                    </p>
                    <p className="text-xs uppercase tracking-[0.22em] text-slate-400">
                      Central admin
                    </p>
                  </div>
                ) : null}
              </div>
              <button
                type="button"
                onClick={() => setSidebarCollapsed((value) => !value)}
                className={`${ui.iconButton} h-10 w-10 p-0 text-slate-300`}
                aria-label={
                  sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"
                }
              >
                {sidebarCollapsed ? (
                  <PanelLeftOpen size={18} />
                ) : (
                  <PanelLeftClose size={18} />
                )}
              </button>
            </div>

            {!sidebarCollapsed ? (
              <div className="mt-5 rounded-[24px] border border-white/10 bg-white/[0.04] p-4">
                <div className="flex items-center justify-between gap-3">
                  <p className="admin-page-eyebrow">Workspace</p>
                  <AdminStatusBadge
                    label={formatAdminRoleLabel(access.role)}
                    tone={roleTone(access.role)}
                  />
                </div>
                <p className="mt-3 text-sm font-semibold text-white">
                  {activeClubLabel}
                </p>
                <p className="mt-1 text-xs text-slate-400">
                  {access.canSelectClub
                    ? "Centralized control for all assigned clubs."
                    : "Single-club control lane."}
                </p>
              </div>
            ) : null}

            <div className="mt-5 flex-1 overflow-y-auto pr-1 custom-scrollbar">
              <SidebarNavigation
                pathname={pathname}
                selectedClubId={selectedClubId}
                collapsed={sidebarCollapsed}
              />
            </div>

            {!sidebarCollapsed ? (
              <div className="mt-5 rounded-[24px] border border-white/10 bg-white/[0.04] p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-white">
                      {sessionIdentity}
                    </p>
                    <p className="mt-1 text-xs text-slate-400">
                      {access.assignmentCount} assignment
                      {access.assignmentCount === 1 ? "" : "s"}
                    </p>
                  </div>
                  <span className="rounded-full bg-white/8 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                    {access.canSelectClub ? "Multi-club" : "Scoped"}
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => signOut().catch(() => {})}
                  className={`${ui.buttonSecondary} mt-4 w-full hover:border-rose-400/30 hover:text-rose-200`}
                >
                  Sign out
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => signOut().catch(() => {})}
                className={`${ui.iconButton} mt-5 h-11 w-11 self-center p-0 text-slate-300 hover:border-rose-400/30 hover:text-rose-200`}
                aria-label="Sign out"
              >
                <X size={18} />
              </button>
            )}
          </div>
        </aside>

        <div className="min-w-0 flex-1">
          <div className="sticky top-0 z-20 px-4 py-4 sm:px-6 lg:px-8">
            <div
              className={`${ui.panel} rounded-[30px] border-[1.2px] px-4 py-4 sm:px-5`}
            >
              <div className="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
                <div className="flex flex-wrap items-center gap-3">
                  <button
                    type="button"
                    onClick={() => setSidebarCollapsed((value) => !value)}
                    className={`${ui.iconButton} hidden h-11 w-11 p-0 text-slate-300 xl:inline-flex`}
                    aria-label={
                      sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"
                    }
                  >
                    {sidebarCollapsed ? (
                      <PanelLeftOpen size={18} />
                    ) : (
                      <PanelLeftClose size={18} />
                    )}
                  </button>
                  <div>
                    <p className="admin-page-eyebrow">Command center</p>
                    <div className="mt-1 flex flex-wrap items-center gap-2">
                      <p className="font-display text-[1.7rem] font-bold uppercase tracking-[-0.05em] text-white">
                        {activeItem?.label ?? "Workspace"}
                      </p>
                      <span className="rounded-full border border-white/10 bg-white/6 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                        {formattedDate}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col gap-3 xl:items-end">
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="hidden items-center gap-3 rounded-full border border-white/10 bg-white/[0.04] px-4 py-3 xl:flex">
                      <Search size={16} className="text-slate-400" />
                      <span className="text-sm text-slate-300">
                        Search platform
                      </span>
                      <kbd className="inline-flex h-6 items-center gap-1 rounded-full border border-white/10 bg-black/20 px-2 font-mono text-[10px] font-semibold text-slate-400">
                        <Command size={10} />K
                      </kbd>
                    </div>

                    {access.canSelectClub && clubOptions.length > 1 ? (
                      <label className="flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-4 py-3 text-sm text-slate-200">
                        <Sparkles size={15} className="text-club-accent" />
                        <select
                          value={selectedClubId ?? ""}
                          onChange={(event) => {
                            setClubScope(event.target.value).catch(() => {});
                          }}
                          disabled={switchingClub}
                          className="bg-transparent font-semibold text-white outline-none disabled:opacity-60"
                        >
                          {clubOptions.map((club) => (
                            <option
                              key={club.id}
                              value={club.id}
                              className="bg-[#141133]"
                            >
                              {club.clubName}
                            </option>
                          ))}
                        </select>
                      </label>
                    ) : (
                      <span className="rounded-full border border-white/10 bg-white/[0.04] px-4 py-3 text-sm font-semibold text-white">
                        {activeClubLabel}
                      </span>
                    )}

                    <AdminStatusBadge
                      label={formatAdminRoleLabel(access.role)}
                      tone={roleTone(access.role)}
                    />
                  </div>

                  <div className="flex flex-wrap items-center gap-2 text-xs uppercase tracking-[0.18em] text-slate-400">
                    <span className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5">
                      {access.canSelectClub
                        ? "Centralized admin"
                        : "Club admin"}
                    </span>
                    <span className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5">
                      {activeClub?.clubSlug ?? "club-scope"}
                    </span>
                    <span className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5">
                      {activeClub?.currencyCode ?? "USD"}
                    </span>
                  </div>
                </div>
              </div>

              {notice ? (
                <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.05] px-4 py-3 text-sm text-slate-200">
                  {switchingClub
                    ? "Refreshing the workspace for the selected club..."
                    : notice}
                </div>
              ) : null}
              {error ? (
                <div className="mt-4 rounded-2xl border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
                  {error}
                </div>
              ) : null}
            </div>
          </div>

          <main id="admin-main-content" className="px-4 pb-28 sm:px-6 lg:px-8">
            <div className="mx-auto flex max-w-[1480px] flex-col gap-6">
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
        className={`fixed inset-x-0 bottom-0 z-30 pb-[env(safe-area-inset-bottom)] xl:hidden ${ui.shellBar}`}
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
                className={cn(active ? ui.navTabActive : ui.navTab)}
              >
                <Icon size={22} strokeWidth={active ? 2.2 : 1.6} />
                <span
                  className={cn(
                    "leading-none",
                    active
                      ? ui.kicker
                      : "text-[11px] uppercase tracking-[0.2em]",
                  )}
                >
                  {item.label}
                </span>
                {active ? <span className={ui.navIndicator} /> : null}
              </Link>
            );
          })}

          <button
            type="button"
            onClick={() => setSheetOpen(true)}
            className={cn(sheetOpen ? ui.navTabActive : ui.navTab)}
            aria-label="Show more admin options"
          >
            <MoreHorizontal size={22} strokeWidth={1.6} />
            <span className="leading-none">More</span>
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
            className={`absolute inset-0 ${ui.drawerScrim}`}
            onClick={() => setSheetOpen(false)}
            onKeyDown={(event) => event.key === "Escape" && setSheetOpen(false)}
          />
          <div
            className={`${ui.panel} absolute inset-x-0 bottom-0 rounded-t-[30px] p-5 pb-[calc(env(safe-area-inset-bottom)+1rem)]`}
          >
            <div className="flex items-center justify-between pb-4">
              <p className="text-base font-semibold text-white">More</p>
              <button
                type="button"
                onClick={() => setSheetOpen(false)}
                className={`${ui.iconButton} h-10 w-10 p-2 text-slate-300`}
                aria-label="Close"
              >
                <X size={20} />
              </button>
            </div>

            <div className="space-y-5">
              {overflowSections.map((section) => (
                <div key={section.title}>
                  <p className="admin-nav-section-label">{section.title}</p>
                  <div className="grid gap-1.5">
                    {section.items.map((href) => {
                      const item = resolveNavItem(href);
                      const Icon = navIcons[href] ?? LayoutDashboard;
                      const active = isActivePath(href, pathname);

                      return (
                        <Link
                          key={href}
                          href={withAdminClubScope(href, selectedClubId)}
                          onClick={() => setSheetOpen(false)}
                          aria-current={active ? "page" : undefined}
                          className={cn(
                            "admin-nav-link",
                            active && "admin-nav-link-active",
                          )}
                        >
                          <Icon size={18} className="text-club-accent" />
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
              className={`${ui.buttonSecondary} mt-5 w-full hover:border-rose-400/30 hover:text-rose-200`}
            >
              Sign out
            </button>
          </div>
        </div>
      ) : null}
    </>
  );
}
