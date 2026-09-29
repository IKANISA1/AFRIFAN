export type AuthCallbackState =
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

export const authCallbackOperationTimeoutMs = 8_000;

export function resolveNextPath(nextValue: string | null, origin: string) {
  if (
    typeof nextValue !== "string" ||
    !nextValue.startsWith("/") ||
    nextValue.startsWith("//") ||
    nextValue.includes("\\") ||
    /[\u0000-\u001f\u007f]/u.test(nextValue)
  ) {
    return "/admin";
  }

  try {
    const candidate = new URL(nextValue, origin);
    if (candidate.origin !== origin) {
      return "/admin";
    }
    return `${candidate.pathname}${candidate.search}${candidate.hash}`;
  } catch {
    return "/admin";
  }
}
