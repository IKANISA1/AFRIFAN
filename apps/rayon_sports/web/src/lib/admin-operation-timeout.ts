export const adminOperationTimeoutMs = 12_000;

export class AdminOperationTimeoutError extends Error {
  constructor(operation: string) {
    super(
      `${operation} timed out. Check your connection and try again. No change was confirmed.`,
    );
    this.name = "AdminOperationTimeoutError";
  }
}

export async function withAdminOperationTimeout<T>(
  operation: T,
  label: string,
  timeoutMs = adminOperationTimeoutMs,
): Promise<Awaited<T>> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race<Awaited<T>>([
      Promise.resolve(operation),
      new Promise<Awaited<T>>((_resolve, reject) => {
        timeoutId = setTimeout(() => {
          reject(new AdminOperationTimeoutError(label));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId != null) {
      clearTimeout(timeoutId);
    }
  }
}

export async function fetchAdminWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit,
  label: string,
  timeoutMs = adminOperationTimeoutMs,
): Promise<Response> {
  const controller = new AbortController();
  let timedOut = false;
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timeoutId = setTimeout(() => {
      timedOut = true;
      controller.abort();
      reject(new AdminOperationTimeoutError(label));
    }, timeoutMs);
  });

  try {
    return await Promise.race([
      fetch(input, {
        ...init,
        signal: controller.signal,
      }),
      timeout,
    ]);
  } catch (caught) {
    if (timedOut) {
      throw new AdminOperationTimeoutError(label);
    }
    throw caught;
  } finally {
    if (timeoutId != null) {
      clearTimeout(timeoutId);
    }
  }
}
