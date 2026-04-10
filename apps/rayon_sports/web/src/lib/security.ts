import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getAdminSupabase } from "@/lib/supabase/admin";

type RateLimitState = {
  count: number;
  resetAt: number;
};

declare global {
  var __gikundiroRateLimitStore: Map<string, RateLimitState> | undefined;
}

const rateLimitStore =
  globalThis.__gikundiroRateLimitStore ??
  (globalThis.__gikundiroRateLimitStore = new Map<string, RateLimitState>());

type RateLimitRpcRow = {
  allowed: boolean;
  retry_after_seconds: number;
  remaining: number;
  reset_at: string;
};

type RateLimitClient = {
  rpc: (
    fn: "consume_request_rate_limit",
    args: {
      p_bucket_key: string;
      p_limit: number;
      p_window_ms: number;
    },
  ) => Promise<{ data: RateLimitRpcRow[] | null; error: { message: string } | null }>;
};

function cleanupExpiredBuckets(now: number) {
  for (const [key, state] of rateLimitStore.entries()) {
    if (state.resetAt <= now) {
      rateLimitStore.delete(key);
    }
  }
}

export function getClientIp(request: NextRequest) {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() || "unknown";
  }

  return (
    request.headers.get("cf-connecting-ip") ||
    request.headers.get("x-real-ip") ||
    "unknown"
  );
}

function isAllowedFetchSite(request: NextRequest) {
  const fetchSite = request.headers.get("sec-fetch-site");
  return (
    fetchSite == null ||
    fetchSite === "same-origin" ||
    fetchSite === "same-site" ||
    fetchSite === "none"
  );
}

export function isSameOriginMutation(request: NextRequest) {
  const requestOrigin = request.nextUrl.origin;
  const origin = request.headers.get("origin");
  if (origin) {
    try {
      return new URL(origin).origin === requestOrigin;
    } catch {
      return false;
    }
  }

  const referer = request.headers.get("referer");
  if (referer) {
    try {
      return new URL(referer).origin === requestOrigin;
    } catch {
      return false;
    }
  }

  return isAllowedFetchSite(request);
}

export function rejectInsecureMutation(request: NextRequest) {
  if (isSameOriginMutation(request)) {
    return null;
  }

  return NextResponse.json(
    { error: "Cross-site mutation blocked." },
    { status: 403 },
  );
}

function rejectWithRetryAfter(retryAfterSeconds: number) {
  return NextResponse.json(
    { error: "Too many requests. Please try again shortly." },
    {
      status: 429,
      headers: {
        "Retry-After": String(retryAfterSeconds),
      },
    },
  );
}

function consumeLocalRateLimit(bucketKey: string, limit: number, windowMs: number) {
  const now = Date.now();
  cleanupExpiredBuckets(now);

  const current = rateLimitStore.get(bucketKey);

  if (current == null || current.resetAt <= now) {
    rateLimitStore.set(bucketKey, {
      count: 1,
      resetAt: now + windowMs,
    });
    return null;
  }

  if (current.count >= limit) {
    return Math.max(
      1,
      Math.ceil((current.resetAt - now) / 1000),
    );
  }

  current.count += 1;
  rateLimitStore.set(bucketKey, current);
  return null;
}

export async function rejectRateLimitedRequest(
  request: NextRequest,
  key: string,
  limit: number,
  windowMs: number,
  client: RateLimitClient | null = null,
) {
  const bucketKey = `${key}:${getClientIp(request)}`;
  const sharedClient =
    client ?? ((getAdminSupabase() as unknown) as RateLimitClient | null);

  if (sharedClient != null) {
    const { data, error } = await sharedClient.rpc("consume_request_rate_limit", {
      p_bucket_key: bucketKey,
      p_limit: limit,
      p_window_ms: windowMs,
    });
    const row = data?.[0] ?? null;
    if (!error && row != null) {
      if (row.allowed) {
        return null;
      }
      return rejectWithRetryAfter(Math.max(1, row.retry_after_seconds));
    }
  }

  const retryAfterSeconds = consumeLocalRateLimit(bucketKey, limit, windowMs);
  if (retryAfterSeconds == null) {
    return null;
  }
  return rejectWithRetryAfter(retryAfterSeconds);
}
