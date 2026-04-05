"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { X, User, Ticket, ShoppingBag } from "lucide-react";
import { siteNavigation, utilityNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";
import { cn } from "@/lib/utils";

interface MobileNavDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  club: ClubProfile;
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
}: MobileNavDrawerProps) {
  const pathname = usePathname();
  const drawerRef = useRef<HTMLDivElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const [visible, setVisible] = useState(false);

  // Drive the transition: visible controls CSS classes
  useEffect(() => {
    if (isOpen) {
      // Mount visible on next frame so the transition triggers
      requestAnimationFrame(() => setVisible(true));
    } else {
      setVisible(false);
    }
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
          "fixed inset-0 z-50 bg-black/60 backdrop-blur-sm transition-opacity duration-300",
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
          "fixed top-0 right-0 bottom-0 z-50 w-[85vw] max-w-[400px] bg-surface-strong shadow-2xl flex flex-col border-l border-border-soft",
          "transition-transform duration-300 ease-out",
          visible ? "translate-x-0" : "translate-x-full",
        )}
      >
        {/* Header section */}
        <div className="flex items-center justify-between p-5 border-b border-border-soft">
          <div className="flex items-center gap-3">
             <Image
              src={club.officialLogoUrl ?? "/icons/icon-192x192.png"}
              alt={`${club.clubName} crest`}
              width={36}
              height={36}
              sizes="36px"
              className="rounded-full border border-white/10 bg-white/5 object-cover"
            />
            <div>
              <p className="font-display text-lg font-bold uppercase leading-none mt-1">
                Gikundiro
              </p>
              <p className="text-[10px] uppercase tracking-[0.24em] text-slate-500">
                {club.shortName}
              </p>
            </div>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            className="p-2 -mr-2 text-slate-300 hover:text-white transition-colors focus-ring"
            aria-label="Close menu"
          >
            <X size={24} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto overflow-x-hidden p-5 flex flex-col gap-8">
          {/* Quick access row */}
          <div className="flex justify-between gap-3">
            <Link
              href={siteConfig.fansUrl}
              prefetch={false}
              className="flex-1 flex flex-col items-center justify-center gap-2 p-3 rounded-2xl bg-white/5 border border-border-soft hover:bg-white/10 transition focus-ring"
            >
              <User size={20} className="text-club-primary-light" />
              <span className="text-xs uppercase tracking-wider font-semibold">Portal</span>
            </Link>
            <Link
              href="/tickets"
              prefetch={false}
              className="flex-1 flex flex-col items-center justify-center gap-2 p-3 rounded-2xl bg-white/5 border border-border-soft hover:bg-white/10 transition focus-ring"
            >
              <Ticket size={20} className="text-club-accent" />
              <span className="text-xs uppercase tracking-wider font-semibold">Tickets</span>
            </Link>
            <Link
              href="/shop"
              prefetch={false}
              className="flex-1 flex flex-col items-center justify-center gap-2 p-3 rounded-2xl bg-white/5 border border-border-soft hover:bg-white/10 transition focus-ring"
            >
              <ShoppingBag size={20} className="text-club-secondary" />
              <span className="text-xs uppercase tracking-wider font-semibold">Shop</span>
            </Link>
          </div>

          {/* Primary Navigation List */}
          <nav className="flex flex-col gap-1">
            <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-500 mb-2 pl-2">Menu</p>
            {siteNavigation.map((item) => {
              const active = pathname === item.href || (item.href !== "/" && pathname.startsWith(item.href));

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  prefetch={false}
                  className={cn(
                    "relative px-4 py-3 text-lg font-semibold rounded-xl transition-all focus-ring",
                    active
                      ? "bg-club-primary/10 text-white"
                      : "text-slate-300 hover:bg-white/5 hover:text-white"
                  )}
                >
                  {item.label}
                  {active && (
                    <div className="absolute left-0 top-[20%] bottom-[20%] w-1 bg-club-primary-light rounded-r-full" />
                  )}
                </Link>
              );
            })}
          </nav>

          <div className="space-y-3">
            <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-500 pl-2">
              Utility
            </p>
            <div className="flex flex-wrap gap-2">
              {utilityNavigation.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  prefetch={false}
                  className="rounded-full border border-border-soft bg-white/4 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-300 transition hover:bg-white/8 hover:text-white"
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </div>

          {/* Utility row */}
          <div className="mt-auto">
             <div className="p-4 rounded-2xl bg-white/5 border border-border-soft flex items-center justify-between text-sm">
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
