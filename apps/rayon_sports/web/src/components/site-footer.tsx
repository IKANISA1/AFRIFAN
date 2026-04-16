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
    <footer className="bg-black border-t border-white/5 pt-20 pb-12 lg:pt-32">
      <div className="page-shell">
        <div className="grid gap-16 lg:grid-cols-12">
          {/* Brand Column */}
          <div className="lg:col-span-4">
            <Link href="/" className="inline-flex items-center gap-4 mb-8">
              <div className="h-16 w-16 overflow-hidden rounded-full bg-white p-1">
                <Image
                  src={club.officialLogoUrl ?? "/icons/icon-192x192.png"}
                  alt={club.clubName}
                  width={64}
                  height={64}
                  className="h-full w-full object-contain"
                />
              </div>
              <div>
                <p className="font-display text-3xl font-black uppercase italic leading-none text-white tracking-tighter">
                  {club.shortName}
                </p>
                <p className="mt-1 text-[10px] font-bold uppercase tracking-[0.3em] text-[var(--club-accent)]">
                  {club.nickname || "The Beloved"}
                </p>
              </div>
            </Link>
            <p className="text-sm font-bold leading-relaxed text-white/40 mb-10 max-w-sm">
              Experience the pulse of Rwandan football. From matchday magic at the Cathedral to digital fan engagement across the globe.
            </p>
            <div className="flex gap-4">
              {socialLinks.map((entry) => {
                const Icon = socialIconMap[entry.key];
                return (
                  <a
                    key={entry.key}
                    href={entry.href ?? "#"}
                    target="_blank"
                    rel="noreferrer"
                    className="flex h-10 w-10 items-center justify-center rounded-full border border-white/10 text-white hover:bg-[var(--club-accent)] hover:text-black transition-all"
                    aria-label={entry.key}
                  >
                    <Icon size={18} />
                  </a>
                );
              })}
            </div>
          </div>

          {/* Navigation Columns */}
          <div className="lg:col-span-8">
            <div className="grid grid-cols-2 gap-12 sm:grid-cols-4">
              {footerNavigationGroups.map((group) => (
                <div key={group.title}>
                  <p className="text-[10px] font-bold uppercase tracking-[0.3em] text-white mb-8">
                    {group.title}
                  </p>
                  <ul className="space-y-4">
                    {group.links.map((link) => (
                      <li key={link.href}>
                        <Link
                          href={link.href}
                          className="text-sm font-bold text-white/40 hover:text-white transition-colors uppercase tracking-widest"
                        >
                          {link.label}
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="mt-20 border-t border-white/5 pt-12 flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-wrap gap-8 text-[10px] font-bold uppercase tracking-[0.2em] text-white/20">
            <span>© {new Date().getFullYear()} {club.clubName}</span>
            <Link href="/privacy" className="hover:text-white transition-colors">Privacy Policy</Link>
            <Link href="/terms" className="hover:text-white transition-colors">Terms of Service</Link>
          </div>
          <div className="flex items-center gap-4 text-[10px] font-black uppercase tracking-[0.3em] text-white/40">
            <span>Powered by</span>
            <span className="text-white">AFRICLUB</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
