import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { hasCoverageExclusion, missingCriticalCoverage, requiredCoverageFiles } from "./run-unit-tests.mjs";

test("a nominal unit success cannot conceal the provider's parse exclusion", () => {
  assert.equal(hasCoverageExclusion("1181 tests passed\nFailed to parse file:///source.ts. Excluding it from coverage.\n"), true);
  assert.equal(hasCoverageExclusion("Tests 1181 passed\nCoverage enabled with v8"), false);
});

test("critical source admission requires every real caller/helper, including untested files", () => {
  const root = path.resolve("synthetic-web");
  const summary = Object.fromEntries(requiredCoverageFiles.map(file => [path.resolve(root, file), { lines: { pct: 0 } }]));
  assert.deepEqual(missingCriticalCoverage(summary, root), []);
  delete summary[path.resolve(root, "src/app/api/admin/[resource]/route.ts")];
  assert.deepEqual(missingCriticalCoverage(summary, root), ["src/app/api/admin/[resource]/route.ts"]);
});
