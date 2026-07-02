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
  return (
    <TvDisplayClient
      initialState={createDemoTvSessionState()}
      sessionId={sessionId}
    />
  );
}
