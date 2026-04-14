import Link from "next/link";
import { ArrowRight, Flag } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { clubHistoryMoments } from "@/lib/content";
import { getClubProfile, getCmsContent } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.history.metaTitle(club),
    description: copy.pages.history.metaDescription(club),
    path: "/history",
  });
}

export default async function HistoryPage() {
  const [club, cmsItems] = await Promise.all([
    getClubProfile(),
    getCmsContent("club_history"),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  // Use DB content if available, otherwise fall back to hardcoded
  const moments =
    cmsItems.length > 0
      ? cmsItems.map((item) => ({ title: item.title, body: item.body }))
      : clubHistoryMoments;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.history.eyebrow}
        title={copy.pages.history.title(club)}
        description={copy.pages.history.description(club)}
        actions={
          <>
            <Link
              href="/news"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.clubNewsroom}
            </Link>
            <Link
              href="/fan-clubs"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.supporterChapters}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.moments, value: moments.length.toString() },
          { label: copy.common.identity, value: club.nickname || club.shortName },
          { label: copy.common.surface, value: copy.pages.history.surfaceValue },
        ]}
      />

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        {moments.map((moment, index) => (
          <article
            key={moment.title}
            className="glass-panel card-interactive rounded-[30px] p-6"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-accent/15 text-club-accent">
                <Flag size={18} />
              </span>
              <span className="font-mono text-xs uppercase tracking-[0.24em] text-slate-300">
                {copy.pages.history.chapter} {index + 1}
              </span>
            </div>
            <p className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
              {moment.title}
            </p>
            <p className="mt-4 text-sm leading-7 text-slate-300">
              {moment.body}
            </p>
          </article>
        ))}
      </section>

      <section className="glass-panel rounded-[34px] p-6">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          {copy.pages.history.clubIdentity}
        </p>
        <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
          {copy.pages.history.historyAcrossClub}
        </h2>
        <p className="mt-4 max-w-3xl text-sm leading-8 text-slate-300 sm:text-base">
          {copy.pages.history.identityParagraph}
        </p>
        <Link
          href="/membership"
          className="mt-6 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          {copy.pages.history.seeMembershipIdentity} <ArrowRight size={18} />
        </Link>
      </section>
    </div>
  );
}
