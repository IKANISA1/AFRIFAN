"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import type { VenueAccess } from "@/lib/data/venue-access";
import { ui } from "@/ui-kit";

const navigation = [
  ["Today", "/venue"],
  ["Verify tickets", "/venue/tickets/verify", "ticket-verification"],
  ["Orders", "/venue/orders"],
  ["Menu", "/venue/menu"],
  ["Check-ins", "/venue/checkins"],
  ["Promotions", "/venue/promotions"],
  ["Staff", "/venue/staff"],
] as const;

const VenueConnectivityContext = createContext(true);

export function useVenueOnline() {
  return useContext(VenueConnectivityContext);
}

export function VenueShellClient({
  access,
  children,
}: {
  access: VenueAccess;
  children: ReactNode;
}) {
  const pathname = usePathname();
  const [online, setOnline] = useState(true);

  useEffect(() => {
    const update = () => setOnline(navigator.onLine);
    update();
    window.addEventListener("online", update);
    window.addEventListener("offline", update);
    return () => {
      window.removeEventListener("online", update);
      window.removeEventListener("offline", update);
    };
  }, []);

  return (
    <VenueConnectivityContext.Provider value={online}>
      <div
        className="venue-portal min-h-screen bg-[#050510] text-white"
        data-venue-connectivity={online ? "online" : "offline"}
      >
        {!online ? (
          <section
            className="border-b border-amber-300/30 bg-amber-950 px-5 py-3 text-sm text-amber-100"
            role="status"
            aria-live="polite"
          >
            You are offline. Confirmed venue information remains visible, but
            changes are unavailable until the connection returns.
          </section>
        ) : null}
        <header className="venue-shell-header border-b border-white/10 px-5 py-4">
          <div className="mx-auto flex max-w-7xl flex-col gap-4 xl:grid xl:grid-cols-[minmax(12rem,auto)_minmax(0,1fr)] xl:items-center">
            <div>
              <p className={ui.kicker}>Assigned venue</p>
              <p className="mt-1 text-lg font-bold">{access.venueName}</p>
              <p className="text-xs uppercase tracking-[0.14em] text-slate-400">
                {access.venueCity || "Venue operations"} · {access.role}
              </p>
            </div>
            <nav
              aria-label="Venue operations"
              className="grid w-full max-w-full grid-cols-2 gap-2 sm:grid-cols-4 xl:flex xl:flex-wrap"
            >
              {navigation
                .filter(
                  ([, , capability]) =>
                    capability !== "ticket-verification" ||
                    access.canVerifyTickets === true,
                )
                .map(([label, href]) => {
                  const active = pathname === href;
                  return (
                    <Link
                      key={href}
                      href={href}
                      aria-current={active ? "page" : undefined}
                      className={`${active ? ui.buttonSecondary : ui.buttonTertiary} w-full justify-center text-center xl:min-w-24 xl:flex-1`}
                    >
                      {label}
                    </Link>
                  );
                })}
            </nav>
          </div>
        </header>
        {children}
      </div>
    </VenueConnectivityContext.Provider>
  );
}
