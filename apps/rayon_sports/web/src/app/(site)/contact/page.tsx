import Link from "next/link";
import { ExternalLink, MessageCircle, ShieldCheck } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getClubProfile } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";

export const metadata = buildPageMetadata({
  title: "Rayon Sports contact",
  description:
    "Official Rayon Sports contact details, digital support routes, and club social channels.",
  path: "/contact",
});

export default async function ContactPage() {
  const club = await getClubProfile();
  const socialLinks = [
    { label: "Facebook", href: club.facebookUrl },
    { label: "Instagram", href: club.instagramUrl },
    { label: "X", href: club.xUrl },
    { label: "TikTok", href: club.tiktokUrl },
  ].filter((entry) => entry.href);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Contact"
        title="Official club contact and digital support in one place."
        description="Find official club channels, supporter help, and the right path into membership, ticketing, and portal support."
        actions={
          <>
            <Link
              href="/app"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Open fan portal
            </Link>
            <Link
              href="/membership"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Membership support
            </Link>
          </>
        }
        stats={[
          { label: "Languages", value: club.supportedLanguages.length.toString() },
          { label: "Channels", value: (socialLinks.length + 1).toString() },
          { label: "Club", value: club.shortName },
        ]}
      />

      <div className="grid gap-5 lg:grid-cols-[1fr_1fr]">
        <article className="glass-panel rounded-[30px] p-6">
          <p className="font-display text-4xl font-bold uppercase leading-none text-white">
            Club contact
          </p>
          <p className="mt-4 text-sm leading-7 text-slate-300">
            {club.officialContact}
          </p>
          <div className="mt-5 flex flex-wrap gap-2">
            {club.supportedLanguages.map((language) => (
              <span
                key={language}
                className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
              >
                {language.toUpperCase()}
              </span>
            ))}
          </div>
        </article>
        <article className="glass-panel rounded-[30px] p-6">
          <p className="font-display text-4xl font-bold uppercase leading-none text-white">
            Digital support
          </p>
          <p className="mt-4 text-sm leading-7 text-slate-300">
            Use the fan portal for profile, membership, shop, and ticketing
            requests. Public club updates and campaign announcements remain on
            the public site.
          </p>
          <div className="mt-5 grid gap-3">
            {[
              { icon: ShieldCheck, copy: "Membership, tickets, and orders stay in the portal for authenticated follow-up." },
              { icon: MessageCircle, copy: "Public contact stays focused on club communication, media, and general supporter questions." },
            ].map(({ icon: Icon, copy }) => (
              <div
                key={copy}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4"
              >
                <div className="flex items-start gap-3">
                  <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-primary/16 text-club-accent">
                    <Icon size={18} />
                  </span>
                  <p className="text-sm leading-7 text-slate-300">{copy}</p>
                </div>
              </div>
            ))}
          </div>
        </article>
      </div>

      <section className="glass-panel rounded-[34px] p-6">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Social channels
        </p>
        <div className="mt-5 flex flex-wrap gap-3">
          {socialLinks.map((entry) => (
            <a
              key={entry.label}
              href={entry.href ?? "#"}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {entry.label} <ExternalLink size={15} />
            </a>
          ))}
          <Link
            href="/news"
            className="inline-flex items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Club newsroom
          </Link>
        </div>
      </section>
    </div>
  );
}
