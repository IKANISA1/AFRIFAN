"use client";

import { useEffect, useState } from "react";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackFanClubs } from "@/lib/content";
import { rayonClub } from "@/lib/config";
import type { FanClubItem } from "@/lib/types";

export default function FanClubsPortalPage() {
  const { client, user } = useFanPortal();
  const [fanClubs, setFanClubs] = useState<FanClubItem[]>(fallbackFanClubs);
  const [joinedClubIds, setJoinedClubIds] = useState<string[]>([]);
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadData() {
      const [clubsRows, membershipsRows] = await Promise.all([
        activeClient
          .from("fan_clubs")
          .select("*")
          .eq("club_id", rayonClub.numericId)
          .order("member_count", { ascending: false }),
        activeClient
          .from("fan_club_members")
          .select("club_id")
          .eq("user_id", activeUser.id),
      ]);

      if (clubsRows.data && clubsRows.data.length > 0) {
        setFanClubs(
          clubsRows.data.map((row) => ({
            id: String(row.id),
            name: String(row.name),
            region: String(row.region ?? "Official"),
            description: String(row.description ?? "Supporter chapter"),
            memberCount: Number(row.member_count ?? 0),
            eventCount: Number(row.event_count ?? 0),
            rating: Number(row.rating ?? 0),
            bannerImageUrl: row.banner_image_url ? String(row.banner_image_url) : null,
          })),
        );
      }

      if (membershipsRows.data) {
        setJoinedClubIds(
          membershipsRows.data.map((row) => String(row.club_id)).filter(Boolean),
        );
      }
    }

    loadData().catch(() => {});
  }, [client, user]);

  async function toggleMembership(fanClubId: string, joined: boolean) {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    setStatus(joined ? "Leaving fan club..." : "Joining fan club...");

    try {
      if (joined) {
        await activeClient
          .from("fan_club_members")
          .delete()
          .eq("club_id", fanClubId)
          .eq("user_id", activeUser.id);
        setJoinedClubIds((current) => current.filter((id) => id !== fanClubId));
        setStatus("Fan club membership removed.");
      } else {
        await activeClient.from("fan_club_members").insert({
          club_id: fanClubId,
          user_id: activeUser.id,
          tenant_club_id: rayonClub.numericId,
        });
        setJoinedClubIds((current) => [...current, fanClubId]);
        setStatus("Fan club joined.");
      }
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Action failed.");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Fan clubs"
        title="Join supporter chapters from the same web session."
        description="This page focuses on chapter discovery and membership. Administrative chapter creation remains a separate club-admin concern."
      />
      <div className="grid gap-5 lg:grid-cols-2">
        {fanClubs.map((fanClub) => {
          const joined = joinedClubIds.includes(fanClub.id);

          return (
            <article key={fanClub.id} className="glass-panel rounded-[30px] p-6">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-display text-4xl font-bold uppercase leading-none">
                    {fanClub.name}
                  </p>
                  <p className="mt-2 text-sm uppercase tracking-[0.24em] text-club-accent">
                    {fanClub.region}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-display text-3xl font-bold uppercase">
                    {fanClub.memberCount}
                  </p>
                  <p className="text-xs uppercase tracking-[0.22em] text-slate-400">
                    members
                  </p>
                </div>
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {fanClub.description}
              </p>
              <button
                type="button"
                onClick={() => toggleMembership(fanClub.id, joined)}
                className="mt-6 rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
              >
                {joined ? "Leave chapter" : "Join chapter"}
              </button>
            </article>
          );
        })}
      </div>
      {status ? <p className="text-sm text-slate-300">{status}</p> : null}
    </div>
  );
}
