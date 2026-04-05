import Link from "next/link";
import { ShieldCheck, Ticket } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getMembershipPackages } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { formatCurrency } from "@/lib/utils";

export const metadata = buildPageMetadata({
  title: "Rayon Sports membership",
  description:
    "Official Rayon Sports membership tiers with pricing, benefits, ticket priority, and supporter status across web and portal.",
  path: "/membership",
});

export default async function MembershipPage() {
  const packages = await getMembershipPackages();
  const paidPackages = packages.filter((membershipPackage) => membershipPackage.annualPrice > 0);
  const featureSet = Array.from(
    new Set(
      packages.flatMap((membershipPackage) => membershipPackage.perks),
    ),
  ).slice(0, 8);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Membership"
        title="Membership built for matchday."
        description="Compare every Rayon Sports membership tier, see the benefits clearly, and activate in the fan portal."
        actions={
          <>
            <Link
              href="/app/membership"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Activate in portal
            </Link>
            <Link
              href="/tickets"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Ticket priority
            </Link>
          </>
        }
        stats={[
          { label: "Tiers", value: packages.length.toString() },
          {
            label: "Paid plans",
            value: paidPackages.length.toString(),
          },
          {
            label: "From",
            value: paidPackages.length > 0
              ? formatCurrency(
                  paidPackages.reduce(
                    (lowest, membershipPackage) =>
                      Math.min(lowest, membershipPackage.annualPrice),
                    paidPackages[0].annualPrice,
                  ),
                )
              : "Included",
          },
        ]}
      />

      <section className="grid gap-5 xl:grid-cols-4">
        {packages.map((membershipPackage) => (
          <article
            key={membershipPackage.id}
            className="glass-panel card-interactive rounded-[32px] border border-border-soft p-6"
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
            Membership benefits
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold text-white">
            What every tier covers
          </h2>
          <div className="mt-6 grid gap-3">
            {featureSet.map((feature) => (
              <div
                key={feature}
                className="flex items-center justify-between gap-4 rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
              >
                <span className="text-sm font-medium text-slate-200">{feature}</span>
                <span className="rounded-full bg-club-primary/18 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                  Included
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Why it matters
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold text-white">
            One supporter identity
          </h2>
          <div className="mt-5 grid gap-4">
            {[
              { icon: ShieldCheck, copy: "Membership keeps login, supporter status, and club access consistent across web and portal." },
              { icon: Ticket, copy: "Ticket priority is the clearest reason to move up a tier." },
            ].map(({ icon: Icon, copy }) => (
              <div
                key={copy}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4"
              >
                <div className="flex items-start gap-3">
                  <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-accent/18 text-club-accent">
                    <Icon size={18} />
                  </span>
                  <p className="text-sm leading-7 text-slate-300">{copy}</p>
                </div>
              </div>
            ))}
          </div>
          <Link
            href="/app/membership"
            className="mt-6 inline-flex w-fit items-center gap-2 rounded-full bg-club-primary px-6 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            Activate membership in fan portal
          </Link>
        </div>
      </section>
    </div>
  );
}
