"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { X, User, Ticket, ShoppingBag } from "lucide-react";
import { ui } from "@/ui-kit";
import { resolveFanAppHref } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";
import type { SiteNavigationItem } from "@/lib/feature-config";
import { cn } from "@/lib/utils";

interface MobileNavDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  club: ClubProfile;
  navigationItems?: SiteNavigationItem[];
  utilityItems?: SiteNavigationItem[];
}

/**
 * Always-mounted mobile nav drawer with smooth enter/exit animations.
 * Uses `inert` + `aria-hidden` when closed for accessibility.
 * Focus is trapped inside when open.
 */
export function MobileNavDrawer({
  isOpen,
  onClose,
  club,
  navigationItems = [],
  utilityItems = [],
}: MobileNavDrawerProps) {
  const pathname = usePathname();
  const drawerRef = useRef<HTMLDivElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const [visible, setVisible] = useState(false);

  // Drive the transition: visible controls CSS classes
  useEffect(() => {
    let frameId = 0;
    if (isOpen) {
      // Mount visible on next frame so the transition triggers
      frameId = requestAnimationFrame(() => setVisible(true));
    } else {
      frameId = requestAnimationFrame(() => setVisible(false));
    }
    return () => cancelAnimationFrame(frameId);
  }, [isOpen]);

  // Close on route change
  useEffect(() => {
    onClose();
  }, [pathname, onClose]);

  // Lock body scroll when open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [isOpen]);

  // Close on Escape key
  useEffect(() => {
    if (!isOpen) return;
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        onClose();
      }
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [isOpen, onClose]);

  // Focus trap — cycle Tab within drawer
  const handleFocusTrap = useCallback(
    (e: KeyboardEvent) => {
      if (!isOpen || e.key !== "Tab") return;
      const drawer = drawerRef.current;
      if (!drawer) return;

      const focusable = drawer.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
      );
      if (focusable.length === 0) return;

      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault();
          last.focus();
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    },
    [isOpen],
  );

  useEffect(() => {
    if (!isOpen) return;
    document.addEventListener("keydown", handleFocusTrap);
    // Focus the close button on open
    requestAnimationFrame(() => closeButtonRef.current?.focus());
    return () => document.removeEventListener("keydown", handleFocusTrap);
  }, [isOpen, handleFocusTrap]);

  return (
    <>
      {/* Scrim Overlay — always in DOM, opacity-controlled */}
      <div
        className={cn(
          `fixed inset-0 z-50 transition-opacity duration-300 ${ui.drawerScrim}`,
          visible ? "opacity-100" : "pointer-events-none opacity-0",
        )}
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Drawer — always in DOM, transform-controlled */}
      <div
        ref={drawerRef}
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
        aria-hidden={!isOpen}
        inert={!isOpen ? true : undefined}
        className={cn(
          `fixed top-0 right-0 bottom-0 z-50 flex w-[85vw] max-w-[400px] flex-col ${ui.drawerShell}`,
          "transition-transform duration-300 ease-out",
          visible ? "translate-x-0" : "translate-x-full",
        )}
      >
        {/* Header section */}
        <div
          className={`flex items-center justify-between p-5 ${ui.drawerDivider}`}
        >
          <div className="flex items-center gap-3">
            <Image
              src={club.officialLogoUrl ?? "/brand-mark.svg"}
              alt={`${club.clubName} brand mark`}
              width={36}
              height={36}
              sizes="36px"
              className={`${ui.brandMark} rounded-full object-cover`}
            />
            <div>
              <p className="font-display text-lg font-bold uppercase leading-none mt-1">
                {club.nickname || club.shortName}
              </p>
              <p className="text-[10px] uppercase tracking-[0.24em] text-slate-500">
                {club.clubName}
              </p>
            </div>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            className={`${ui.iconButton} -mr-2 h-11 w-11 p-0 text-slate-300 focus-ring`}
            aria-label="Close menu"
          >
            <X size={24} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto overflow-x-hidden p-5 flex flex-col gap-8">
          {/* Quick access row */}
          <div className="flex justify-between gap-3">
            <Link
              href={resolveFanAppHref()}
              prefetch={false}
              className={`${ui.drawerShortcut} focus-ring flex-1 rounded-[24px] p-3`}
            >
              <User size={20} className="text-club-primary-light" />
              <span className="text-xs uppercase tracking-wider font-semibold">
                Fan App
              </span>
            </Link>
            <Link
              href="/tickets"
              prefetch={false}
              className={`${ui.drawerShortcut} focus-ring flex-1 rounded-[24px] p-3`}
            >
              <Ticket size={20} className="text-club-accent" />
              <span className="text-xs uppercase tracking-wider font-semibold">
                Tickets
              </span>
            </Link>
            <Link
              href="/shop"
              prefetch={false}
              className={`${ui.drawerShortcut} focus-ring flex-1 rounded-[24px] p-3`}
            >
              <ShoppingBag size={20} className="text-club-secondary" />
              <span className="text-xs uppercase tracking-wider font-semibold">
                Shop
              </span>
            </Link>
          </div>

          {/* Primary Navigation List */}
          <nav className="flex flex-col gap-1">
            <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-500 mb-2 pl-2">
              Menu
            </p>
            {navigationItems.map((item) => {
              const active =
                pathname === item.href ||
                (item.href !== "/" && pathname.startsWith(item.href));

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  prefetch={false}
                  className={cn(
                    "focus-ring",
                    active ? ui.drawerLinkActive : ui.drawerLink,
                  )}
                >
                  {item.label}
                  {active ? <div className={ui.drawerActiveBar} /> : null}
                </Link>
              );
            })}
          </nav>

          <div className="space-y-3">
            <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-500 pl-2">
              Utility
            </p>
            <div className="flex flex-wrap gap-2">
              {utilityItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  prefetch={false}
                  className={`${ui.utilityPill} rounded-full px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em]`}
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </div>

          {/* Utility row */}
          <div className="mt-auto">
            <div
              className={`${ui.panelInset} flex items-center justify-between rounded-[24px] p-4 text-sm`}
            >
              <span className="text-slate-300">Language</span>
              <div className="flex items-center gap-3 font-semibold text-slate-300">
                {club.supportedLanguages.map((language, index) => (
                  <span
                    key={language}
                    className={cn(
                      "hover:text-white transition",
                      index === 0 && "text-white",
                    )}
                  >
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
      </div>
    </>
  );
}
