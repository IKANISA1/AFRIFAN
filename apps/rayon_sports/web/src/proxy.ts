import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import {
  isAdminHostname,
  mapAdminSubdomainPath,
  shouldBypassAdminRewrite,
} from "@/lib/admin-auth";

/**
 * Edge Proxy — rewrites admin.gikundiro.com requests to /admin/* routes.
 */
export function proxy(request: NextRequest) {
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
