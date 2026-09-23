import { AdminApiError } from "@/lib/data/admin/http";

export const ADMIN_RESOURCE_TIMEOUT_MS = 12_000;

export type AdminResourceStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

export class AdminResourceTimeoutError extends Error {
  constructor(resourceLabel: string) {
    super(`${resourceLabel} timed out.`);
    this.name = "AdminResourceTimeoutError";
  }
}

export function resolveAdminResourceFailure(
  error: unknown,
  online = true,
): AdminResourceStatus {
  if (!online) {
    return "offline";
  }
  if (error instanceof AdminResourceTimeoutError) {
    return "security_timeout";
  }
  if (error instanceof AdminApiError) {
    if (error.status === 401 || error.status === 403) {
      return "permission_denied";
    }
    if (error.status === 409 || error.code === "STALE_RECORD") {
      return "conflict";
    }
    if (error.status === 504 || error.code === "ADMIN_OPERATION_TIMEOUT") {
      return "security_timeout";
    }
  }
  return "error";
}

export async function withAdminResourceTimeout<T>({
  operation,
  controller,
  resourceLabel,
  timeoutMs = ADMIN_RESOURCE_TIMEOUT_MS,
}: {
  operation: Promise<T>;
  controller: AbortController;
  resourceLabel: string;
  timeoutMs?: number;
}): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race([
      operation,
      new Promise<never>((_resolve, reject) => {
        timeoutId = setTimeout(() => {
          controller.abort();
          reject(new AdminResourceTimeoutError(resourceLabel));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId != null) {
      clearTimeout(timeoutId);
    }
  }
}
