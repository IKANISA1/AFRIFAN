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
  Crown,
  FileImage,
  FileText,
  HandHeart,
  Handshake,
  LayoutDashboard,
  ListOrdered,
  MessageCircle,
  MoreHorizontal,
  Newspaper,
  Settings,
  Settings2,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  Sparkles,
  Trophy,
  Users,
  X,
} from "lucide-react";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { formatAdminPhoneForDisplay } from "@/lib/admin-auth";
import { adminNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { formatAdminRoleLabel } from "@/lib/data/admin/access";
import { cn } from "@/lib/utils";
import { ui } from "@/design-system";

const navIcons: Record<string, LucideIcon> = {
  "/admin": LayoutDashboard,
  "/admin/settings": Settings,
  "/admin/fantasy": Sparkles,
  "/admin/cms": FileText,
  "/admin/cms/banners": FileImage,
  "/admin/cms/content": Newspaper,
  "/admin/cms/config": Settings2,
  "/admin/matches": Trophy,
  "/admin/squad": Users,
  "/admin/shop": ShoppingBag,
  "/admin/membership": Crown,
  "/admin/gamification": Award,
  "/admin/community": Handshake,
  "/admin/standings": ListOrdered,
  "/admin/contributions": HandHeart,
  "/admin/notifications": Bell,
  "/admin/sms-monitor": Smartphone,
};

const sidebarSections = [
  {
    title: "Core",
    items: ["/admin", "/admin/matches", "/admin/notifications", "/admin/sms-monitor"],
  },
  {
    title: "Supporters",
    items: ["/admin/community", "/admin/contributions", "/admin/membership", "/admin/shop"],
  },
  {
    title: "Content",
    items: ["/admin/cms", "/admin/squad", "/admin/standings"],
  },
  {
    title: "Platform",
    items: ["/admin/fantasy", "/admin/gamification", "/admin/settings"],
  },
];

const cmsViews = ["/admin/cms/banners", "/admin/cms/content", "/admin/cms/config"];
const primaryMobileTabs = ["/admin", "/admin/matches", "/admin/cms", "/admin/notifications"];

function resolveNavItem(href: string) {
  return adminNavigation.find((item) => item.href === href) ?? { href, label: href };
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
    setStatus("Sending code");

    try {
      await requestWhatsAppCode(phone);
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
      await verifyWhatsAppCode(code);
      setStatus("Verified");
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Verification failed.",
      );
    }
  }

  const activePhone = pendingPhone ?? (phone.trim() || null);

  return (
    <div className="page-shell py-10 sm:py-16">
      <div className={`${ui.panel} mx-auto grid max-w-lg gap-6 rounded-[28px] p-6 sm:p-8`}>
        <div className="space-y-3 text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl border border-border-soft bg-white/5">
            <Image
              src="/icons/icon-192x192.png"
              alt={`${siteConfig.shortTitle} emblem`}
              width={34}
              height={34}
              priority
            />
          </div>
          <div className="space-y-1">
            <p className="admin-page-eyebrow">Admin workspace</p>
            <h1 className="admin-page-title">Secure sign in</h1>
            <p className="admin-page-copy mx-auto max-w-sm">
              Use your approved WhatsApp number to unlock the operations workspace.
            </p>
          </div>
        </div>

        <div className={`${ui.panelInset} grid gap-4 rounded-[22px] p-5`}>
          <div className="flex items-center gap-3">
            <div className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#25d366]/30 bg-[#25d366]/12 text-[#25d366]">
              <MessageCircle className="h-4 w-4" />
            </div>
            <p className="text-sm text-slate-300">
              {activePhone ? "Enter the 6-digit code" : "Enter your WhatsApp number"}
            </p>
          </div>

          {!activePhone ? (
            <form className="grid gap-4" onSubmit={handlePhoneSubmit}>
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
    <div className="page-shell py-10 sm:py-16">
      <div className={`${ui.panel} mx-auto grid max-w-3xl gap-5 rounded-[28px] p-6 sm:p-8`}>
        <div className={`${ui.iconButton} h-14 w-14 text-club-accent`}>
          <ShieldCheck className="h-6 w-6 text-club-accent" />
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
  );
}

function SidebarNavigation({
  pathname,
}: {
  pathname: string;
}) {
  const contextualSections = pathname.startsWith("/admin/cms")
    ? [{ title: "CMS views", items: cmsViews }]
    : [];

  return (
    <div className="space-y-5">
      {sidebarSections.map((section) => (
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
                  href={href}
                  aria-current={active ? "page" : undefined}
                  className={cn("admin-nav-link", active && "admin-nav-link-active")}
                >
                  <Icon size={17} className="shrink-0 text-club-accent" />
                  <span className="text-sm font-semibold">{item.label}</span>
                </Link>
              );
            })}
          </div>
        </div>
      ))}

      {contextualSections.map((section) => (
        <div key={section.title}>
          <p className="admin-nav-section-label">{section.title}</p>
          <div className="grid gap-1.5">
            {section.items.map((href) => {
              const item = resolveNavItem(href);
              const Icon = navIcons[href] ?? FileText;
              const active = isActivePath(href, pathname);

              return (
                <Link
                  key={href}
                  href={href}
                  aria-current={active ? "page" : undefined}
                  className={cn("admin-nav-link", active && "admin-nav-link-active")}
                >
                  <Icon size={17} className="shrink-0 text-club-accent" />
                  <span className="text-sm font-semibold">{item.label}</span>
                </Link>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

export function AdminShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const { access, error, loading, notice, signOut, user } = useAdminPortal();

  const activeItem = useMemo(() => {
    return [...adminNavigation]
      .sort((left, right) => right.href.length - left.href.length)
      .find((item) => isActivePath(item.href, pathname));
  }, [pathname]);

  if (loading) {
    return (
      <div className="page-shell py-10 sm:py-16">
        <div className={`${ui.panel} mx-auto max-w-md rounded-[28px] p-8`}>
          <div className="flex flex-col items-center gap-4 text-center">
            <Image
              src="/icons/icon-192x192.png"
              alt={`${siteConfig.shortTitle} emblem`}
              width={56}
              height={56}
              className="animate-pulse"
              priority
            />
            <p className="admin-page-eyebrow">Admin workspace</p>
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

  return (
    <div className="page-shell pb-28 pt-6 lg:py-8">
      <a
        href="#admin-main-content"
        className={`sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 ${ui.buttonPrimary} focus:px-4 focus:py-2 focus:text-sm`}
      >
        Skip to main content
      </a>

      <div className="grid gap-6 xl:grid-cols-[292px_minmax(0,1fr)]">
        <aside className={`${ui.panel} hidden h-fit rounded-[28px] p-5 xl:sticky xl:top-6 xl:block`}>
          <div className="flex items-center gap-3 border-b border-white/6 pb-5">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl border border-border-soft bg-white/5">
              <Image
                src="/icons/icon-192x192.png"
                alt={`${siteConfig.shortTitle} emblem`}
                width={28}
                height={28}
              />
            </div>
            <div className="space-y-1">
              <p className="text-sm font-semibold text-white">Club admin</p>
              <p className="text-xs text-slate-400">Operations workspace</p>
            </div>
          </div>

          <div className="admin-session-panel mt-5 space-y-3">
            <div className="flex items-center justify-between gap-3">
              <p className="admin-page-eyebrow">Session</p>
              <AdminStatusBadge
                label={formatAdminRoleLabel(access.role)}
                tone={roleTone(access.role)}
              />
            </div>
            <p className="break-all text-sm font-medium text-white">{sessionIdentity}</p>
            <div className="flex flex-wrap gap-2">
              <span className="admin-meta-chip">
                {access.canSelectClub ? "Multi-club" : "Club scoped"}
              </span>
              <span className="admin-meta-chip">
                {access.assignmentCount} assignment{access.assignmentCount === 1 ? "" : "s"}
              </span>
            </div>
          </div>

          <div className="mt-5">
            <SidebarNavigation pathname={pathname} />
          </div>

          <button
            type="button"
            onClick={() => signOut().catch(() => {})}
            className={`${ui.buttonSecondary} mt-6 w-full hover:border-rose-400/30 hover:text-rose-200`}
          >
            Sign out
          </button>
        </aside>

        <main id="admin-main-content" className="space-y-6 pb-8">
          <div className={`${ui.panel} rounded-[24px] p-4 sm:p-5`}>
            <div className="admin-topbar">
              <div className="flex flex-wrap items-center gap-2">
                <span className="admin-meta-chip">Workspace</span>
                {activeItem ? <span className="admin-meta-chip">{activeItem.label}</span> : null}
                <span className="admin-meta-chip">
                  {new Intl.DateTimeFormat("en-US", {
                    month: "short",
                    day: "numeric",
                    hour: "2-digit",
                    minute: "2-digit",
                  }).format(new Date())}
                </span>
              </div>
              <p className="text-sm text-slate-400">{sessionIdentity}</p>
            </div>
            {notice ? (
              <div className="mt-4 rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-sm text-slate-200">
                {notice}
              </div>
            ) : null}
            {error ? (
              <div className="mt-4 rounded-2xl border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
                {error}
              </div>
            ) : null}
          </div>

          {children}
        </main>
      </div>

      <AdminMobileNav pathname={pathname} onSignOut={() => signOut().catch(() => {})} />
    </div>
  );
}

interface AdminMobileNavProps {
  pathname: string;
  onSignOut: () => void;
}

function AdminMobileNav({ pathname, onSignOut }: AdminMobileNavProps) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const primaryItems = primaryMobileTabs.map(resolveNavItem);
  const overflowSections = [
    ...sidebarSections
      .map((section) => ({
        ...section,
        items: section.items.filter((href) => !primaryMobileTabs.includes(href)),
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
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={cn(active ? ui.navTabActive : ui.navTab)}
              >
                <Icon size={22} strokeWidth={active ? 2.2 : 1.6} />
                <span className={cn("leading-none", active ? ui.kicker : "text-[11px] uppercase tracking-[0.2em]")}>
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
          <div className={`${ui.panel} absolute inset-x-0 bottom-0 rounded-t-[28px] p-5 pb-[calc(env(safe-area-inset-bottom)+1rem)]`}>
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
                          href={href}
                          onClick={() => setSheetOpen(false)}
                          aria-current={active ? "page" : undefined}
                          className={cn("admin-nav-link", active && "admin-nav-link-active")}
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
