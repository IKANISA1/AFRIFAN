import Link from "next/link";

type DisabledFeatureFallbackProps = {
  title: string;
  description: string;
  ctaHref?: string;
  ctaLabel?: string;
  secondaryHref?: string;
  secondaryLabel?: string;
};

export function DisabledFeatureFallback({
  title,
  description,
  ctaHref = "/",
  ctaLabel = "Return home",
  secondaryHref = "/contact",
  secondaryLabel = "Contact support",
}: DisabledFeatureFallbackProps) {
  return (
    <div className="page-shell section-grid py-16">
      <section className="glass-panel mx-auto max-w-3xl rounded-[34px] p-8 text-center sm:p-10">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Feature availability
        </p>
        <h1 className="mt-4 font-display text-4xl font-bold uppercase text-white sm:text-5xl">
          {title}
        </h1>
        <p className="mx-auto mt-4 max-w-2xl text-base leading-8 text-slate-300">
          {description}
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <Link
            href={ctaHref}
            className="rounded-full bg-club-accent px-5 py-3 text-sm font-semibold text-slate-950 transition hover:brightness-110"
          >
            {ctaLabel}
          </Link>
          <Link
            href={secondaryHref}
            className="rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            {secondaryLabel}
          </Link>
        </div>
      </section>
    </div>
  );
}
