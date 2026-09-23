import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, symlink, lstat, readlink, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { createRequire } from "node:module";
import path from "node:path";
import test from "node:test";
import qs from "qs";
import browserslist from "browserslist";
import { NodeHfs } from "@humanfs/node";
import yaml from "js-yaml";

// Exercise the installed transitive packages, not a copied implementation.
// Advisory IDs and dependency chains are documented in the remediation report.
test("YAML merge budgets also bound repeated empty sources", () => {
  const input = `base: &base {}\nmerged:\n  <<: [${Array(12).fill("*base").join(", ")}]\n`;
  assert.throws(() => yaml.load(input, { maxTotalMergeKeys: 5 }), /maxTotalMergeKeys/);
  assert.deepEqual(yaml.load("base: &base {club: Rayon}\nmerged: {<<: *base}\n"), {
    base: { club: "Rayon" },
    merged: { club: "Rayon" },
  });
});

for (const consumer of ["next", "miniflare"]) {
  test(`patched sharp retains image processing for ${consumer}`, async () => {
    const requireFromConsumer = createRequire(import.meta.resolve(consumer));
    const sharp = requireFromConsumer("sharp");
    const avif = await sharp({
      create: { width: 4, height: 4, channels: 3, background: { r: 3, g: 55, b: 210 } },
    }).avif().toBuffer();
    const { info } = await sharp(avif).resize(2, 2).png().toBuffer({ resolveWithObject: true });
    assert.equal(info.format, "png");
    assert.equal(info.width, 2);
    assert.equal(info.height, 2);
  });
}

test("qs safely serializes constructor/isBuffer keys from untrusted input", () => {
  for (const options of [{ plainObjects: true }, { allowPrototypes: true }]) {
    const parsed = qs.parse("x%5Bconstructor%5D%5BisBuffer%5D=y", options);
    assert.doesNotThrow(() => qs.stringify(parsed));
  }
  assert.doesNotThrow(() => qs.stringify(JSON.parse('{"x":{"constructor":{"isBuffer":true}}}')));
  assert.deepEqual(qs.parse(qs.stringify({ club: "Rayon Sports", filters: ["home", "away"] })), {
    club: "Rayon Sports", filters: ["home", "away"],
  });
});

test("qs applies comma array limits to bracket keys and encoded aliases", () => {
  const options = { comma: true, arrayLimit: 3, throwOnLimitExceeded: true };
  for (const key of ["a", "a[]", "a%5B%5D"]) {
    assert.throws(() => qs.parse(`${key}=1,2,3,4`, options), RangeError);
  }
  assert.deepEqual(qs.parse("a=1,2,3", options), { a: ["1", "2", "3"] });
});

test("browserslist treats prototype-shaped custom stats as data", () => {
  const expected = browserslist("last 1 chrome version", { stats: { chrome: { 100: 50 } } });
  for (const key of ["__proto__", "constructor", "toString", "hasOwnProperty"]) {
    const stats = JSON.parse(`{"${key}":{"onekey":5},"chrome":{"100":50}}`);
    assert.deepEqual(browserslist("last 1 chrome version", { stats }), expected);
  }
  assert.equal(Object.prototype.onekey, undefined);
});

test("browserslist evicts old distinct queries while retaining current cache hits", () => {
  const query = "since 1900-01-01";
  const original = browserslist(query);
  assert.equal(browserslist(query), original);
  // A bounded workload demonstrates eviction without attempting an OOM.
  for (let day = 0; day < 1200; day += 1) {
    const date = new Date(Date.UTC(1901, 0, 1 + day)).toISOString().slice(0, 10);
    browserslist(`since ${date}`);
  }
  const recomputed = browserslist(query);
  assert.notEqual(recomputed, original);
  assert.deepEqual(recomputed, original);
  assert.equal(browserslist(query), recomputed);
});

for (const operation of ["copy", "copyAll"]) {
  test(`humanfs ${operation} preserves links without materializing outside file contents`, async () => {
    const root = await mkdtemp(path.join(tmpdir(), "africlub-copy-regression-"));
    try {
      const source = path.join(root, "source");
      const destination = path.join(root, "destination");
      const outside = path.join(root, "outside.txt");
      await mkdir(source);
      await writeFile(outside, "synthetic outside-tree fixture");
      await writeFile(path.join(source, "ordinary.txt"), "ordinary project file");
      await symlink("../outside.txt", path.join(source, "link.txt"));
      const hfs = new NodeHfs();
      if (operation === "copyAll") {
        await hfs.copyAll(source, destination);
      } else {
        await mkdir(destination);
        await hfs.copy(path.join(source, "link.txt"), path.join(destination, "link.txt"));
        await hfs.copy(path.join(source, "ordinary.txt"), path.join(destination, "ordinary.txt"));
      }
      assert.equal((await lstat(path.join(destination, "link.txt"))).isSymbolicLink(), true);
      assert.equal(await readlink(path.join(destination, "link.txt")), "../outside.txt");
      assert.equal(await readFile(path.join(destination, "ordinary.txt"), "utf8"), "ordinary project file");
      // This is symlink preservation, not a claim that later link traversal is safe.
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
}
