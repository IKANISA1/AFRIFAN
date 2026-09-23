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
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
      ...Object.fromEntries(new Headers(extraHeaders)),
    },
  });
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
