import { ui } from "@/design-system";

interface SectionHeadingProps {
  eyebrow?: string;
  title: string;
  description?: string;
  className?: string;
}

export function SectionHeading({
  eyebrow,
  title,
  description,
  className,
}: SectionHeadingProps) {
  return (
    <div className={className ?? "space-y-4"}>
      {eyebrow ? <p className={ui.kicker}>{eyebrow}</p> : null}
      <div className="flex items-end justify-between gap-4">
        <h2 className="fluid-heading font-display font-bold uppercase leading-none tracking-[-0.055em] text-balance text-white">
          {title}
        </h2>
        <div className="hidden h-px flex-1 rounded-full bg-gradient-to-r from-club-primary/60 via-club-accent/50 to-transparent lg:block" />
      </div>
      {description ? (
        <p className="max-w-3xl text-base leading-7 text-slate-300 sm:text-lg">
          {description}
        </p>
      ) : null}
    </div>
  );
}
