/**
 * Shared JSON response helpers for all Edge Functions.
 * Ensures consistent error shapes across the backend.
 */

export interface ApiErrorBody {
  error: string;
  code?: string;
  details?: Record<string, unknown>;
}

export function jsonOk<T>(data: T, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
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
  const body: ApiErrorBody = { error: message };
  if (code) body.code = code;
  if (details) body.details = details;

  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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

/** CORS preflight response for browser-based callers. */
export function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  };
}

export function corsPreflightResponse(): Response {
  return new Response("ok", { headers: corsHeaders() });
}
