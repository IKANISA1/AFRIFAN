import Image from "next/image";
import Link from "next/link";
import { siteNavigation, utilityNavigation } from "@/lib/content";
import type { ClubProfile } from "@/lib/types";

const PRIMARY_LINKS = siteNavigation.filter(
  (item) =>
    !["/", "/standings", "/fan-clubs", "/history", "/contact"].includes(item.href),
);

interface SiteHeaderProps {
  club: ClubProfile;
}

export function SiteHeader({ club }: SiteHeaderProps) {
  const logoUrl = club.officialLogoUrl ?? "/icons/icon-192x192.png";

  return (
    <header className="sticky top-0 z-[60] border-b border-transparent bg-surface-strong/80 backdrop-blur-xl">
      <div className="overflow-hidden border-b border-transparent">
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
                prefetch={false}
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

      <div className="page-shell flex items-center justify-between gap-4 py-3.5">
        <Link href="/" className="flex items-center gap-3">
          <Image
            src={logoUrl}
            alt={`${club.clubName} crest`}
            width={64}
            height={64}
            priority
            sizes="48px"
            className="h-12 w-12 rounded-full border border-white/10 bg-white/5 object-cover"
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

        <nav aria-label="Primary" className="hidden items-center gap-1 lg:flex">
          {PRIMARY_LINKS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              prefetch={false}
              className="rounded-full px-3.5 py-2 text-sm font-semibold text-slate-300 transition-all duration-200 hover:bg-white/6 hover:text-white focus-ring"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <Link
            href="/search"
            prefetch={false}
            className="flex h-11 min-w-11 items-center justify-center rounded-full border border-border-soft bg-white/4 px-3 text-slate-200 transition hover:bg-white/10 hover:text-white focus-ring"
            aria-label="Search"
          >
            <span className="text-sm font-semibold uppercase tracking-[0.18em] xl:hidden">
              Search
            </span>
            <span className="hidden text-xs uppercase tracking-[0.18em] xl:inline">
              Search
            </span>
          </Link>
          <Link
            href="/app"
            prefetch={false}
            className="hidden min-h-11 items-center gap-2 rounded-full bg-club-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-club-primary-light cta-glow focus-ring md:inline-flex"
          >
            Fan portal
          </Link>
          <details className="relative lg:hidden">
            <summary className="flex h-11 w-11 list-none items-center justify-center rounded-full border border-border-soft bg-white/5 text-white transition hover:bg-white/10 focus-ring [&::-webkit-details-marker]:hidden">
              <span className="text-xs font-semibold uppercase tracking-[0.2em]">
                Menu
              </span>
            </summary>
            <div className="absolute right-0 top-full z-50 mt-3 w-[85vw] max-w-[360px] rounded-[28px] border border-border-soft bg-surface-strong p-5 shadow-2xl">
              <div className="grid gap-3">
                <div className="grid grid-cols-3 gap-3">
                  <Link
                    href="/app"
                    prefetch={false}
                    className="rounded-2xl border border-border-soft bg-white/5 px-3 py-3 text-center text-xs font-semibold uppercase tracking-[0.18em] text-white transition hover:bg-white/10"
                  >
                    Portal
                  </Link>
                  <Link
                    href="/tickets"
                    prefetch={false}
                    className="rounded-2xl border border-border-soft bg-white/5 px-3 py-3 text-center text-xs font-semibold uppercase tracking-[0.18em] text-white transition hover:bg-white/10"
                  >
                    Tickets
                  </Link>
                  <Link
                    href="/shop"
                    prefetch={false}
                    className="rounded-2xl border border-border-soft bg-white/5 px-3 py-3 text-center text-xs font-semibold uppercase tracking-[0.18em] text-white transition hover:bg-white/10"
                  >
                    Shop
                  </Link>
                </div>

                <div className="grid gap-1 border-t border-border-soft pt-3">
                  {siteNavigation.map((item) => (
                    <Link
                      key={item.href}
                      href={item.href}
                      prefetch={false}
                      className="rounded-xl px-3 py-3 text-sm font-semibold text-slate-200 transition hover:bg-white/6 hover:text-white"
                    >
                      {item.label}
                    </Link>
                  ))}
                </div>

                <div className="border-t border-border-soft pt-3">
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
              </div>
            </div>
          </details>
        </div>
      </div>
    </header>
  );
}
