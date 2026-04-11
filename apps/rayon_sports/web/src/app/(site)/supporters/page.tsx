import Link from "next/link";
import { Download, ShieldCheck, Smartphone } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { buildPageMetadata } from "@/lib/metadata";

export const metadata = buildPageMetadata({
  title: "Supporter app",
  description:
    "Continue membership, ticketing, BioPay, shop, and supporter actions in the mobile app.",
  path: "/supporters",
});

export default function SupportersPage() {
  const fanAppHref = resolveFanAppHref();
  const hasExternalAppUrl = siteConfig.fanAppUrl.length > 0;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Fan app"
        title="The supporter journey continues on mobile."
        description="The website now handles discovery and club storytelling. Membership activation, secure checkout, BioPay, and authenticated supporter actions continue in the mobile app."
        actions={
          <>
            <Link
              href={fanAppHref}
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {hasExternalAppUrl ? "Open fan app" : "App links coming soon"}
            </Link>
            <Link
              href="/tickets"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Browse tickets first
            </Link>
          </>
        }
        stats={[
          { label: "Ticketing", value: "Mobile" },
          { label: "Membership", value: "Mobile" },
          { label: "BioPay", value: "Mobile" },
        ]}
      />

      <section className="grid gap-5 lg:grid-cols-3">
        {[
          {
            icon: Smartphone,
            title: "Supporter identity",
            copy: "Sign in once and keep club membership, profile, and supporter status together on the native mobile surface.",
          },
          {
            icon: ShieldCheck,
            title: "Secure actions",
            copy: "Ticket purchases, community contributions, BioPay flows, and protected fan activity now stay inside the mobile app.",
          },
          {
            icon: Download,
            title: "Rollout ready",
            copy: hasExternalAppUrl
              ? "Your club-specific app destination is configured for this environment."
              : "Configure NEXT_PUBLIC_FAN_APP_URL when store, deep-link, or landing destinations are ready.",
          },
        ].map(({ icon: Icon, title, copy }) => (
          <article
            key={title}
            className="glass-panel rounded-[30px] p-6"
          >
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-club-primary/15 text-club-accent">
              <Icon size={20} />
            </span>
            <h2 className="mt-5 font-display text-3xl font-bold uppercase leading-none text-white">
              {title}
            </h2>
            <p className="mt-4 text-sm leading-7 text-slate-300">{copy}</p>
          </article>
        ))}
      </section>
    </div>
  );
}
