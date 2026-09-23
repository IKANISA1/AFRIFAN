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
import { useReducedMotion } from "@/lib/use-reduced-motion";

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
  const reducedMotion = useReducedMotion();

  // Drive the transition: visible controls CSS classes
  useEffect(() => {
    if (reducedMotion) {
      return;
    }
    let frameId = 0;
    if (isOpen) {
      // Mount visible on next frame so the transition triggers
      frameId = requestAnimationFrame(() => setVisible(true));
    } else {
      frameId = requestAnimationFrame(() => setVisible(false));
    }
    return () => cancelAnimationFrame(frameId);
  }, [isOpen, reducedMotion]);

  const presented = reducedMotion ? isOpen : visible;

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
    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    document.addEventListener("keydown", handleFocusTrap);
    // Focus the close button on open
    const frame = requestAnimationFrame(() => closeButtonRef.current?.focus());
    return () => {
      cancelAnimationFrame(frame);
      document.removeEventListener("keydown", handleFocusTrap);
      if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
    };
  }, [isOpen, handleFocusTrap]);

  return (
    <>
      {/* Scrim Overlay — always in DOM, opacity-controlled */}
      <div
        className={cn(
          `fixed inset-0 z-50 transition-opacity duration-300 motion-reduce:transition-none ${ui.drawerScrim}`,
          presented ? "opacity-100" : "pointer-events-none opacity-0",
        )}
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Drawer — always in DOM, transform-controlled */}
      <div
        ref={drawerRef}
        id="mobile-navigation-drawer"
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
        aria-hidden={!isOpen}
        inert={!isOpen ? true : undefined}
        className={cn(
          `fixed top-0 right-0 bottom-0 z-50 flex w-[85vw] max-w-[400px] flex-col ${ui.drawerShell}`,
          "transition-transform duration-300 ease-out motion-reduce:transition-none",
          presented ? "translate-x-0" : "translate-x-full",
        )}
      >
        {/* Header section */}
        <div
          className={`site-drawer-header ${ui.drawerDivider}`}
        >
          <div className="flex min-w-0 flex-wrap items-center gap-[12px]">
            <Image
              src={club.officialLogoUrl ?? "/brand-mark.svg"}
              alt={`${club.clubName} brand mark`}
              width={36}
              height={36}
              sizes="36px"
              className={`${ui.brandMark} shrink-0 rounded-full object-cover`}
            />
            <div className="min-w-0 flex-1 basis-[100px] [overflow-wrap:anywhere]">
              <p className="font-display text-lg font-medium normal-case leading-none mt-1">
                {club.nickname || club.shortName}
              </p>
              <p className="text-[10px] normal-case tracking-normal text-muted">
                {club.clubName}
              </p>
            </div>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            className={`${ui.iconButton} shrink-0 p-0 text-muted focus-ring`}
            aria-label="Close menu"
          >
            <X size={24} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto overflow-x-hidden p-5 flex flex-col gap-8">
          {/* Quick access row */}
          <div className="site-drawer-shortcuts grid gap-3">
            <Link
              href={resolveFanAppHref()}
              prefetch={false}
              className={`${ui.drawerShortcut} focus-ring min-w-0 rounded-[24px] p-3`}
            >
              <User size={20} className="text-action-blue-hover" />
              <span className="text-xs normal-case tracking-normal font-semibold">
                Fan App
              </span>
            </Link>
            <Link
              href="/tickets"
              prefetch={false}
              className={`${ui.drawerShortcut} focus-ring min-w-0 rounded-[24px] p-3`}
            >
              <Ticket size={20} className="text-action-neutral" />
              <span className="text-xs normal-case tracking-normal font-semibold">
                Tickets
              </span>
            </Link>
            <Link
              href="/shop"
              prefetch={false}
              className={`${ui.drawerShortcut} focus-ring min-w-0 rounded-[24px] p-3`}
            >
              <ShoppingBag size={20} className="text-muted" />
              <span className="text-xs normal-case tracking-normal font-semibold">
                Shop
              </span>
            </Link>
          </div>

          {/* Primary Navigation List */}
          <nav className="flex flex-col gap-1">
            <p className="font-mono text-[10px] normal-case tracking-normal text-muted mb-2 pl-2">
              Menu
            </p>
            {!navigationItems.some((item) => item.href === "/search") && (
              <Link href="/search" prefetch={false} className={`${ui.drawerLink} focus-ring`}>
                Search site
              </Link>
            )}
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
            <p className="font-mono text-[10px] normal-case tracking-normal text-muted pl-2">
              Utility
            </p>
            <div className="flex flex-wrap gap-2">
              {utilityItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  prefetch={false}
                  className={`${ui.utilityPill} rounded-full px-3 py-1.5 text-[11px] font-semibold normal-case tracking-normal`}
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </div>


        </div>
      </div>
    </>
  );
}
