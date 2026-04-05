import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import {
  isAdminHostname,
  isFansHostname,
  mapAdminSubdomainPath,
  mapFansSubdomainPath,
  resolveRoutingHostname,
  shouldBypassSubdomainRewrite,
} from "@/lib/host-routing";

/**
 * Keep using Edge middleware here because OpenNext Cloudflare does not yet
 * support the Node.js runtime used by Next 16 proxy.ts files.
 */
export function middleware(request: NextRequest) {
  const hostname = resolveRoutingHostname(
    request.headers.get("x-forwarded-host"),
    request.headers.get("host"),
    request.nextUrl.host,
    request.nextUrl.hostname,
  );

  if (!isAdminHostname(hostname) && !isFansHostname(hostname)) {
    return NextResponse.next();
  }

  const { pathname } = request.nextUrl;
  if (shouldBypassSubdomainRewrite(pathname)) {
    return NextResponse.next();
  }

  if (isFansHostname(hostname) && pathname === "/") {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = "/home";
    return NextResponse.redirect(redirectUrl);
  }

  if (isFansHostname(hostname) && pathname === "/app") {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = "/home";
    return NextResponse.redirect(redirectUrl);
  }

  if (
    (isAdminHostname(hostname) &&
      (pathname === "/admin" || pathname.startsWith("/admin/"))) ||
    (isFansHostname(hostname) &&
      (pathname === "/app" || pathname.startsWith("/app/")))
  ) {
    return NextResponse.next();
  }

  const rewriteUrl = request.nextUrl.clone();
  rewriteUrl.pathname = isAdminHostname(hostname)
    ? mapAdminSubdomainPath(pathname)
    : mapFansSubdomainPath(pathname);
  return NextResponse.rewrite(rewriteUrl);
}

export const config = {
  matcher: ["/:path*"],
};
