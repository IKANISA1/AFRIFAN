import Image from "next/image";
import Link from "next/link";
import { siteNavigation, utilityNavigation } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";
import { SiteHeaderControls } from "@/components/site-header-controls";

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
        <div className="page-shell flex flex-wrap items-center justify-between gap-3 py-2 text-[10px] uppercase tracking-[0.24em] text-slate-300">
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
            <p className="mt-1 text-[11px] uppercase tracking-[0.18em] text-slate-300">
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

        <SiteHeaderControls club={club} />
      </div>
    </header>
  );
}
