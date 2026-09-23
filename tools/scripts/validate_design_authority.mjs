import { createHash } from "node:crypto";
import { readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const requiredAuthorityFiles = [
  "SKILL.md",
  "references/DESIGN.md",
  "references/brand-adaptation.md",
  "references/screen-typologies.md",
  "references/mobile-patterns.md",
  "references/web-patterns.md",
  "references/pwa-and-accessibility.md",
  "references/component-contracts.md",
  "references/quality-standard.md",
  "references/operational-checklist.md",
];
const digest = (value) => createHash("sha256").update(value).digest("hex");

// This checks the product's authority binding only. It does not score visual
// fidelity or grant visual approval from metadata or tests.
export function validateDesignAuthority({ root, register, authorityRoot }) {
  const errors = [];
  const result = {
    scope: "design_authority_binding_only",
    status: "fail",
    design_complete: false,
    errors,
  };
  try {
    const document = JSON.parse(readFileSync(register, "utf8"));
    const authority = document.design_authority;
    if (authority?.skill !== "revolut-design" || authority?.path !== "SKILL.md") {
      throw new Error("The selected revolut-design SKILL.md must be the authority.");
    }
    const directory = realpathSync(authorityRoot || authority.root_hint);
    const source = path.join(directory, "SKILL.md");
    const adapter = document.product_adapter;
    if (adapter?.path !== "DESIGN.md" || realpathSync(source) === realpathSync(path.join(root, adapter.path))) {
      throw new Error("The repository adapter cannot replace the selected skill.");
    }
    const bindings = authority.bound_files;
    if (!Array.isArray(bindings) || bindings.length !== requiredAuthorityFiles.length
      || new Set(bindings.map((entry) => entry.path)).size !== bindings.length
      || requiredAuthorityFiles.some((name) => !bindings.some((entry) => entry.path === name))) {
      throw new Error("Every applicable authority reference requires exactly one binding.");
    }
    for (const entry of bindings) {
      const actual = digest(readFileSync(path.join(directory, entry.path)));
      if (entry.sha256 !== actual) errors.push(`Authority hash mismatch: ${entry.path}`);
    }
    const skillHash = digest(readFileSync(source));
    const adapterHash = digest(readFileSync(path.join(root, adapter.path)));
    if (authority.sha256 !== skillHash) errors.push("Selected skill revision is stale.");
    if (adapter.sha256 !== adapterHash) errors.push("Product adapter revision is stale.");
    Object.assign(result, {
      authority_root: directory,
      authority_path: source,
      authority_sha256: skillHash,
      product_adapter_sha256: adapterHash,
      bound_file_count: bindings.length,
    });
    if (errors.length === 0) result.status = "pass";
  } catch (error) {
    errors.push(error.message);
  }
  return result;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
  const result = validateDesignAuthority({
    root,
    register: process.env.EXCEPTIONS_REGISTER || path.join(root, "docs/governance/design-exceptions.json"),
    authorityRoot: process.env.REVOLUT_DESIGN_ROOT,
  });
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = result.status === "pass" ? 0 : 1;
}
