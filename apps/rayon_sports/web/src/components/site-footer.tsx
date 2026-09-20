import Image from "next/image";
import Link from "next/link";
import { Camera, Globe, LucideIcon, Music2, Send } from "lucide-react";
import type { ClubProfile } from "@/lib/types";
import type { SiteChromeCopy } from "@/lib/site-copy";
import type { SiteNavigationItem } from "@/lib/feature-config";

const socialIconMap: Record<string, LucideIcon> = {
  facebook: Globe,
  instagram: Camera,
  x: Send,
  tiktok: Music2,
};

interface SiteFooterProps {
  club: ClubProfile;
  copy: SiteChromeCopy;
  navigationItems?: SiteNavigationItem[];
}

const footerGroupLabels: Record<string, string> = {
  footer_matchday: "Matchday",
  footer_supporters: "Supporters",
  footer_club: "Club",
  legal: "Legal",
};

function groupFooterNavigation(items: SiteNavigationItem[]) {
  return Object.entries(
    items.reduce<Record<string, SiteNavigationItem[]>>((groups, item) => {
      if (!item.nav_group.startsWith("footer_") && item.nav_group !== "legal") {
        return groups;
      }
      groups[item.nav_group] = [...(groups[item.nav_group] ?? []), item];
      return groups;
    }, {}),
  ).map(([key, links]) => ({
    title:
      footerGroupLabels[key] ?? key.replace(/^footer_/, "").replace(/_/g, " "),
    links: links.sort(
      (left, right) => (left.sort_order ?? 999) - (right.sort_order ?? 999),
    ),
  }));
}

export function SiteFooter({
  club,
  copy: _copy,
  navigationItems = [],
}: SiteFooterProps) {
  const socialLinks = [
    { key: "facebook", href: club.facebookUrl },
    { key: "instagram", href: club.instagramUrl },
    { key: "x", href: club.xUrl },
    { key: "tiktok", href: club.tiktokUrl },
  ].filter((entry) => entry.href);
  const footerNavigationGroups = groupFooterNavigation(navigationItems);

  return (
    <footer className="bg-black border-t border-white/5 pt-20 pb-12 lg:pt-32">
      <div className="page-shell">
        <div className="grid gap-16 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
          {/* Brand Column */}
          <div className="min-w-0">
            <Link
              href="/"
              className="mb-8 inline-flex max-w-full flex-col items-start gap-[16px] sm:flex-row sm:items-center"
            >
              <div className="h-[64px] w-[64px] shrink-0 overflow-hidden rounded-full bg-white p-[4px]">
                <Image
                  src={club.officialLogoUrl ?? "/brand-mark.svg"}
                  alt={club.clubName}
                  width={64}
                  height={64}
                  className="h-full w-full object-contain"
                />
              </div>
              <div className="min-w-0 max-w-full">
                <p className="break-words font-display text-2xl font-black uppercase italic leading-none tracking-tighter text-white">
                  {club.shortName}
                </p>
                <p className="mt-1 text-[10px] font-bold uppercase tracking-[0.3em] text-white/80">
                  {club.nickname || club.shortName}
                </p>
              </div>
            </Link>
            <p className="mb-10 max-w-full break-words text-sm font-bold leading-relaxed text-white/70">
              Follow {club.clubName} through fixtures, club news and supporter activities.
            </p>
            <div className="flex flex-wrap gap-[16px]">
              {socialLinks.map((entry) => {
                const Icon = socialIconMap[entry.key];
                return (
                  <a
                    key={entry.key}
                    href={entry.href ?? "#"}
                    target="_blank"
                    rel="noreferrer"
                    className="flex h-[40px] w-[40px] items-center justify-center rounded-full border border-white/10 text-white transition-all hover:bg-[var(--club-accent)] hover:text-black"
                    aria-label={entry.key}
                  >
                    <Icon size={18} />
                  </a>
                );
              })}
            </div>
          </div>

          {/* Navigation Columns */}
          <div className="min-w-0">
            <div className="site-footer-navigation grid grid-cols-2 gap-12 sm:grid-cols-4">
              {footerNavigationGroups.map((group) => (
                <div key={group.title} className="min-w-0 [overflow-wrap:anywhere]">
                  <p className="text-[10px] font-bold uppercase tracking-[0.3em] text-white mb-8">
                    {group.title}
                  </p>
                  <ul className="space-y-4">
                    {group.links.map((link) => (
                      <li key={link.href}>
                        <Link
                          href={link.href}
                          className="text-sm font-bold text-white/70 hover:text-white transition-colors uppercase tracking-widest"
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
          <div className="flex flex-wrap gap-8 text-[10px] font-bold uppercase tracking-[0.2em] text-white/70">
            <span>
              © {new Date().getFullYear()} {club.clubName}
            </span>
            <Link
              href="/privacy"
              className="hover:text-white transition-colors"
            >
              Privacy Policy
            </Link>
            <Link href="/terms" className="hover:text-white transition-colors">
              Terms of Service
            </Link>
            <Link
              href="/support"
              className="hover:text-white transition-colors"
            >
              Support
            </Link>
            <Link
              href="/account-deletion"
              className="hover:text-white transition-colors"
            >
              Account deletion
            </Link>
          </div>
          <div className="flex items-center gap-4 text-[10px] font-black uppercase tracking-[0.3em] text-white/70">
            <span>Powered by</span>
            <span className="text-white">AFRICLUB</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
