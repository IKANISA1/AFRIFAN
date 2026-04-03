import Link from "next/link";
import { ArrowRight, Flag } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { clubHistoryMoments } from "@/lib/content";

export default function HistoryPage() {
  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="History"
        title="The beloved is a story, not just a section label."
        description="History gives the public site emotional gravity. It should explain what Gikundiro means, why the club identity matters, and how supporter culture carries across every digital surface."
        actions={
          <>
            <Link
              href="/news"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Club newsroom
            </Link>
            <Link
              href="/fan-clubs"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Supporter chapters
            </Link>
          </>
        }
        stats={[
          { label: "Moments", value: clubHistoryMoments.length.toString() },
          { label: "Identity", value: "Beloved" },
          { label: "Surface", value: "Club-first" },
        ]}
      />

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        {clubHistoryMoments.map((moment, index) => (
          <article
            key={moment.title}
            className="glass-panel card-interactive rounded-[30px] border border-border-soft p-6"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-accent/15 text-club-accent">
                <Flag size={18} />
              </span>
              <span className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">
                Chapter {index + 1}
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
          Storytelling principle
        </p>
        <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
          History should feed the whole experience
        </h2>
        <p className="mt-4 max-w-3xl text-sm leading-8 text-slate-300 sm:text-base">
          The strongest club websites do not isolate history on a dead page. They
          let history influence matchday copy, membership identity, supporter
          campaigns, and how the club presents itself visually. This route becomes
          the source material for that wider brand system.
        </p>
        <Link
          href="/membership"
          className="mt-6 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          See membership identity <ArrowRight size={18} />
        </Link>
      </section>
    </div>
  );
}
