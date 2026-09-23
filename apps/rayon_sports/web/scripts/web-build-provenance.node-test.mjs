import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { beginProductionBuild, markProductionCompilationComplete, sealProductionBuild, validateProductionBuild } from "./web-build-provenance.mjs";

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-build-proof-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const put = (name, value = "fixture") => {
    fs.mkdirSync(path.dirname(path.join(root, name)), { recursive: true });
    fs.writeFileSync(path.join(root, name), value);
  };
  for (const file of ["src/page.tsx", "public/crest.svg", "next.config.ts", "postcss.config.mjs", "tsconfig.json", "package-lock.json",
    "scripts/run-next-build-stable.mjs", "scripts/ensure-next-build-artifacts.mjs", "scripts/fix-route-group-manifests.mjs", "scripts/web-build-provenance.mjs"]) put(file);
  put("package.json", JSON.stringify({ packageManager: "npm@12.0.2" }));
  put("node_modules/next/package.json", JSON.stringify({ version: "synthetic-test-version" }));
  put(".env.local", "SECRET=private-fixture-value\n");
  const compile = () => {
    for (const file of [".next/BUILD_ID", ".next/server/app/page.js", ".next/static/chunk.js", ".next/standalone/server.js"]) put(file);
    markProductionCompilationComplete(root);
  };
  const build = () => { beginProductionBuild(root, ["synthetic-fixture-compiler"]); compile(); return sealProductionBuild(root); };
  return { root, put, compile, build };
}

test("sealed production source, build and artifacts stay linked without exposing dotenv values", (t) => {
  const { root, build } = fixture(t);
  const record = build();
  const checked = validateProductionBuild(root);
  assert.equal(checked.source_sha256, record.source.sha256);
  assert.equal(checked.artifact_sha256, record.artifacts.sha256);
  assert.ok(!JSON.stringify(record).includes("private-fixture-value"));
});

test("same build ID cannot conceal a source change", (t) => {
  const { root, put, build } = fixture(t); build();
  put("src/page.tsx", "new product code");
  assert.throws(() => validateProductionBuild(root), /stale for the current source/);
});

test("a changed public asset or build dotenv file invalidates the source link", (t) => {
  for (const changed of ["public/crest.svg", ".env.local"]) {
    const { root, put, build } = fixture(t); build(); put(changed, "changed input");
    assert.throws(() => validateProductionBuild(root), /stale for the current source/);
  }
});

test("modified or missing compiled code invalidates artifact proof despite a matching build ID", (t) => {
  const { root, put, build } = fixture(t); build(); put(".next/static/chunk.js", "tampered output");
  assert.throws(() => validateProductionBuild(root), /artifacts changed/);
  build(); fs.unlinkSync(path.join(root, ".next/standalone/server.js"));
  assert.throws(() => validateProductionBuild(root), /Incomplete production artifacts/);
});

test("source changes during compilation cannot be sealed", (t) => {
  const { root, put, compile } = fixture(t);
  beginProductionBuild(root, ["synthetic-fixture-compiler"]); put("src/page.tsx", "concurrent edit");
  assert.throws(compile, /source changed during compilation/);
  assert.throws(() => sealProductionBuild(root), /No successful production compilation/);
});

test("postprocessing cannot seal against newly changed production source", (t) => {
  const { root, put, compile } = fixture(t);
  beginProductionBuild(root, ["synthetic-fixture-compiler"]); compile(); put("next.config.ts", "changed config");
  assert.throws(() => sealProductionBuild(root), /source changed before sealing/);
});

test("runtime cache and new test fixtures do not become production artifacts or inputs", (t) => {
  const { root, put, build } = fixture(t); build(); const before = validateProductionBuild(root);
  put(".next/cache/runtime-entry", "cached data"); put(".next/trace", "runtime trace"); put("e2e/fixture.spec.ts", "changed test");
  assert.deepEqual(validateProductionBuild(root), before);
});

test("an unsealed or unsuccessful build is rejected", (t) => {
  const { root } = fixture(t);
  assert.throws(() => validateProductionBuild(root), /provenance is missing/);
  beginProductionBuild(root, ["synthetic-fixture-compiler"]);
  assert.throws(() => sealProductionBuild(root), /No successful production compilation/);
});
