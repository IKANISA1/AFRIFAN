import type { MetadataRoute } from "next";
import { headers } from "next/headers";
import { resolveFanAppHref } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import {
  isAdminHostname,
  resolveRoutingHostname,
} from "@/lib/host-routing";

export default async function manifest(): Promise<MetadataRoute.Manifest> {
  const headersList = await headers();
  const host = resolveRoutingHostname(
    headersList.get("x-forwarded-host"),
    headersList.get("host"),
  );
  const club = await getClubProfile();
  const icons: MetadataRoute.Manifest["icons"] = club.officialLogoUrl
    ? [{ src: club.officialLogoUrl, purpose: "any" }]
    : [];


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
      background_color: "#000000",
      theme_color: "#000000",
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
      icons,
      share_target: {
        action: "/admin/cms",
        method: "GET",
        enctype: "application/x-www-form-urlencoded",
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
    background_color: "#000000",
    theme_color: "#000000",
    shortcuts: [
      { name: "Home", short_name: "Home", url: "/" },
      { name: "Tickets", short_name: "Tickets", url: "/tickets" },
      { name: "Support Groups", short_name: "Groups", url: "/Groups" },
      { name: "Fan App", short_name: "Fan App", url: resolveFanAppHref(club.clubSlug) },
    ],
    icons,
    share_target: {
      action: "/share-target",
      method: "GET",
      enctype: "application/x-www-form-urlencoded",
      params: {
        title: "title",
        text: "text",
        url: "url",
      },
    },
  };
}
