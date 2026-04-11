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
    <div className={className ?? "space-y-3"}>
      {eyebrow ? (
        <p className={ui.kicker}>
          {eyebrow}
        </p>
      ) : null}
      <h2 className="fluid-heading font-display font-bold uppercase leading-none tracking-[-0.05em] text-balance text-white">
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
