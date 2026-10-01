"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  startTransition,
  type ReactNode,
} from "react";
import type {
  AuthChangeEvent,
  Session,
  SupabaseClient,
  User,
} from "@supabase/supabase-js";
import {
  adminPhoneAccessDeniedMessage,
  normalizeAdminPhone,
  formatAdminPhoneForDisplay,
} from "@/lib/admin-auth";
import {
  fetchAdminWithTimeout,
  withAdminOperationTimeout,
} from "@/lib/admin-operation-timeout";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
  readCookieValue,
  writeAdminClubScopeCookie,
} from "@/lib/admin-club-scope";
import { emptyAdminAccess, resolveAdminAccess } from "@/lib/data/admin/access";
import { getAdminClubScopeOptions } from "@/lib/data/admin/settings";
import { getBrowserSupabase } from "@/lib/supabase/browser";
import { inspectStaffAssurance } from "@/lib/staff-assurance";
import type { AdminAccess, AdminClubScopeOption, AdminPortalInitialState } from "@/lib/types";

const pendingPhoneStorageKey = "gikundiro.admin.pending-phone";

function getRequestedClubIdFromLocation() {
  if (typeof window === "undefined") {
    return null;
  }

  const url = new URL(window.location.href);
  return getRequestedAdminClubId(
    url.searchParams,
    readCookieValue(document.cookie, adminClubScopeCookieName),
  );
}

interface AdminPortalContextValue {
  client: SupabaseClient | null;
  session: Session | null;
  user: User | null;
  access: AdminAccess;
  clubOptions: AdminClubScopeOption[];
  activeClub: AdminClubScopeOption | null;
  switchingClub: boolean;
  authBusy: boolean;
  loading: boolean;
  error: string | null;
  notice: string | null;
  pendingPhone: string | null;
  controlledEvidence: boolean;
  accessUnavailable: boolean;
  refresh: () => Promise<void>;
  setClubScope: (clubId: string) => Promise<void>;
  requestPhoneCode: (phone: string) => Promise<void>;
  verifyPhoneCode: (code: string) => Promise<void>;
  resetPendingPhone: () => void;
  signOut: () => Promise<void>;
}

const AdminPortalContext = createContext<AdminPortalContextValue | null>(null);

function readAuthErrorFromUrl() {
  if (typeof window === "undefined") {
    return null;
  }

  const url = new URL(window.location.href);
  const description =
    url.searchParams.get("error_description") ?? url.searchParams.get("error");

  if (!description) {
    return null;
  }

  return description.replaceAll("+", " ");
}

async function consumeHashSession(client: SupabaseClient) {
  if (typeof window === "undefined") {
    return null;
  }

  const hash = window.location.hash.startsWith("#")
    ? window.location.hash.slice(1)
    : window.location.hash;
  const hashParams = new URLSearchParams(hash);
  const accessToken = hashParams.get("access_token");
  const refreshToken = hashParams.get("refresh_token");

  if (!accessToken || !refreshToken) {
    return readAuthErrorFromUrl();
  }

  const { error } = await withAdminOperationTimeout(
    client.auth.setSession({
      access_token: accessToken,
      refresh_token: refreshToken,
    }),
    "Admin session recovery",
  );

  if (error) {
    throw error;
  }

  const cleanUrl = new URL(window.location.href);
  cleanUrl.hash = "";
  cleanUrl.searchParams.delete("error");
  cleanUrl.searchParams.delete("error_code");
  cleanUrl.searchParams.delete("error_description");
  cleanUrl.searchParams.delete("sb");
  window.history.replaceState({}, document.title, cleanUrl.toString());

  return null;
}

function hasPendingAuthHash() {
  if (typeof window === "undefined") {
    return false;
  }

  const hash = window.location.hash.startsWith("#")
    ? window.location.hash.slice(1)
    : window.location.hash;
  if (!hash) {
    return false;
  }

  const hashParams = new URLSearchParams(hash);
  return Boolean(hashParams.get("access_token") && hashParams.get("refresh_token"));
}

export function AdminPortalProvider({
  children,
  initialState,
}: {
  children: ReactNode;
  initialState?: AdminPortalInitialState;
}) {
  const controlledEvidence = initialState?.controlledEvidence === true;
  const [client] = useState<SupabaseClient | null>(() => {
    const configuredClient = getBrowserSupabase();
    if (configuredClient != null || !controlledEvidence) {
      return configuredClient;
    }

    // Controlled local evidence pages use the authenticated same-origin admin
    // API and never call this sentinel directly. A non-null value lets those
    // pages exercise their real API state machines without browser credentials.
    return {} as SupabaseClient;
  });
  const [session, setSession] = useState<Session | null>(initialState?.session ?? null);
  const [user, setUser] = useState<User | null>(initialState?.user ?? null);
  const [access, setAccess] = useState<AdminAccess>(initialState?.access ?? emptyAdminAccess);
  const [clubOptions, setClubOptions] = useState<AdminClubScopeOption[]>(
    initialState?.clubOptions ?? [],
  );
  const [switchingClub, setSwitchingClub] = useState(false);
  const [authBusy, setAuthBusy] = useState(false);
  const [loading, setLoading] = useState(initialState == null);
  const [error, setError] = useState<string | null>(initialState?.error ?? null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingPhone, setPendingPhone] = useState<string | null>(null);
  const [accessUnavailable, setAccessUnavailable] = useState(false);
  const refreshGeneration = useRef(0);
  const authGeneration = useRef(0);
  const sessionIdentity = useRef(initialState?.user?.id ?? null);
  // This owner identifies retained UI drafts, never permission to execute work.
  const verifiedWorkspaceOwner = useRef(initialState?.access.hasAccess ? initialState.user?.id ?? null : null);

  const syncPendingPhone = useCallback((value: string | null) => {
    setPendingPhone(value);

    if (typeof window === "undefined") {
      return;
    }

    if (value) {
      window.sessionStorage.setItem(pendingPhoneStorageKey, value);
      return;
    }

    window.sessionStorage.removeItem(pendingPhoneStorageKey);
  }, []);

  const runRefresh = useCallback(async ({ blocking = true }: { blocking?: boolean } = {}) => {
    const generation = ++refreshGeneration.current;
    const current = () => refreshGeneration.current === generation;
    const previousOwner = sessionIdentity.current;
    let identityRejected = false;
    if (client == null) {
      setLoading(false);
      setError("Supabase browser configuration is missing.");
      setAccess(emptyAdminAccess);
      setAccessUnavailable(false);
      setClubOptions([]);
      return;
    }

    if (blocking) {
      setLoading(true);
    }

    try {
      const urlError = await consumeHashSession(client);
      const result = await withAdminOperationTimeout(
        client.auth.getSession(),
        "Admin session refresh",
      );
      if (!current()) return;
      if (result.error) throw result.error;
      const nextSession = result.data.session ?? null;
      if (!nextSession || nextSession.user.id !== previousOwner) identityRejected = true;
      let nextUser: User | null = null;
      if (nextSession) {
        const verified = await withAdminOperationTimeout(client.auth.getUser(), "Admin identity check");
        if (!current()) return;
        if (verified.error) {
          if ([400, 401, 403].includes(verified.error.status ?? 0)) identityRejected = true;
          throw new Error("Admin identity could not be verified. Try again.");
        }
        if (!verified.data.user || verified.data.user.id !== nextSession.user.id) {
          identityRejected = true;
          throw new Error("Admin identity could not be verified. Sign in again.");
        }
        nextUser = verified.data.user;
      }
      const nextAccess = await withAdminOperationTimeout(
        resolveAdminAccess(client, nextUser, {
          requestedClubId: getRequestedClubIdFromLocation(),
        }),
        "Admin access check",
      );
      if (!current()) return;
      let nextClubOptions: AdminClubScopeOption[] = [];
      if (nextAccess.hasAccess) {
        try {
          const claims = await withAdminOperationTimeout(client.auth.getClaims(), "Staff authentication check");
          if (!current()) return;
          if (!claims.error && nextUser && inspectStaffAssurance(claims.data?.claims ?? null, nextUser.id).allowed) {
            nextClubOptions = await withAdminOperationTimeout(
              getAdminClubScopeOptions(client, nextAccess),
              "Admin club scope loading",
            );
          }
        } catch {
          nextClubOptions = [];
        }
      }
      if (!current()) return;
      sessionIdentity.current = nextUser?.id ?? null;
      verifiedWorkspaceOwner.current = nextAccess.hasAccess ? nextUser?.id ?? null : null;
      startTransition(() => {
        if (!current()) return;
        setSession(nextSession);
        setUser(nextUser);
        setAccess(nextAccess);
        setAccessUnavailable(false);
        setClubOptions(nextClubOptions);
      });
      if (nextUser != null) {
        syncPendingPhone(null);
      }
      setError(nextUser == null ? urlError : null);
    } catch (caught) {
      if (!current()) return;
      const retainDrafts = !identityRejected && previousOwner != null
        && sessionIdentity.current === previousOwner && verifiedWorkspaceOwner.current === previousOwner;
      startTransition(() => {
        if (!current()) return;
        if (retainDrafts) {
          // Keep the same owner/club/role key so drafts survive, but deny all
          // workspace access until current provider identity and grants recover.
          setAccess((previous) => ({ ...previous, hasAccess: false, isSuperAdmin: false }));
        } else {
          sessionIdentity.current = null;
          verifiedWorkspaceOwner.current = null;
          setSession(null);
          setUser(null);
          setAccess(emptyAdminAccess);
        }
        setAccessUnavailable(retainDrafts);
        setClubOptions([]);
      });
      setError(
        caught instanceof Error
          ? caught.message
          : "Could not initialize admin workspace.",
      );
    } finally {
      if (current()) {
        setLoading(false);
      }
    }
  }, [client, syncPendingPhone]);

  const refresh = useCallback(async () => {
    await runRefresh({ blocking: false });
  }, [runRefresh]);

  const requestPhoneCode = useCallback(
    async (phone: string) => {
      if (client == null) {
        throw new Error("Supabase browser configuration is missing.");
      }

      const normalizedPhone = normalizeAdminPhone(phone);
      const generation = ++authGeneration.current;
      setError(null);
      setNotice(null);
      setAuthBusy(true);

      try {
        const eligibilityResponse = await fetchAdminWithTimeout(
          "/api/admin/auth/eligible",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Africlub-CSRF": "1",
            },
            body: JSON.stringify({ phone: normalizedPhone }),
            credentials: "same-origin",
            cache: "no-store",
          },
          "Admin eligibility check",
        );
        const eligibilityPayload = (await eligibilityResponse
          .json()
          .catch(() => ({}))) as { error?: string };
        if (authGeneration.current !== generation) return;

        if (!eligibilityResponse.ok) {
          throw new Error(
            eligibilityPayload.error ?? adminPhoneAccessDeniedMessage(),
          );
        }

        syncPendingPhone(normalizedPhone);
        setNotice(
          `If ${formatAdminPhoneForDisplay(normalizedPhone)} is approved, a verification code will arrive shortly.`,
        );
      } finally {
        if (authGeneration.current === generation) setAuthBusy(false);
      }
    },
    [client, syncPendingPhone],
  );

  const verifyPhoneCode = useCallback(
    async (code: string) => {
      if (client == null) {
        throw new Error("Supabase browser configuration is missing.");
      }

      if (!pendingPhone) {
        throw new Error("Request a verification code first.");
      }

      const token = code.trim();
      if (!/^\d{6}$/.test(token)) {
        throw new Error("Enter the 6-digit code sent to your phone.");
      }

      setError(null);
      setNotice(null);
      setAuthBusy(true);
      const generation = ++authGeneration.current;

      try {
        const { error: authError } = await withAdminOperationTimeout(
          client.auth.verifyOtp({
            phone: pendingPhone,
            token,
            type: "sms",
          }),
          "Admin code verification",
        );
        if (authGeneration.current !== generation) return;

        if (authError) {
          throw authError;
        }

        syncPendingPhone(null);
        setNotice("Admin access verified.");
        await runRefresh({ blocking: false });
      } finally {
        if (authGeneration.current === generation) setAuthBusy(false);
      }
    },
    [client, pendingPhone, runRefresh, syncPendingPhone],
  );

  const setClubScope = useCallback(
    async (clubId: string) => {
      if (typeof window === "undefined") {
        return;
      }

      const nextClubId = clubId.trim();
      if (!nextClubId || nextClubId === access.clubId) {
        return;
      }

      const currentUrl = new URL(window.location.href);
      currentUrl.searchParams.set("club", nextClubId);
      window.history.replaceState({}, document.title, currentUrl.toString());
      writeAdminClubScopeCookie(nextClubId);
      setNotice("Switching club scope...");
      setSwitchingClub(true);

      try {
        await runRefresh({ blocking: false });
        setNotice("Club scope updated.");
      } finally {
        setSwitchingClub(false);
      }
    },
    [access.clubId, runRefresh],
  );

  const signOut = useCallback(async () => {
    if (client == null) {
      return;
    }

    ++refreshGeneration.current;
    ++authGeneration.current;
    sessionIdentity.current = null;
    verifiedWorkspaceOwner.current = null;
    setSession(null);
    setUser(null);
    setAccess(emptyAdminAccess);
    setAccessUnavailable(false);
    setClubOptions([]);
    setLoading(false);
    setAuthBusy(false);
    setNotice(null);
    syncPendingPhone(null);
    const result = await withAdminOperationTimeout(
      client.auth.signOut(),
      "Admin sign-out",
    );
    if (result.error) {
      setError("Sign-out could not be confirmed. Try again.");
      throw new Error("Sign-out could not be confirmed. Try again.");
    }
    setNotice("Signed out of admin workspace.");
  }, [client, syncPendingPhone]);

  useEffect(() => {
    if (controlledEvidence) {
      setLoading(false);
      return;
    }

    if (client == null) {
      setLoading(false);
      setError("Supabase browser configuration is missing.");
      return;
    }

    const ownedRefreshGeneration = refreshGeneration;
    const ownedAuthGeneration = authGeneration;

    if (typeof window !== "undefined") {
      syncPendingPhone(
        window.sessionStorage.getItem(pendingPhoneStorageKey) || null,
      );
    }

    const shouldHydrateFromClient =
      initialState == null || hasPendingAuthHash() || readAuthErrorFromUrl() != null;

    if (shouldHydrateFromClient) {
      runRefresh({ blocking: initialState == null }).catch(() => {});
    } else {
      setLoading(false);
    }

    const {
      data: { subscription },
    } = client.auth.onAuthStateChange(
      (_event: AuthChangeEvent, nextSession: Session | null) => {
        ++refreshGeneration.current;
        const sameAccount = sessionIdentity.current === nextSession?.user.id;
        sessionIdentity.current = nextSession?.user.id ?? null;
        if (_event === "SIGNED_OUT" || _event === "SIGNED_IN") {
          ++authGeneration.current;
          setAuthBusy(false);
          syncPendingPhone(null);
        }
        setSession(nextSession);
        setUser(nextSession?.user ?? null);
        // Discard old-account grants immediately. A same-account token refresh
        // preserves drafts while the server still reauthorizes every request.
        if (!sameAccount || nextSession == null) {
          verifiedWorkspaceOwner.current = null;
          setAccess(emptyAdminAccess);
          setAccessUnavailable(false);
          setClubOptions([]);
        }
        queueMicrotask(() => {
          runRefresh({ blocking: false }).catch(() => {});
        });
      },
    );

    return () => {
      ++ownedRefreshGeneration.current;
      ++ownedAuthGeneration.current;
      subscription.unsubscribe();
    };
  }, [
    client,
    controlledEvidence,
    initialState,
    runRefresh,
    syncPendingPhone,
  ]);

  useEffect(() => {
    if (!notice) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setNotice(null);
    }, 4000);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [notice]);

  const activeClub =
    clubOptions.find((club) => club.id === access.clubId) ?? null;

  return (
    <AdminPortalContext.Provider
      value={{
        client,
        session,
        user,
        access,
        clubOptions,
        activeClub,
        switchingClub,
        authBusy,
        loading,
        error,
        notice,
        pendingPhone,
        controlledEvidence,
        accessUnavailable,
        refresh,
        setClubScope,
        requestPhoneCode,
        verifyPhoneCode,
        resetPendingPhone: () => syncPendingPhone(null),
        signOut,
      }}
    >
      {children}
    </AdminPortalContext.Provider>
  );
}

export function useAdminPortal() {
  const context = useContext(AdminPortalContext);
  if (context == null) {
    throw new Error("useAdminPortal must be used within AdminPortalProvider.");
  }
  return context;
}
