import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { stageWebEvidence, validateWebCapture } from "./register_web_route_state_evidence.mjs";
const require = createRequire(new URL("../../apps/rayon_sports/web/package.json", import.meta.url));
const sharp = require("sharp");
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
const json = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value)); };

async function fixture(t) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "africlub-review-test-")));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const web = path.join(root, "apps/rayon_sports/web"), dir = path.join(root, "output/capture");
  fs.mkdirSync(path.join(web, "e2e"), { recursive: true }); fs.mkdirSync(dir, { recursive: true });
  const source = "// Isolated validator fixture; no browser or product acceptance.\n";
  for (const file of ["e2e/example.spec.ts", "e2e/state-evidence-provenance.ts", "package-lock.json"]) fs.writeFileSync(path.join(web, file), source);
  await sharp({ create: { width: 2, height: 4, channels: 3, background: "blue" } }).png().toFile(path.join(dir, "dark.png"));
  const profile = { viewport: { width: 2, height: 4 }, document: { width: 2, height: 4 }, device_pixel_ratio: 1, user_agent: "isolated-fixture", prefers_color_scheme: "dark", prefers_reduced_motion: false, full_page: true, tiles: [{ file: "dark.png", y: 0, height: 4 }] };
  const manifest = { route: "/fixture", applicable_states: ["dark"], not_applicable_states: [], captures: [{ state: "dark", file: "dark.png", capture_profile: profile }] };
  json(path.join(dir, "capture-profiles.json"), { "dark.png": profile });
  json(path.join(dir, "fixture-state-evidence.json"), manifest);
  const binding = { build_id: "isolated-test-fixture", source_sha256: digest("source"), artifact_sha256: digest("artifact"), provenance_sha256: digest("seal"), finished_at: "2026-01-01T00:00:00.000Z" };
  const provenance = { schema_version: "1.0", status: "capture_complete_unreviewed", acceptance: "unreviewed_engineering_evidence", data_source: "controlled_synthetic_browser_states", next_build_id: binding.build_id, production_build: binding,
    started_at: "2026-01-01T00:00:01.000Z", finished_at: "2026-01-01T00:00:02.000Z", project: "fixture", browser: { name: "chromium", version: "fixture" },
    test_source_file: "apps/rayon_sports/web/e2e/example.spec.ts", test_source_sha256: digest(source), provenance_helper_sha256: digest(source), package_lock_sha256: digest(source) };
  const save = () => { provenance.artifacts = fs.readdirSync(dir).filter((file) => file !== "runtime-provenance.json").sort().map((file) => ({ file, sha256: digest(fs.readFileSync(path.join(dir, file))) })); json(path.join(dir, "runtime-provenance.json"), provenance); };
  save();
  return { root, web, dir, profile, manifest, provenance, binding, save, validate: () => validateWebCapture(root, dir, binding) };
}

test("decoded source-bound captures remain pending in every quality dimension", async (t) => {
  const f = await fixture(t), result = await f.validate();
  assert.equal(result.artifact_integrity, "verified"); assert.equal(result.review_status, "pending");
  assert.deepEqual(result.screenshots.map(({ width, height }) => [width, height]), [[2, 4]]);
  assert.ok(Object.values(result.quality_results).every((value) => value === "unverified"));
  assert.equal(fs.existsSync(path.join(f.root, "docs/governance")), false);
});

test("a flag cannot fabricate review or write the governance registries", async (t) => {
  const f = await fixture(t), registry = path.join(f.root, "docs/governance/route-state-evidence.json");
  json(registry, { preserve: true }); const before = fs.readFileSync(registry);
  await assert.rejects(stageWebEvidence(f.root, ["--admit-reviewed"]), /cannot grant acceptance/);
  assert.deepEqual(fs.readFileSync(registry), before);
  await assert.rejects(stageWebEvidence(f.root, ["--capture-dir=output/capture", "--output=docs/governance/review.json"]), /under output/);
  await assert.rejects(stageWebEvidence(f.root, ["--capture-dir=output/capture", "--output=output/capture/runtime-provenance.json"]), /already exists/);
});

test("old build IDs, changed seals and unfinished captures are rejected", async (t) => {
  for (const change of [(p) => { p.next_build_id = "old"; }, (p) => { p.production_build = { ...p.production_build, source_sha256: digest("stale") }; }, (p) => { p.status = "capture_started_unreviewed"; }]) {
    const f = await fixture(t); change(f.provenance); f.save(); await assert.rejects(f.validate());
  }
});

test("changing a test, shared helper or lockfile invalidates the capture", async (t) => {
  for (const file of ["e2e/example.spec.ts", "e2e/state-evidence-provenance.ts", "package-lock.json"]) {
    const f = await fixture(t); fs.appendFileSync(path.join(f.web, file), "changed"); await assert.rejects(f.validate(), /source is stale/);
  }
});

test("missing files, unlisted files and changed bytes cannot pass integrity", async (t) => {
  for (const change of [(f) => fs.unlinkSync(path.join(f.dir, "dark.png")), (f) => fs.writeFileSync(path.join(f.dir, "extra.png"), "extra"), (f) => fs.appendFileSync(path.join(f.dir, "dark.png"), "change")]) {
    const f = await fixture(t); change(f); await assert.rejects(f.validate());
  }
});

test("malformed PNG pixel data is rejected even with its updated hash", async (t) => {
  const f = await fixture(t), file = path.join(f.dir, "dark.png");
  fs.writeFileSync(file, fs.readFileSync(file).subarray(0, 45)); f.save(); await assert.rejects(f.validate());
});

test("DPR mismatch, discontinuous tiles and incomplete states are rejected", async (t) => {
  for (const change of [(f) => { f.profile.device_pixel_ratio = 3; }, (f) => { f.profile.tiles[0].y = 1; }, (f) => { f.manifest.applicable_states.push("light"); }]) {
    const f = await fixture(t); change(f);
    json(path.join(f.dir, "capture-profiles.json"), { "dark.png": f.profile });
    json(path.join(f.dir, "fixture-state-evidence.json"), f.manifest); f.save(); await assert.rejects(f.validate());
  }
});

test("capture path traversal and symlinked images are rejected", async (t) => {
  const f = await fixture(t);
  await assert.rejects(validateWebCapture(f.root, "../escape", f.binding), /inside repository output/);
  const target = path.join(f.root, "external.png"); fs.renameSync(path.join(f.dir, "dark.png"), target); fs.symlinkSync(target, path.join(f.dir, "dark.png"));
  await assert.rejects(f.validate(), /regular file/);
  const external = path.join(f.root, "outside-output"); fs.mkdirSync(external);
  fs.symlinkSync(external, path.join(f.root, "output/alias"));
  await assert.rejects(stageWebEvidence(f.root, ["--capture-dir=output/capture", "--output=output/alias/created/review.json"]), /symlinks/);
  assert.equal(fs.existsSync(path.join(external, "created")), false);
});
