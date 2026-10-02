import { logDiagnostic } from "./diagnostics.ts";
import { HttpError } from "./http_error.ts";

export type BodyBounds = {
  maxBytes?: number;
  timeoutMs?: number;
  allowEmpty?: boolean;
  rejectContentEncoding?: boolean;
  signal?: AbortSignal;
};

/** Bounds decoded bytes while streaming; Content-Length is only an early check. */
export async function readBoundedBytes(
  source: Request | Response,
  {
    maxBytes = 64 * 1024,
    timeoutMs = 5000,
    allowEmpty = false,
    rejectContentEncoding = source instanceof Request,
    signal,
  }: BodyBounds = {},
): Promise<Uint8Array> {
  if (rejectContentEncoding && source.headers.has("content-encoding")) {
    throw new HttpError(415, "Request must contain uncompressed data.");
  }
  const length = source.headers.get("content-length");
  if (length !== null && (!/^\d+$/.test(length) || Number(length) > maxBytes)) {
    throw new HttpError(413, "Request body is too large.");
  }
  if (allowEmpty && source.body === null && (!length || Number(length) === 0)) {
    return new Uint8Array();
  }
  if (!source.body) throw new HttpError(400, "Request body is required.");
  const reader = source.body.getReader();
  let timer: ReturnType<typeof setTimeout> | undefined;
  let onAbort: (() => void) | undefined;
  let size = 0;
  const chunks: Uint8Array[] = [];
  try {
    return await Promise.race([
      (async () => {
        for (;;) {
          const { value, done } = await reader.read();
          if (done) break;
          size += value.byteLength;
          if (size > maxBytes) {
            throw new HttpError(413, "Request body is too large.");
          }
          chunks.push(value);
        }
        const bytes = new Uint8Array(size);
        let offset = 0;
        for (const chunk of chunks) {
          bytes.set(chunk, offset);
          offset += chunk.byteLength;
        }
        return bytes;
      })(),
      new Promise<never>((_, reject) => {
        onAbort = () => {
          void reader.cancel().catch(() => {});
          reject(
            signal?.reason instanceof HttpError
              ? signal.reason
              : new HttpError(408, "Request body timed out."),
          );
        };
        if (signal?.aborted) onAbort();
        else signal?.addEventListener("abort", onAbort, { once: true });
        timer = setTimeout(
          () => reject(new HttpError(408, "Request body timed out.")),
          timeoutMs,
        );
      }),
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
    if (onAbort) signal?.removeEventListener("abort", onAbort);
    // Never wait for a hostile stream's cancellation acknowledgement.
    void reader.cancel().catch(() => {});
  }
}

export async function readBoundedText(
  source: Request | Response,
  bounds: BodyBounds = {},
): Promise<string> {
  if (bounds.allowEmpty && source.body === null) {
    await readBoundedBytes(source, bounds);
    return "";
  }
  if (
    !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(
      source.headers.get("content-type") ?? "",
    )
  ) {
    throw new HttpError(415, "Request must contain JSON.");
  }
  const bytes = await readBoundedBytes(source, bounds);
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new HttpError(400, "Request must contain valid UTF-8 JSON.");
  }
}

export async function readBoundedJson<T = Record<string, unknown>>(
  source: Request | Response,
  bounds: BodyBounds = {},
): Promise<T> {
  const text = await readBoundedText(source, bounds);
  if (!text && bounds.allowEmpty) return {} as T;
  try {
    const data = JSON.parse(text);
    if (data === null || typeof data !== "object" || Array.isArray(data)) {
      throw new Error();
    }
    return data as T;
  } catch {
    throw new HttpError(400, "Request must contain a valid JSON object.");
  }
}

/** One deadline covers provider headers and bounded decoded response bytes. */
export async function fetchBoundedJson<T = Record<string, unknown>>(
  fetchFn: typeof fetch,
  url: string,
  init: RequestInit,
  { maxBytes = 256 * 1024, timeoutMs = 15000, acceptErrorResponse = false }:
    & BodyBounds
    & { acceptErrorResponse?: boolean } = {},
): Promise<T> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      (async () => {
        const response = await fetchFn(url, {
          ...init,
          signal: controller.signal,
        });
        if (!response.ok && !acceptErrorResponse) {
          void response.body?.cancel().catch(() => {});
          throw new HttpError(502, "Provider request failed.");
        }
        return await readBoundedJson<T>(response, {
          maxBytes,
          timeoutMs,
          rejectContentEncoding: false,
          signal: controller.signal,
        });
      })(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          const error = new HttpError(504, "Provider request timed out.");
          controller.abort(error);
          reject(error);
        }, timeoutMs);
      }),
    ]);
  } catch (error) {
    logDiagnostic("error", "edge_provider_request_failed", error);
    if (error instanceof HttpError && [502, 504].includes(error.status)) {
      throw error;
    }
    throw new HttpError(502, "Provider request failed.");
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}
