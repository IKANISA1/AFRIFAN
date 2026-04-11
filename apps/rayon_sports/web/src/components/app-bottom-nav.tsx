"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Landmark, ShieldCheck, Ticket } from "lucide-react";
import { cn } from "@/lib/utils";
import { ui } from "@/design-system";

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
    pathname.startsWith("/fantasy") ||
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
      className={`fixed inset-x-0 bottom-0 z-50 pb-[env(safe-area-inset-bottom)] ${ui.shellBar}`}
      aria-label="Main navigation"
    >
      <div className="mx-auto flex max-w-md items-stretch justify-around px-3 pt-2">
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
                active ? ui.navTabActive : ui.navTab,
                !active && "active:text-slate-200",
              )}
            >
              <Icon
                size={22}
                strokeWidth={active ? 2.2 : 1.6}
                className="transition-transform active:scale-90"
              />
              <span className={cn("leading-none", active ? ui.kicker : "text-[11px] uppercase tracking-[0.22em]")}>
                {tab.label}
              </span>
              {active ? (
                <span className={ui.navIndicator} />
              ) : null}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
