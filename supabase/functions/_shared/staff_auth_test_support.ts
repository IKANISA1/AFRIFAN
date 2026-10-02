/** Synthetic JWTs for tests whose fake Auth provider validates this same token. */
export function syntheticStaffJwt(
  subject: string,
  changes: Record<string, unknown> = {},
): string {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replace(/\+/g, "-").replace(/\//g, "_").replace(
      /=+$/g,
      "",
    );
  return `${encode({ alg: "HS256", typ: "JWT" })}.${
    encode({
      sub: subject,
      role: "authenticated",
      is_anonymous: false,
      aal: "aal2",
      exp: now + 3600,
      amr: [{ method: "password", timestamp: now - 600 }, {
        method: "totp",
        timestamp: now - 1,
      }],
      ...changes,
    })
  }.dGVzdC1zaWduYXR1cmU`;
}
