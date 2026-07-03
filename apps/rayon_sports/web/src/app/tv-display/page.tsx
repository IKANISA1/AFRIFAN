import type { Metadata } from "next";
import { createDemoTvSessionState, resolveTvSessionId } from "@/lib/game-runtime";
import { TvDisplayClient } from "./tv-display-client";

export const metadata: Metadata = {
  title: "Matchday quiz display",
  description:
    "Large-screen AfriClub quiz display for venue-led supporter games.",
  robots: {
    index: false,
    follow: false,
  },
};

type TvDisplayPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function TvDisplayPage({
  searchParams,
}: TvDisplayPageProps) {
  const params = await searchParams;
  const sessionId = resolveTvSessionId(params);
  const venueCode = typeof params.venue_code === "string" ? params.venue_code : null;
  const venueName = typeof params.venue_name === "string" ? params.venue_name : null;
  const venueCodeExpiresAt =
    typeof params.expires_at === "string" ? params.expires_at : null;
  const venueRewardLabel = typeof params.fet === "string" ? params.fet : null;
  return (
    <TvDisplayClient
      initialState={createDemoTvSessionState()}
      sessionId={sessionId}
      venueCheckin={
        venueCode
          ? {
              code: venueCode,
              venueName,
              expiresAt: venueCodeExpiresAt,
              rewardLabel: venueRewardLabel,
            }
          : null
      }
    />
  );
}
