"use client";

import { useEffect, useState } from "react";

interface MatchCountdownProps {
  matchDate: string;
  className?: string;
}

/**
 * Live-ticking countdown for upcoming matches.
 * Displays "Xd Xh Xm Xs" format. Falls back to "Started" or "—" when elapsed.
 */
export function MatchCountdown({ matchDate, className }: MatchCountdownProps) {
  const [timeLeft, setTimeLeft] = useState(() => getTimeLeft(matchDate));

  useEffect(() => {
    const interval = setInterval(() => {
      setTimeLeft(getTimeLeft(matchDate));
    }, 1000);
    return () => clearInterval(interval);
  }, [matchDate]);

  if (timeLeft.total <= 0) {
    return (
      <span className={className ?? "text-[11px] uppercase tracking-[0.22em] text-slate-400"}>
        Started
      </span>
    );
  }

  return (
    <span className={className ?? "font-score text-sm font-bold uppercase tracking-wide text-white"}>
      {timeLeft.days > 0 ? `${timeLeft.days}d ` : ""}
      {timeLeft.hours > 0 || timeLeft.days > 0 ? `${timeLeft.hours}h ` : ""}
      {timeLeft.minutes}m{" "}
      {timeLeft.days === 0 ? `${timeLeft.seconds}s` : ""}
    </span>
  );
}

function getTimeLeft(dateString: string) {
  const target = new Date(dateString).getTime();
  const now = Date.now();
  const total = target - now;

  if (total <= 0) {
    return { total: 0, days: 0, hours: 0, minutes: 0, seconds: 0 };
  }

  return {
    total,
    days: Math.floor(total / (1000 * 60 * 60 * 24)),
    hours: Math.floor((total / (1000 * 60 * 60)) % 24),
    minutes: Math.floor((total / (1000 * 60)) % 60),
    seconds: Math.floor((total / 1000) % 60),
  };
}
