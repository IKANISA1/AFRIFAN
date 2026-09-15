#!/usr/bin/env node
// The route generator calls snapshot before Flutter and seal only after it
// succeeds. Neither operation writes mobile reviews or acceptance records.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { configuredApps, nativeSourceSnapshot, hashFile } from "./validate_mobile_design_release.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const [stage, directoryArgument] = process.argv.slice(2);
if (!["snapshot", "seal"].includes(stage) || !directoryArgument || process.argv.length !== 4) throw new Error("Usage: route_inventory_provenance.mjs snapshot|seal <output-directory>");
const directory = path.resolve(directoryArgument);
fs.mkdirSync(directory, { recursive: true });
const current = Object.fromEntries(configuredApps(root).map(app => [app, nativeSourceSnapshot(root, app).sha256]));
const beforePath = path.join(directory, "native-sources-before.json");
if (stage === "snapshot") {
  fs.writeFileSync(beforePath, JSON.stringify({ captured_at: new Date().toISOString(), native_sources: current }, null, 2) + "\n");
} else {
  const before = JSON.parse(fs.readFileSync(beforePath, "utf8"));
  if (JSON.stringify(before.native_sources) !== JSON.stringify(current)) throw new Error("Source changed while generating the route inventory; regenerate on a stable checkout.");
  const inventory = path.join(directory, "route-inventory.json");
  const value = JSON.parse(fs.readFileSync(inventory, "utf8"));
  if (!Array.isArray(value.routes) || value.routes.length === 0 || value.duplicate_keys?.length !== 0) throw new Error("Route discovery is empty or has duplicates.");
  fs.writeFileSync(path.join(directory, "route-inventory-provenance.json"), JSON.stringify({ generated_at: new Date().toISOString(), generator: "packages/app_registry/tool/generate_route_inventory.dart", route_inventory_sha256: hashFile(inventory), native_sources: current }, null, 2) + "\n");
}
console.log(`Route inventory source ${stage} complete for ${Object.keys(current).length} clubs; no visual acceptance is implied.`);
