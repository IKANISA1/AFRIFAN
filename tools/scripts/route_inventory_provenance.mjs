#!/usr/bin/env node
// Bind generated route inventories to source bytes. This records provenance,
// not visual review or release approval.
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const must = (condition, message) => { if (!condition) throw new Error(message); };
export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}
export const digest = (value) => createHash("sha256").update(value).digest("hex");
export function hashFile(file) {
  const hash = createHash("sha256");
  const handle = fs.openSync(file, "r");
  const buffer = Buffer.alloc(128 * 1024);
  try {
    let count;
    while ((count = fs.readSync(handle, buffer, 0, buffer.length, null)) > 0) hash.update(buffer.subarray(0, count));
  } finally { fs.closeSync(handle); }
  return hash.digest("hex");
}
export function nativeSourceSnapshot(root, app) {
  must(/^[a-z][a-z0-9_]*$/.test(app), "Invalid app slug");
  must(fs.existsSync(path.join(root, "apps", app, "assets/flavors/production.json")), "Unknown configured app");
  const paths = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "packages", `apps/${app}`, "tools/scripts", ".github/workflows", "pubspec.yaml", "pubspec.lock", ".fvmrc", "DESIGN.md"], { cwd: root, encoding: "utf8" }).split("\0").filter(Boolean)
    .filter((name) => !name.startsWith(`apps/${app}/web/`))
    .filter((name) => !name.startsWith("packages/") || /\/(?:lib|assets)\/|\/pubspec\.(?:yaml|lock)$/.test(name));
  for (const relative of [
    `apps/${app}/android/app/google-services.json`,
    `apps/${app}/android/local.properties`,
    `apps/${app}/ios/Runner/GoogleService-Info.plist`,
    `apps/${app}/ios/Flutter/Generated.xcconfig`,
    `apps/${app}/ios/Runner/GeneratedPluginRegistrant.h`,
    `apps/${app}/ios/Runner/GeneratedPluginRegistrant.m`,
    `apps/${app}/.flutter-plugins-dependencies`,
  ]) {
    if (fs.existsSync(path.join(root, relative))) paths.push(relative);
  }
  // Ignored generated Dart files and bundled assets still affect the binary.
  // Git's tracked/untracked listing alone is not a complete build-input list.
  const collect = (directory) => {
    if (!fs.existsSync(directory)) return;
    for (const name of fs.readdirSync(directory).sort()) {
      if (name.startsWith(".")) continue;
      const full = path.join(directory, name);
      const stat = fs.lstatSync(full);
      if (stat.isDirectory()) collect(full);
      else paths.push(path.relative(root, full));
    }
  };
  for (const directory of ["lib", "assets", "android/app/src"].map(relative => path.join(root, "apps", app, relative))) collect(directory);
  for (const packageFile of paths.filter((name) => /^packages\/.+\/pubspec\.yaml$/.test(name))) {
    const directory = path.dirname(path.join(root, packageFile));
    collect(path.join(directory, "lib")); collect(path.join(directory, "assets"));
  }
  const files = [...new Set(paths)].sort().map((name) => {
    const file = path.join(root, name);
    if (!fs.existsSync(file)) return { path: name, deleted: true };
    const stat = fs.lstatSync(file);
    if (stat.isSymbolicLink()) {
      must(fs.statSync(file).isFile(), "Native source directory links require an explicit build-input inventory");
      return { path: name, link: fs.readlinkSync(file), sha256: hashFile(file), bytes: fs.statSync(file).size };
    }
    return { path: name, sha256: hashFile(file), bytes: stat.size };
  });
  must(files.length > 0, "Native source input inventory is empty");
  return { app, sha256: digest(canonical(files)), files };
}
export function configuredApps(root) {
  return fs.readdirSync(path.join(root, "apps")).filter((app) => fs.existsSync(path.join(root, "apps", app, "assets/flavors/production.json"))).sort();
}

export function recordRouteInventoryProvenance({ root, stage, directory }) {
  must(["snapshot", "seal"].includes(stage), "Unknown route provenance stage");
  fs.mkdirSync(directory, { recursive: true });
  const current = Object.fromEntries(configuredApps(root).map(app => [app, nativeSourceSnapshot(root, app).sha256]));
  must(Object.keys(current).length > 0, "No configured clubs found");
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
  return Object.keys(current).length;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
  const [stage, directoryArgument] = process.argv.slice(2);
  if (!["snapshot", "seal"].includes(stage) || !directoryArgument || process.argv.length !== 4) throw new Error("Usage: route_inventory_provenance.mjs snapshot|seal <output-directory>");
  const count = recordRouteInventoryProvenance({ root, stage, directory: path.resolve(directoryArgument) });
  console.log(`Route inventory source ${stage} complete for ${count} clubs; no visual acceptance is implied.`);
}
