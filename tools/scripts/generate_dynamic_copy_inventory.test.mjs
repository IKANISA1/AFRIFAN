import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import test from "node:test";

const script = resolve(
  new URL("generate_dynamic_copy_inventory.mjs", import.meta.url).pathname,
);

test("fails closed until each dynamic source has an exact disposition", (t) => {
  const root = fixtureRoot(t);
  const source = join(root, "packages/features/example/lib/model.dart");
  mkdirSync(dirname(source), { recursive: true });
  writeFileSync(
    source,
    "class Article { factory Article.fromJson(Map<String, dynamic> json) { return Article(json['title']); } Article(this.title); final String title; }\n",
  );

  const first = run(root);
  assert.equal(first.summary.dynamic_copy_candidates, 1);
  assert.equal(first.summary.pending_dynamic_copy_candidates, 1);
  const candidate = first.entries[0];
  writeJson(join(root, "dispositions.json"), {
    schema_version: "1.0",
    task_id: "MOB-08",
    entries: [
      {
        file: candidate.file,
        context: candidate.context,
        accessor: candidate.accessor,
        source_key: candidate.source_key,
        occurrence: candidate.occurrence,
        disposition: "editorial_content_requires_source_locale_approval",
        contract: "editorial source locale is governed outside the client",
        rationale: "The client renders approved editorial content as supplied.",
        review_authority: "fixture review",
        reviewed_at: "2026-08-13",
      },
    ],
  });

  const reviewed = run(root);
  assert.equal(reviewed.summary.reviewed_dynamic_copy_candidates, 1);
  assert.equal(reviewed.summary.pending_dynamic_copy_candidates, 0);
});

test("rejects stale registry entries that no longer match source", (t) => {
  const root = fixtureRoot(t);
  writeJson(join(root, "dispositions.json"), {
    schema_version: "1.0",
    task_id: "MOB-08",
    entries: [
      {
        file: "packages/features/example/lib/model.dart",
        context: "Article.fromJson",
        accessor: "json",
        source_key: "title",
        occurrence: 1,
        disposition: "editorial_content_requires_source_locale_approval",
        contract: "fixture",
        rationale: "fixture",
        review_authority: "fixture review",
        reviewed_at: "2026-08-13",
      },
    ],
  });

  const result = spawnSync(process.execPath, command(root), {
    cwd: root,
    encoding: "utf8",
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /do not match current source candidates/);
});

function fixtureRoot(t) {
  const root = mkdtempSync(join(tmpdir(), "africlub-dynamic-copy-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, "packages/features/example/lib"), { recursive: true });
  writeJson(join(root, "dispositions.json"), {
    schema_version: "1.0",
    task_id: "MOB-08",
    entries: [],
  });
  return root;
}

function run(root) {
  execFileSync(process.execPath, command(root), { cwd: root, stdio: "pipe" });
  return JSON.parse(readFileSync(join(root, "inventory.json"), "utf8"));
}

function command(root) {
  return [
    script,
    "--repo-root",
    root,
    "--roots",
    "packages/features",
    "--json",
    "inventory.json",
    "--markdown",
    "inventory.md",
    "--dispositions",
    "dispositions.json",
  ];
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}
