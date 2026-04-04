import type { AdminMatchItem } from "@/lib/types";

export const emptyMatchForm = {
  id: "",
  homeTeam: "Rayon Sports",
  awayTeam: "",
  competition: "Rwanda Premier League",
  venue: "Kigali Pele Stadium",
  matchDate: new Date().toISOString().slice(0, 10),
  kickoffTime: "18:00",
  isOnSale: false,
  generalPrice: "3000",
  vipPrice: "10000",
  capacity: "18000",
  imageUrl: "",
  matchStatus: "scheduled",
  homeScore: "0",
  awayScore: "0",
  liveMinute: "",
  matchSummary: "",
  isFeatured: false,
};

export type MatchFormState = typeof emptyMatchForm;

export const statusColors: Record<string, string> = {
  live: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  halftime: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  fulltime: "bg-slate-500/15 text-slate-300 border-slate-500/30",
  scheduled: "bg-club-accent/10 text-club-accent border-club-accent/30",
  postponed: "bg-rose-500/15 text-rose-300 border-rose-500/30",
  cancelled: "bg-rose-500/15 text-rose-300 border-rose-500/30",
};

export function matchToFormState(match: AdminMatchItem): MatchFormState {
  return {
    id: match.id,
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam,
    competition: match.competition,
    venue: match.venue,
    matchDate: match.matchDate.slice(0, 10),
    kickoffTime: (match.kickoffTime ?? "18:00:00").slice(0, 5),
    isOnSale: match.isOnSale,
    generalPrice: String(match.generalPrice),
    vipPrice: String(match.vipPrice),
    capacity: String(match.capacity),
    imageUrl: match.imageUrl ?? "",
    matchStatus: match.matchStatus,
    homeScore: String(match.homeScore),
    awayScore: String(match.awayScore),
    liveMinute: match.liveMinute == null ? "" : String(match.liveMinute),
    matchSummary: match.matchSummary ?? "",
    isFeatured: match.isFeatured,
  };
}
