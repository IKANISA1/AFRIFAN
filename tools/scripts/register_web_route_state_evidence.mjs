#!/usr/bin/env node
// Stage current browser evidence for review. This command never grants acceptance.
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { validateProductionBuild } from "../../apps/rayon_sports/web/scripts/web-build-provenance.mjs";

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const webRelative = "apps/rayon_sports/web";
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const assert = (condition, message) => { if (!condition) throw new Error(message); };
const equal = (left, right) => JSON.stringify(left) === JSON.stringify(right);
const relative = (root, file) => path.relative(root, file).split(path.sep).join("/");
const filename = (name) => typeof name === "string" && /^[a-zA-Z0-9_.-]+$/.test(name) && ![".", ".."].includes(name);
const sha = (value) => typeof value === "string" && /^[a-f0-9]{64}$/.test(value);

function below(root, file) {
  const result = path.relative(root, file);
  return result !== "" && result !== ".." && !result.startsWith(`..${path.sep}`) && !path.isAbsolute(result);
}

function regular(file) {
  assert(fs.lstatSync(file).isFile(), `Evidence must be a regular file: ${file}`);
  return fs.readFileSync(file);
}

export async function validateWebCapture(root, directory, binding) {
  const output = path.join(root, "output");
  const full = path.resolve(root, directory);
  assert(below(output, full), "Capture directory must be inside repository output/");
  assert(fs.realpathSync(full) === full, "Capture path must not traverse symlinks");
  const provenanceBytes = regular(path.join(full, "runtime-provenance.json"));
  const provenance = JSON.parse(provenanceBytes);
  assert(provenance.schema_version === "1.0" && provenance.status === "capture_complete_unreviewed", "Capture is incomplete or has unsupported provenance");
  assert(provenance.acceptance === "unreviewed_engineering_evidence" && provenance.data_source === "controlled_synthetic_browser_states", "Expected explicitly unreviewed synthetic browser evidence");
  assert(equal(provenance.production_build, binding) && provenance.next_build_id === binding.build_id, "Capture does not match the current sealed production build");
  assert(Number.isFinite(Date.parse(provenance.started_at)) && Date.parse(provenance.finished_at) >= Date.parse(provenance.started_at) && Date.parse(provenance.started_at) >= Date.parse(binding.finished_at), "Capture timestamps do not follow its completed build");
  assert(typeof provenance.project === "string" && provenance.project.length > 0 && ["chromium", "firefox", "webkit"].includes(provenance.browser?.name) && typeof provenance.browser.version === "string", "Capture lacks its real browser/project identity");
  const testFile = path.resolve(root, provenance.test_source_file ?? "");
  assert(below(path.join(root, webRelative, "e2e"), testFile), "Capture test source must be a web E2E file");
  for (const [file, expected] of [
    [testFile, provenance.test_source_sha256],
    [path.join(root, webRelative, "e2e/state-evidence-provenance.ts"), provenance.provenance_helper_sha256],
    [path.join(root, webRelative, "package-lock.json"), provenance.package_lock_sha256],
  ]) assert(sha(expected) && hash(regular(file)) === expected, `Capture source is stale: ${relative(root, file)}`);

  assert(Array.isArray(provenance.artifacts) && provenance.artifacts.length > 0, "Capture has no artifact inventory");
  const artifacts = new Map();
  for (const item of provenance.artifacts) {
    assert(filename(item.file) && item.file !== "runtime-provenance.json" && sha(item.sha256) && !artifacts.has(item.file), "Invalid or repeated capture artifact");
    assert(hash(regular(path.join(full, item.file))) === item.sha256, `Capture artifact changed: ${item.file}`);
    artifacts.set(item.file, item.sha256);
  }
  const actual = fs.readdirSync(full).filter((file) => file !== "runtime-provenance.json").sort();
  assert(equal(actual, [...artifacts.keys()].sort()), "Capture directory differs from its completed artifact inventory");
  const manifests = actual.filter((file) => file.endsWith("state-evidence.json"));
  assert(manifests.length === 1 && artifacts.has("capture-profiles.json"), "Capture needs one state manifest and recorded profiles");
  const manifest = read(path.join(full, manifests[0]));
  const profiles = read(path.join(full, "capture-profiles.json"));
  assert(Array.isArray(manifest.captures) && manifest.captures.length > 0, "No declared state captures");
  assert(Array.isArray(manifest.applicable_states) && Array.isArray(manifest.not_applicable_states), "State applicability must be explicit");
  assert(new Set(manifest.applicable_states).size === manifest.applicable_states.length && !manifest.applicable_states.some((state) => manifest.not_applicable_states.includes(state)), "Contradictory state applicability");
  if (manifest.not_applicable_states.length) assert(typeof manifest.not_applicable_rationale === "string" && manifest.not_applicable_rationale.trim().length > 0, "N/A states require a reason");
  const require = createRequire(path.join(repository, webRelative, "package.json"));
  const sharp = require("sharp");
  const screenshots = [], cells = new Set(), baseFiles = new Set();
  for (const capture of manifest.captures) {
    const route = capture.route ?? manifest.route;
    assert(typeof route === "string" && /^\/(?!\/)/.test(route) && !/[?#]/.test(route), "Capture must identify a local route");
    assert(typeof capture.state === "string" && (manifest.applicable_states.includes(capture.state) || ["responsive_tablet", "responsive_compact"].includes(capture.state)), "Capture state is outside its applicability catalog");
    const cell = `${route}|${capture.state}`;
    assert(!cells.has(cell) && filename(capture.file) && !baseFiles.has(capture.file), "Repeated state or screenshot in capture manifest");
    cells.add(cell); baseFiles.add(capture.file);
    const profile = profiles[capture.file];
    assert(profile && equal(profile, capture.capture_profile), "State manifest lacks the original recorded capture profile");
    for (const value of [profile.viewport?.width, profile.viewport?.height, profile.document?.width, profile.document?.height, profile.device_pixel_ratio]) assert(Number.isFinite(value) && value > 0, "Invalid capture viewport/document/DPR");
    assert(typeof profile.user_agent === "string" && ["dark", "light"].includes(profile.prefers_color_scheme) && typeof profile.prefers_reduced_motion === "boolean", "Capture profile lacks input/media identity");
    assert(Array.isArray(profile.tiles) && profile.tiles.length > 0, "Capture has no screenshot coverage");
    let y = 0;
    for (const tile of profile.tiles) {
      assert(filename(tile.file) && tile.file.endsWith(".png") && artifacts.has(tile.file) && tile.y === y && Number.isFinite(tile.height) && tile.height > 0, "Invalid or discontinuous screenshot tile");
      assert(!screenshots.some((entry) => entry.file === tile.file), "Screenshot tile is used twice");
      const file = path.join(full, tile.file);
      const image = sharp(file, { failOn: "warning", limitInputPixels: 200_000_000 });
      const metadata = await image.metadata();
      await image.stats(); // Decode the image, including compressed pixel data.
      const width = (profile.full_page ? profile.document.width : profile.viewport.width) * profile.device_pixel_ratio;
      assert(metadata.format === "png" && Math.abs(metadata.width - width) <= 1 && Math.abs(metadata.height - tile.height * profile.device_pixel_ratio) <= 1, `Screenshot dimensions do not match the recorded profile: ${tile.file}`);
      screenshots.push({ file: tile.file, sha256: artifacts.get(tile.file), width: metadata.width, height: metadata.height });
      y += tile.height;
    }
    assert(y === (profile.full_page ? profile.document.height : profile.viewport.height), "Screenshot coverage is incomplete");
  }
  assert(equal([...baseFiles].sort(), Object.keys(profiles).sort()), "Unexpected capture profiles");
  assert(equal(screenshots.map((entry) => entry.file).sort(), actual.filter((file) => file.endsWith(".png")).sort()), "Undeclared screenshot files");
  const routes = [...new Set([...cells].map((cell) => cell.split("|")[0]))];
  for (const route of routes) for (const state of manifest.applicable_states) assert(cells.has(`${route}|${state}`), `Missing applicable capture: ${route}|${state}`);
  return { directory: relative(root, full), provenance_sha256: hash(provenanceBytes), manifest: manifests[0],
    project: provenance.project, browser: provenance.browser, production_build: binding, source_commit_at_capture: provenance.source_commit,
    tracked_worktree_diff_sha256_at_capture: provenance.tracked_worktree_diff_sha256,
    test_source_file: provenance.test_source_file, test_source_sha256: provenance.test_source_sha256,
    helper_sha256: provenance.provenance_helper_sha256, captures: manifest.captures, screenshots,
    artifact_integrity: "verified", review_status: "pending", applicability_review: "pending",
    quality_results: { visual_fidelity: "unverified", usability: "unverified", accessibility: "unverified", performance: "unverified", resilience: "unverified" },
    scope: "Synthetic browser evidence for review. Recorded test assertions are not independent visual, usability, accessibility, performance, resilience or release acceptance." };
}

export async function stageWebEvidence(root, args) {
  assert(!args.includes("--admit-reviewed"), "--admit-reviewed cannot grant acceptance. Stage captures for a named independent review; no review or acceptance is generated by this command.");
  const directories = args.filter((arg) => arg.startsWith("--capture-dir=")).map((arg) => arg.slice(14));
  const outputs = args.filter((arg) => arg.startsWith("--output=")).map((arg) => arg.slice(9));
  assert(args.length === directories.length + outputs.length && directories.length > 0 && outputs.length === 1 && new Set(directories).size === directories.length,
    "Use --capture-dir=output/<completed-capture> (repeat as needed) --output=output/<new-review-packet.json>");
  const target = path.resolve(root, outputs[0]);
  assert(below(path.join(root, "output"), target) && target.endsWith(".json"), "Review packet must be a new JSON file under output/");
  assert(!fs.existsSync(target), "Review packet already exists; choose a new path to preserve previous review work");
  let ancestor = path.dirname(target);
  while (!fs.existsSync(ancestor)) ancestor = path.dirname(ancestor);
  assert(fs.realpathSync(ancestor) === ancestor, "Review packet path must not traverse symlinks");
  const binding = validateProductionBuild(path.join(root, webRelative));
  const captures = [];
  for (const directory of directories) captures.push(await validateWebCapture(root, directory, binding));
  assert(equal(binding, validateProductionBuild(path.join(root, webRelative))), "Build changed while validating captures");
  fs.mkdirSync(path.dirname(target), { recursive: true });
  assert(fs.realpathSync(path.dirname(target)) === path.dirname(target), "Review packet path must not traverse symlinks");
  const packet = { schema_version: 1, staged_at: new Date().toISOString(), review_status: "pending", acceptance: "unreviewed_engineering_evidence", production_build: binding,
    governance_registries_changed: false, captures };
  fs.writeFileSync(target, JSON.stringify(packet, null, 2) + "\n", { flag: "wx" });
  return { packet: relative(root, target), captures: captures.length, screenshots: captures.reduce((sum, item) => sum + item.screenshots.length, 0), review_status: "pending", governance_registries_changed: false };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(await stageWebEvidence(repository, process.argv.slice(2)), null, 2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
