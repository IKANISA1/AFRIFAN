"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import {
  CircleUserRound,
  HandHeart,
  House,
  Radio,
  ScanFace,
  ShieldPlus,
  ShoppingBag,
  Ticket,
  Trophy,
  Users,
  Zap,
} from "lucide-react";
import { portalSidebarNavigation, portalSidebarSecondary } from "@/lib/content";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import {
  normalizePortalPathname,
  resolvePortalHref,
} from "@/lib/host-routing";
import { cn } from "@/lib/utils";
import { AppBottomNav } from "@/components/app-bottom-nav";

const navIcons = {
  "/app/home": House,
  "/app/live": Radio,
  "/app/tickets": Ticket,
  "/app/shop": ShoppingBag,
  "/app/biopay": ScanFace,
  "/app/profile": CircleUserRound,
  "/app/membership": ShieldPlus,
  "/app/contributions": HandHeart,
  "/app/fan-clubs": Users,
  "/app/xp": Zap,
} as const;

export function PortalShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const { loading, error, profile, membership } = useFanPortal();
  const normalizedPathname = normalizePortalPathname(pathname);
  const supporterName = profile?.displayName ?? "Blue wave supporter";
  const supporterAlias = profile?.publicUserId ?? "Alias loading";
  const supporterTier = membership?.tier ?? "fan";
  const supporterChapter = membership?.chapter ?? "Main stand";
  const supporterPoints = membership?.points ?? 0;

  return (
    <div className="page-shell pb-28 pt-6 lg:py-8">
      <a
        href="#fan-main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-club-primary focus:px-4 focus:py-2 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to fan portal content
      </a>

      {/* Mobile identity card removed — supporter info is in the desktop sidebar and Profile page.
           Keeping the first mobile screen task-first per club-app benchmark standards. */}

      <div className="mt-6 grid gap-6 lg:grid-cols-[300px_minmax(0,1fr)] lg:items-start">
        <aside className="glass-panel-elevated hidden h-fit rounded-[34px] p-5 lg:sticky lg:top-6 lg:block">
          <div className="flex items-center gap-4 border-b border-border-soft pb-5">
            <Image
              src="/icons/icon-192x192.png"
              alt="Rayon Sports crest"
              width={52}
              height={52}
              className="rounded-2xl"
            />
            <div>
              <p className="font-mono text-[10px] uppercase tracking-[0.3em] text-club-accent">
                Gikundiro fans
              </p>
              <p className="mt-2 font-display text-3xl font-bold uppercase leading-none text-white">
                Matchday base
              </p>
            </div>
          </div>

          <div className="mt-5 rounded-[26px] border border-border-soft bg-black/20 p-5">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-club-accent">
                  Supporter alias
                </p>
                <p className="mt-3 break-all font-display text-3xl font-bold uppercase text-white">
                  {supporterAlias}
                </p>
              </div>
              <span className="rounded-full border border-club-accent/30 bg-club-accent/12 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-club-accent">
                {supporterTier}
              </span>
            </div>
            <p className="mt-3 text-sm leading-6 text-slate-300">
              {supporterName} is set for tickets, perks, and live club moments.
            </p>
            <div className="mt-5 grid gap-3 sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3">
              <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-300">
                  Chapter
                </p>
                <p className="mt-2 font-semibold text-white">{supporterChapter}</p>
              </div>
              <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-300">
                  FAT
                </p>
                <p className="mt-2 font-semibold text-white">{supporterPoints}</p>
              </div>
              <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-300">
                  Membership
                </p>
                <p className="mt-2 font-semibold text-white">
                  {membership?.membershipNumber ?? "Pending"}
                </p>
              </div>
            </div>
          </div>

          {loading ? (
            <p className="mt-4 text-sm text-slate-300">Starting your matchday base...</p>
          ) : null}
          {error ? (
            <p className="mt-4 rounded-[18px] border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
              {error}
            </p>
          ) : null}

          <nav className="mt-5 flex flex-col gap-1.5" aria-label="Fan portal sidebar">
            {portalSidebarNavigation.map((item) => {
              const active =
                normalizedPathname === item.href ||
                (item.href !== "/app" && normalizedPathname.startsWith(item.href));
              const Icon = navIcons[item.href as keyof typeof navIcons] ?? Trophy;

              return (
                <Link
                  key={item.href}
                  href={resolvePortalHref(pathname, item.href)}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-semibold transition",
                    active
                      ? "bg-club-primary text-white shadow-lg shadow-club-primary/20"
                      : "text-slate-200 hover:bg-white/8",
                  )}
                >
                  <Icon size={18} className="text-club-accent" />
                  {item.label}
                </Link>
              );
            })}

            {/* Discovery items — visually separated */}
            <div className="mt-2 border-t border-border-soft pt-3">
              <p className="mb-2 px-4 text-[10px] uppercase tracking-[0.24em] text-slate-400">
                Explore
              </p>
              {portalSidebarSecondary.map((item) => {
                const active =
                  normalizedPathname === item.href ||
                  (item.href !== "/app" && normalizedPathname.startsWith(item.href));
                const Icon = navIcons[item.href as keyof typeof navIcons] ?? Trophy;

                return (
                  <Link
                    key={item.href}
                    href={resolvePortalHref(pathname, item.href)}
                    aria-current={active ? "page" : undefined}
                    className={cn(
                      "flex items-center gap-3 rounded-2xl px-4 py-2.5 text-sm font-semibold transition",
                      active
                        ? "bg-club-primary text-white shadow-lg shadow-club-primary/20"
                        : "text-slate-300 hover:bg-white/8",
                    )}
                  >
                    <Icon size={16} className="text-club-accent/70" />
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </nav>
        </aside>

        <main id="fan-main-content" className="min-w-0 space-y-6">
          {children}
        </main>
      </div>

      <AppBottomNav surface="portal" />
    </div>
  );
}
