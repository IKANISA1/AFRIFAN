import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const report = readFileSync(new URL("./design_compliance_report.sh", import.meta.url), "utf8");
const start = report.indexOf("governed_club_crest() {");
assert.ok(start >= 0);
const validator = report.slice(start, report.indexOf("\n}\n", start) + 3);

function fixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), "africlub-registered-crest-"));
  t.after(() => rmSync(root, { force: true, recursive: true }));
  const directory = path.join(root, "packages/features/feat_club/assets/crests");
  mkdirSync(directory, { recursive: true });
  const bytes = "synthetic binary fixture";
  const hash = createHash("sha256").update(bytes).digest("hex");
  const asset = path.join(directory, "rayon_sports.png");
  const manifest = path.join(directory, "SOURCES.md");
  writeFileSync(asset, bytes);
  writeFileSync(manifest, [
    "- File: `rayon_sports.png`",
    "- source: `https://example.invalid/fixture`",
    `- SHA-256: \`${hash}\``,
    "- Release rights review remains required.",
  ].join("\n") + "\n");
  return { asset, manifest, run: () => spawnSync("bash", ["-c", `${validator}\ngoverned_club_crest`], {
    env: { ...process.env, ROOT: root }, encoding: "utf8",
  }).status };
}

test("the exact registered crest passes source provenance without granting release rights", (t) => {
  assert.equal(fixture(t).run(), 0);
});
test("changed crest bytes cannot use the prior source record", (t) => {
  const f = fixture(t); writeFileSync(f.asset, "unregistered replacement");
  assert.notEqual(f.run(), 0);
});
test("missing provenance fails closed", (t) => {
  const f = fixture(t); rmSync(f.manifest); assert.notEqual(f.run(), 0);
});
test("a source record with no rights status fails closed", (t) => {
  const f = fixture(t);
  writeFileSync(f.manifest, readFileSync(f.manifest, "utf8").replace("- Release rights review remains required.\n", ""));
  assert.notEqual(f.run(), 0);
});
