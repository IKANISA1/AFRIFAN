import { NextResponse } from "next/server";
import {
  authCallbackOperationTimeoutMs,
  resolveNextPath,
  type AuthCallbackState,
} from "@/lib/auth-callback";
import {
  ControlledApiTimeoutError,
  withControlledApiTimeout,
} from "@/lib/controlled-api-response";
import { getServerSupabase } from "@/lib/supabase/server";

function authCallbackRedirect(
  url: URL,
  nextPath: string,
  failure?: { error: string; state: AuthCallbackState },
) {
  const destination = new URL(nextPath, url.origin);
  if (failure) {
    destination.searchParams.set("error", failure.error);
    destination.searchParams.set("state", failure.state);
  }

  const response = NextResponse.redirect(destination);
  response.headers.set("Cache-Control", "no-store");
  response.headers.set("Referrer-Policy", "no-referrer");
  return response;
}

function isPermissionDenied(error: unknown) {
  if (typeof error !== "object" || error == null) {
    return false;
  }
  const candidate = error as { code?: unknown; status?: unknown };
  return (
    candidate.status === 401 ||
    candidate.status === 403 ||
    candidate.code === "42501" ||
    candidate.code === "PGRST301"
  );
}

function isConflict(error: unknown) {
  if (typeof error !== "object" || error == null) {
    return false;
  }
  const candidate = error as { code?: unknown; status?: unknown };
  return candidate.status === 409 || candidate.code === "23505";
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const nextPath = resolveNextPath(url.searchParams.get("next"), url.origin);

  if (code == null) {
    return authCallbackRedirect(url, nextPath, {
      error: "missing_auth_code",
      state: "empty",
    });
  }

  try {
    const supabase = await withControlledApiTimeout(
      getServerSupabase(),
      authCallbackOperationTimeoutMs,
    );
    if (supabase == null) {
      return authCallbackRedirect(url, nextPath, {
        error: "auth_service_unavailable",
        state: "error",
      });
    }

    const { error } = await withControlledApiTimeout(
      supabase.auth.exchangeCodeForSession(code),
      authCallbackOperationTimeoutMs,
    );
    if (error) {
      if (isPermissionDenied(error)) {
        return authCallbackRedirect(url, nextPath, {
          error: "auth_access_denied",
          state: "permission_denied",
        });
      }
      if (isConflict(error)) {
        return authCallbackRedirect(url, nextPath, {
          error: "auth_session_conflict",
          state: "conflict",
        });
      }
      return authCallbackRedirect(url, nextPath, {
        error: "auth_callback_failed",
        state: "error",
      });
    }

    return authCallbackRedirect(url, nextPath);
  } catch (error) {
    if (error instanceof ControlledApiTimeoutError) {
      return authCallbackRedirect(url, nextPath, {
        error: "auth_callback_timeout",
        state: "security_timeout",
      });
    }
    if (isPermissionDenied(error)) {
      return authCallbackRedirect(url, nextPath, {
        error: "auth_access_denied",
        state: "permission_denied",
      });
    }
    if (isConflict(error)) {
      return authCallbackRedirect(url, nextPath, {
        error: "auth_session_conflict",
        state: "conflict",
      });
    }
    return authCallbackRedirect(url, nextPath, {
      error: "auth_callback_failed",
      state: "error",
    });
  }
}
