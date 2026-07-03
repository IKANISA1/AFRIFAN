import Image from "next/image";
import Link from "next/link";
import { siteNavigation, utilityNavigation } from "@/lib/content";
import type { ClubProfile } from "@/lib/types";
import type { SiteChromeCopy } from "@/lib/site-copy";
import { SiteHeaderControls } from "@/components/site-header-controls";
import { ui } from "@/ui-kit";

const PRIMARY_LINKS = siteNavigation.filter(
  (item) =>
    !["/", "/standings", "/fan-clubs", "/history", "/contact"].includes(item.href),
);

interface SiteHeaderProps {
  club: ClubProfile;
  copy: SiteChromeCopy;
}

export function SiteHeader({ club, copy }: SiteHeaderProps) {
  const logoUrl = club.officialLogoUrl ?? "/brand-mark.svg";

  return (
    <header className="sticky top-0 z-[60]">
      <div className={`${ui.glassHeader} border-b-0`}>
        <div className="page-shell flex flex-wrap items-center justify-between gap-3 py-2 text-[10px] uppercase tracking-[0.24em] text-slate-300">
          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            <span className={ui.kicker}>{club.shortName}</span>
            <span className="hidden text-white/20 sm:inline">•</span>
            <span className="text-slate-400 sm:text-slate-300">{club.league}</span>
            <span className="hidden text-white/20 sm:inline">•</span>
            <span className="hidden sm:inline">{copy.officialClubWebsite}</span>
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
            <span className="text-white/20">|</span>
            <div className="flex items-center gap-2">
              {club.supportedLanguages.map((language, index) => (
                <span key={language} className="transition hover:text-white">
                  {language.toUpperCase()}
                  {index < club.supportedLanguages.length - 1 ? (
                    <span className="ml-2 text-white/20">/</span>
                  ) : null}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="page-shell relative py-4">
        <div className={`${ui.panel} flex items-center justify-between gap-4 rounded-[32px] px-4 py-3 sm:px-5 lg:px-6`}>
          <Link href="/" className="flex items-center gap-3">
            <Image
              src={logoUrl}
              alt={`${club.clubName} brand mark`}
              width={64}
              height={64}
              priority
              sizes="48px"
              className={`${ui.brandMark} h-12 w-12 rounded-full object-cover`}
            />
            <div className="hidden sm:block">
              <p className="font-display text-xl font-bold uppercase leading-none tracking-[-0.05em] text-white lg:text-[1.75rem]">
                {club.nickname || club.shortName}
              </p>
              <p className={`mt-1 ${ui.meta}`}>
                {club.clubName}
              </p>
            </div>
          </Link>

          <nav aria-label="Primary" className="hidden items-center gap-1 xl:flex">
            {PRIMARY_LINKS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                prefetch={false}
                className={`${ui.button} ${ui.buttonTertiary} rounded-full px-3.5 py-2 text-sm text-slate-300 hover:text-white focus-ring`}
              >
                {item.label}
              </Link>
            ))}
          </nav>

          <SiteHeaderControls club={club} copy={copy} />
        </div>
      </div>
    </header>
  );
}
