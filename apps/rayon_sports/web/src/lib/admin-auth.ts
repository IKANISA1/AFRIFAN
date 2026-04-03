const ADMIN_HOSTNAME = "admin.gikundiro.com";
const STATIC_FILE_PATTERN = /\.[a-z0-9]+$/i;

export function normalizeAdminPhone(input: string) {
  const trimmed = input.trim();
  if (!trimmed) {
    throw new Error("Enter the admin WhatsApp number.");
  }

  let normalized = trimmed.replace(/[^\d+]/g, "");
  if (normalized.startsWith("00")) {
    normalized = `+${normalized.slice(2)}`;
  }

  if (!normalized.startsWith("+")) {
    if (/^0\d{9}$/.test(normalized)) {
      normalized = `+250${normalized.slice(1)}`;
    } else if (/^\d{9}$/.test(normalized)) {
      normalized = `+250${normalized}`;
    } else {
      normalized = `+${normalized}`;
    }
  }

  normalized = normalized.replace(/(?!^)\+/g, "");
  if (!/^\+[1-9]\d{7,14}$/.test(normalized)) {
    throw new Error("Use a valid WhatsApp number in international format.");
  }

  return normalized;
}

export function formatAdminPhoneForDisplay(phone: string) {
  if (!phone.startsWith("+")) {
    return phone;
  }

  if (phone.startsWith("+250") && phone.length === 13) {
    return `+250 ${phone.slice(4, 7)} ${phone.slice(7, 10)} ${phone.slice(10)}`;
  }

  return phone;
}

export function isAdminHostname(hostname: string | null | undefined) {
  if (!hostname) {
    return false;
  }

  return hostname.split(":")[0].toLowerCase() === ADMIN_HOSTNAME;
}

export function shouldBypassAdminRewrite(pathname: string) {
  return (
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.startsWith("/auth/") ||
    pathname === "/favicon.ico" ||
    pathname === "/robots.txt" ||
    pathname === "/sitemap.xml" ||
    pathname === "/manifest.webmanifest" ||
    pathname === "/sw.js" ||
    pathname.startsWith("/media/") ||
    pathname.startsWith("/icons/") ||
    STATIC_FILE_PATTERN.test(pathname)
  );
}

export function mapAdminSubdomainPath(pathname: string) {
  if (pathname === "/") {
    return "/admin";
  }

  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    return pathname;
  }

  return `/admin${pathname}`;
}
