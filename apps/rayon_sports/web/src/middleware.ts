import type { NextRequest } from "next/server";
import { routeHostRequest } from "@/lib/host-request-routing";

// The pinned OpenNext Cloudflare adapter requires Edge middleware. Next 16
// still supports this file convention; proxy.ts would force the Node runtime.
// Keep routing and request-header policy in the same reviewed implementation.
export function middleware(request: NextRequest) {
  return routeHostRequest(request);
}

export const config = {
  matcher: ["/:path*"],
};
