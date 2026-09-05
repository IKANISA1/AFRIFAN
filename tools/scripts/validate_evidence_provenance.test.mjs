import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const scriptName = "validate_evidence_provenance.sh";
const sourceScript = path.join(repoRoot, "tools/scripts", scriptName);
const nonexistentCommit = "f".repeat(40);

const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};

function createFixture(t, baselineCommit, manifestBaselineCommit = baselineCommit) {
  const fixtureRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "africlub-evidence-provenance-test-"),
  );
  t.after(() => fs.rmSync(fixtureRoot, { recursive: true, force: true }));

  execFileSync("git", ["init", "-q"], { cwd: fixtureRoot });
  execFileSync("git", ["config", "user.name", "Fixture"], {
    cwd: fixtureRoot,
  });
  execFileSync("git", ["config", "user.email", "fixture@example.test"], {
    cwd: fixtureRoot,
  });
  fs.writeFileSync(path.join(fixtureRoot, "tracked.txt"), "fixture\n");
  execFileSync("git", ["add", "tracked.txt"], { cwd: fixtureRoot });
  execFileSync("git", ["commit", "-q", "-m", "fixture baseline"], {
    cwd: fixtureRoot,
  });
  const validCommit = execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: fixtureRoot,
    encoding: "utf8",
  }).trim();

  const resolvedBaseline = baselineCommit === "HEAD" ? validCommit : baselineCommit;
  const resolvedManifestBaseline =
    manifestBaselineCommit === "HEAD" ? validCommit : manifestBaselineCommit;
  const fixtureScript = path.join(fixtureRoot, "tools/scripts", scriptName);
  fs.mkdirSync(path.dirname(fixtureScript), { recursive: true });
  fs.copyFileSync(sourceScript, fixtureScript);

  const relativeDirectory =
    "output/evidence/fixture_bundle";
  const artifactPath = `${relativeDirectory}/artifact.txt`;
  const artifact = Buffer.from("controlled evidence\n");
  fs.mkdirSync(path.join(fixtureRoot, relativeDirectory), { recursive: true });
  fs.writeFileSync(path.join(fixtureRoot, artifactPath), artifact);

  const provenance = {
    baseline_commit: resolvedBaseline,
    dirty_state: false,
    app_version: "1.0.0",
    build_number: "1",
    flavor: "fixture",
    platform: "fixture",
    runtime_device: "fixture",
    viewport_profiles: [{ width: 100, height: 100 }],
    locale: "en",
    themes: ["fixture"],
    captured_at: "2026-08-09T00:00:00Z",
    data_source: "fixture",
  };
  const registryPath = path.join(
    fixtureRoot,
    "docs/governance/evidence-bundles.json",
  );
  writeJson(registryPath, {
    schema_version: "1.0",
    manifest_name: "build-provenance.json",
    bundles: [
      {
        id: "fixture-bundle",
        admission_status: "admitted",
        directory: relativeDirectory,
        artifact_scope: "immediate",
        task_ids: ["FIXTURE-01"],
        ...provenance,
      },
    ],
  });
  writeJson(
    path.join(fixtureRoot, relativeDirectory, "build-provenance.json"),
    {
      schema_version: "1.0",
      bundle_id: "fixture-bundle",
      task_ids: ["FIXTURE-01"],
      bundle_directory: relativeDirectory,
      artifact_scope: "immediate",
      provenance: {
        ...provenance,
        baseline_commit: resolvedManifestBaseline,
        manifest_generated_at: "2026-08-09T00:00:01Z",
      },
      artifacts: [
        {
          path: artifactPath,
          sha256: createHash("sha256").update(artifact).digest("hex"),
          bytes: artifact.length,
        },
      ],
    },
  );

  return { fixtureRoot, fixtureScript, validCommit };
}

function runValidator(fixtureRoot, fixtureScript) {
  return spawnSync("bash", [fixtureScript], {
    cwd: fixtureRoot,
    encoding: "utf8",
  });
}

test("accepts a baseline SHA that resolves to a commit", (t) => {
  const { fixtureRoot, fixtureScript, validCommit } = createFixture(t, "HEAD");
  const result = runValidator(fixtureRoot, fixtureScript);

  assert.equal(validCommit.length, 40);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Evidence provenance valid: 1 admitted bundles/);
});

test("rejects a well-formed 40-hex SHA that does not exist", (t) => {
  const { fixtureRoot, fixtureScript } = createFixture(t, nonexistentCommit);
  const result = runValidator(fixtureRoot, fixtureScript);

  assert.notEqual(result.status, 0);
  assert.match(
    result.stderr,
    new RegExp(
      `Evidence bundle baseline commit does not exist: fixture-bundle \\(${nonexistentCommit}\\)`,
    ),
  );
});

test("rejects a nonexistent commit recorded by an admitted manifest", (t) => {
  const { fixtureRoot, fixtureScript } = createFixture(
    t,
    "HEAD",
    nonexistentCommit,
  );
  const result = runValidator(fixtureRoot, fixtureScript);

  assert.notEqual(result.status, 0);
  assert.match(
    result.stderr,
    new RegExp(
      `Evidence manifest baseline commit does not exist: fixture-bundle \\(${nonexistentCommit}\\)`,
    ),
  );
});

test("an empty registry reports unverified coverage without requiring old artifacts", (t) => {
  const { fixtureRoot, fixtureScript } = createFixture(t, "HEAD");
  writeJson(path.join(fixtureRoot, "docs/governance/evidence-bundles.json"), {
    schema_version: "1.0", manifest_name: "build-provenance.json", bundles: [],
  });
  fs.rmSync(path.join(fixtureRoot, "output"), { recursive: true });
  const result = runValidator(fixtureRoot, fixtureScript);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /coverage remain unverified/);
  assert.doesNotMatch(result.stdout, /Evidence provenance valid/);
});

test("an empty registry rejects unregistered evidence directories", (t) => {
  const { fixtureRoot, fixtureScript } = createFixture(t, "HEAD");
  writeJson(path.join(fixtureRoot, "docs/governance/evidence-bundles.json"), {
    schema_version: "1.0", manifest_name: "build-provenance.json", bundles: [],
  });
  const result = runValidator(fixtureRoot, fixtureScript);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /does not match current bundle directories/);
});
