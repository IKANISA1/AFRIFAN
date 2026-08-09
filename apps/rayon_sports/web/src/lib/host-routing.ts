const ADMIN_HOSTNAMES = new Set(["admin.gikundiro.com"]);
const STATIC_FILE_PATTERN = /\.[a-z0-9]+$/i;
const RELEASE_CONTRACT_PATHS = [
  "/privacy",
  "/terms",
  "/support",
  "/contact",
  "/account-deletion",
] as const;

export function resolveRoutingHostname(
  ...hostnames: Array<string | null | undefined>
) {
  for (const hostname of hostnames) {
    const normalized = hostname
      ?.split(",")[0]
      ?.trim()
      ?.split(":")[0]
      ?.toLowerCase();

    if (normalized) {
      return normalized;
    }
  }

  return "";
}

function mapSubdomainPath(pathname: string, routePrefix: string) {
  if (pathname === "/") {
    return routePrefix;
  }

  if (pathname === routePrefix || pathname.startsWith(`${routePrefix}/`)) {
    return pathname;
  }

  return `${routePrefix}${pathname}`;
}

export function isAdminHostname(hostname: string | null | undefined) {
  return ADMIN_HOSTNAMES.has(resolveRoutingHostname(hostname));
}

export function isWorkersPreviewHostname(
  hostname: string | null | undefined,
) {
  return resolveRoutingHostname(hostname).endsWith(".workers.dev");
}

export function canonicalRecoveryPath(pathname: string) {
  return pathname === "/admin/offline" ? "/admin-offline" : null;
}

export function isReleaseContractPath(pathname: string) {
  return (
    pathname === "/.well-known" ||
    pathname.startsWith("/.well-known/") ||
    RELEASE_CONTRACT_PATHS.some(
      (path) => pathname === path || pathname.startsWith(`${path}/`),
    )
  );
}

export function shouldBypassSubdomainRewrite(pathname: string) {
  return (
    isReleaseContractPath(pathname) ||
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.startsWith("/auth/") ||
    pathname === "/robots.txt" ||
    pathname === "/sitemap.xml" ||
    pathname === "/manifest.webmanifest" ||
    pathname === "/sw.js" ||
    pathname === "/share-target" ||
    pathname === "/offline" ||
    pathname === "/admin-offline" ||
    STATIC_FILE_PATTERN.test(pathname)
  );
}

export function mapAdminSubdomainPath(pathname: string) {
  return mapSubdomainPath(pathname, "/admin");
}
