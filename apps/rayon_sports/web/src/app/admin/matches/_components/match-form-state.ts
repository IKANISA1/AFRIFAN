import { fallbackClubProfile } from "@/lib/content";
import type { AdminMatchItem } from "@/lib/types";

export const emptyMatchForm = {
  id: "",
  expectedUpdatedAt: "",
  homeTeam: fallbackClubProfile.shortName,
  awayTeam: "",
  competition: fallbackClubProfile.league,
  venue: "",
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

export function matchToFormState(match: AdminMatchItem): MatchFormState {
  return {
    id: match.id,
    expectedUpdatedAt: match.updatedAt,
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
