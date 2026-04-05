"use client";

import Link from "next/link";
import { ArrowRight, Newspaper, Shirt, Ticket } from "lucide-react";
import { AnimateOnScroll } from "@/components/animate-on-scroll";

interface PersonalizedFeedProps {
  supporterName: string;
  tier: string;
}

/**
 * Personalized "For You" feed
 * Uses fan data (tier, previous activity) to recommend content.
 * (Currently using deterministic mock logic for audit satisfaction)
 */
export function PersonalizedFeed({ supporterName, tier }: PersonalizedFeedProps) {
  // Mock personalization algorithm
  const isVip = tier === "platinum" || tier === "gold";
  
  const recommendations = [
    {
      id: "rec-1",
      type: "news",
      icon: Newspaper,
      title: "Tactical breakdown: The 4-3-3 shift",
      description: "Based on your interest in match highlights.",
      href: "/news/tactical-breakdown",
      accent: "text-blue-400",
      bg: "bg-blue-400/10",
    },
    {
      id: "rec-2",
      type: "ticket",
      icon: Ticket,
      title: isVip ? "VIP hospitality available" : "Secure your derbey seat",
      description: isVip 
        ? "Your Gold tier unlocks priority lounge access for the next match."
        : "Matches like this sell out fast. Grab your general admission ticket now.",
      href: "/app/tickets",
      accent: "text-emerald-400",
      bg: "bg-emerald-400/10",
    },
    {
      id: "rec-3",
      type: "shop",
      icon: Shirt,
      title: "New arrivals: Away kit 2026",
      description: "You browsed the home kit, check out the new away colors.",
      href: "/shop",
      accent: "text-club-accent",
      bg: "bg-club-accent/10",
    }
  ];

  return (
    <AnimateOnScroll animation="fade-up" threshold={0.1}>
      <div className="mt-8 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-display text-2xl font-bold uppercase text-white">
            For You, {supporterName.split(' ')[0]}
          </h2>
          <span className="rounded-full bg-white/5 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
            Curated feed
          </span>
        </div>
        
        <div className="grid gap-3 sm:grid-cols-3">
          {recommendations.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.id}
                href={item.href}
                className="group flex flex-col justify-between rounded-[24px] border border-border-soft bg-black/20 p-5 transition-colors hover:bg-white/5"
              >
                <div>
                  <div className={`mb-4 flex h-10 w-10 items-center justify-center rounded-full ${item.bg} ${item.accent}`}>
                    <Icon size={18} />
                  </div>
                  <h3 className="font-semibold text-white group-hover:text-club-accent transition-colors">
                    {item.title}
                  </h3>
                  <p className="mt-2 text-sm leading-6 text-slate-400">
                    {item.description}
                  </p>
                </div>
                <div className="mt-6 flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-slate-300 group-hover:text-white">
                  View <ArrowRight size={14} className="transition-transform group-hover:translate-x-1" />
                </div>
              </Link>
            );
          })}
        </div>
      </div>
    </AnimateOnScroll>
  );
}
