"use client";

import { StoriesCarousel } from "@/components/engagement/stories-carousel";
import type { Story } from "@/components/engagement/stories-carousel";

/**
 * Demo stories — these will be replaced with CMS/Supabase content in production.
 * Each story represents a club content category (matchday, training, fans, shop).
 */
const DEMO_STORIES: Story[] = [
  {
    id: "matchday-Rayon Sports",
    title: "Matchday",
    thumbnail: "/media/stadium-hero.jpg",
    viewed: false,
    author: "Club Media",
    publishedAt: "2h ago",
    slides: [
      {
        id: "md-1",
        type: "image",
        src: "/media/stadium-hero.jpg",
        durationMs: 5000,
        eyebrow: "Match preview",
        caption: "A title-race fixture with the whole supporter base watching",
        cta: { label: "Get tickets", href: "/tickets" },
      },
      {
        id: "md-2",
        type: "image",
        src: "/media/stadium-hero-2.jpg",
        durationMs: 5000,
        eyebrow: "Kickoff countdown",
        caption: "Gates open early for supporters, families, and matchday hospitality",
      },
    ],
  },
  {
    id: "training-week",
    title: "Training",
    thumbnail: "/media/stadium-hero-2.jpg",
    viewed: false,
    author: "Performance Desk",
    publishedAt: "5h ago",
    slides: [
      {
        id: "tw-1",
        type: "image",
        src: "/media/stadium-hero-2.jpg",
        durationMs: 5000,
        eyebrow: "Behind the scenes",
        caption: "Midweek intensity session ahead of derby day",
      },
      {
        id: "tw-2",
        type: "image",
        src: "/media/stadium-hero.jpg",
        durationMs: 5000,
        eyebrow: "Recovery",
        caption: "Squad rotation keeping the group fresh",
      },
    ],
  },
  {
    id: "fan-travel",
    title: "Away Day",
    thumbnail: "/media/stadium-hero.jpg",
    viewed: true,
    author: "Fan Liaison",
    publishedAt: "1d ago",
    slides: [
      {
        id: "ft-1",
        type: "image",
        src: "/media/stadium-hero.jpg",
        durationMs: 5000,
        eyebrow: "Travel update",
        caption: "Supporter travel plans are live for the next away day",
        cta: { label: "Join travel Group", href: "/Groups" },
      },
    ],
  },
  {
    id: "shop-drop",
    title: "New Drop",
    thumbnail: "/media/stadium-hero-2.jpg",
    viewed: true,
    author: "Retail Desk",
    publishedAt: "2d ago",
    slides: [
      {
        id: "sd-1",
        type: "image",
        src: "/media/stadium-hero-2.jpg",
        durationMs: 5000,
        eyebrow: "Shop",
        caption: "2026 Home Replica — now available online",
        cta: { label: "Shop now", href: "/shop" },
      },
    ],
  },
  {
    id: "community-impact",
    title: "Community",
    thumbnail: "/media/stadium-hero.jpg",
    viewed: true,
    author: "CSR Team",
    publishedAt: "3d ago",
    slides: [
      {
        id: "ci-1",
        type: "image",
        src: "/media/stadium-hero.jpg",
        durationMs: 6000,
        eyebrow: "Community",
        caption: "The latest community activation brought families into the club orbit",
      },
    ],
  },
];

export function StoriesBlock() {
  return (
    <section className="page-shell">
      <StoriesCarousel stories={DEMO_STORIES} />
    </section>
  );
}
