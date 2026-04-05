"use client";

import {
  useCallback,
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import type {
  AuthChangeEvent,
  Session,
  SupabaseClient,
  User,
} from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import { getBrowserSupabase } from "@/lib/supabase/browser";
import type { FanMembership, FanProfile } from "@/lib/types";
import { safeString } from "@/lib/utils";

interface FanPortalContextValue {
  client: SupabaseClient | null;
  session: Session | null;
  user: User | null;
  profile: FanProfile | null;
  membership: FanMembership | null;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  updateProfile: (updates: {
    displayName: string;
    countryCode: string;
    languageCode: string;
    momoNumber: string;
    whatsappNumber: string;
  }) => Promise<void>;
}

const FanPortalContext = createContext<FanPortalContextValue | null>(null);

async function loadProfileSnapshot(
  client: SupabaseClient,
  userId: string,
): Promise<{
  profile: FanProfile | null;
  membership: FanMembership | null;
}> {
  const profileResult = await client
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .maybeSingle();

  const contactsResult = await client
    .from("user_private_contacts")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  let membershipResult = await client
    .from("fan_memberships")
    .select("*")
    .eq("user_id", userId)
    .eq("club_id", rayonClub.numericId)
    .maybeSingle();

  if (membershipResult.error) {
    membershipResult = await client
      .from("fan_memberships")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();
  }

  const profileRow = profileResult.data;
  const contactsRow = contactsResult.data;
  const membershipRow = membershipResult.data;

  return {
    profile: profileRow
      ? {
          id: userId,
          clubId:
            safeString(profileRow.club_id?.toString()) || rayonClub.slug,
          publicUserId: safeString(profileRow.public_user_id) || null,
          displayName: safeString(profileRow.display_name) || null,
          countryCode: safeString(profileRow.country_code) || null,
          languageCode: safeString(profileRow.language_code) || null,
          isActive: profileRow.is_active !== false,
          momoNumber: safeString(contactsRow?.momo_number) || null,
          whatsappNumber: safeString(contactsRow?.whatsapp_number) || null,
        }
      : null,
    membership: membershipRow
      ? {
          id: safeString(membershipRow.id, userId),
          clubId: membershipRow.club_id ?? rayonClub.numericId,
          partnerId: safeString(membershipRow.partner_id) || null,
          tier:
            safeString(membershipRow.tier).toLowerCase() == "gold"
              ? "gold"
              : safeString(membershipRow.tier).toLowerCase() == "platinum"
                ? "platinum"
                : safeString(membershipRow.tier).toLowerCase() == "bronze"
                  ? "bronze"
                  : "fan",
          points:
            typeof membershipRow.points == "number" ? membershipRow.points : 0,
          chapter: safeString(membershipRow.chapter, "Main"),
          membershipNumber:
            safeString(membershipRow.membership_number) || null,
        }
      : null,
  };
}

export function FanPortalProvider({ children }: { children: ReactNode }) {
  const [client] = useState(() => getBrowserSupabase());
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<FanProfile | null>(null);
  const [membership, setMembership] = useState<FanMembership | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (client == null) {
      setLoading(false);
      setError("Supabase browser configuration is missing.");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const sessionResult = await client.auth.getSession();
      let activeSession = sessionResult.data.session ?? null;

      if (activeSession == null) {
        /* Check sessionStorage to avoid re-auth within the same browser session.
           This prevents 429 rate-limit errors from Supabase when users rapidly
           refresh or multiple tabs trigger signInAnonymously simultaneously. */
        const cachedAt = typeof window !== "undefined"
          ? sessionStorage.getItem("gikundiro_anon_auth_ts")
          : null;
        const recentlyAuthed = cachedAt != null && Date.now() - Number(cachedAt) < 15 * 60 * 1000;

        if (!recentlyAuthed) {
          /* Exponential backoff — retry up to 3 times on rate-limit or network errors */
          let lastError: Error | null = null;
          for (let attempt = 0; attempt < 3; attempt++) {
            if (attempt > 0) {
              await new Promise((resolve) => setTimeout(resolve, 1000 * Math.pow(2, attempt)));
            }

            const anonymous = await client.auth.signInAnonymously({
              options: {
                data: {
                  club_id: rayonClub.slug,
                  country_code: rayonClub.countryCode,
                  language_code: "rw",
                },
              },
            });

            if (anonymous.error) {
              lastError = anonymous.error;
              /* Only retry on rate-limit (429) or network errors */
              const is429 = anonymous.error.message?.includes("429") ||
                anonymous.error.message?.toLowerCase().includes("rate");
              if (!is429) throw anonymous.error;
              continue;
            }

            activeSession = anonymous.data.session ?? null;
            lastError = null;

            /* Cache the successful auth timestamp */
            if (typeof window !== "undefined") {
              sessionStorage.setItem("gikundiro_anon_auth_ts", String(Date.now()));
            }
            break;
          }

          if (lastError != null) {
            throw lastError;
          }
        } else {
          /* Recent anonymous auth exists — re-fetch the session which should now be available */
          const retrySession = await client.auth.getSession();
          activeSession = retrySession.data.session ?? null;
        }
      }

      setSession(activeSession);
      const nextUser = activeSession?.user ?? null;
      setUser(nextUser);

      if (nextUser != null) {
        const snapshot = await loadProfileSnapshot(client, nextUser.id);
        setProfile(snapshot.profile);
        setMembership(snapshot.membership);
      } else {
        setProfile(null);
        setMembership(null);
      }
    } catch (caught) {
      /* Suppress raw rate-limit errors — show a friendly fallback instead */
      const rawMessage = caught instanceof Error ? caught.message : "";
      const isRateLimit = rawMessage.includes("429") || rawMessage.toLowerCase().includes("rate");
      setError(
        isRateLimit
          ? "Connecting to your supporter account\u2026 please wait a moment."
          : rawMessage || "Could not start fan portal.",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  async function updateProfile(updates: {
    displayName: string;
    countryCode: string;
    languageCode: string;
    momoNumber: string;
    whatsappNumber: string;
  }) {
    if (client == null || user == null) {
      throw new Error("Fan session is not ready.");
    }

    await client.from("profiles").upsert(
      {
        id: user.id,
        club_id: rayonClub.numericId,
        display_name: updates.displayName,
        full_name: updates.displayName,
        country_code: updates.countryCode,
        country: updates.countryCode,
        language_code: updates.languageCode,
        is_active: true,
      },
      { onConflict: "id" },
    );

    await client.from("user_private_contacts").upsert(
      {
        user_id: user.id,
        club_id: rayonClub.numericId,
        momo_number: updates.momoNumber || null,
        whatsapp_number: updates.whatsappNumber || null,
        country_code: updates.countryCode,
      },
      { onConflict: "user_id" },
    );

    await refresh();
  }

  useEffect(() => {
    if (client == null) {
      setLoading(false);
      setError("Supabase browser configuration is missing.");
      return;
    }

    refresh().catch(() => {});

    const {
      data: { subscription },
    } = client.auth.onAuthStateChange(
      (_event: AuthChangeEvent, nextSession: Session | null) => {
      setSession(nextSession);
      setUser(nextSession?.user ?? null);
      },
    );

    return () => {
      subscription.unsubscribe();
    };
  }, [client, refresh]);

  return (
    <FanPortalContext.Provider
      value={{
        client,
        session,
        user,
        profile,
        membership,
        loading,
        error,
        refresh,
        updateProfile,
      }}
    >
      {children}
    </FanPortalContext.Provider>
  );
}

export function useFanPortal() {
  const context = useContext(FanPortalContext);
  if (context == null) {
    throw new Error("useFanPortal must be used within FanPortalProvider.");
  }
  return context;
}
