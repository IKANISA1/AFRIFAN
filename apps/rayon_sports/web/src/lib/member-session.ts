"use client";

export const memberRequestTimeoutMs = 8_000;
export const memberSignOutStorageKey = "africlub:member:sign-out-pending";
const signOutCookie = "africlub_member_signout_pending";

// This marker contains no account data. Keep an unsuccessful sign-out locked
// across reloads and tabs; provider revocation is only confirmed on success.
export function isMemberSignOutPending() {
  try {
    if (window.localStorage.getItem(memberSignOutStorageKey) === "1") return true;
  } catch { /* Cookie fallback also covers denied localStorage. */ }
  return typeof document !== "undefined" && document.cookie.split(";").some(
    (cookie) => cookie.trim() === `${signOutCookie}=1`,
  );
}

export function setMemberSignOutPending(pending: boolean) {
  try {
    if (pending) window.localStorage.setItem(memberSignOutStorageKey, "1");
    else window.localStorage.removeItem(memberSignOutStorageKey);
  } catch { /* Keep the non-secret cookie marker when localStorage is denied. */ }
  document.cookie = `${signOutCookie}=${pending ? "1" : ""}; Path=/; SameSite=Lax; Max-Age=${pending ? 31_536_000 : 0}${window.location.protocol === "https:" ? "; Secure" : ""}`;
}

export async function boundedMemberRequest<T>(request: PromiseLike<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Promise.resolve(request),
      new Promise<never>((_resolve, reject) => {
        timer = setTimeout(() => reject(new Error("Member request timed out.")), memberRequestTimeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
