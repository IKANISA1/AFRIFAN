import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import test from "node:test";
import { hashFile, nativeSourceSnapshot, recordRouteInventoryProvenance } from "./route_inventory_provenance.mjs";

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-route-provenance-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  execFileSync("git", ["init", "-q", root]);
  const write = (name, contents) => {
    const target = path.join(root, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, contents);
  };
  write("apps/fixture/assets/flavors/production.json", '{"CLUB_ID":"1"}');
  write("apps/fixture/lib/main.dart", "void main() {}\n");
  write("packages/feature/pubspec.yaml", "name: feature\n");
  write(".gitignore", "*.g.dart\nignored.png\noutput/\n");
  const directory = path.join(root, "output/routes");
  write("output/routes/route-inventory.json", JSON.stringify({ routes: [{ surface: "mobile", path: "/home", kind: "tab" }], duplicate_keys: [] }));
  const record = stage => recordRouteInventoryProvenance({ root, stage, directory });
  return { root, write, record, directory };
}

test("route provenance seals the discovered bytes on unchanged source", t => {
  const f = fixture(t);
  assert.equal(f.record("snapshot"), 1);
  assert.equal(f.record("seal"), 1);
  const proof = JSON.parse(fs.readFileSync(path.join(f.directory, "route-inventory-provenance.json")));
  assert.equal(proof.route_inventory_sha256, hashFile(path.join(f.directory, "route-inventory.json")));
  assert.equal(proof.native_sources.fixture, nativeSourceSnapshot(f.root, "fixture").sha256);
});

test("source changes between discovery and sealing are rejected", t => {
  const f = fixture(t);
  f.record("snapshot");
  f.write("apps/fixture/lib/main.dart", "void main() { print('changed'); }\n");
  assert.throws(() => f.record("seal"), /Source changed/);
  assert.equal(fs.existsSync(path.join(f.directory, "route-inventory-provenance.json")), false);
});

test("ignored generated code, assets and native configuration affect the fingerprint", t => {
  const f = fixture(t);
  let before = nativeSourceSnapshot(f.root, "fixture").sha256;
  for (const name of ["packages/feature/lib/model.g.dart", "apps/fixture/assets/ignored.png", "apps/fixture/android/app/google-services.json"]) {
    f.write(name, "synthetic fixture bytes\n");
    const after = nativeSourceSnapshot(f.root, "fixture").sha256;
    assert.notEqual(after, before, name);
    before = after;
  }
});

test("empty and duplicate route discovery cannot be sealed", t => {
  const f = fixture(t);
  f.record("snapshot");
  for (const inventory of [{ routes: [], duplicate_keys: [] }, { routes: [{ path: "/home" }], duplicate_keys: ["/home"] }]) {
    f.write("output/routes/route-inventory.json", JSON.stringify(inventory));
    assert.throws(() => f.record("seal"), /Route discovery is empty or has duplicates/);
  }
});
