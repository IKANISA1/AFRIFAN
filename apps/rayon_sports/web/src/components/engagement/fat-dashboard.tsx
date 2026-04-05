"use client";

import { cn } from "@/lib/utils";

interface FatBadge {
  id: string;
  name: string;
  description: string;
  icon: string;
  earned: boolean;
  earnedAt?: string;
  fatReward: number;
}

interface FatLevel {
  level: number;
  title: string;
  minFat: number;
  maxFat: number;
}

interface FatDashboardProps {
  totalFat: number;
  currentLevel: FatLevel;
  nextLevel: FatLevel | null;
  badges: FatBadge[];
  recentActivity: { label: string; fat: number; date: string }[];
}

const FAT_LEVELS: FatLevel[] = [
  { level: 1, title: "Newcomer", minFat: 0, maxFat: 99 },
  { level: 2, title: "Supporter", minFat: 100, maxFat: 299 },
  { level: 3, title: "Faithful", minFat: 300, maxFat: 599 },
  { level: 4, title: "Devoted", minFat: 600, maxFat: 999 },
  { level: 5, title: "Ultras", minFat: 1000, maxFat: 1999 },
  { level: 6, title: "Legend", minFat: 2000, maxFat: 4999 },
  { level: 7, title: "Gikundiro Icon", minFat: 5000, maxFat: Infinity },
];

export function getLevelForFat(totalFat: number): { current: FatLevel; next: FatLevel | null } {
  let current = FAT_LEVELS[0];
  for (const level of FAT_LEVELS) {
    if (totalFat >= level.minFat) current = level;
  }
  const nextIdx = FAT_LEVELS.indexOf(current) + 1;
  const next = nextIdx < FAT_LEVELS.length ? FAT_LEVELS[nextIdx] : null;
  return { current, next };
}

/**
 * FAT level progress ring — circular SVG showing current level and progress to next.
 */
function FatProgressRing({
  current,
  next,
  totalFat,
}: {
  current: FatLevel;
  next: FatLevel | null;
  totalFat: number;
}) {
  const progress = next
    ? Math.min(((totalFat - current.minFat) / (next.minFat - current.minFat)) * 100, 100)
    : 100;
  const circumference = 2 * Math.PI * 52;
  const strokeDashoffset = circumference - (progress / 100) * circumference;

  return (
    <div className="relative flex h-36 w-36 items-center justify-center sm:h-40 sm:w-40">
      <svg className="absolute inset-0 -rotate-90" viewBox="0 0 120 120">
        {/* Background ring */}
        <circle
          cx="60"
          cy="60"
          r="52"
          fill="none"
          stroke="currentColor"
          className="text-white/8"
          strokeWidth="6"
        />
        {/* Progress ring */}
        <circle
          cx="60"
          cy="60"
          r="52"
          fill="none"
          stroke="url(#fatGradient)"
          strokeWidth="6"
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          className="transition-[stroke-dashoffset] duration-1000 ease-out"
        />
        <defs>
          <linearGradient id="fatGradient" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="var(--club-accent)" />
            <stop offset="100%" stopColor="var(--club-primary)" />
          </linearGradient>
        </defs>
      </svg>
      <div className="text-center">
        <p className="font-score text-3xl font-bold text-white sm:text-4xl">
          {totalFat.toLocaleString()}
        </p>
        <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400">FAT</p>
      </div>
    </div>
  );
}

/**
 * Badge chip — shows earned/locked state with icon.
 */
function BadgeChip({ badge }: { badge: FatBadge }) {
  return (
    <div
      className={cn(
        "flex flex-col items-center gap-2 rounded-2xl border p-3 text-center transition",
        badge.earned
          ? "border-club-accent/30 bg-club-accent/8"
          : "border-white/6 bg-white/3 opacity-40",
      )}
    >
      <span className="text-2xl">{badge.icon}</span>
      <p className="text-[10px] font-semibold text-white leading-tight">
        {badge.name}
      </p>
      <p className="text-[8px] uppercase tracking-[0.18em] text-slate-400">
        +{badge.fatReward} FAT
      </p>
    </div>
  );
}

/**
 * Full FAT dashboard — level ring, badge grid, activity log.
 */
export function FatDashboard({
  totalFat,
  currentLevel,
  nextLevel,
  badges,
  recentActivity,
}: FatDashboardProps) {
  const earnedCount = badges.filter((b) => b.earned).length;

  return (
    <div className="grid gap-6">
      {/* Level overview */}
      <div className="glass-panel-elevated rounded-[34px] p-5 sm:p-6">
        <div className="flex flex-col items-center gap-5 sm:flex-row sm:items-start sm:gap-8">
          <FatProgressRing current={currentLevel} next={nextLevel} totalFat={totalFat} />
          <div className="flex-1 text-center sm:text-left">
            <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
              Fan Achievement Tokens
            </p>
            <h2 className="mt-2 font-display text-3xl font-bold uppercase leading-none text-white sm:text-4xl">
              Level {currentLevel.level}: {currentLevel.title}
            </h2>
            {nextLevel && (
              <p className="mt-3 text-sm leading-7 text-slate-300">
                {nextLevel.minFat - totalFat} FAT to reach{" "}
                <span className="font-semibold text-club-accent">
                  Level {nextLevel.level}: {nextLevel.title}
                </span>
              </p>
            )}
            <div className="mt-4 flex flex-wrap justify-center gap-2 sm:justify-start">
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.2em] text-slate-200">
                {earnedCount}/{badges.length} badges
              </span>
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.2em] text-slate-200">
                {totalFat.toLocaleString()} total FAT
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Badges grid */}
      <div className="glass-panel rounded-[34px] p-5 sm:p-6">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
          Achievements
        </p>
        <p className="mt-2 font-display text-2xl font-bold uppercase leading-none text-white sm:text-3xl">
          {earnedCount} of {badges.length} earned
        </p>
        <div className="mt-5 grid grid-cols-3 gap-2 sm:grid-cols-4 lg:grid-cols-6">
          {badges.map((badge) => (
            <BadgeChip key={badge.id} badge={badge} />
          ))}
        </div>
      </div>

      {/* Recent FAT activity */}
      {recentActivity.length > 0 && (
        <div className="glass-panel rounded-[34px] p-5 sm:p-6">
          <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
            Recent activity
          </p>
          <p className="mt-2 font-display text-2xl font-bold uppercase leading-none text-white sm:text-3xl">
            How you earned it
          </p>
          <div className="mt-5 grid gap-2">
            {recentActivity.map((activity, i) => (
              <div
                key={i}
                className="flex items-center justify-between gap-3 rounded-2xl border border-border-soft bg-white/4 px-4 py-3"
              >
                <div className="min-w-0">
                  <p className="text-sm font-medium text-white">{activity.label}</p>
                  <p className="text-[10px] text-slate-400">{activity.date}</p>
                </div>
                <span className="shrink-0 rounded-full bg-club-accent/15 px-3 py-1 text-[11px] font-bold tabular-nums text-club-accent">
                  +{activity.fat} FAT
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
