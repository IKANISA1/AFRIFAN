import Link from "next/link";
import { ShieldCheck, Ticket } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getMembershipPackages } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { formatCurrency } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.membership.metaTitle(club),
    description: copy.pages.membership.metaDescription(club),
    path: "/membership",
  });
}

export default async function MembershipPage() {
  const featureGate = await getFeaturePageGuard("membership");
  if (featureGate) {
    return featureGate;
  }

  const [club, packages] = await Promise.all([
    getClubProfile(),
    getMembershipPackages(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const paidPackages = packages.filter((membershipPackage) => membershipPackage.annualPrice > 0);
  const featureSet = Array.from(
    new Set(
      packages.flatMap((membershipPackage) => membershipPackage.perks),
    ),
  ).slice(0, 8);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.membership.eyebrow}
        title={copy.pages.membership.title}
        description={copy.pages.membership.description(club)}
        actions={
          <>
            <Link
              href="/supporters"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.activateInFanApp}
            </Link>
            <Link
              href="/tickets"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.ticketPriority}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.tiers, value: packages.length.toString() },
          {
            label: copy.common.paidPlans,
            value: paidPackages.length.toString(),
          },
          {
            label: copy.common.from,
            value: paidPackages.length > 0
              ? formatCurrency(
                  paidPackages.reduce(
                    (lowest, membershipPackage) =>
                      Math.min(lowest, membershipPackage.annualPrice),
                    paidPackages[0].annualPrice,
                  ),
                )
              : copy.common.included,
          },
        ]}
      />

      <section className="grid gap-5 sm:grid-cols-2 xl:grid-cols-4">
        {packages.map((membershipPackage) => (
          <article
            key={membershipPackage.id}
            className="glass-panel card-interactive rounded-[32px] p-6"
          >
            <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
              {membershipPackage.tier}
            </p>
            <p className="mt-4 font-display text-4xl font-bold uppercase leading-none">
              {membershipPackage.title}
            </p>
            <p className="mt-4 text-sm leading-7 text-slate-300">
              {membershipPackage.description}
            </p>
            <p className="mt-5 font-display text-3xl font-bold uppercase">
              {formatCurrency(membershipPackage.annualPrice)}
            </p>
            <ul className="mt-5 space-y-3 text-sm text-slate-200">
              {membershipPackage.perks.map((perk) => (
                <li key={perk} className="rounded-[20px] border border-border-soft bg-white/6 px-4 py-3">
                  {perk}
                </li>
              ))}
            </ul>
          </article>
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            {copy.pages.membership.membershipBenefits}
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold text-white">
            {copy.pages.membership.whatEveryTierCovers}
          </h2>
          <div className="mt-6 grid gap-3">
            {featureSet.map((feature) => (
              <div
                key={feature}
                className="flex items-center justify-between gap-4 rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
              >
                <span className="text-sm font-medium text-slate-200">{feature}</span>
                <span className="rounded-full bg-club-primary/18 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                  {copy.common.included}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            {copy.pages.membership.whyItMatters}
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold text-white">
            {copy.pages.membership.oneSupporterIdentity}
          </h2>
          <div className="mt-5 grid gap-4">
            {[
              { icon: ShieldCheck, copy: copy.pages.membership.identityPoints[0] },
              { icon: Ticket, copy: copy.pages.membership.identityPoints[1] },
            ].map(({ icon: Icon, copy: point }) => (
              <div
                key={point}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4"
              >
                <div className="flex items-start gap-3">
                  <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-accent/18 text-club-accent">
                    <Icon size={18} />
                  </span>
                  <p className="text-sm leading-7 text-slate-300">{point}</p>
                </div>
              </div>
            ))}
          </div>
          <Link
            href="/supporters"
            className="mt-6 inline-flex w-fit items-center gap-2 rounded-full bg-club-primary px-6 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {copy.common.activateMembershipInFanApp}
          </Link>
        </div>
      </section>
    </div>
  );
}
