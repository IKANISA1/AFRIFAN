export const adminClubScopeCookieName = "africlub_admin_club";

function normalizeClubScope(value: string | null | undefined) {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

export function writeAdminClubScopeCookie(clubId: string | null) {
  if (typeof document === "undefined") {
    return;
  }

  if (clubId == null) {
    document.cookie = `${adminClubScopeCookieName}=; Max-Age=0; Path=/; SameSite=Lax`;
    return;
  }

  document.cookie = `${adminClubScopeCookieName}=${encodeURIComponent(clubId)}; Max-Age=${60 * 60 * 24 * 365}; Path=/; SameSite=Lax`;
}

export function withAdminClubScope(
  href: string,
  clubId: string | null | undefined,
) {
  const normalizedClubId = normalizeClubScope(clubId);
  if (normalizedClubId == null) {
    return href;
  }

  const url = new URL(href, "https://admin.africlub.local");
  url.searchParams.set("club", normalizedClubId);
  return `${url.pathname}${url.search}${url.hash}`;
}

export function getRequestedAdminClubId(
  searchParams:
    | Pick<URLSearchParams, "get">
    | { get(name: string): string | null }
    | null
    | undefined,
  cookieValue?: string | null,
) {
  const queryValue =
    searchParams?.get("club") ?? searchParams?.get("club_id") ?? null;

  return normalizeClubScope(queryValue) ?? normalizeClubScope(cookieValue);
}

export function readCookieValue(cookieSource: string, cookieName: string) {
  for (const entry of cookieSource.split(";")) {
    const [rawName, ...rawValue] = entry.split("=");
    if (rawName?.trim() !== cookieName) {
      continue;
    }
    const value = rawValue.join("=").trim();
    if (!value) {
      return null;
    }
    try {
      return decodeURIComponent(value);
    } catch {
      return value;
    }
  }

  return null;
}
