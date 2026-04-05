import type { Metadata } from "next";
import type { ReactNode } from "react";
import { FanPortalLoader } from "./fan-portal-loader";
import { buildPageMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildPageMetadata({
  title: "Fan portal",
  description:
    "Supporter hub for tickets, membership, merch, fan clubs, and live matchday access.",
  path: "/app",
  robots: {
    index: false,
    follow: false,
  },
});

export default function FanPortalLayout({
  children,
}: {
  children: ReactNode;
}) {
  return <FanPortalLoader>{children}</FanPortalLoader>;
}
