"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Landmark, ShieldCheck, Ticket } from "lucide-react";
import { cn } from "@/lib/utils";

const tabs = [
  {
    id: "home",
    href: "/",
    icon: Landmark,
    label: "Home",
  },
  {
    id: "tickets",
    href: "/tickets",
    icon: Ticket,
    label: "Tickets",
  },
  {
    id: "membership",
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
    pathname.startsWith("/circles") ||
    pathname.startsWith("/fan-clubs") ||
    pathname.startsWith("/contact")
  ) {
    return "membership";
  }

  return "home";
}

export function AppBottomNav() {
  const pathname = usePathname();
  const activeTab = resolveActiveTab(pathname);

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-50 border-t border-border-soft bg-surface-strong/95 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl"
      aria-label="Main navigation"
    >
      <div className="mx-auto flex max-w-md items-stretch justify-around">
        {tabs.map((tab) => {
          const active = tab.id === activeTab;
          const Icon = tab.icon;

          return (
            <Link
              key={tab.id}
              href={tab.href}
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
