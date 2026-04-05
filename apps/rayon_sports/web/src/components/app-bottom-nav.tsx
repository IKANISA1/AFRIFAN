"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Landmark, ScanFace, Settings } from "lucide-react";
import {
  normalizePortalPathname,
  resolvePortalHref,
} from "@/lib/host-routing";
import { cn } from "@/lib/utils";

/**
 * Fans PWA bottom navigation — mirrors the native Flutter app exactly.
 *
 * Flutter tabs (AfriClubBottomNav):
 *   1. HOME     → Icons.stadium_outlined / Icons.stadium
 *   2. BIOPAY   → Icons.face_outlined / Icons.face
 *   3. SETTINGS → Icons.settings_outlined / Icons.settings
 *
 * Lucide equivalents:
 *   stadium → Landmark (closest architectural venue icon)
 *   face    → ScanFace (biometric scan context)
 *   settings → Settings
 */
const tabs = [
  {
    id: "home",
    href: "/app/home",
    siteHref: "/",
    icon: Landmark,
    label: "Home",
  },
  {
    id: "biopay",
    href: "/app/biopay",
    siteHref: "/biopay",
    icon: ScanFace,
    label: "BioPay",
  },
  {
    id: "settings",
    href: "/app/profile",
    siteHref: "/membership",
    icon: Settings,
    label: "Settings",
  },
] as const;

/* Map routes to tab IDs for active-state matching */
function resolveActiveTab(pathname: string): string {
  const normalized = normalizePortalPathname(pathname);

  /* Home tab: home, matches, live, tickets, shop — all content tabs */
  if (
    normalized === "/app" ||
    normalized === "/app/home" ||
    normalized.startsWith("/app/live") ||
    normalized.startsWith("/app/tickets") ||
    normalized.startsWith("/app/shop") ||
    normalized.startsWith("/app/fan-clubs") ||
    normalized.startsWith("/app/contributions") ||
    normalized.startsWith("/app/xp")
  )
    return "home";

  /* BioPay tab */
  if (normalized.startsWith("/app/biopay")) return "biopay";

  /* Settings tab: profile, membership */
  if (
    normalized.startsWith("/app/profile") ||
    normalized.startsWith("/app/membership") ||
    normalized.startsWith("/app/settings")
  )
    return "settings";

  /* Public site route mapping */
  if (pathname === "/" || pathname === "/home") return "home";
  if (
    pathname.startsWith("/fixtures") ||
    pathname.startsWith("/results") ||
    pathname.startsWith("/standings") ||
    pathname.startsWith("/tickets") ||
    pathname.startsWith("/shop")
  )
    return "home";
  if (pathname.startsWith("/biopay")) return "biopay";
  if (
    pathname.startsWith("/membership") ||
    pathname.startsWith("/circles") ||
    pathname.startsWith("/profile") ||
    pathname.startsWith("/settings")
  )
    return "settings";

  return "home";
}

interface AppBottomNavProps {
  /** Which surface is rendering this nav — affects route resolution */
  surface: "site" | "portal";
}

export function AppBottomNav({ surface }: AppBottomNavProps) {
  const pathname = usePathname();
  const activeTab = resolveActiveTab(pathname);

  return (
    <nav
      className={cn(
        "fixed inset-x-0 bottom-0 z-50 border-t border-border-soft bg-surface-strong/95 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl",
        surface === "portal" && "lg:hidden",
      )}
      aria-label="Main navigation"
    >
      <div className="mx-auto flex max-w-md items-stretch justify-around">
        {tabs.map((tab) => {
          const active = tab.id === activeTab;
          const Icon = tab.icon;

          /* Resolve the correct href depending on surface */
          const href =
            surface === "portal"
              ? resolvePortalHref(pathname, tab.href)
              : tab.siteHref;

          return (
            <Link
              key={tab.id}
              href={href}
              prefetch={false}
              aria-current={active ? "page" : undefined}
              aria-label={tab.label}
              className={cn(
                "relative flex flex-1 flex-col items-center gap-1 rounded-xl py-2.5 text-[11px] font-medium transition-colors",
                active
                  ? "bg-club-primary/10 text-club-accent"
                  : "text-slate-300 active:text-slate-200",
              )}
            >
              <Icon
                size={22}
                strokeWidth={active ? 2.2 : 1.6}
                className="transition-transform active:scale-90"
              />
              <span className="leading-none">{tab.label}</span>
              {active ? (
                <span className="absolute top-0 left-1/2 h-[2.5px] w-5 -translate-x-1/2 rounded-full bg-club-accent" />
              ) : null}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
