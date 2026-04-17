"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
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
  adminClubScopeCookieName,
  getRequestedAdminClubId,
  readCookieValue,
  writeAdminClubScopeCookie,
} from "@/lib/admin-club-scope";
import { emptyAdminAccess, resolveAdminAccess } from "@/lib/data/admin/access";
import { getAdminClubScopeOptions } from "@/lib/data/admin/settings";
import { getBrowserSupabase } from "@/lib/supabase/browser";
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

  const { error } = await client.auth.setSession({
    access_token: accessToken,
    refresh_token: refreshToken,
  });

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
  const [client] = useState(() => getBrowserSupabase());
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
    if (client == null) {
      setLoading(false);
      setError("Supabase browser configuration is missing.");
      setAccess(emptyAdminAccess);
      setClubOptions([]);
      return;
    }

    if (blocking) {
      setLoading(true);
    }

    try {
      const urlError = await consumeHashSession(client);
      const result = await client.auth.getSession();
      const nextSession = result.data.session ?? null;
      const nextUser = nextSession?.user ?? null;
      startTransition(() => {
        setSession(nextSession);
        setUser(nextUser);
      });
      const nextAccess = await resolveAdminAccess(client, nextUser, {
        requestedClubId: getRequestedClubIdFromLocation(),
      });
      startTransition(() => {
        setAccess(nextAccess);
      });
      if (nextAccess.hasAccess) {
        try {
          const nextClubOptions = await getAdminClubScopeOptions(client, nextAccess);
          startTransition(() => {
            setClubOptions(nextClubOptions);
          });
        } catch {
          startTransition(() => {
            setClubOptions([]);
          });
        }
      } else {
        startTransition(() => {
          setClubOptions([]);
        });
      }
      if (nextUser != null) {
        syncPendingPhone(null);
      }
      setError(nextUser == null ? urlError : null);
    } catch (caught) {
      startTransition(() => {
        setAccess(emptyAdminAccess);
        setClubOptions([]);
      });
      setError(
        caught instanceof Error
          ? caught.message
          : "Could not initialize admin workspace.",
      );
    } finally {
      if (blocking) {
        setLoading(false);
      }
    }
  }, [client, syncPendingPhone]);

  const refresh = useCallback(async () => {
    await runRefresh();
  }, [runRefresh]);

  const requestPhoneCode = useCallback(
    async (phone: string) => {
      if (client == null) {
        throw new Error("Supabase browser configuration is missing.");
      }

      const normalizedPhone = normalizeAdminPhone(phone);
      setError(null);
      setNotice(null);
      setAuthBusy(true);

      try {
        const eligibilityResponse = await fetch("/api/admin/auth/eligible", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Africlub-CSRF": "1",
          },
          body: JSON.stringify({ phone: normalizedPhone }),
          credentials: "same-origin",
          cache: "no-store",
        });
        const eligibilityPayload = (await eligibilityResponse
          .json()
          .catch(() => ({}))) as { error?: string };

        if (!eligibilityResponse.ok) {
          throw new Error(
            eligibilityPayload.error ?? adminPhoneAccessDeniedMessage(),
          );
        }

        const { error: authError } = await client.auth.signInWithOtp({
          phone: normalizedPhone,
          options: {
            shouldCreateUser: false,
            channel: "whatsapp",
          },
        });

        if (authError) {
          throw authError;
        }

        syncPendingPhone(normalizedPhone);
        setNotice(
          `Verification code sent to ${formatAdminPhoneForDisplay(normalizedPhone)}.`,
        );
      } finally {
        setAuthBusy(false);
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

      try {
        const { error: authError } = await client.auth.verifyOtp({
          phone: pendingPhone,
          token,
          type: "sms",
        });

        if (authError) {
          throw authError;
        }

        syncPendingPhone(null);
        setNotice("Admin access verified.");
        await runRefresh({ blocking: false });
      } finally {
        setAuthBusy(false);
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

    await client.auth.signOut();
    syncPendingPhone(null);
    setNotice("Signed out of admin workspace.");
    await runRefresh({ blocking: false });
  }, [client, runRefresh, syncPendingPhone]);

  useEffect(() => {
    if (client == null) {
      setLoading(false);
      setError("Supabase browser configuration is missing.");
      return;
    }

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
        setSession(nextSession);
        setUser(nextSession?.user ?? null);
        queueMicrotask(() => {
          runRefresh({ blocking: false }).catch(() => {});
        });
      },
    );

    return () => {
      subscription.unsubscribe();
    };
  }, [client, initialState, runRefresh, syncPendingPhone]);

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
