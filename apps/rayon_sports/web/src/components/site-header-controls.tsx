"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { Menu, Search, User } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { siteConfig } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";

const MobileNavDrawer = dynamic(
  () => import("./mobile-nav-drawer").then((mod) => mod.MobileNavDrawer),
  { loading: () => null },
);

const SearchDialog = dynamic(
  () => import("./search-dialog").then((mod) => mod.SearchDialog),
  { ssr: false, loading: () => null },
);

interface SiteHeaderControlsProps {
  club: ClubProfile;
}

export function SiteHeaderControls({ club }: SiteHeaderControlsProps) {
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);

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

  return (
    <>
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
          href={siteConfig.fansUrl}
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

      {isDrawerOpen ? (
        <MobileNavDrawer
          isOpen={isDrawerOpen}
          onClose={closeDrawer}
          club={club}
        />
      ) : null}
      {isSearchOpen ? (
        <SearchDialog open={isSearchOpen} onClose={closeSearch} />
      ) : null}
    </>
  );
}
