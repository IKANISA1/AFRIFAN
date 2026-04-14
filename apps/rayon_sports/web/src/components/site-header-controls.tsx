"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { Menu, Search, User } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { resolveFanAppHref } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";
import type { SiteChromeCopy } from "@/lib/site-copy";
import { ui } from "@/design-system";

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
  copy: SiteChromeCopy;
}

export function SiteHeaderControls({ club, copy }: SiteHeaderControlsProps) {
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
          className={`${ui.iconButton} min-w-11 px-3 text-slate-200 focus-ring`}
          aria-label={copy.search}
        >
          <Search size={18} />
          <span className={`ml-2 hidden ${ui.meta} xl:inline`}>
            {copy.search}
          </span>
        </button>
        <Link
          href={resolveFanAppHref()}
          className={`${ui.buttonPrimary} cta-glow hidden px-4 py-2.5 focus-ring md:inline-flex`}
        >
          <User size={15} />
          {copy.fanApp}
        </Link>
        <button
          type="button"
          onClick={() => setIsDrawerOpen(true)}
          className={`${ui.iconButton} text-white focus-ring lg:hidden`}
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
