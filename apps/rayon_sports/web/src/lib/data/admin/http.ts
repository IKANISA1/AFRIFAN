import { fetchWithOfflineQueue } from "@/lib/offline-queue";

type AdminApiMethod = "GET" | "POST" | "DELETE";

type AdminApiOptions = {
  method?: AdminApiMethod;
  body?: unknown;
  query?: Record<string, string | number | boolean | null | undefined>;
};

export async function requestAdminApi<T>(
  resource: string,
  options: AdminApiOptions = {},
): Promise<T> {
  const url = new URL(`/api/admin/${resource}`, window.location.origin);
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
            "X-Gikundiro-CSRF": "1",
          },
    body:
      options.body === undefined ? undefined : JSON.stringify(options.body),
    credentials: "same-origin",
    cache: "no-store",
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
              "X-Gikundiro-CSRF": "1",
            },
      body:
        options.body === undefined ? undefined : JSON.stringify(options.body),
      credentials: "same-origin",
      cache: "no-store",
    });
  });

  const payload = (await response.json().catch(() => ({}))) as {
    data?: T;
    error?: string;
  };

  if (!response.ok) {
    throw new Error(payload.error ?? "Admin request failed.");
  }

  return payload.data as T;
}
