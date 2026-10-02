import { createClient } from "npm:@supabase/supabase-js@2";
import {
  getSupabasePublishableKey,
  getSupabaseSecretKey,
  getSupabaseUrl,
} from "./supabase.ts";
import { readBoundedBytes } from "./http.ts";

/** Bounds the actual SDK HTTP transport, including Storage/Auth/RPC responses. */
export const lifecycleFetch: typeof fetch = async (input, init = {}) => {
  const signal = AbortSignal.any([
    AbortSignal.timeout(15_000),
    ...(init.signal ? [init.signal] : []),
  ]);
  const response = await fetch(input, { ...init, signal });
  if (!response.body) return response;
  const bytes = await readBoundedBytes(response, {
    maxBytes: 512 * 1024,
    timeoutMs: 15_000,
    signal,
  });
  const headers = new Headers(response.headers);
  headers.delete("content-encoding");
  headers.delete("content-length");
  return new Response(new Uint8Array(bytes), {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
};
export function createLifecycleAdminClient() {
  const deadline = AbortSignal.timeout(45_000);
  return createClient(getSupabaseUrl(), getSupabaseSecretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: (input, init = {}) =>
        lifecycleFetch(input, {
          ...init,
          signal: AbortSignal.any([
            deadline,
            ...(init.signal ? [init.signal] : []),
          ]),
        }),
    },
  });
}

export function createLifecycleUserClient(authorization: string) {
  return createClient(getSupabaseUrl(), getSupabasePublishableKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: { Authorization: authorization },
      fetch: lifecycleFetch,
    },
  });
}
