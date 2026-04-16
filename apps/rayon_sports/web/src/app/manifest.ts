import type { MetadataRoute } from "next";
import { headers } from "next/headers";
import { resolveFanAppHref } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import {
  isAdminHostname,
  resolveRoutingHostname,
} from "@/lib/host-routing";

const sharedIcons: MetadataRoute.Manifest["icons"] = [
  { src: "/icons/icon-72x72.png", sizes: "72x72", type: "image/png" },
  { src: "/icons/icon-96x96.png", sizes: "96x96", type: "image/png" },
  { src: "/icons/icon-128x128.png", sizes: "128x128", type: "image/png" },
  { src: "/icons/icon-144x144.png", sizes: "144x144", type: "image/png" },
  { src: "/icons/icon-152x152.png", sizes: "152x152", type: "image/png" },
  { src: "/icons/icon-256x256.png", sizes: "256x256", type: "image/png" },
  { src: "/icons/icon-192x192.png", sizes: "192x192", type: "image/png", purpose: "any" },
  { src: "/icons/icon-384x384.png", sizes: "384x384", type: "image/png" },
  { src: "/icons/icon-512x512.png", sizes: "512x512", type: "image/png", purpose: "any" },
  {
    src: "/icons/icon-512x512.png",
    sizes: "512x512",
    type: "image/png",
    purpose: "maskable",
  },
  { src: "/icons/icon-1024x1024.png", sizes: "1024x1024", type: "image/png" },
];

export default async function manifest(): Promise<MetadataRoute.Manifest> {
  const headersList = await headers();
  const host = resolveRoutingHostname(
    headersList.get("x-forwarded-host"),
    headersList.get("host"),
  );
  const club = await getClubProfile();

  if (isAdminHostname(host)) {
    return {
      id: "/admin",
      name: "AfriClub Admin",
      short_name: "AfriAdmin",
      description:
        "Centralized club admin workspace for operations, publishing, supporter management, and white-label configuration.",
      start_url: "/admin",
      scope: "/admin",
      display: "standalone",
      display_override: ["window-controls-overlay", "standalone"],
      orientation: "portrait",
      background_color: "#07162f",
      theme_color: "#0038a8",
      shortcuts: [
        { name: "Dashboard", short_name: "Dashboard", url: "/admin" },
        { name: "Matches", short_name: "Matches", url: "/admin/matches" },
        {
          name: "Notifications",
          short_name: "Notify",
          url: "/admin/notifications",
        },
        { name: "CMS", short_name: "CMS", url: "/admin/cms" },
      ],
      icons: sharedIcons,
      screenshots: [
        {
          src: "/screenshots/admin-dashboard.png",
          sizes: "1024x1024",
          type: "image/png",
          form_factor: "wide",
          label: "Admin dashboard with metrics, quick actions, and recent activity",
        },
        {
          src: "/screenshots/admin-matches-rayon.png",
          sizes: "2688x2363",
          type: "image/png",
          form_factor: "wide",
          label: "Club match management with status badges and inline editing",
        },
      ],
      share_target: {
        action: "/admin/cms",
        method: "GET",
        params: {
          title: "title",
          text: "text",
          url: "url",
        },
      },
    };
  }

  return {
    id: "/",
    name: `${club.shortName} Website`,
    short_name: club.shortName,
    description: `${club.clubName} public website for fixtures, tickets, membership, community, and supporter app entry points.`,
    start_url: "/",
    scope: "/",
    display: "standalone",
    display_override: ["window-controls-overlay", "standalone"],
    orientation: "portrait",
    background_color: "#07162f",
    theme_color: club.primaryColorHex,
    shortcuts: [
      { name: "Home", short_name: "Home", url: "/" },
      { name: "Tickets", short_name: "Tickets", url: "/tickets" },
      { name: "Support Groups", short_name: "Groups", url: "/Groups" },
      { name: "Fan App", short_name: "Fan App", url: resolveFanAppHref() },
    ],
    icons: sharedIcons,
    screenshots: [
      {
        src: "/screenshots/fans-home.png",
        sizes: "1082x2402",
        type: "image/png",
        form_factor: "narrow",
        label: "Official club matchday home with tickets, tiers, and live fixtures",
      },
      {
        src: "/screenshots/fans-tickets.png",
        sizes: "1082x2402",
        type: "image/png",
        form_factor: "narrow",
        label: "Matchday ticket checkout with seat selection and pricing",
      },
    ],
    share_target: {
      action: "/share-target",
      method: "GET",
      params: {
        title: "title",
        text: "text",
        url: "url",
      },
    },
  };
}
