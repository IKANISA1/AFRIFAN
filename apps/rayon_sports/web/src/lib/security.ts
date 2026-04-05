import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

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

export function rejectRateLimitedRequest(
  request: NextRequest,
  key: string,
  limit: number,
  windowMs: number,
) {
  const now = Date.now();
  cleanupExpiredBuckets(now);

  const bucketKey = `${key}:${getClientIp(request)}`;
  const current = rateLimitStore.get(bucketKey);

  if (current == null || current.resetAt <= now) {
    rateLimitStore.set(bucketKey, {
      count: 1,
      resetAt: now + windowMs,
    });
    return null;
  }

  if (current.count >= limit) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((current.resetAt - now) / 1000),
    );
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

  current.count += 1;
  rateLimitStore.set(bucketKey, current);
  return null;
}
