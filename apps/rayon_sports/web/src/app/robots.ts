import type { MetadataRoute } from "next";
import { headers } from "next/headers";
import { absoluteUrl } from "@/lib/config";
import {
  isAdminHostname,
  resolveRoutingHostname,
} from "@/lib/host-routing";

export default async function robots(): Promise<MetadataRoute.Robots> {
  const headersList = await headers();
  const host = resolveRoutingHostname(
    headersList.get("x-forwarded-host"),
    headersList.get("host"),
  );

  if (isAdminHostname(host)) {
    return {
      rules: [
        {
          userAgent: "*",
          disallow: "/",
        },
      ],
    };
  }

  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/admin", "/admin/*", "/api/*", "/share-target"],
      },
    ],
    sitemap: absoluteUrl("/sitemap.xml"),
  };
}
