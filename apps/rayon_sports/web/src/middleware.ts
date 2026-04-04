import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import {
  isAdminHostname,
  mapAdminSubdomainPath,
  shouldBypassAdminRewrite,
} from "@/lib/admin-auth";

/**
 * Edge Middleware — rewrites admin.gikundiro.com requests to /admin/* routes.
 *
 * Uses Edge runtime (required for Cloudflare Workers via @opennextjs/cloudflare).
 * Note: @opennextjs/cloudflare v1.x does not support Next 16's proxy.ts yet,
 * so we use the standard middleware.ts convention.
 */
export function middleware(request: NextRequest) {
  const host = request.headers.get("host");
  if (!isAdminHostname(host)) {
    return NextResponse.next();
  }

  const { pathname } = request.nextUrl;
  if (shouldBypassAdminRewrite(pathname)) {
    return NextResponse.next();
  }

  const rewriteUrl = request.nextUrl.clone();
  rewriteUrl.pathname = mapAdminSubdomainPath(pathname);
  return NextResponse.rewrite(rewriteUrl);
}

export const config = {
  matcher: ["/:path*"],
};
