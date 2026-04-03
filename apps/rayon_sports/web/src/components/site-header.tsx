"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, Search, User } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { siteNavigation, utilityNavigation } from "@/lib/content";
import type { ClubProfile, SearchIndexItem } from "@/lib/types";
import { cn } from "@/lib/utils";
import { MobileNavDrawer } from "./mobile-nav-drawer";
import { SearchDialog } from "./search-dialog";

interface SiteHeaderProps {
  club: ClubProfile;
  searchItems: SearchIndexItem[];
}

export function SiteHeader({ club, searchItems }: SiteHeaderProps) {
  const pathname = usePathname();
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isCompact, setIsCompact] = useState(false);

  useEffect(() => {
    let ticking = false;

    function onScroll() {
      if (ticking) {
        return;
      }

      window.requestAnimationFrame(() => {
        setIsCompact(window.scrollY > 56);
        ticking = false;
      });
      ticking = true;
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    function handleShortcut(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setIsSearchOpen((open) => !open);
      }
    }

    document.addEventListener("keydown", handleShortcut);
    return () => document.removeEventListener("keydown", handleShortcut);
  }, []);

  const closeDrawer = useCallback(() => setIsDrawerOpen(false), []);
  const closeSearch = useCallback(() => setIsSearchOpen(false), []);

  const primaryLinks = useMemo(
    () =>
      siteNavigation.filter(
        (item) =>
          ![
            "/",
            "/standings",
            "/fan-clubs",
            "/history",
            "/contact",
          ].includes(item.href),
      ),
    [],
  );

  return (
    <>
      <header
        className={cn(
          "sticky top-0 z-[60] border-b transition-all duration-200",
          isCompact
            ? "border-border-soft bg-[#051228]/97 shadow-[0_12px_32px_rgba(2,9,24,0.44)] backdrop-blur-2xl"
            : "border-transparent bg-surface-strong/80 backdrop-blur-xl",
        )}
      >
        <div
          className={cn(
            "overflow-hidden border-b border-transparent transition-all duration-300",
            isCompact ? "max-h-0 opacity-0" : "max-h-12 opacity-100",
          )}
        >
          <div className="page-shell flex flex-wrap items-center justify-between gap-3 py-2 text-[10px] uppercase tracking-[0.24em] text-slate-400">
            <div className="flex flex-wrap items-center gap-3">
              <span>{club.shortName}</span>
              <span className="hidden sm:inline">·</span>
              <span className="hidden sm:inline">{club.league}</span>
              <span className="hidden sm:inline">·</span>
              <span className="hidden sm:inline">Kigali, Rwanda</span>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              {utilityNavigation.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="transition hover:text-white"
                >
                  {item.label}
                </Link>
              ))}
              <span className="text-slate-600">|</span>
              <div className="flex items-center gap-2">
                {club.supportedLanguages.map((language, index) => (
                  <span key={language} className="transition hover:text-white">
                    {language.toUpperCase()}
                    {index < club.supportedLanguages.length - 1 ? (
                      <span className="ml-2 text-slate-600">/</span>
                    ) : null}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div
          className={cn(
            "page-shell flex items-center justify-between gap-4 transition-all duration-200",
            isCompact ? "py-2.5" : "py-3.5",
          )}
        >
          <Link href="/" className="flex items-center gap-3">
            <Image
              src={club.officialLogoUrl ?? "/media/rayon-crest.png"}
              alt={`${club.clubName} crest`}
              width={96}
              height={96}
              priority
              className={cn(
                "rounded-full border border-white/10 bg-white/5 object-cover transition-all duration-200",
                isCompact ? "h-10 w-10" : "h-12 w-12",
              )}
            />
            <div className="hidden sm:block">
              <p className="font-display text-xl font-bold uppercase leading-none text-white lg:text-2xl">
                Gikundiro
              </p>
              <p className="mt-1 text-[11px] uppercase tracking-[0.18em] text-slate-400">
                The beloved lives here
              </p>
            </div>
          </Link>

          <nav className="hidden items-center gap-1 lg:flex">
            {primaryLinks.map((item) => {
              const active =
                pathname === item.href ||
                (item.href !== "/" && pathname.startsWith(item.href));

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "relative rounded-full px-3.5 py-2 text-sm font-semibold transition-all duration-200 focus-ring",
                    active
                      ? "bg-white/8 text-white"
                      : "text-slate-300 hover:bg-white/6 hover:text-white",
                  )}
                >
                  {item.label}
                  {active ? (
                    <span className="absolute inset-x-3 -bottom-[11px] h-[2px] rounded-full bg-club-accent" />
                  ) : null}
                </Link>
              );
            })}
          </nav>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setIsSearchOpen(true)}
              className="flex h-11 min-w-11 items-center justify-center rounded-full border border-border-soft bg-white/4 px-3 text-slate-200 transition hover:bg-white/10 hover:text-white focus-ring"
              aria-label="Search"
            >
              <Search size={18} />
              <span className="ml-2 hidden text-xs uppercase tracking-[0.18em] text-slate-400 xl:inline">
                Search
              </span>
            </button>
            <Link
              href="/app"
              className="hidden min-h-11 items-center gap-2 rounded-full bg-club-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-club-primary-light cta-glow focus-ring md:inline-flex"
            >
              <User size={15} />
              Fan portal
            </Link>
            <button
              type="button"
              onClick={() => setIsDrawerOpen(true)}
              className="flex h-11 w-11 items-center justify-center rounded-full border border-border-soft bg-white/5 text-white transition hover:bg-white/10 focus-ring lg:hidden"
              aria-label="Open menu"
            >
              <Menu size={20} />
            </button>
          </div>
        </div>
      </header>

      <MobileNavDrawer
        isOpen={isDrawerOpen}
        onClose={closeDrawer}
        club={club}
      />
      <SearchDialog items={searchItems} open={isSearchOpen} onClose={closeSearch} />
    </>
  );
}
