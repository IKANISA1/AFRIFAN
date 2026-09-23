// default open-next.config.ts file created by @opennextjs/cloudflare
import { defineCloudflareConfig } from "@opennextjs/cloudflare";
import kvIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/kv-incremental-cache";

export default defineCloudflareConfig({
	// Route ISR and data cache traffic through Cloudflare KV; this account does not have R2 enabled.
	incrementalCache: kvIncrementalCache,
});
