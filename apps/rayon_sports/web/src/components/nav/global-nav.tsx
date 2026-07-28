"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronDown, Globe, Search, User, Menu } from "lucide-react";
import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";
import { resolveFanAppHref } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";
import type { SiteChromeCopy } from "@/lib/site-copy";
import type { ReactNode } from "react";

import type { PlatformFeature, SiteNavigationItem } from "@/lib/feature-config";

interface GlobalNavProps {
  club: ClubProfile;
  copy: SiteChromeCopy;
  features?: PlatformFeature[];
  navigationItems?: SiteNavigationItem[];
  ribbon?: ReactNode;
}

export function GlobalNav({
  club,
  copy: _copy,
  features = [],
  navigationItems = [],
  ribbon,
}: GlobalNavProps) {
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const [activeMenu, setActiveMenu] = useState<string | null>(null);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 40);
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const logoUrl = club.officialLogoUrl ?? "/brand-mark.svg";

  const navItems =
    navigationItems.length > 0
      ? navigationItems.map((item) => ({
          label: item.label,
          href: item.href,
          featureKey: item.feature_key ?? item.nav_key,
          hasMega:
            item.metadata.hasMega === true ||
            ["live", "squad"].includes(item.feature_key ?? ""),
        }))
      : features.map((feature) => ({
          label: feature.display_name,
          href: feature.channel?.route_key || `/${feature.feature_key}`,
          featureKey: feature.feature_key,
          hasMega:
            feature.rules?.metadata?.hasMega === true ||
            ["live", "squad"].includes(feature.feature_key),
        }));

  return (
    <div
      className={cn(
        "fixed inset-x-0 top-0 z-[100] transition-all duration-500",
        scrolled
          ? "bg-[var(--club-primary)]/95 backdrop-blur-md shadow-xl translate-y-[-36px] xl:translate-y-[-36px]"
          : "bg-transparent",
      )}
      onMouseLeave={() => setActiveMenu(null)}
    >
      {!scrolled && ribbon}
      <div className="hidden border-b border-white/10 bg-black/20 xl:block">
        <div className="page-shell flex h-9 items-center justify-between px-4 text-[10px] font-bold uppercase tracking-[0.2em] text-white/70">
          <div className="flex items-center gap-6">
            <span className="text-white/40">{club.league}</span>
            <div className="flex items-center gap-4">
              {club.supportedLanguages.map((lang) => (
                <button
                  key={lang}
                  className="hover:text-white transition-colors"
                >
                  {lang}
                </button>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-6">
            <Link
              href="/contact"
              className="hover:text-white transition-colors"
            >
              Support
            </Link>
            <Link
              href="/history"
              className="hover:text-white transition-colors"
            >
              History
            </Link>
            <div className="flex items-center gap-2 text-[var(--club-accent)]">
              <Globe size={10} />
              <span>Gikundiro Global</span>
            </div>
          </div>
        </div>
      </div>

      {/* Main Nav */}
      <nav className="page-shell flex h-16 items-center justify-between gap-8 px-4 lg:h-20 lg:px-6">
        <Link href="/" className="flex shrink-0 items-center gap-3">
          <div className="relative h-10 w-10 overflow-hidden rounded-full border-2 border-white/20 bg-white lg:h-12 lg:w-12">
            <Image
              src={logoUrl}
              alt={club.clubName}
              fill
              className="object-contain p-1"
            />
          </div>
          <div className="hidden lg:block">
            <p className="font-display text-xl font-bold uppercase leading-none tracking-tight text-white">
              {club.shortName}
            </p>
            <p className="mt-1 text-[9px] font-bold uppercase tracking-[0.2em] text-white/50">
              The Beloved
            </p>
          </div>
        </Link>

        {/* Desktop Links */}
        <div className="hidden flex-1 items-center justify-center gap-1 xl:flex">
          {navItems.map((item) => (
            <div
              key={item.href}
              className="relative py-4"
              onMouseEnter={() =>
                item.hasMega
                  ? setActiveMenu(item.featureKey)
                  : setActiveMenu(null)
              }
            >
              <Link
                href={item.href}
                className={cn(
                  "flex items-center gap-1.5 px-4 py-2 text-sm font-bold uppercase tracking-widest text-white/80 transition-all hover:text-white",
                  pathname.startsWith(item.href) && "text-white",
                )}
              >
                {item.label}
                {item.hasMega && (
                  <ChevronDown
                    size={14}
                    className={cn(
                      "transition-transform duration-300",
                      activeMenu === item.featureKey && "rotate-180",
                    )}
                  />
                )}
              </Link>
              {pathname.startsWith(item.href) && (
                <div className="absolute inset-x-4 bottom-0 h-0.5 bg-[var(--club-accent)]" />
              )}
            </div>
          ))}
        </div>

        {/* Actions */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            aria-label="Search site"
            className="hidden h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20 lg:flex"
          >
            <Search size={18} />
          </button>
          <Link
            href={resolveFanAppHref()}
            className="flex items-center gap-2 rounded-full bg-[var(--club-accent)] px-5 py-2.5 text-xs font-bold uppercase tracking-wider text-slate-950 shadow-lg transition-transform hover:scale-105 active:scale-95"
          >
            <User size={16} />
            <span className="hidden sm:inline">Fan Portal</span>
            <span className="sm:hidden">Portal</span>
          </Link>
          <button
            type="button"
            aria-label="Open menu"
            className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white xl:hidden"
          >
            <Menu size={20} />
          </button>
        </div>
      </nav>

      {/* Mega Menu Overlay */}
      <div
        className={cn(
          "absolute inset-x-0 top-full border-t border-white/10 bg-[var(--club-primary)] shadow-2xl transition-all duration-500 ease-in-out",
          activeMenu
            ? "max-h-[600px] opacity-100 visible"
            : "max-h-0 opacity-0 invisible overflow-hidden",
        )}
      >
        <div className="page-shell p-8 lg:p-12">
          {activeMenu === "live" && (
            <div className="grid grid-cols-4 gap-12">
              <div className="col-span-2">
                <p className="mb-6 text-xs font-bold uppercase tracking-widest text-white/40">
                  Next Fixture
                </p>
                <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
                  <div className="flex items-center justify-between text-center">
                    <div className="space-y-4">
                      <div className="h-16 w-16 mx-auto rounded-full bg-white/10" />
                      <p className="font-bold text-white uppercase tracking-tight">
                        {club.shortName}
                      </p>
                    </div>
                    <div className="text-center">
                      <p className="text-3xl font-black text-white/20 italic">
                        VS
                      </p>
                      <p className="mt-2 text-xs font-bold text-[var(--club-accent)]">
                        20 APR · 18:00
                      </p>
                    </div>
                    <div className="space-y-4">
                      <div className="h-16 w-16 mx-auto rounded-full bg-white/10" />
                      <p className="font-bold text-white uppercase tracking-tight">
                        APR FC
                      </p>
                    </div>
                  </div>
                  <Link
                    href="/tickets"
                    className="mt-8 block w-full rounded-xl bg-white py-3 text-center text-sm font-bold uppercase tracking-widest text-[var(--club-primary)] hover:bg-[var(--club-accent)] transition-colors"
                  >
                    Get Tickets Now
                  </Link>
                </div>
              </div>
              <div>
                <p className="mb-6 text-xs font-bold uppercase tracking-widest text-white/40">
                  Information
                </p>
                <ul className="space-y-4 text-sm font-bold uppercase tracking-wider text-white">
                  <li>
                    <Link
                      href="/fixtures"
                      className="hover:text-[var(--club-accent)] transition-colors"
                    >
                      Full Fixtures
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/results"
                      className="hover:text-[var(--club-accent)] transition-colors"
                    >
                      Results
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/standings"
                      className="hover:text-[var(--club-accent)] transition-colors"
                    >
                      League Table
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/tickets"
                      className="hover:text-[var(--club-accent)] transition-colors"
                    >
                      Ticket Info
                    </Link>
                  </li>
                </ul>
              </div>
              <div className="relative overflow-hidden rounded-2xl bg-black/40 p-6">
                <div className="absolute inset-0 opacity-20 bg-[url('/brand-surface.svg')] bg-cover bg-center" />
                <div className="relative z-10">
                  <p className="text-xs font-bold uppercase tracking-widest text-[var(--club-accent)]">
                    Season 2025/26
                  </p>
                  <p className="mt-2 text-2xl font-black text-white uppercase leading-none">
                    The Quest for
                    <br />
                    Continental Glory
                  </p>
                  <Link
                    href="/history"
                    className="mt-4 inline-block text-[10px] font-bold uppercase tracking-[0.2em] text-white/60 hover:text-white transition-colors underline underline-offset-4"
                  >
                    Learn More
                  </Link>
                </div>
              </div>
            </div>
          )}
          {activeMenu === "squad" && (
            <div className="grid grid-cols-4 gap-8">
              {[1, 2, 3, 4].map((i) => (
                <div
                  key={i}
                  className="group relative aspect-[3/4] overflow-hidden rounded-xl bg-white/5"
                >
                  <div className="absolute inset-0 bg-gradient-to-t from-[var(--club-primary)] via-transparent to-transparent opacity-60 group-hover:opacity-80 transition-opacity" />
                  <div className="absolute bottom-4 left-4 right-4">
                    <p className="text-2xl font-black text-white italic leading-none">
                      {i === 1 ? "17" : i === 2 ? "11" : i === 3 ? "09" : "01"}
                    </p>
                    <p className="text-sm font-bold uppercase tracking-tight text-white">
                      {i === 1
                        ? "Kevin Muhire"
                        : i === 2
                          ? "Yannick Mukunzi"
                          : i === 3
                            ? "Fall Ngagne"
                            : "Mugenzi M."}
                    </p>
                    <p className="text-[10px] font-bold uppercase tracking-widest text-[var(--club-accent)]">
                      First Team
                    </p>
                  </div>
                </div>
              ))}
              <div className="col-span-4 mt-8 flex justify-center">
                <Link
                  href="/squad"
                  className="text-xs font-bold uppercase tracking-[0.3em] text-white/60 hover:text-white transition-colors"
                >
                  View Full First Team Roster →
                </Link>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
