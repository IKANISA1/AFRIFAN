/** Extract first-party modules from archived deployed ESZIP bundles.
 *
 * Run from repository root with:
 * deno run --allow-read --allow-write --allow-net tools/scripts/extract_supabase_edge_functions.ts
 * The output is private and git-ignored. Third-party modules remain in .body archives.
 */
import { Parser } from "https://deno.land/x/eszip@v0.109.0/mod.ts";

const base = "output/migration/cloudflare-stage0/edge-functions";
const manifest = JSON.parse(await Deno.readTextFile(`${base}/manifest.json`)) as {
  functions: Array<{ slug: string; local_file: string; sha256: string }>;
};

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (value) => value.toString(16).padStart(2, "0")).join("");
}

const entries: Array<{ slug: string; files: Array<{ path: string; bytes: number; sha256: string }> }> = [];
for (const item of manifest.functions) {
  if (!/^[a-z0-9][a-z0-9-]{0,99}$/.test(item.slug)) throw new Error("Unsafe function slug");
  const bytes = await Deno.readFile(`${base}/${item.local_file}`);
  if (hex(await crypto.subtle.digest("SHA-256", bytes)) !== item.sha256) {
    throw new Error(`Bundle hash mismatch for ${item.slug}`);
  }
  const parser = await Parser.createInstance();
  const specifiers = await parser.parseBytes(bytes);
  await parser.load();
  const files: Array<{ path: string; bytes: number; sha256: string }> = [];
  const destination = `${base}/recovered/${item.slug}`;
  await Deno.mkdir(destination, { recursive: true, mode: 0o700 });
  for (const specifier of specifiers) {
    if (!specifier.startsWith(`functions/${item.slug}/`) &&
        !specifier.startsWith("functions/_shared/")) continue;
    if (!/^functions\/[a-zA-Z0-9_./-]+$/.test(specifier) || specifier.includes("..")) {
      throw new Error(`Unsafe module path in ${item.slug}`);
    }
    const source = await parser.getModuleSource(specifier);
    if (typeof source !== "string") continue;
    const file = `${destination}/${specifier}`;
    await Deno.mkdir(file.slice(0, file.lastIndexOf("/")), { recursive: true, mode: 0o700 });
    await Deno.writeTextFile(file, source, { mode: 0o600 });
    await Deno.chmod(file, 0o600);
    const data = new TextEncoder().encode(source);
    files.push({ path: specifier, bytes: data.length,
      sha256: hex(await crypto.subtle.digest("SHA-256", data)) });
  }
  parser.free();
  entries.push({ slug: item.slug, files });
}
const destination = `${base}/recovered/manifest.json`;
await Deno.writeTextFile(destination, JSON.stringify({ functions: entries }, null, 2) + "\n", { mode: 0o600 });
await Deno.chmod(destination, 0o600);
console.log(`Recovered first-party modules from ${entries.length} deployed function bundles; ` +
  `${entries.reduce((sum, entry) => sum + entry.files.length, 0)} module copies`);
