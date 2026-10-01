"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronDown, Globe, Search, User, Menu } from "lucide-react";
import { useCallback, useState, useEffect, useRef } from "react";
import { cn } from "@/lib/utils";
import { MobileNavDrawer } from "@/components/mobile-nav-drawer";
import { useHydrated } from "@/lib/use-hydrated";
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

const fallbackNavigationItems: SiteNavigationItem[] = [
  ["fixtures", "Fixtures", "/fixtures"],
  ["tickets", "Tickets", "/tickets"],
  ["shop", "Shop", "/shop"],
  ["membership", "Membership", "/membership"],
  ["supporters", "Supporters", "/supporters"],
  ["news", "News", "/news"],
].map(([nav_key, label, href], sort_order) => ({
  nav_key,
  label,
  href,
  nav_group: "primary",
  surface: "both",
  feature_key: nav_key,
  sort_order,
  metadata: {},
}));

export function GlobalNav({
  club,
  copy: _copy,
  features = [],
  navigationItems = [],
  ribbon,
}: GlobalNavProps) {
  const pathname = usePathname();
  const hydrated = useHydrated();
  const [scrolled, setScrolled] = useState(false);
  const [activeMenu, setActiveMenu] = useState<string | null>(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [desktopFits, setDesktopFits] = useState(false);
  const headerRef = useRef<HTMLDivElement>(null);
  const navigationRef = useRef<HTMLElement>(null);
  const brandRef = useRef<HTMLAnchorElement>(null);
  const desktopLinksRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLAnchorElement>(null);
  const portalRef = useRef<HTMLAnchorElement>(null);
  const menuTriggers = useRef<Record<string, HTMLButtonElement | null>>({});
  const closeMobileMenu = useCallback(
    () => setMobileMenuOpen(false),
    [setMobileMenuOpen],
  );

  useEffect(() => {
    const navigation = navigationRef.current;
    const brand = brandRef.current;
    const links = desktopLinksRef.current;
    const search = searchRef.current;
    const portal = portalRef.current;
    if (!navigation || !brand || !links || !search || !portal) return;
    const measure = () => {
      const style = getComputedStyle(navigation);
      const available = navigation.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
      const searchWidth = search.getBoundingClientRect().width;
      const required = brand.getBoundingClientRect().width + links.getBoundingClientRect().width
        + portal.getBoundingClientRect().width + searchWidth
        + (searchWidth > 0 ? 12 : 0) + 2 * parseFloat(style.columnGap);
      setDesktopFits(available > 0 && required <= available);
    };
    measure();
    // Keep the intrinsic link row measurable while hidden. Observe fonts,
    // text enlargement, configured labels and the available container width.
    const observer = new ResizeObserver(measure);
    for (const element of [navigation, brand, links, search, portal]) observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 40);
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    // Detail pages reserve the expanded header, including its optional ribbon.
    // Keep that space when scrolling hides the ribbon to avoid content jumps.
    if (scrolled) return;
    const header = headerRef.current;
    const site = header?.closest<HTMLElement>(".club-site");
    if (!header || !site) return;
    const measure = () => site.style.setProperty(
      "--site-header-block-size",
      `${Math.ceil(header.getBoundingClientRect().height)}px`,
    );
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(header);
    return () => observer.disconnect();
  }, [scrolled]);

  const logoUrl = club.officialLogoUrl ?? "/brand-mark.svg";

  const resolvedNavigationItems =
    navigationItems.length > 0 ? navigationItems : fallbackNavigationItems;

  const navItems =
    resolvedNavigationItems.length > 0
      ? resolvedNavigationItems.map((item) => ({
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
      ref={headerRef}
      data-site-header
      className={cn(
        "fixed inset-x-0 top-0 z-[100] transition-all duration-500",
        scrolled || pathname !== "/"
          ? "bg-[var(--chrome-surface)]"
          : "bg-transparent",
      )}
      onMouseLeave={() => setActiveMenu(null)}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setActiveMenu(null);
      }}
      onKeyDown={(event) => {
        if (event.key === "Escape" && activeMenu) {
          event.preventDefault();
          menuTriggers.current[activeMenu]?.focus();
          setActiveMenu(null);
        }
      }}
    >
      {!scrolled && ribbon}
      <div className={cn("hidden border-b border-white/10 bg-black/20", !scrolled && "xl:block")}>
        <div className="page-shell flex h-9 items-center justify-between px-4 text-[10px] font-medium normal-case tracking-normal text-white/70">
          <div className="flex items-center gap-6">
            <span>{club.league}</span>

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
            <div className="flex items-center gap-2 text-white/80">
              <Globe size={10} />
              <span>{club.nickname || club.shortName}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Main Nav */}
      <nav ref={navigationRef} data-desktop-fits={desktopFits} aria-label="Primary navigation" className="site-primary-navigation page-shell flex h-16 items-center justify-between gap-[16px] px-[16px] lg:h-20 lg:px-[24px]">
        <Link ref={brandRef} href="/" className="flex min-h-[48px] min-w-[48px] shrink-0 items-center gap-[12px]">
          <div className="relative h-[40px] w-[40px] overflow-hidden rounded-full border-2 border-white/20 bg-white lg:h-[48px] lg:w-[48px]">
            <Image
              src={logoUrl}
              alt={club.clubName}
              fill
              className="object-contain p-1"
            />
          </div>
          <div className="site-brand-copy hidden lg:block">
            <p className="font-display text-xl font-medium normal-case leading-none tracking-tight text-white">
              {club.shortName}
            </p>
            <p className="mt-1 text-[9px] font-medium normal-case tracking-normal text-white/50">
              {club.nickname || club.clubName}
            </p>
          </div>
        </Link>

        {/* Desktop Links */}
        <div ref={desktopLinksRef} aria-hidden={!desktopFits} inert={!desktopFits} className="site-desktop-links hidden flex-1 items-center justify-center gap-1 xl:flex">
          {navItems.map((item) => (
            <div
              key={item.href}
              className="relative flex items-center py-4"
              onMouseEnter={() =>
                item.hasMega
                  ? setActiveMenu(item.featureKey)
                  : setActiveMenu(null)
              }
            >
              <Link
                href={item.href}
                aria-current={pathname === item.href || pathname.startsWith(`${item.href}/`) ? "page" : undefined}
                className={cn(
                  "flex min-h-[48px] items-center gap-1.5 px-4 py-2 text-sm font-medium normal-case tracking-normal text-white/80 transition-all hover:text-white",
                  pathname.startsWith(item.href) && "text-white",
                )}
              >
                {item.label}
              </Link>
              {item.hasMega && (
                <button type="button"
                  ref={(element) => { menuTriggers.current[item.featureKey] = element; }}
                  aria-label={`${activeMenu === item.featureKey ? "Close" : "Open"} ${item.label} navigation`}
                  aria-expanded={activeMenu === item.featureKey}
                  aria-controls="site-mega-menu"
                  className="flex min-h-[48px] min-w-[48px] items-center justify-center text-white/80 focus-ring"
                  onClick={() => setActiveMenu(current => current === item.featureKey ? null : item.featureKey)}
                  onKeyDown={(event) => {
                    if (event.key === "ArrowDown") {
                      event.preventDefault();
                      setActiveMenu(item.featureKey);
                      requestAnimationFrame(() => document.querySelector<HTMLAnchorElement>("#site-mega-menu a[href]")?.focus());
                    }
                  }}>
                  <ChevronDown
                    aria-hidden="true"
                    size={14}
                    className={cn(
                      "transition-transform duration-300",
                      activeMenu === item.featureKey && "rotate-180",
                    )}
                  />
                </button>
              )}
              {pathname.startsWith(item.href) && (
                <div className="absolute inset-x-4 bottom-0 h-0.5 bg-[var(--action-neutral)]" />
              )}
            </div>
          ))}
        </div>

        {/* Actions */}
        <div className="flex min-w-0 items-center gap-[12px]">
          <Link
            ref={searchRef}
            href="/search"
            aria-label="Search site"
            className="hidden h-[48px] w-[48px] shrink-0 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20 lg:flex"
          >
            <Search size={18} />
          </Link>
          <Link
            ref={portalRef}
            href="/membership"
            aria-label="Fan Portal"
            className="site-portal-link flex min-h-[48px] min-w-[48px] items-center gap-[8px] rounded-full bg-[var(--action-neutral)] px-[20px] py-[10px] text-xs font-medium normal-case tracking-normal text-[var(--on-action-neutral)] shadow-lg transition-transform hover:scale-105 active:scale-95"
          >
            <User size={16} />
            <span className="site-portal-label hidden sm:inline">Fan Portal</span>
            <span className="site-portal-label sm:hidden">Portal</span>
          </Link>
          <button
            type="button"
            aria-label="Open menu"
            disabled={!hydrated}
            aria-expanded={mobileMenuOpen}
            aria-controls="mobile-navigation-drawer"
            onClick={() => setMobileMenuOpen(true)}
            className="site-menu-trigger flex h-[48px] w-[48px] shrink-0 items-center justify-center rounded-full bg-white/10 text-white xl:hidden"
          >
            <Menu size={20} />
          </button>
        </div>
      </nav>

      {/* Mega Menu Overlay */}
      <div
        id="site-mega-menu"
        role="region"
        aria-label={`${navItems.find(item => item.featureKey === activeMenu)?.label ?? "Club"} navigation`}
        aria-hidden={!activeMenu || !desktopFits}
        inert={!activeMenu || !desktopFits}
        className={cn(
          "absolute inset-x-0 top-full border-t border-white/10 bg-[var(--surface)] shadow-2xl transition-all duration-500 ease-in-out",
          activeMenu
            ? "max-h-[600px] opacity-100 visible"
            : "max-h-0 opacity-0 invisible overflow-hidden",
        )}
      >
        <div className="page-shell p-8 lg:p-12">
          {activeMenu && !["live", "squad"].includes(activeMenu) ? (
            <Link href={navItems.find(item => item.featureKey === activeMenu)?.href ?? "/"} className="inline-flex min-h-[48px] items-center text-white underline">Open {navItems.find(item => item.featureKey === activeMenu)?.label ?? "club page"}</Link>
          ) : null}
          {activeMenu === "live" && (
            <div className="grid grid-cols-4 gap-12">
              <div className="col-span-2">
                <p className="mb-6 text-xs font-medium normal-case tracking-normal text-white/40">
                  Match centre
                </p>
                <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
                  <p className="font-medium text-white">{club.shortName}</p>
                  <Link href="/fixtures" className="mt-4 inline-flex min-h-[48px] items-center text-white underline">
                    View confirmed fixtures
                  </Link>
                </div>
              </div>
              <div>
                <p className="mb-6 text-xs font-medium normal-case tracking-normal text-white/40">
                  Information
                </p>
                <ul className="space-y-4 text-sm font-medium normal-case tracking-normal text-white">
                  <li>
                    <Link
                      href="/fixtures"
                      className="hover:text-[var(--action-neutral)] transition-colors"
                    >
                      Full Fixtures
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/results"
                      className="hover:text-[var(--action-neutral)] transition-colors"
                    >
                      Results
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/standings"
                      className="hover:text-[var(--action-neutral)] transition-colors"
                    >
                      League Table
                    </Link>
                  </li>
                  <li>
                    <Link
                      href="/tickets"
                      className="hover:text-[var(--action-neutral)] transition-colors"
                    >
                      Ticket Info
                    </Link>
                  </li>
                </ul>
              </div>
              <div className="relative overflow-hidden rounded-2xl bg-black/40 p-6">
                <div className="absolute inset-0 opacity-20 bg-[url('/brand-surface.svg')] bg-cover bg-center" />
                <div className="relative z-10">
                  <p className="text-xs font-medium normal-case tracking-normal text-[var(--action-neutral)]">
                    Club history
                  </p>
                  <p className="mt-2 text-2xl font-medium text-white normal-case leading-none">
                    {club.shortName}
                  </p>
                  <Link
                    href="/history"
                    className="mt-4 inline-block text-[10px] font-medium normal-case tracking-normal text-white/60 hover:text-white transition-colors underline underline-offset-4"
                  >
                    Learn More
                  </Link>
                </div>
              </div>
            </div>
          )}
          {activeMenu === "squad" && (
            <div className="grid grid-cols-4 gap-8">
              <div className="col-span-4 mt-8 flex justify-center">
                <Link
                  href="/squad"
                  className="text-xs font-medium normal-case tracking-normal text-white/60 hover:text-white transition-colors"
                >
                  View Full First Team Roster →
                </Link>
              </div>
            </div>
          )}
        </div>
      </div>

      <div>
        <MobileNavDrawer
          isOpen={mobileMenuOpen}
          onClose={closeMobileMenu}
          club={club}
          navigationItems={resolvedNavigationItems}
        />
      </div>
    </div>
  );
}
