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
      {eyebrow ? (
        <p className="text-[10px] font-bold uppercase tracking-[0.4em] text-[var(--club-accent)]">
          {eyebrow}
        </p>
      ) : null}
      <h2 className="font-display text-4xl font-black uppercase italic leading-[0.9] tracking-tighter text-white lg:text-6xl text-balance">
        {title}
      </h2>
      {description ? (
        <p className="max-w-2xl text-base font-medium leading-relaxed text-white/60">
          {description}
        </p>
      ) : null}
    </div>
  );
}
