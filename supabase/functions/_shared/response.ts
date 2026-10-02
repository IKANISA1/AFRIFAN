import { logDiagnostic } from "./diagnostics.ts";
import { HttpError } from "./auth.ts";

export interface ApiErrorBody {
  error: string;
  code?: string;
  details?: Record<string, unknown>;
}

const privateHeaders = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "private, no-store",
  "Pragma": "no-cache",
  "X-Content-Type-Options": "nosniff",
  "Vary": "Origin",
};
const statusCodes: Record<number, string> = {
  400: "INVALID_REQUEST",
  401: "UNAUTHORIZED",
  403: "FORBIDDEN",
  404: "NOT_FOUND",
  405: "METHOD_NOT_ALLOWED",
  408: "REQUEST_TIMEOUT",
  409: "CONFLICT",
  413: "PAYLOAD_TOO_LARGE",
  415: "UNSUPPORTED_MEDIA_TYPE",
  429: "RATE_LIMITED",
  500: "INTERNAL_ERROR",
  502: "PROVIDER_UNAVAILABLE",
  503: "SERVICE_UNAVAILABLE",
  504: "PROVIDER_TIMEOUT",
};

export function jsonOk<T>(data: T, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: privateHeaders,
  });
}
export function jsonCreated<T>(data: T): Response {
  return jsonOk(data, 201);
}

export function jsonError(
  message: string,
  status = 400,
  code?: string,
  details?: Record<string, unknown>,
): Response {
  // SQL/provider/configuration details must never cross the public error boundary.
  const body: ApiErrorBody = {
    error: status >= 500
      ? "The service could not complete this request."
      : message,
    code: code ?? statusCodes[status] ?? "REQUEST_FAILED",
  };
  if (details && status < 500) body.details = details;
  return jsonOk(body, status);
}
export function errorResponse(
  error: unknown,
  fallback = "The request could not be completed.",
  code?: string,
): Response {
  if (!(error instanceof HttpError)) return jsonError(fallback, 500);
  const response = jsonError(error.message, error.status, code);
  // Typed callers can preserve Retry-After without overriding private/CORS headers.
  const retryAfter = error.headers["Retry-After"] ??
    error.headers["retry-after"];
  if (retryAfter && /^\d{1,6}$/.test(retryAfter)) {
    response.headers.set("Retry-After", retryAfter);
  }
  return response;
}
export function jsonUnauthorized(message = "Unauthorized"): Response {
  return jsonError(message, 401, "UNAUTHORIZED");
}
export function jsonForbidden(message = "Forbidden"): Response {
  return jsonError(message, 403, "FORBIDDEN");
}
export function jsonNotFound(message = "Not found"): Response {
  return jsonError(message, 404, "NOT_FOUND");
}
export function jsonRateLimit(message = "Rate limit exceeded"): Response {
  return jsonError(message, 429, "RATE_LIMITED");
}
export function jsonInternal(message = "Internal error"): Response {
  return jsonError(message, 500, "INTERNAL_ERROR");
}

const allowedHeaders = new Set([
  "authorization",
  "x-client-info",
  "apikey",
  "content-type",
]);
function approvedOrigin(request?: Request): string | null {
  const origin = request?.headers.get("origin");
  if (!origin) return null; // Native/server callers retain their separate authentication.
  const configured = (Deno.env.get("EDGE_ALLOWED_ORIGINS") ?? "").split(",")
    .map((s) => s.trim()).filter(Boolean);
  for (const value of configured) {
    let parsed: URL;
    try {
      parsed = new URL(value);
    } catch {
      throw new HttpError(503, "Browser access is unavailable.");
    }
    if (
      !["https:", "http:"].includes(parsed.protocol) || parsed.origin !== value
    ) throw new HttpError(503, "Browser access is unavailable.");
  }
  if (!configured.includes(origin)) {
    throw new HttpError(403, "Browser origin is not allowed.");
  }
  return origin;
}
export function corsHeaders(request?: Request): Record<string, string> {
  const origin = approvedOrigin(request);
  return {
    "Vary": "Origin",
    ...(origin ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Headers": [...allowedHeaders].join(", "),
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  };
}
export function corsPreflightResponse(request?: Request): Response {
  try {
    const headers = corsHeaders(request);
    const method = request?.headers.get("access-control-request-method");
    const requestedHeaders =
      request?.headers.get("access-control-request-headers")?.split(",").map((
        s,
      ) => s.trim().toLowerCase()) ?? [];
    if (
      (method && !["GET", "POST"].includes(method)) ||
      requestedHeaders.some((h) => !allowedHeaders.has(h))
    ) {
      throw new HttpError(403, "Browser request is not allowed.");
    }
    return new Response(null, {
      status: 204,
      headers: { ...privateHeaders, ...headers },
    });
  } catch (error) {
    return errorResponse(error);
  }
}
/** Every deployed Edge entrypoint uses the same exact-origin and private boundary. */
export function withEdgeBoundary(
  handler: (request: Request) => Response | Promise<Response>,
) {
  return async (request: Request): Promise<Response> => {
    try {
      const cors = corsHeaders(request); // Reject an unapproved origin before handler work.
      if (request.method === "OPTIONS") return corsPreflightResponse(request);
      const response = await handler(request);
      const headers = new Headers(response.headers);
      for (
        const [key, value] of Object.entries({ ...privateHeaders, ...cors })
      ) headers.set(key, value);
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers,
      });
    } catch (error) {
      if (!(error instanceof HttpError) || error.status >= 500) {
        logDiagnostic("error", "edge_request_boundary_failed", error);
      }
      return errorResponse(error);
    }
  };
}

/** Operator summaries may contain SDK/provider errors; retain counters and stable failure text. */
export function publicOperationData(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(publicOperationData);
  if (!value || typeof value !== "object") return value;
  const out: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    if (
      ["error", "error_message", "last_error"].includes(key) &&
      typeof item === "string"
    ) {
      out[key] = "The operation could not be completed.";
    } else if (key === "errors" && Array.isArray(item)) {
      out[key] = item.slice(0, 10).map(() =>
        "The operation could not be completed."
      );
    } else out[key] = publicOperationData(item);
  }
  return out;
}
