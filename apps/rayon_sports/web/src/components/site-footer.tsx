import Image from "next/image";
import Link from "next/link";
import { Camera, Globe, LucideIcon, Music2, Send } from "lucide-react";
import { footerNavigationGroups } from "@/lib/content";
import { resolveFanAppHref } from "@/lib/config";
import type { ClubProfile } from "@/lib/types";
import type { SiteChromeCopy } from "@/lib/site-copy";
import { ui } from "@/design-system";

const socialIconMap: Record<string, LucideIcon> = {
  facebook: Globe,
  instagram: Camera,
  x: Send,
  tiktok: Music2,
};

interface SiteFooterProps {
  club: ClubProfile;
  copy: SiteChromeCopy;
}

export function SiteFooter({ club, copy }: SiteFooterProps) {
  const socialLinks = [
    { key: "facebook", href: club.facebookUrl },
    { key: "instagram", href: club.instagramUrl },
    { key: "x", href: club.xUrl },
    { key: "tiktok", href: club.tiktokUrl },
  ].filter((entry) => entry.href);

  return (
    <footer className="relative mt-24 overflow-hidden pb-[env(safe-area-inset-bottom)]">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-club-primary-light to-transparent opacity-65" />
      <div className="pointer-events-none absolute left-[8%] top-10 h-64 w-64 rounded-full bg-[var(--site-glow-primary)] blur-[120px]" />
      <div className="pointer-events-none absolute right-[8%] top-16 h-56 w-56 rounded-full bg-[var(--site-glow-accent)] blur-[112px]" />

      <div className="page-shell relative py-14">
        <div className={`${ui.panel} grid gap-10 rounded-[40px] border-[1.2px] px-6 py-8 sm:px-8 sm:py-10 lg:grid-cols-[1.05fr_1.95fr]`}>
          <div className="space-y-6">
            <div className="flex items-center gap-4">
              <Image
                src={club.officialLogoUrl ?? "/icons/icon-192x192.png"}
                alt={`${club.clubName} crest`}
                width={64}
                height={64}
                sizes="64px"
                className={`${ui.brandMark} rounded-full object-cover`}
              />
              <div>
                <p className="font-display text-3xl font-bold uppercase tracking-[-0.05em] text-white">
                  {club.shortName}
                </p>
                <p className={ui.kicker}>
                  {club.nickname || copy.officialWebsite}
                </p>
              </div>
            </div>

            <p className="max-w-md text-sm leading-7 text-slate-300">
              Official {club.clubName} coverage for fixtures, tickets,
              membership, club news, supporter circles, and matchday access.
            </p>

            <div className="flex flex-wrap gap-4">
              <Link
                href={resolveFanAppHref()}
                prefetch={false}
                className={`${ui.buttonPrimary} min-h-12 px-5 py-3`}
              >
                {copy.openFanApp}
              </Link>
              <Link
                href="/tickets"
                prefetch={false}
                className={`${ui.buttonSecondary} min-h-12 px-5 py-3`}
              >
                {copy.buyTickets}
              </Link>
              <Link
                href="/circles"
                prefetch={false}
                className={`${ui.buttonSecondary} min-h-12 px-5 py-3`}
              >
                {copy.supportCircles}
              </Link>
            </div>

            <div className="flex flex-wrap gap-2 pt-2">
              {socialLinks.map((entry) => {
                const Icon = socialIconMap[entry.key];
                return (
                  <a
                    key={entry.key}
                    href={entry.href ?? "#"}
                    target="_blank"
                    rel="noreferrer"
                    className={`${ui.iconButton} text-slate-200`}
                    aria-label={entry.key}
                  >
                    <Icon size={18} />
                  </a>
                );
              })}
            </div>
          </div>

          <div className="grid gap-8 sm:grid-cols-2 xl:grid-cols-4">
            {footerNavigationGroups.map((group) => (
              <div key={group.title} className="space-y-4">
                <p className={ui.kicker}>
                  {group.title}
                </p>
                <div className="flex flex-col gap-3">
                  {group.links.map((link) => (
                    <Link
                      key={link.href}
                      href={link.href}
                      prefetch={false}
                      className="text-sm font-medium text-slate-300 transition hover:text-white"
                    >
                      {link.label}
                    </Link>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-12 flex flex-col gap-3 pt-6 text-[11px] uppercase tracking-[0.22em] text-slate-500 md:flex-row md:items-center md:justify-between">
          <p>© {new Date().getFullYear()} {club.clubName}</p>
          <p>{club.league} · {club.supportedLanguages.join(" / ").toUpperCase()}</p>
        </div>
      </div>
    </footer>
  );
}
