import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
} from "@/lib/admin-club-scope";
import {
  canonicalRecoveryPath,
  isAdminHostname,
  isWorkersPreviewHostname,
  mapAdminSubdomainPath,
  resolveRoutingHostname,
  shouldBypassSubdomainRewrite,
} from "@/lib/host-routing";
import { controlledAdminEvidenceRequestHeader } from "@/lib/controlled-admin-evidence";

export function routeHostRequest(request: NextRequest) {
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
  const forwardedRequestHeaders = new Headers(request.headers);
  forwardedRequestHeaders.delete(controlledAdminEvidenceRequestHeader);
  if (isAdminRequest && request.nextUrl.searchParams.has("evidence")) {
    forwardedRequestHeaders.set(controlledAdminEvidenceRequestHeader, "1");
  }

  const continueRequest = () =>
    NextResponse.next({
      request: { headers: forwardedRequestHeaders },
    });

  const applyAdminScopeCookie = (response: NextResponse) => {
    if (isWorkersPreviewHostname(hostname)) {
      response.headers.set(
        "X-Robots-Tag",
        "noindex, nofollow, noarchive",
      );
    }
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
    return applyAdminScopeCookie(continueRequest());
  }

  if (shouldBypassSubdomainRewrite(pathname)) {
    return applyAdminScopeCookie(continueRequest());
  }

  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    return applyAdminScopeCookie(continueRequest());
  }

  const rewriteUrl = request.nextUrl.clone();
  rewriteUrl.pathname = mapAdminSubdomainPath(pathname);
  return applyAdminScopeCookie(
    NextResponse.rewrite(rewriteUrl, {
      request: { headers: forwardedRequestHeaders },
    }),
  );
}
