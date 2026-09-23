import { NextResponse } from "next/server";

export const edgeFunctionOperationTimeoutMs = 12_000;

export class EdgeFunctionOperationTimeoutError extends Error {
  constructor() {
    super("Edge Function operation timed out.");
    this.name = "EdgeFunctionOperationTimeoutError";
  }
}

export async function withEdgeFunctionOperationTimeout<T>(
  operation: PromiseLike<T>,
  timeoutMs = edgeFunctionOperationTimeoutMs,
): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race([
      Promise.resolve(operation),
      new Promise<T>((_resolve, reject) => {
        timeoutId = setTimeout(() => {
          reject(new EdgeFunctionOperationTimeoutError());
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId != null) {
      clearTimeout(timeoutId);
    }
  }
}

function uncachedJson(body: unknown, status: number) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
    },
  });
}

export function edgeFunctionEmptyResponse(error: string) {
  return uncachedJson(
    {
      code: "EDGE_FUNCTION_EMPTY",
      error,
      retryable: false,
      change_confirmed: false,
    },
    400,
  );
}

export function edgeFunctionConfigurationResponse() {
  return uncachedJson(
    {
      code: "EDGE_FUNCTION_UNAVAILABLE",
      error: "The operation is temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
    503,
  );
}

function edgeFunctionAuthorizationResponse(status: 401 | 403) {
  return uncachedJson(
    status === 401
      ? {
          code: "EDGE_FUNCTION_AUTHENTICATION_REQUIRED",
          error: "Authentication is required.",
        }
      : {
          code: "EDGE_FUNCTION_ACCESS_DENIED",
          error: "Access denied.",
        },
    status,
  );
}

function edgeFunctionConflictResponse() {
  return uncachedJson(
    {
      code: "EDGE_FUNCTION_CONFLICT",
      error:
        "The operation conflicts with current data. Refresh before retrying.",
      retryable: true,
      change_confirmed: false,
    },
    409,
  );
}

export function edgeFunctionFailureResponse(error: unknown) {
  if (error instanceof EdgeFunctionOperationTimeoutError) {
    return uncachedJson(
      {
        code: "EDGE_FUNCTION_TIMEOUT",
        error:
          "The operation timed out. Check current data before retrying.",
        retryable: true,
        change_confirmed: false,
      },
      504,
    );
  }

  return uncachedJson(
    {
      code: "EDGE_FUNCTION_UNAVAILABLE",
      error: "The operation could not be completed.",
      retryable: true,
      change_confirmed: false,
    },
    502,
  );
}

export async function proxyEdgeFunctionRequest({
  fetcher,
  url,
  init,
  timeoutMs = edgeFunctionOperationTimeoutMs,
}: {
  fetcher: typeof fetch;
  url: string;
  init: RequestInit;
  timeoutMs?: number;
}) {
  const controller = new AbortController();

  try {
    const upstream = await withEdgeFunctionOperationTimeout(
      fetcher(url, {
        ...init,
        signal: controller.signal,
      }),
      timeoutMs,
    );
    if (upstream.status === 401 || upstream.status === 403) {
      return edgeFunctionAuthorizationResponse(upstream.status);
    }
    if (upstream.status === 409) {
      return edgeFunctionConflictResponse();
    }
    if (upstream.status >= 500) {
      return edgeFunctionFailureResponse(
        new Error("Edge Function returned an unsuccessful response."),
      );
    }
    const responseText = await withEdgeFunctionOperationTimeout(
      upstream.text(),
      timeoutMs,
    );
    const contentType =
      upstream.headers.get("content-type") ?? "application/json";

    return new NextResponse(responseText, {
      status: upstream.status,
      headers: {
        "Content-Type": contentType,
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    controller.abort();
    return edgeFunctionFailureResponse(error);
  }
}
