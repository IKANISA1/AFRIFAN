import { NextResponse } from "next/server";

export const controlledApiOperationTimeoutMs = 8_000;

export class ControlledApiTimeoutError extends Error {
  constructor() {
    super("API operation timed out.");
    this.name = "ControlledApiTimeoutError";
  }
}

export async function withControlledApiTimeout<T>(
  operation: PromiseLike<T>,
  timeoutMs = controlledApiOperationTimeoutMs,
): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race([
      Promise.resolve(operation),
      new Promise<T>((_resolve, reject) => {
        timeoutId = setTimeout(() => {
          reject(new ControlledApiTimeoutError());
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId != null) {
      clearTimeout(timeoutId);
    }
  }
}

export function controlledApiJson(
  body: unknown,
  status = 200,
  extraHeaders: HeadersInit = {},
) {
  const headers = new Headers(extraHeaders);
  headers.set("Cache-Control", "no-store");
  headers.set("CDN-Cache-Control", "no-store");
  headers.set("Cloudflare-CDN-Cache-Control", "no-store");
  return NextResponse.json(body, {
    status,
    headers,
  });
}

/** Only explicitly sanitized public GET projections may select these bounded cache policies. */
export function controlledPublicApiJson(body: unknown, status: number, extraHeaders: HeadersInit) {
  const headers = new Headers(extraHeaders);
  const allowed = [
    "public, max-age=0, s-maxage=60, stale-while-revalidate=120",
    "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
    "public, max-age=0, s-maxage=300, stale-while-revalidate=600",
  ];
  if (status !== 200 || [...headers.keys()].length !== 1 ||
    !allowed.includes(headers.get("cache-control") ?? "")) throw Error("invalid_public_cache_policy");
  return NextResponse.json(body, { status, headers });
}

function isConflict(error: unknown) {
  if (typeof error !== "object" || error == null) {
    return false;
  }

  const candidate = error as { code?: unknown; status?: unknown };
  return candidate.code === "23505" || candidate.status === 409;
}

function isPermissionDenied(error: unknown) {
  if (typeof error !== "object" || error == null) {
    return false;
  }

  const candidate = error as { code?: unknown; status?: unknown };
  return (
    candidate.status === 403 ||
    candidate.code === "42501" ||
    candidate.code === "PGRST301"
  );
}

export function controlledApiFailureResponse(
  error: unknown,
  namespace: string,
) {
  if (error instanceof ControlledApiTimeoutError) {
    return controlledApiJson(
      {
        code: `${namespace}_TIMEOUT`,
        error: "The operation timed out. Check current data before retrying.",
        retryable: true,
        change_confirmed: false,
      },
      504,
    );
  }

  if (isConflict(error)) {
    return controlledApiJson(
      {
        code: `${namespace}_CONFLICT`,
        error:
          "The operation conflicts with current data. Refresh before retrying.",
        retryable: true,
        change_confirmed: false,
      },
      409,
    );
  }

  if (isPermissionDenied(error)) {
    return controlledApiJson(
      {
        code: `${namespace}_ACCESS_DENIED`,
        error: "Access denied.",
        retryable: false,
        change_confirmed: false,
      },
      403,
    );
  }

  return controlledApiJson(
    {
      code: `${namespace}_FAILED`,
      error: "The operation could not be completed.",
      retryable: true,
      change_confirmed: false,
    },
    502,
  );
}
