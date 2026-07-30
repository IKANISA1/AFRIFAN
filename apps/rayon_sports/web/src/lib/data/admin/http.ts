import { fetchWithOfflineQueue } from "@/lib/offline-queue";
import { AdminMutationConflictError } from "./helpers";

type AdminApiMethod = "GET" | "POST" | "DELETE";

type AdminApiOptions = {
  method?: AdminApiMethod;
  body?: unknown;
  query?: Record<string, string | number | boolean | null | undefined>;
  signal?: AbortSignal;
};

export class AdminApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: string | null,
  ) {
    super(message);
    this.name = "AdminApiError";
  }
}

export function isAdminMutationConflict(error: unknown) {
  return (
    error instanceof AdminMutationConflictError ||
    (error instanceof AdminApiError &&
      (error.status === 409 || error.code === "STALE_RECORD"))
  );
}

export async function requestAdminApi<T>(
  resource: string,
  options: AdminApiOptions = {},
): Promise<T> {
  const url = new URL(`/api/admin/${resource}`, window.location.origin);
  const currentParams = new URL(window.location.href).searchParams;
  const requestedClubId =
    currentParams.get("club") ?? currentParams.get("club_id");

  if (requestedClubId && options.query?.club == null && options.query?.club_id == null) {
    url.searchParams.set("club", requestedClubId);
  }

  for (const [key, value] of Object.entries(options.query ?? {})) {
    if (value == null) {
      continue;
    }
    url.searchParams.set(key, String(value));
  }

  const response = await fetch(url, {
    method: options.method ?? "GET",
    headers:
      options.body === undefined
        ? undefined
        : {
            "Content-Type": "application/json",
            "X-Africlub-CSRF": "1",
          },
    body:
      options.body === undefined ? undefined : JSON.stringify(options.body),
    credentials: "same-origin",
    cache: "no-store",
    signal: options.signal,
  }).catch(async (error) => {
    if ((options.method ?? "GET") === "GET") {
      throw error;
    }

    return fetchWithOfflineQueue(url.toString(), {
      method: options.method ?? "GET",
      headers:
        options.body === undefined
          ? undefined
          : {
              "Content-Type": "application/json",
              "X-Africlub-CSRF": "1",
            },
      body:
        options.body === undefined ? undefined : JSON.stringify(options.body),
      credentials: "same-origin",
      cache: "no-store",
      signal: options.signal,
    });
  });

  const payload = (await response.json().catch(() => ({}))) as {
    data?: T;
    error?: string;
    code?: string;
  };

  if (!response.ok) {
    throw new AdminApiError(
      payload.error ?? "Admin request failed.",
      response.status,
      payload.code ?? null,
    );
  }

  return payload.data as T;
}
