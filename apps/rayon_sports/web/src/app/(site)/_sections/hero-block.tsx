import Link from "next/link";
import { EliteHero } from "@/components/home/elite-hero";
import {
  getClubProfile,
  getContributionGroups,
  getFanClubs,
  getCmsContentBlock,
  getHomeBanners,
  getMatches,
  getMembershipPackages,
} from "@/lib/data/public";

const fallbackQuickLinks = [
  { href: "/tickets", label: "Buy tickets" },
  { href: "/Groups", label: "Support Groups" },
  { href: "/membership", label: "Membership tiers" },
  { href: "/news", label: "Latest club news" },
  { href: "/shop", label: "Shop new drop" },
];

export async function HeroBlock() {
  const [
    club,
    matches,
    banners,
    heroCms,
  ] = await Promise.all([
    getClubProfile(),
    getMatches(),
    getHomeBanners(),
    getCmsContentBlock("hero_headline"),
  ]);

  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    matches.find((m) => m.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  // Use banners as quick links when available, else fall back
  const quickLinks =
    banners.length > 0
      ? banners.map((b) => ({ href: b.route, label: b.ctaLabel || b.title }))
      : fallbackQuickLinks;

  return (
    <div className="space-y-12">
      <EliteHero
        club={club}
        featuredMatch={featuredMatch}
        tagline={heroCms?.subtitle || undefined}
        headline={heroCms?.title || undefined}
        description={heroCms?.body || undefined}
      />

      <div className="page-shell flex flex-wrap gap-3">
        {quickLinks.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            prefetch={false}
            className="inline-flex min-h-11 items-center rounded-full border border-white/10 bg-white/6 px-4 py-2 text-sm font-semibold text-slate-100 transition hover:-translate-y-0.5 hover:bg-white/10 hover:text-white"
          >
            {item.label}
          </Link>
        ))}
      </div>
    </div>
  );
}
