"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { portalNavigation } from "@/lib/content";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { cn } from "@/lib/utils";

export function PortalShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const { loading, error, profile, membership } = useFanPortal();

  return (
    <div className="page-shell grid gap-8 py-8 lg:grid-cols-[280px_minmax(0,1fr)]">
      <aside className="glass-panel h-fit rounded-[32px] p-5">
        <div className="space-y-3 border-b border-border-soft pb-5">
          <p className="font-display text-3xl font-bold uppercase leading-none">
            Fan portal
          </p>
          <p className="text-sm leading-6 text-slate-300">
            Anonymous-first supporter workspace connected to Rayon Sports club
            data.
          </p>
          <div className="rounded-2xl bg-white/5 p-4 text-sm text-slate-200">
            <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
              Supporter alias
            </p>
            <p className="mt-2 font-display text-2xl font-bold uppercase">
              {profile?.publicUserId ?? "Bootstrapping"}
            </p>
            <p className="mt-1 text-slate-400">
              Tier: {membership?.tier ?? "fan"}
            </p>
          </div>
          {loading ? (
            <p className="text-sm text-slate-400">Starting your fan session...</p>
          ) : null}
          {error ? (
            <p className="rounded-2xl border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
              {error}
            </p>
          ) : null}
        </div>

        <nav className="mt-5 flex flex-col gap-2">
          {portalNavigation.map((item) => {
            const active =
              pathname === item.href ||
              (item.href !== "/app" && pathname.startsWith(item.href));

            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "rounded-2xl px-4 py-3 text-sm font-semibold transition",
                  active
                    ? "bg-club-primary text-white"
                    : "text-slate-200 hover:bg-white/8",
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </aside>

      <div className="space-y-6">{children}</div>
    </div>
  );
}
