export const adminClubScopeCookieName = "africlub_admin_club";

function normalizeClubScope(value: string | null | undefined) {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
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
