import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { BackButton } from "@/components/back-button";
import { AnimatedWatermark } from "@/components/animated-watermark";
import { ui } from "@/design-system";

interface PageHeroStat {
  label: string;
  value: string;
}

interface PageHeroProps {
  eyebrow: string;
  title: string;
  description: string;
  actions?: ReactNode;
  media?: ReactNode;
  stats?: PageHeroStat[];
  /** Show a back button (for inner pages in standalone PWA mode) */
  showBack?: boolean;
  className?: string;
}

export function PageHero({
  eyebrow,
  title,
  description,
  actions,
  media,
  stats = [],
  showBack = false,
  className,
}: PageHeroProps) {
  return (
    <section
      className={cn(
        `${ui.panelElevated} relative overflow-hidden rounded-[38px] p-6 sm:p-8`,
        className,
      )}
    >
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(181,155,255,0.24),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(239,231,255,0.14),transparent_36%)]" />
      <p className={`${ui.monolithBleed} pointer-events-none absolute left-5 top-4 sm:left-8 sm:top-6`}>
        {title}
      </p>
      <AnimatedWatermark className="left-1/2 top-1/2 h-[150%] w-[150%] -translate-x-1/2 -translate-y-1/2" />
      <div className="relative grid gap-8 lg:grid-cols-[1.2fr_0.8fr] lg:items-end">
        <div className="space-y-5">
          {showBack ? <BackButton className="mb-3" /> : null}
          <p className={ui.kicker}>
            {eyebrow}
          </p>
          <h1 className="fluid-display max-w-4xl font-display font-bold uppercase tracking-[-0.05em] text-balance">
            {title}
          </h1>
          <p className="max-w-3xl text-base leading-8 text-slate-200 sm:text-lg">
            {description}
          </p>
          {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
          {stats.length > 0 ? (
            <div className="grid gap-3 sm:grid-cols-3">
              {stats.map((stat) => (
                <article
                  key={stat.label}
                  className={ui.statCard}
                >
                  <p className={ui.meta}>
                    {stat.label}
                  </p>
                  <p className="mt-3 font-score text-3xl font-bold uppercase tracking-[-0.04em] text-white">
                    {stat.value}
                  </p>
                </article>
              ))}
            </div>
          ) : null}
        </div>
        {media ? <div className="relative">{media}</div> : null}
      </div>
    </section>
  );
}
