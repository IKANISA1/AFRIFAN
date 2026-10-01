export const staffStepUpSeconds = 300;
export const staffClockSkewSeconds = 30;

/** Claims must already be provider verified at a server authorization boundary. */
export function inspectStaffAssurance(
  claims: Record<string, unknown> | null,
  userId: string,
  nowSeconds = Date.now() / 1000,
): { allowed: boolean; expiresAt: number | null } {
  const denied = { allowed: false, expiresAt: null };
  if (!claims || !userId || !Number.isFinite(nowSeconds) || claims.sub !== userId ||
    claims.role !== "authenticated" || claims.aal !== "aal2" || claims.is_anonymous !== false ||
    !Number.isSafeInteger(claims.exp) || (claims.exp as number) <= nowSeconds ||
    !Array.isArray(claims.amr) || claims.amr.length > 16) return denied;

  let expiresAt = 0;
  for (const entry of claims.amr) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
    const { method, timestamp } = entry as Record<string, unknown>;
    if ((method !== "totp" && method !== "mfa/totp") || !Number.isSafeInteger(timestamp)) continue;
    const verifiedAt = timestamp as number;
    if (verifiedAt > nowSeconds + staffClockSkewSeconds || verifiedAt + staffStepUpSeconds <= nowSeconds) continue;
    expiresAt = Math.max(expiresAt, Math.min(claims.exp as number, verifiedAt + staffStepUpSeconds));
  }
  return expiresAt > nowSeconds ? { allowed: true, expiresAt } : denied;
}
