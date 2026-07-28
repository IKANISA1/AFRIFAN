import Link from "next/link";
import { EliteHero } from "@/components/home/elite-hero";
import { resolveFanAppHref } from "@/lib/config";
import {
  getClubProfile,
  getCmsContentBlock,
  getHomeBanners,
  getMatches,
} from "@/lib/data/public";

const fallbackQuickLinks = [
  { href: resolveFanAppHref(), label: "Fan portal" },
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
  const quickLinks = (
    banners.length > 0
      ? [
          { href: resolveFanAppHref(), label: "Fan portal" },
          ...banners.map((b) => ({ href: b.route, label: b.ctaLabel || b.title })),
        ]
      : fallbackQuickLinks
  ).filter(
    (item, index, items) =>
      items.findIndex(
        (candidate) => candidate.href === item.href && candidate.label === item.label,
      ) === index,
  );

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
            className="inline-flex min-h-11 items-center rounded-full border border-slate-700 bg-slate-950/78 px-4 py-2 text-sm font-semibold text-white transition hover:-translate-y-0.5 hover:bg-slate-900 hover:text-white"
          >
            {item.label}
          </Link>
        ))}
      </div>
    </div>
  );
}
