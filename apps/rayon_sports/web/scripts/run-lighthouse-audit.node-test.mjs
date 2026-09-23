import assert from "node:assert/strict";
import test from "node:test";

import {
  artifactName,
  categoryThresholds,
} from "./run-lighthouse-audit.mjs";

test("categoryThresholds extracts only governed Lighthouse categories", () => {
  const thresholds = categoryThresholds({
    "categories:performance": ["error", { minScore: 0.9 }],
    "categories:accessibility": ["error", { minScore: 0.95 }],
    "first-contentful-paint": ["warn", { maxNumericValue: 2000 }],
  });

  assert.deepEqual([...thresholds], [
    ["performance", 0.9],
    ["accessibility", 0.95],
  ]);
});

test("artifactName produces stable route-specific report names", () => {
  assert.equal(artifactName("http://127.0.0.1:3310/", 2, "json"), "home-run-2.json");
  assert.equal(
    artifactName("http://127.0.0.1:3310/admin/match-day", 3, "html"),
    "admin-match-day-run-3.html",
  );
});
