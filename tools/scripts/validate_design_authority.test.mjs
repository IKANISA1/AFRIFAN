import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { requiredAuthorityFiles, validateDesignAuthority } from "./validate_design_authority.mjs";

const digest = (text) => createHash("sha256").update(text).digest("hex");
function fixture(t) {
  const dir = mkdtempSync(path.join(tmpdir(), "africlub-authority-contract-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const root = path.join(dir, "product");
  const authorityRoot = path.join(dir, "selected-skill");
  mkdirSync(root);
  mkdirSync(path.join(authorityRoot, "references"), { recursive: true });
  writeFileSync(path.join(root, "DESIGN.md"), "Synthetic product adapter\n");
  for (const name of requiredAuthorityFiles) {
    writeFileSync(path.join(authorityRoot, name), `Synthetic authority fixture: ${name}\n`);
  }
  const bound_files = requiredAuthorityFiles.map((name) => ({
    path: name, sha256: digest(readFileSync(path.join(authorityRoot, name))),
  }));
  const document = {
    design_authority: {
      skill: "revolut-design", path: "SKILL.md", root_hint: authorityRoot,
      sha256: bound_files.find((entry) => entry.path === "SKILL.md").sha256,
      bound_files,
    },
    product_adapter: { path: "DESIGN.md", sha256: digest(readFileSync(path.join(root, "DESIGN.md"))) },
  };
  const register = path.join(root, "binding.json");
  return { root, authorityRoot, document, run() {
    writeFileSync(register, JSON.stringify(document));
    return validateDesignAuthority({ root, register, authorityRoot });
  } };
}

test("current authority and adapter bindings never manufacture visual acceptance", (t) => {
  const result = fixture(t).run();
  assert.equal(result.status, "pass");
  assert.equal(result.design_complete, false);
  assert.equal(result.bound_file_count, requiredAuthorityFiles.length);
});
test("a repository file cannot declare itself the selected skill", (t) => {
  const f = fixture(t); f.document.design_authority.path = "DESIGN.md";
  assert.equal(f.run().status, "fail");
});
test("changing an applicable reference invalidates its binding", (t) => {
  const f = fixture(t);
  writeFileSync(path.join(f.authorityRoot, "references/web-patterns.md"), "Changed authority");
  assert.match(f.run().errors.join("\n"), /Authority hash mismatch: references\/web-patterns.md/);
});
test("a changed product adapter invalidates its recorded revision", (t) => {
  const f = fixture(t); writeFileSync(path.join(f.root, "DESIGN.md"), "Changed adapter");
  assert.match(f.run().errors.join("\n"), /Product adapter revision is stale/);
});
test("an alternative design authority cannot replace the selected skill", (t) => {
  const f = fixture(t); f.document.design_authority.skill = "local-style-guide";
  assert.match(f.run().errors.join("\n"), /selected revolut-design SKILL.md must be the authority/);
});
test("omitting or duplicating an authority reference fails closed", (t) => {
  const f = fixture(t);
  f.document.design_authority.bound_files[1] = f.document.design_authority.bound_files[0];
  assert.equal(f.run().status, "fail");
});
test("missing external authority bytes cannot be replaced by metadata", (t) => {
  const f = fixture(t); rmSync(path.join(f.authorityRoot, "SKILL.md"));
  assert.equal(f.run().status, "fail");
});
test("a stale skill revision is rejected", (t) => {
  const f = fixture(t);
  f.document.design_authority.sha256 = "0".repeat(64);
  const result = f.run();
  assert.equal(result.status, "fail");
  assert.deepEqual(result.errors, ["Selected skill revision is stale."]);
});
