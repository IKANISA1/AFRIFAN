/** Presentation-only launcher. The destination independently authenticates Access and club grants. */
export type PublishingAccess = { hasAccess: boolean; isAuthenticated: boolean; clubId: string | null };
export function publishingLaunchUrl(enabled: string | undefined, origin: string | undefined,
  access: PublishingAccess | null | undefined, controlledEvidence = false): string | null {
  if (enabled !== "true" || controlledEvidence || !access?.hasAccess || !access.isAuthenticated || access.clubId !== "24") return null;
  if (!origin || origin.length > 240) return null;
  try {
    const url = new URL(origin);
    if (url.protocol !== "https:" || url.origin !== origin || url.username || url.password || url.search || url.hash ||
      url.hostname === "localhost" || /^(127\.|0\.|\[::1\])/.test(url.hostname)) return null;
    return `${origin}/operator/clubs/24/public-source`;
  } catch { return null; }
}
