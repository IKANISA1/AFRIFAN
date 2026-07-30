"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Landmark, ShieldCheck, Ticket } from "lucide-react";
import { cn } from "@/lib/utils";
import type { SiteChromeCopy } from "@/lib/site-copy";
import { PlatformFeature } from "@/lib/feature-config";

const BASE_TABS = [
  {
    id: "home",
    featureKey: "home",
    href: "/",
    icon: Landmark,
    label: "Home",
  },
  {
    id: "tickets",
    featureKey: "ticketing",
    href: "/tickets",
    icon: Ticket,
    label: "Tickets",
  },
  {
    id: "membership",
    featureKey: "membership",
    href: "/membership",
    icon: ShieldCheck,
    label: "Membership",
  },
] as const;

function resolveActiveTab(pathname: string): string {
  if (
    pathname === "/" ||
    pathname === "/home" ||
    pathname.startsWith("/fixtures") ||
    pathname.startsWith("/results") ||
    pathname.startsWith("/standings") ||
    pathname.startsWith("/news") ||
    pathname.startsWith("/shop")
  ) {
    return "home";
  }

  if (
    pathname.startsWith("/tickets") ||
    pathname.startsWith("/supporters")
  ) {
    return "tickets";
  }

  if (
    pathname.startsWith("/membership") ||
    pathname.startsWith("/Groups") ||
    pathname.startsWith("/fan-clubs") ||
    pathname.startsWith("/contact")
  ) {
    return "membership";
  }

  return "home";
}

export function AppBottomNav({ 
  copy, 
  features = [] 
}: { 
  copy: SiteChromeCopy;
  features?: PlatformFeature[];
}) {
  const pathname = usePathname();
  const activeTab = resolveActiveTab(pathname);
  
  const tabs = BASE_TABS.filter((tab) => {
    if (tab.id === "home") return true;
    const feature = features.find((entry) => entry.feature_key === tab.featureKey);
    return feature != null;
  }).map((tab) => {
    // Map label from copy
    const label = tab.id === 'home' ? copy.home :
      tab.id === 'tickets' ? copy.tickets : copy.membership;
    const feature = features.find((entry) => entry.feature_key === tab.featureKey);
    return {
      ...tab,
      href: feature?.channel?.route_key || tab.href,
      label,
    };
  });

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-50 border-t border-white/10 bg-[var(--club-primary)]/90 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl md:hidden"
      aria-label="Main navigation"
    >
      <div className="mx-auto flex max-w-md items-stretch justify-around px-[8px] pt-[8px]">
        {tabs.map((tab) => {
          const active = tab.id === activeTab;
          const Icon = tab.icon;

          return (
            <Link
              key={tab.id}
              href={tab.href}
              prefetch={false}
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex min-w-0 flex-1 flex-col items-center gap-[6px] py-[8px] transition-all duration-300 active:scale-95",
                active ? "text-[var(--club-accent)]" : "text-white/80 hover:text-white"
              )}
            >
              <div className={cn(
                "flex h-[32px] w-[48px] items-center justify-center rounded-full transition-all duration-300",
                active && "bg-[var(--club-accent)]/10"
              )}>
                <Icon
                  size={20}
                  strokeWidth={active ? 2.5 : 2}
                />
              </div>
              <span className={cn(
                "max-w-full text-center text-[0.5625rem] font-black uppercase tracking-normal transition-colors [overflow-wrap:anywhere]",
                active ? "text-white" : "text-white/80"
              )}>
                {tab.label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
