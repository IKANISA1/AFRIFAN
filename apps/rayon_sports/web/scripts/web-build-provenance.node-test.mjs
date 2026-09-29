import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createHash } from "node:crypto";
import { beginProductionBuild, markProductionCompilationComplete, productionSourceSnapshot, sealProductionBuild, validateProductionBuild } from "./web-build-provenance.mjs";

const sharedPrefix = "../../../cloudflare/supporter-browser-api/";
const sharedFiles = ["client.ts", "portal-controller.ts", "browser-platform.ts"];

function fixture(t) {
  const repository = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-build-proof-"));
  const root = path.join(repository, "apps/rayon_sports/web");
  t.after(() => fs.rmSync(repository, { recursive: true, force: true }));
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

function portalFixture(t) {
  const result = fixture(t);
  result.put("src/components/browser-membership-portal.tsx", "export const portal = true;");
  for (const file of sharedFiles) result.put(`${sharedPrefix}${file}`, "export const shared = true;");
  return result;
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

for (const file of sharedFiles) test(`sealed portal build binds the external ${file} bytes`, (t) => {
  const { root, put, build } = portalFixture(t);
  const record = build();
  assert.deepEqual(record.source.files.filter((entry) => entry.file.startsWith(sharedPrefix)).map((entry) => entry.file).sort(), sharedFiles.map((name) => `${sharedPrefix}${name}`).sort());
  validateProductionBuild(root);
  put(`${sharedPrefix}${file}`, "export const shared = 'changed runtime';");
  assert.throws(() => validateProductionBuild(root), /stale for the current source/);
});

test("shared portal changes during compilation reject compilation completion", (t) => {
  const { root, put, compile } = portalFixture(t);
  beginProductionBuild(root, ["synthetic-fixture-compiler"]);
  put(`${sharedPrefix}client.ts`, "changed external runtime");
  assert.throws(compile, /source changed during compilation/);
});

test("shared portal changes after compilation reject sealing", (t) => {
  const { root, put, compile } = portalFixture(t);
  beginProductionBuild(root, ["synthetic-fixture-compiler"]); compile();
  put(`${sharedPrefix}portal-controller.ts`, "changed external runtime");
  assert.throws(() => sealProductionBuild(root), /source changed before sealing/);
});

for (const file of sharedFiles) test(`an installed portal requires its external ${file}`, (t) => {
  const { root } = portalFixture(t);
  fs.unlinkSync(path.join(root, sharedPrefix, file));
  assert.throws(() => beginProductionBuild(root, ["synthetic-fixture-compiler"]), /Missing required shared portal build input/);
});

test("an external dependency symlink cannot escape the declared shared module", (t) => {
  const { root, put } = portalFixture(t);
  put("../../../cloudflare/unrelated-client.ts", "unreviewed external runtime");
  const file = path.join(root, sharedPrefix, "client.ts"); fs.unlinkSync(file);
  fs.symlinkSync(path.resolve(root, "../../../cloudflare/unrelated-client.ts"), file);
  assert.throws(() => beginProductionBuild(root, ["synthetic-fixture-compiler"]), /symlink escapes/);
});

test("a shared module directory symlink cannot relocate the allowed boundary", (t) => {
  const { root } = portalFixture(t);
  const sharedDirectory = path.resolve(root, sharedPrefix), relocated = path.resolve(root, "../../../cloudflare/relocated-module");
  fs.renameSync(sharedDirectory, relocated); fs.symlinkSync(relocated, sharedDirectory);
  assert.throws(() => beginProductionBuild(root, ["synthetic-fixture-compiler"]), /shared portal.*directory.*escapes/i);
});

test("a bounded shared file symlink is recorded and its target mutation invalidates the seal", (t) => {
  const { root, put, build } = portalFixture(t), file = path.join(root, sharedPrefix, "client.ts");
  fs.unlinkSync(file); fs.symlinkSync("portal-controller.ts", file);
  const record = build();
  assert.equal(record.source.files.find((entry) => entry.file === `${sharedPrefix}client.ts`).link, "portal-controller.ts");
  put(`${sharedPrefix}portal-controller.ts`, "changed linked runtime");
  assert.throws(() => validateProductionBuild(root), /stale for the current source/);
});

test("external portal environment keys are hash-only build inputs", (t) => {
  const { root, put } = portalFixture(t), key = "AFRICLUB_SHARED_PORTAL_PROVENANCE_FIXTURE", previous = process.env[key];
  t.after(() => { if (previous === undefined) delete process.env[key]; else process.env[key] = previous; });
  process.env[key] = "private-external-environment-fixture";
  put(`${sharedPrefix}browser-platform.ts`, `export const setting = process.env.${key};`);
  const record = beginProductionBuild(root, ["synthetic-fixture-compiler"]);
  assert.equal(record.environment_value_sha256[key], createHash("sha256").update(process.env[key]).digest("hex"));
  assert.ok(!JSON.stringify(record).includes(process.env[key]));
  assert.ok(!JSON.stringify(record).includes("private-fixture-value"));
});

test("the shared inventory is bounded and required only when the portal component exists", (t) => {
  const plain = fixture(t), before = productionSourceSnapshot(plain.root);
  plain.put(`${sharedPrefix}client.ts`, "unconsumed runtime");
  assert.deepEqual(productionSourceSnapshot(plain.root), before);
  const portal = portalFixture(t); portal.build(); const sealed = validateProductionBuild(portal.root);
  portal.put(`${sharedPrefix}unrelated-test.ts`, "unconsumed fixture");
  assert.deepEqual(validateProductionBuild(portal.root), sealed);
});
