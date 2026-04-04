import Link from "next/link";
import { HeroSection } from "@/components/hero-section";
import { fallbackContributionGroups } from "@/lib/content";
import {
  getClubProfile,
  getContributionGroups,
  getFanClubs,
  getMatches,
  getMembershipPackages,
} from "@/lib/data/public";

export async function HeroBlock() {
  const [club, matches, fanClubs, contributionGroups, membershipPackages] =
    await Promise.all([
      getClubProfile(),
      getMatches(),
      getFanClubs(),
      getContributionGroups(),
      getMembershipPackages(),
    ]);

  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    matches.find((m) => m.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  const activeCircles =
    contributionGroups.length > 0 ? contributionGroups : fallbackContributionGroups;

  return (
    <>
      <HeroSection
        club={club}
        featuredMatch={featuredMatch}
        contributionGroups={activeCircles}
        fanClubs={fanClubs}
        membershipPackages={membershipPackages}
      />

      <div className="page-shell flex flex-wrap gap-3">
        {[
          { href: "/tickets", label: "Buy tickets" },
          { href: "/circles", label: "Support circles" },
          { href: "/membership", label: "Membership tiers" },
          { href: "/news", label: "Latest club news" },
          { href: "/shop", label: "Shop new drop" },
        ].map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className="rounded-full border border-border-soft bg-white/5 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-white/10 hover:text-white"
          >
            {item.label}
          </Link>
        ))}
      </div>
    </>
  );
}
