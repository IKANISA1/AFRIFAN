import type { createAdminClient } from "./supabase.ts";
import { extractClientIp, hashOtpRateActorKey } from "./otp_abuse.ts";

type AdminClient = ReturnType<typeof createAdminClient>;

export type BioPayMatchRateScope = "user" | "ip";
export type BioPayMatchRateOutcome =
  | "match"
  | "miss"
  | "blocked_user_rate_limit"
  | "blocked_ip_rate_limit"
  | "lockout_started"
  | "blocked_lockout";

export type BioPayMatchProtectionConfig = {
  threshold: number;
  rateWindowSeconds: number;
  userMaxAttempts: number;
  ipMaxAttempts: number;
  missWindowSeconds: number;
  maxMissesPerWindow: number;
  lockoutSeconds: number;
};

const defaultBioPayMatchProtectionConfig: BioPayMatchProtectionConfig = {
  threshold: 0.72,
  rateWindowSeconds: 60,
  userMaxAttempts: 8,
  ipMaxAttempts: 20,
  missWindowSeconds: 600,
  maxMissesPerWindow: 5,
  lockoutSeconds: 900,
};

const protectionConfigKeys = [
  "BioPay_match_threshold",
  "BioPay_match_rate_window_seconds",
  "BioPay_match_user_max_attempts",
  "BioPay_match_ip_max_attempts",
  "BioPay_match_miss_window_seconds",
  "BioPay_match_miss_lockout_threshold",
  "BioPay_match_lockout_seconds",
] as const;

function parsePositiveInteger(
  rawValue: string | undefined,
  fallback: number,
): number {
  const parsed = Number.parseInt(rawValue ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseThreshold(
  rawValue: string | undefined,
  fallback: number,
): number {
  const parsed = Number(rawValue ?? "");
  return Number.isFinite(parsed) && parsed > 0 && parsed <= 1
    ? parsed
    : fallback;
}

export async function getBioPayMatchProtectionConfig(
  adminClient: AdminClient,
): Promise<BioPayMatchProtectionConfig> {
  const { data, error } = await adminClient
    .from("app_config")
    .select("key, value")
    .in("key", [...protectionConfigKeys]);

  if (error) {
    throw error;
  }

  const values = new Map<string, string>();
  for (const row of data ?? []) {
    const key = row.key?.toString().trim();
    const value = row.value?.toString().trim();
    if (key && value) {
      values.set(key, value);
    }
  }

  return {
    threshold: parseThreshold(
      values.get("BioPay_match_threshold"),
      defaultBioPayMatchProtectionConfig.threshold,
    ),
    rateWindowSeconds: parsePositiveInteger(
      values.get("BioPay_match_rate_window_seconds"),
      defaultBioPayMatchProtectionConfig.rateWindowSeconds,
    ),
    userMaxAttempts: parsePositiveInteger(
      values.get("BioPay_match_user_max_attempts"),
      defaultBioPayMatchProtectionConfig.userMaxAttempts,
    ),
    ipMaxAttempts: parsePositiveInteger(
      values.get("BioPay_match_ip_max_attempts"),
      defaultBioPayMatchProtectionConfig.ipMaxAttempts,
    ),
    missWindowSeconds: parsePositiveInteger(
      values.get("BioPay_match_miss_window_seconds"),
      defaultBioPayMatchProtectionConfig.missWindowSeconds,
    ),
    maxMissesPerWindow: parsePositiveInteger(
      values.get("BioPay_match_miss_lockout_threshold"),
      defaultBioPayMatchProtectionConfig.maxMissesPerWindow,
    ),
    lockoutSeconds: parsePositiveInteger(
      values.get("BioPay_match_lockout_seconds"),
      defaultBioPayMatchProtectionConfig.lockoutSeconds,
    ),
  };
}

export async function countRecentBioPayMatchRateEvents(
  adminClient: AdminClient,
  options: {
    scope: BioPayMatchRateScope;
    actorKey: string;
    windowStartIso: string;
    outcomes?: readonly BioPayMatchRateOutcome[];
  },
): Promise<number> {
  let query = adminClient
    .from("BioPay_match_rate_events")
    .select("id", { count: "exact", head: true })
    .eq("scope", options.scope)
    .eq("actor_key", options.actorKey)
    .gte("created_at", options.windowStartIso);

  if ((options.outcomes?.length ?? 0) == 1) {
    query = query.eq("outcome", options.outcomes![0]);
  } else if ((options.outcomes?.length ?? 0) > 1) {
    query = query.in("outcome", [...options.outcomes!]);
  }

  const result = await query;
  if (result.error) {
    throw result.error;
  }

  return result.count ?? 0;
}

export async function getLatestBioPayMatchRateEventAt(
  adminClient: AdminClient,
  options: {
    scope: BioPayMatchRateScope;
    actorKey: string;
    outcome: BioPayMatchRateOutcome;
    windowStartIso: string;
  },
): Promise<string | null> {
  const { data, error } = await adminClient
    .from("BioPay_match_rate_events")
    .select("created_at")
    .eq("scope", options.scope)
    .eq("actor_key", options.actorKey)
    .eq("outcome", options.outcome)
    .gte("created_at", options.windowStartIso)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw error;
  }

  const createdAt = data?.created_at?.toString().trim();
  return createdAt?.length ? createdAt : null;
}

export async function hashBioPayMatchActorKey(rawValue: string) {
  return await hashOtpRateActorKey(rawValue);
}

export async function recordBioPayMatchRateEvent(
  adminClient: AdminClient,
  event: {
    scope: BioPayMatchRateScope;
    actorKey: string;
    requesterUserId: string;
    outcome: BioPayMatchRateOutcome;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await adminClient
    .from("BioPay_match_rate_events")
    .insert({
      scope: event.scope,
      actor_key: event.actorKey,
      requester_user_id: event.requesterUserId,
      outcome: event.outcome,
      metadata: event.metadata ?? {},
    });

  if (error) {
    throw error;
  }
}

export { extractClientIp };
