import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
} from "@/lib/admin-club-scope";
import {
  canonicalRecoveryPath,
  isAdminHostname,
  mapAdminSubdomainPath,
  resolveRoutingHostname,
  shouldBypassSubdomainRewrite,
} from "@/lib/host-routing";

export function middleware(request: NextRequest) {
  const hostname = resolveRoutingHostname(
    request.headers.get("x-forwarded-host"),
    request.headers.get("host"),
    request.nextUrl.host,
    request.nextUrl.hostname,
  );
  const { pathname } = request.nextUrl;
  const isAdminRequest =
    isAdminHostname(hostname) ||
    pathname === "/admin" ||
    pathname.startsWith("/admin/") ||
    pathname.startsWith("/api/admin/");
  const requestedAdminClubId = isAdminRequest
    ? getRequestedAdminClubId(request.nextUrl.searchParams)
    : null;

  const applyAdminScopeCookie = (response: NextResponse) => {
    if (requestedAdminClubId == null) {
      return response;
    }

    response.cookies.set({
      name: adminClubScopeCookieName,
      value: requestedAdminClubId,
      path: "/",
      sameSite: "lax",
      secure: request.nextUrl.protocol === "https:",
      maxAge: 60 * 60 * 24 * 30,
    });
    return response;
  };

  const recoveryPath = canonicalRecoveryPath(pathname);
  if (recoveryPath != null) {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = recoveryPath;
    return applyAdminScopeCookie(NextResponse.redirect(redirectUrl, 308));
  }

  if (!isAdminHostname(hostname)) {
    return applyAdminScopeCookie(NextResponse.next());
  }

  if (shouldBypassSubdomainRewrite(pathname)) {
    return applyAdminScopeCookie(NextResponse.next());
  }

  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    return applyAdminScopeCookie(NextResponse.next());
  }

  const rewriteUrl = request.nextUrl.clone();
  rewriteUrl.pathname = mapAdminSubdomainPath(pathname);
  return applyAdminScopeCookie(NextResponse.rewrite(rewriteUrl));
}

export const config = {
  matcher: ["/:path*"],
};
