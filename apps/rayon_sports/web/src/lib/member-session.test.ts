import { afterEach, describe, expect, it, vi } from "vitest";
import {
  boundedMemberRequest,
  isMemberSignOutPending,
  memberRequestTimeoutMs,
  memberSignOutStorageKey,
  setMemberSignOutPending,
} from "./member-session";

afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
  setMemberSignOutPending(false);
});

describe("member sign-out recovery", () => {
  it("keeps an unfinished sign-out visible across reads and removes both markers on completion", () => {
    setMemberSignOutPending(true);
    expect(isMemberSignOutPending()).toBe(true);
    expect(localStorage.getItem(memberSignOutStorageKey)).toBe("1");
    expect(document.cookie).toContain("africlub_member_signout_pending=1");
    setMemberSignOutPending(false);
    expect(isMemberSignOutPending()).toBe(false);
    expect(localStorage.getItem(memberSignOutStorageKey)).toBeNull();
    expect(document.cookie).not.toContain("africlub_member_signout_pending=1");
  });

  it("keeps the pending lock when localStorage is denied", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new DOMException("Storage denied", "SecurityError");
    });
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new DOMException("Storage denied", "SecurityError");
    });
    setMemberSignOutPending(true);
    expect(isMemberSignOutPending()).toBe(true);
    setMemberSignOutPending(false);
    expect(isMemberSignOutPending()).toBe(false);
  });

  it("bounds a request that never settles", async () => {
    vi.useFakeTimers();
    const request = boundedMemberRequest(new Promise<never>(() => {}));
    const result = expect(request).rejects.toThrow("Member request timed out.");
    await vi.advanceTimersByTimeAsync(memberRequestTimeoutMs);
    await result;
    expect(vi.getTimerCount()).toBe(0);
  });

  it("clears its deadline after a successful response", async () => {
    vi.useFakeTimers();
    await expect(boundedMemberRequest(Promise.resolve("confirmed"))).resolves.toBe("confirmed");
    expect(vi.getTimerCount()).toBe(0);
  });
});
