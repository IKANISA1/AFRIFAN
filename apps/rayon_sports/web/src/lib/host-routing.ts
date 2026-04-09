const ADMIN_HOSTNAME = "admin.gikundiro.com";
const STATIC_FILE_PATTERN = /\.[a-z0-9]+$/i;

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
  return resolveRoutingHostname(hostname) === ADMIN_HOSTNAME;
}

export function shouldBypassSubdomainRewrite(pathname: string) {
  return (
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.startsWith("/auth/") ||
    pathname === "/favicon.ico" ||
    pathname === "/robots.txt" ||
    pathname === "/sitemap.xml" ||
    pathname === "/manifest.webmanifest" ||
    pathname === "/sw.js" ||
    pathname === "/share-target" ||
    pathname === "/offline" ||
    pathname === "/admin-offline" ||
    pathname.startsWith("/media/") ||
    pathname.startsWith("/icons/") ||
    STATIC_FILE_PATTERN.test(pathname)
  );
}

export function mapAdminSubdomainPath(pathname: string) {
  return mapSubdomainPath(pathname, "/admin");
}
