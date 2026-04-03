import type { MetadataRoute } from "next";
import { siteConfig } from "@/lib/config";

export default function manifest(): MetadataRoute.Manifest {
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
      {
        name: "Fan Portal",
        short_name: "Portal",
        url: "/app",
      },
      {
        name: "Tickets",
        short_name: "Tickets",
        url: "/tickets",
      },
      {
        name: "Support Circles",
        short_name: "Circles",
        url: "/circles",
      },
    ],
    icons: [
      {
        src: "/media/rayon-crest.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      }
    ],
  };
}
