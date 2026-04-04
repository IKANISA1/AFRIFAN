import type { MetadataRoute } from "next";
import { headers } from "next/headers";
import { siteConfig } from "@/lib/config";
import { isAdminHostname } from "@/lib/admin-auth";

const sharedIcons: MetadataRoute.Manifest["icons"] = [
  { src: "/icons/icon-72x72.png", sizes: "72x72", type: "image/png" },
  { src: "/icons/icon-96x96.png", sizes: "96x96", type: "image/png" },
  { src: "/icons/icon-128x128.png", sizes: "128x128", type: "image/png" },
  { src: "/icons/icon-144x144.png", sizes: "144x144", type: "image/png" },
  { src: "/icons/icon-152x152.png", sizes: "152x152", type: "image/png" },
  { src: "/icons/icon-192x192.png", sizes: "192x192", type: "image/png", purpose: "any" },
  { src: "/icons/icon-384x384.png", sizes: "384x384", type: "image/png" },
  { src: "/icons/icon-512x512.png", sizes: "512x512", type: "image/png", purpose: "any" },
  { src: "/media/rayon-crest.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
];

export default async function manifest(): Promise<MetadataRoute.Manifest> {
  const headersList = await headers();
  const host = headersList.get("host");

  if (isAdminHostname(host)) {
    return {
      id: "/admin",
      name: "Gikundiro Admin",
      short_name: "Admin",
      description:
        "Club admin workspace for Rayon Sports operations, publishing, and supporter management.",
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
          src: "/screenshots/admin-matches.png",
          sizes: "1024x1024",
          type: "image/png",
          form_factor: "wide",
          label: "Match management with status badges and inline editing",
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
    name: siteConfig.title,
    short_name: siteConfig.shortTitle,
    description: siteConfig.description,
    start_url: "/",
    scope: "/",
    display: "standalone",
    display_override: ["window-controls-overlay", "standalone"],
    orientation: "portrait",
    background_color: "#07162f",
    theme_color: "#0038a8",
    shortcuts: [
      { name: "Fan Portal", short_name: "Portal", url: "/app" },
      { name: "Tickets", short_name: "Tickets", url: "/tickets" },
      { name: "Support Circles", short_name: "Circles", url: "/circles" },
    ],
    icons: sharedIcons,
  };
}
