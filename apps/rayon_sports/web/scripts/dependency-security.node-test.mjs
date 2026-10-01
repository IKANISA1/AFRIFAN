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
test("locked Next and every brace-expansion copy retain the October security floors", async () => {
  // GHSA-vcvr-r3jv-pc5j; GHSA-q2hr-2g5m-vwhr, GHSA-qhr7-859c-m2p7,
  // GHSA-6j4f-fj2g-mc7p. Unknown branches require a fresh reviewed floor.
  const lock = JSON.parse(await readFile(new URL("../package-lock.json", import.meta.url), "utf8"));
  const floors = { next: { 16: [3, 6] }, "brace-expansion": { 1: [1, 21], 2: [1, 7], 5: [0, 12] } };
  for (const [name, branches] of Object.entries(floors)) {
    const copies = Object.entries(lock.packages).filter(([location]) => location.endsWith(`node_modules/${name}`));
    assert.ok(copies.length, `${name} must be present in the governed graph`);
    for (const [location, { version }] of copies) {
      assert.match(version, /^\d+\.\d+\.\d+$/, `${location} must use a reviewed stable release`);
      const [major, minor, patch] = version.split(".").map(Number);
      const minimum = branches[major];
      assert.ok(minimum, `${location}: ${version} requires a reviewed branch floor`);
      assert.ok(minor > minimum[0] || (minor === minimum[0] && patch >= minimum[1]),
        `${location}: ${version} predates the security patch`);
      const installed = JSON.parse(await readFile(new URL(`../${location}/package.json`, import.meta.url), "utf8"));
      assert.equal(installed.version, version, `${location}: installed dependency must match the reviewed lockfile`);
    }
  }
});

// Undici's September 2026 advisories patch the maintained branches at these
// floors: https://github.com/nodejs/undici/releases/tag/v7.29.1
test("every locked undici copy meets its maintained security patch floor", async () => {
  const lock = JSON.parse(await readFile(new URL("../package-lock.json", import.meta.url), "utf8"));
  const copies = Object.entries(lock.packages).filter(([name]) => /(?:^|\/)node_modules\/undici$/.test(name));
  assert.ok(copies.length > 0, "Miniflare's undici dependency must be represented in the lockfile");
  const minimums = { 6: [28, 1], 7: [29, 1], 8: [10, 2] };
  for (const [location, { version }] of copies) {
    assert.match(version, /^\d+\.\d+\.\d+$/, `${location} must use a reviewed stable release`);
    const [major, minor, patch] = version.split(".").map(Number);
    const minimum = minimums[major];
    assert.ok(minimum, `${location}: undici ${version} requires a reviewed security floor for this release branch`);
    assert.ok(minor > minimum[0] || (minor === minimum[0] && patch >= minimum[1]),
      `${location}: undici ${version} predates the branch security patch`);
  }
  const requireFromMiniflare = createRequire(import.meta.resolve("miniflare"));
  const installed = requireFromMiniflare("undici/package.json");
  assert.ok(copies.some(([, entry]) => entry.version === installed.version), "Miniflare's installed undici must match the reviewed lock graph");
});

test("Miniflare's undici BalancedPool retains a rejecting custom connector", async (t) => {
  // GHSA-w293-vg96-wgc3: BalancedPool's JSON clone previously discarded
  // function-valued connection options, bypassing custom connection policy.
  const requireFromMiniflare = createRequire(import.meta.resolve("miniflare"));
  const { BalancedPool } = requireFromMiniflare("undici");
  const expected = new Error("synthetic custom connector policy rejection");
  let calls = 0;
  const pool = new BalancedPool("http://127.0.0.1:1", {
    connect(_options, callback) {
      calls += 1;
      callback(expected, null);
    },
  });
  t.after(() => pool.destroy());
  await assert.rejects(pool.request({ path: "/", method: "GET" }), (error) => error === expected);
  assert.equal(calls, 1);
});

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
