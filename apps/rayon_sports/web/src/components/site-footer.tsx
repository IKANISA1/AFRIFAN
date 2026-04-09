import Image from "next/image";
import Link from "next/link";
import { Camera, Globe, LucideIcon, Music2, Send } from "lucide-react";
import { footerNavigationGroups } from "@/lib/content";
import { getClubProfile } from "@/lib/data/public";
import { resolveFanAppHref } from "@/lib/config";

const socialIconMap: Record<string, LucideIcon> = {
  facebook: Globe,
  instagram: Camera,
  x: Send,
  tiktok: Music2,
};

export async function SiteFooter() {
  const club = await getClubProfile();
  const socialLinks = [
    { key: "facebook", href: club.facebookUrl },
    { key: "instagram", href: club.instagramUrl },
    { key: "x", href: club.xUrl },
    { key: "tiktok", href: club.tiktokUrl },
  ].filter((entry) => entry.href);

  return (
    <footer className="relative mt-20 overflow-hidden border-t border-border-soft bg-[#040d1d]">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-club-primary-light to-transparent opacity-70" />
      <div className="pointer-events-none absolute left-[10%] top-12 h-56 w-56 rounded-full bg-club-primary/15 blur-[100px]" />
      <div className="pointer-events-none absolute right-[10%] top-16 h-48 w-48 rounded-full bg-club-accent/10 blur-[96px]" />

      <div className="page-shell relative py-14">
        <div className="grid gap-10 lg:grid-cols-[1.1fr_1.9fr]">
          <div className="space-y-6">
            <div className="flex items-center gap-4">
              <Image
                src={club.officialLogoUrl ?? "/icons/icon-192x192.png"}
                alt={`${club.clubName} crest`}
                width={64}
                height={64}
                sizes="64px"
                className="rounded-full border border-white/10 bg-white/5 object-cover"
              />
              <div>
                <p className="font-display text-3xl font-bold uppercase text-white">
                  {club.shortName}
                </p>
                <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-club-accent">
                  {club.nickname || club.clubName}
                </p>
              </div>
            </div>

            <p className="max-w-md text-sm leading-7 text-slate-300">
              Official {club.clubName} coverage for fixtures, tickets,
              membership, club news, supporter circles, and matchday access.
            </p>

            <div className="flex flex-wrap gap-3">
              <Link
                href={resolveFanAppHref()}
                prefetch={false}
                className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
              >
                Open fan app
              </Link>
              <Link
                href="/tickets"
                prefetch={false}
                className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Buy tickets
              </Link>
              <Link
                href="/circles"
                prefetch={false}
                className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Support circles
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
                    className="flex h-11 w-11 items-center justify-center rounded-full border border-border-soft bg-white/5 text-slate-200 transition hover:border-white/20 hover:bg-white/10 hover:text-white"
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
                <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-club-accent">
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

        <div className="mt-12 flex flex-col gap-3 border-t border-border-soft pt-6 text-[11px] uppercase tracking-[0.22em] text-slate-500 md:flex-row md:items-center md:justify-between">
          <p>© {new Date().getFullYear()} {club.clubName}</p>
          <p>{club.league} · {club.supportedLanguages.join(" / ").toUpperCase()}</p>
        </div>
      </div>
    </footer>
  );
}
