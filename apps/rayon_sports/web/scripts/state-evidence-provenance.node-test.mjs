import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { prepareStateEvidence, finalizeStateEvidence } from "../e2e/state-evidence-provenance.ts";

function fixture(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-evidence-test-"));
  try {
    const prepare = (engine = "chromium", retry = 0) => prepareStateEvidence(
      { browserType: () => ({ name: () => engine }), version: () => "synthetic-test-version" },
      {
        project: { name: `desktop-${engine}` }, testId: "synthetic-case", retry,
        file: fileURLToPath(import.meta.url),
        outputPath: (slug) => path.join(root, engine, `retry-${retry}`, slug),
      },
      "synthetic_fixture",
    );
    run(prepare);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

function capture(directory, declared = ["default.png"]) {
  fs.writeFileSync(path.join(directory, "default.png"), "synthetic pixels");
  fs.writeFileSync(path.join(directory, "synthetic-state-evidence.json"), JSON.stringify({
    captures: declared.map((file) => ({ file, state: "default" })),
  }));
}

test("browser projects and retries retain separate captures and actual engine metadata", () => fixture((prepare) => {
  const directories = [prepare(), prepare("firefox"), prepare("chromium", 1)];
  assert.equal(new Set(directories).size, 3);
  for (const directory of directories) {
    capture(directory);
    finalizeStateEvidence(directory);
    const record = JSON.parse(fs.readFileSync(path.join(directory, "runtime-provenance.json"), "utf8"));
    assert.equal(record.project, `desktop-${record.browser.name}`);
    assert.equal(record.status, "capture_complete_unreviewed");
    assert.equal(record.acceptance, "unreviewed_engineering_evidence");
    const screenshot = record.artifacts.find(({ file }) => file === "default.png");
    assert.equal(screenshot.sha256, createHash("sha256").update("synthetic pixels").digest("hex"));
  }
}));

test("missing declared captures cannot produce a completed evidence record", () => fixture((prepare) => {
  const directory = prepare();
  capture(directory, ["default.png", "missing-error.png"]);
  assert.throws(() => finalizeStateEvidence(directory), /manifest and captured screenshot files differ/);
  const record = JSON.parse(fs.readFileSync(path.join(directory, "runtime-provenance.json"), "utf8"));
  assert.equal(record.status, "capture_started_unreviewed");
}));

for (const [field, message] of [
  ["next_build_id", /Build changed during capture/],
  ["production_build", /Production build provenance changed during capture/],
  ["tracked_worktree_diff_sha256", /Source changed during capture/],
  ["untracked_source", /Untracked source changed during capture/],
]) {
  test(`stale ${field} cannot produce completed evidence`, () => fixture((prepare) => {
    const directory = prepare();
    capture(directory);
    const file = path.join(directory, "runtime-provenance.json");
    const record = JSON.parse(fs.readFileSync(file, "utf8"));
    record[field] = "stale-synthetic-value";
    fs.writeFileSync(file, JSON.stringify(record));
    assert.throws(() => finalizeStateEvidence(directory), message);
  }));
}
