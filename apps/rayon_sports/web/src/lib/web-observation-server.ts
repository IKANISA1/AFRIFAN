import "server-only";
import { getCloudflareContext } from "@opennextjs/cloudflare";

export async function webObservationEnvironment(): Promise<Record<string, unknown>> {
  try {
    return (await getCloudflareContext({ async: true })).env as unknown as Record<string, unknown>;
  } catch {
    // Disabled/unbound local previews cannot turn public requests into provider calls.
    return {};
  }
}
