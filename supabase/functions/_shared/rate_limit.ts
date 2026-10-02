import { HttpError } from "./auth.ts";

type AdminClientLike = {
  rpc(name: string, params: Record<string, unknown>): PromiseLike<{
    data: unknown;
    error: unknown;
  }>;
};

export type RateLimitConfig = {
  /** Maximum admitted requests in any rolling window (1–1000). */
  maxRequests: number;
  /** Rolling window in seconds (1–86400). */
  windowSeconds: number;
  /** Server-resolved tenant scope; omit for a global per-subject budget. */
  clubId?: number;
};

export type RateLimitResult = {
  allowed: boolean;
  retryAfterSeconds: number;
};

/**
 * Atomic, exact sliding-window admission. The service-only RPC locks one bounded
 * bucket and records an accepted request in the same transaction. Telemetry is
 * deliberately not an authorization dependency. Store errors/timeouts fail closed.
 */
export async function enforceRateLimit(
  adminClient: AdminClientLike,
  userId: string,
  functionName: string,
  config: RateLimitConfig,
): Promise<void> {
  if (
    !userId || userId.length > 128 ||
    !/^[a-z][a-z0-9_-]{0,79}$/.test(functionName) ||
    !Number.isInteger(config.maxRequests) || config.maxRequests < 1 ||
    config.maxRequests > 1000 || !Number.isInteger(config.windowSeconds) ||
    config.windowSeconds < 1 || config.windowSeconds > 86400 ||
    (config.clubId !== undefined &&
      (!Number.isSafeInteger(config.clubId) || config.clubId < 1))
  ) {
    throw new HttpError(503, "Rate admission is unavailable.");
  }

  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    const result = await Promise.race([
      Promise.resolve(adminClient.rpc("consume_edge_rate_limit", {
        // JSON tuple encoding prevents delimiter collisions between subjects,
        // functions and trusted tenant contexts.
        p_bucket_key: JSON.stringify([
          userId,
          functionName,
          config.clubId ?? null,
        ]),
        p_limit: config.maxRequests,
        p_window_seconds: config.windowSeconds,
      })),
      new Promise<never>((_, reject) => {
        timeout = setTimeout(
          () => reject(new Error("Admission deadline")),
          5000,
        );
      }),
    ]);
    if (
      result.error || !Array.isArray(result.data) || result.data.length !== 1
    ) {
      throw new Error("Admission store failed");
    }
    const decision = result.data[0];
    if (
      !decision || typeof decision !== "object" ||
      typeof decision.allowed !== "boolean" ||
      !Number.isInteger(decision.retry_after_seconds) ||
      decision.retry_after_seconds < 0 ||
      decision.retry_after_seconds > config.windowSeconds ||
      (decision.allowed && decision.retry_after_seconds !== 0) ||
      (!decision.allowed && decision.retry_after_seconds < 1)
    ) {
      throw new Error("Invalid admission result");
    }
    if (!decision.allowed) {
      throw new HttpError(
        429,
        "Rate limit exceeded. Please wait before trying again.",
        {
          "Retry-After": String(decision.retry_after_seconds),
        },
      );
    }
  } catch (error) {
    if (error instanceof HttpError && error.status === 429) throw error;
    throw new HttpError(503, "Rate admission is unavailable.", {
      "Retry-After": "5",
    });
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}
