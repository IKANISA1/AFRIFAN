"use client";

import { useEffect, useState } from "react";
import { ArrowRight, Star, Users } from "lucide-react";
import { PageHero } from "@/components/page-hero";
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

    setStatus(joined ? "Leaving chapter..." : "Joining chapter...");

    try {
      if (joined) {
        await activeClient
          .from("fan_club_members")
          .delete()
          .eq("club_id", fanClubId)
          .eq("user_id", activeUser.id);
        setJoinedClubIds((current) => current.filter((id) => id !== fanClubId));
        setStatus("Left the chapter.");
      } else {
        await activeClient.from("fan_club_members").insert({
          club_id: fanClubId,
          user_id: activeUser.id,
          tenant_club_id: rayonClub.numericId,
        });
        setJoinedClubIds((current) => [...current, fanClubId]);
        setStatus("Chapter joined.");
      }
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Action failed.");
    }
  }

  const totalMembers = fanClubs.reduce((sum, club) => sum + club.memberCount, 0);
  const featuredClub = fanClubs[0];

  return (
    <div className="section-grid">
      <PageHero
        eyebrow="Fan clubs"
        title="Find your chapter."
        description="Supporter chapters across Kigali, Rwanda, and the diaspora — connect with fellow fans, organise travel, and build the blue wave together."
        stats={[
          { label: "Chapters", value: fanClubs.length.toString() },
          { label: "Joined", value: joinedClubIds.length.toString() },
          { label: "Total supporters", value: totalMembers.toString() },
        ]}
        actions={
          <a
            href="#chapters"
            className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            Explore chapters <Users size={18} />
          </a>
        }
        media={
          featuredClub ? (
            <article className="rounded-[28px] border border-border-soft bg-black/20 p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-club-accent">
                    Largest chapter
                  </p>
                  <p className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
                    {featuredClub.name}
                  </p>
                  <p className="mt-2 text-sm uppercase tracking-[0.2em] text-slate-300">
                    {featuredClub.region}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-display text-3xl font-bold uppercase text-white">
                    {featuredClub.memberCount}
                  </p>
                  <p className="text-xs uppercase tracking-[0.18em] text-slate-300">
                    members
                  </p>
                </div>
              </div>
              <p className="mt-4 text-sm leading-6 text-slate-300">
                {featuredClub.description}
              </p>
              <div className="mt-4 flex items-center gap-3">
                {featuredClub.rating > 0 ? (
                  <span className="inline-flex items-center gap-1.5 rounded-full border border-club-accent/30 bg-club-accent/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-club-accent">
                    <Star size={12} />
                    {featuredClub.rating.toFixed(1)}
                  </span>
                ) : null}
                <span className="rounded-full border border-border-soft px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300">
                  {featuredClub.eventCount} events
                </span>
              </div>
            </article>
          ) : null
        }
      />

      <div id="chapters" className="grid gap-5 lg:grid-cols-2">
        {fanClubs.map((fanClub) => {
          const joined = joinedClubIds.includes(fanClub.id);

          return (
            <article
              key={fanClub.id}
              className={`glass-panel card-interactive relative overflow-hidden rounded-[30px] p-6 ${
                joined ? "ring-2 ring-club-accent/30" : ""
              }`}
            >
              {joined ? (
                <span className="absolute top-5 right-5 rounded-full border border-emerald-400/30 bg-emerald-500/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-emerald-200">
                  Joined
                </span>
              ) : null}
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
                  <p className="text-xs uppercase tracking-[0.22em] text-slate-300">
                    members
                  </p>
                </div>
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {fanClub.description}
              </p>
              <div className="mt-5 flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={() => toggleMembership(fanClub.id, joined)}
                  className={`rounded-full px-5 py-3 font-semibold transition ${
                    joined
                      ? "border border-border-soft bg-white/5 text-white hover:bg-white/10"
                      : "bg-club-primary text-white hover:bg-club-secondary"
                  }`}
                >
                  {joined ? "Leave chapter" : "Join chapter"}
                </button>
                {fanClub.rating > 0 ? (
                  <span className="inline-flex items-center gap-1.5 text-sm text-slate-300">
                    <Star size={14} className="text-club-accent" />
                    {fanClub.rating.toFixed(1)}
                  </span>
                ) : null}
                <span className="text-sm text-slate-300">
                  {fanClub.eventCount} events
                </span>
              </div>
            </article>
          );
        })}
      </div>
      {status ? (
        <p className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3 text-sm text-slate-200">
          {status}
        </p>
      ) : null}
    </div>
  );
}
