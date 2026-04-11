import Link from "next/link";
import { HeroSection } from "@/components/hero-section";
import { fallbackContributionGroups } from "@/lib/content";
import {
  getClubProfile,
  getContributionGroups,
  getFeaturedFantasyCompetition,
  getFanClubs,
  getCmsContentBlock,
  getHomeBanners,
  getMatches,
  getMembershipPackages,
} from "@/lib/data/public";

const fallbackQuickLinks = [
  { href: "/tickets", label: "Buy tickets" },
  { href: "/fantasy", label: "Fantasy football" },
  { href: "/circles", label: "Support circles" },
  { href: "/membership", label: "Membership tiers" },
  { href: "/news", label: "Latest club news" },
  { href: "/shop", label: "Shop new drop" },
];

export async function HeroBlock() {
  const [club, matches, fanClubs, contributionGroups, membershipPackages, banners, heroCms, featuredFantasyCompetition] =
    await Promise.all([
      getClubProfile(),
      getMatches(),
      getFanClubs(),
      getContributionGroups(),
      getMembershipPackages(),
      getHomeBanners(),
      getCmsContentBlock("hero_headline"),
      getFeaturedFantasyCompetition(),
    ]);

  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    matches.find((m) => m.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  const activeCircles =
    contributionGroups.length > 0 ? contributionGroups : fallbackContributionGroups;

  // Use banners as quick links when available, else fall back
  const quickLinks =
    banners.length > 0
      ? banners.map((b) => ({ href: b.route, label: b.ctaLabel || b.title }))
      : fallbackQuickLinks;

  const fantasyQuickLink =
    featuredFantasyCompetition == null
      ? null
      : {
          href: `/fantasy/${featuredFantasyCompetition.slug}`,
          label: featuredFantasyCompetition.ctaLabel || featuredFantasyCompetition.name,
        };

  const quickLinksWithFantasy =
    fantasyQuickLink == null ||
    quickLinks.some((item) => item.href === fantasyQuickLink.href)
      ? quickLinks
      : [fantasyQuickLink, ...quickLinks];

  return (
    <>
      <HeroSection
        club={club}
        featuredMatch={featuredMatch}
        contributionGroups={activeCircles}
        fanClubs={fanClubs}
        membershipPackages={membershipPackages}
        heroTagline={heroCms?.subtitle || undefined}
        heroHeadline={heroCms?.title || undefined}
        heroDescription={heroCms?.body || undefined}
      />

      <div className="page-shell flex flex-wrap gap-3">
        {quickLinksWithFantasy.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            prefetch={false}
            className="inline-flex min-h-11 items-center rounded-full border border-border-soft bg-white/5 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-white/10 hover:text-white"
          >
            {item.label}
          </Link>
        ))}
      </div>
    </>
  );
}
