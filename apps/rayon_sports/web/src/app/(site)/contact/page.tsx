import Link from "next/link";
import { ExternalLink, MessageCircle, ShieldCheck } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { resolveFanAppHref } from "@/lib/config";
import { getClubProfile, getCmsContent } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.contact.metaTitle(club),
    description: copy.pages.contact.metaDescription(club),
    path: "/contact",
  });
}

const fallbackSupportBlocks = [
  {
    icon: ShieldCheck,
    copy: "Membership, tickets, and orders stay in the fan app for authenticated follow-up.",
  },
  {
    icon: MessageCircle,
    copy: "Public contact stays focused on club communication, media, and general supporter questions.",
  },
];

export default async function ContactPage() {
  const [club, cmsBlocks] = await Promise.all([
    getClubProfile(),
    getCmsContent("contact_support"),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  const socialLinks = [
    { label: "Facebook", href: club.facebookUrl },
    { label: "Instagram", href: club.instagramUrl },
    { label: "X", href: club.xUrl },
    { label: "TikTok", href: club.tiktokUrl },
  ].filter((entry) => entry.href);

  // Use CMS content for support blocks if available
  const supportBlocks =
    cmsBlocks.length > 0
      ? cmsBlocks.map((block, i) => ({
          icon: i === 0 ? ShieldCheck : MessageCircle,
          copy: block.body || block.title,
        }))
      : fallbackSupportBlocks;

  const digitalSupportTitle =
    cmsBlocks.length > 0
      ? cmsBlocks[0]?.subtitle || copy.pages.contact.digitalSupport
      : copy.pages.contact.digitalSupport;

  const digitalSupportDescription =
    cmsBlocks.length > 0
      ? cmsBlocks[0]?.rationale ||
        copy.pages.contact.digitalSupportDescription
      : copy.pages.contact.digitalSupportDescription;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.contact.eyebrow}
        title={copy.pages.contact.title}
        description={copy.pages.contact.description}
        actions={
          <>
            <Link
              href={resolveFanAppHref()}
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.openFanApp}
            </Link>
            <Link
              href="/membership"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.pages.contact.membershipSupport}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.languages, value: club.supportedLanguages.length.toString() },
          { label: copy.common.channels, value: (socialLinks.length + 1).toString() },
          { label: copy.common.club, value: club.shortName },
        ]}
      />

      <div className="grid gap-5 lg:grid-cols-[1fr_1fr]">
        <article className="glass-panel rounded-[30px] p-6">
          <p className="font-display text-4xl font-bold uppercase leading-none text-white">
            {copy.pages.contact.contactCardTitle}
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
            {digitalSupportTitle}
          </p>
          <p className="mt-4 text-sm leading-7 text-slate-300">
            {digitalSupportDescription}
          </p>
          <div className="mt-5 grid gap-3">
            {supportBlocks.map(({ icon: Icon, copy }) => (
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
          {copy.pages.contact.socialChannels}
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
            {copy.common.clubNewsroom}
          </Link>
        </div>
      </section>
    </div>
  );
}
