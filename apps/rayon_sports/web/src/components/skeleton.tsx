import { cn } from "@/lib/utils";
import { ui } from "@/ui-kit";

export function Skeleton({
  className,
}: {
  className?: string;
}) {
  return <div className={cn("skeleton", className)} aria-hidden="true" />;
}

export function SkeletonCard() {
  return (
    <div className={`${ui.panel} rounded-[28px] p-5`}>
      <Skeleton className="h-40 w-full rounded-[22px]" />
      <div className="mt-5 space-y-3">
        <Skeleton className="skeleton-text h-3 w-24" />
        <Skeleton className="skeleton-text h-9 w-4/5" />
        <Skeleton className="skeleton-text h-4 w-full" />
        <Skeleton className="skeleton-text h-4 w-3/4" />
      </div>
    </div>
  );
}

export function SkeletonHero() {
  return (
    <div className={`${ui.panelElevated} overflow-hidden rounded-[38px] p-6`}>
      <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
        <div className="space-y-4">
          <Skeleton className="skeleton-text h-3 w-28" />
          <Skeleton className="skeleton-text h-16 w-full" />
          <Skeleton className="skeleton-text h-5 w-4/5" />
          <div className="flex gap-3">
            <Skeleton className="h-11 w-36 rounded-full" />
            <Skeleton className="h-11 w-36 rounded-full" />
          </div>
        </div>
        <Skeleton className="h-72 w-full rounded-[30px]" />
      </div>
    </div>
  );
}

export function SkeletonTable() {
  return (
    <div className={`${ui.panel} rounded-[30px] p-5`}>
      <div className="space-y-3">
        {Array.from({ length: 6 }).map((_, index) => (
          <Skeleton
            key={index}
            className="h-11 w-full rounded-2xl"
          />
        ))}
      </div>
    </div>
  );
}
