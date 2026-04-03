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
    <div className={className ?? "space-y-3"}>
      {eyebrow ? (
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          {eyebrow}
        </p>
      ) : null}
      <h2 className="fluid-heading font-display font-bold uppercase leading-none text-balance text-white">
        {title}
      </h2>
      {description ? (
        <p className="max-w-3xl text-base leading-7 text-slate-300 sm:text-lg">
          {description}
        </p>
      ) : null}
    </div>
  );
}
