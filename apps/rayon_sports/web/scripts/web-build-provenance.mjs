import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const requireValue = (value, message) => { if (!value) throw new Error(message); };
const inputPath = (root) => path.join(root, "tmp/next-build-inputs.json");
const sealPath = (root) => path.join(root, ".next/africlub-build-provenance.json");
const write = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};

function inventory(root, entries) {
  const files = [];
  const visit = (relative) => {
    const full = path.resolve(root, relative);
    const stat = fs.lstatSync(full);
    if (stat.isSymbolicLink()) {
      const target = fs.realpathSync(full);
      const relativeTarget = path.relative(root, target);
      requireValue(relativeTarget !== ".." && !relativeTarget.startsWith(`..${path.sep}`) && !path.isAbsolute(relativeTarget), `Build input symlink escapes web root: ${relative}`);
      requireValue(fs.statSync(target).isFile(), `Build input directory link requires explicit inventory: ${relative}`);
      files.push({ file: relative, link: fs.readlinkSync(full), sha256: sha256(fs.readFileSync(full)) });
    } else if (stat.isDirectory()) {
      for (const entry of fs.readdirSync(full).sort()) visit(path.join(relative, entry));
    } else {
      requireValue(stat.isFile(), `Unsupported build input: ${relative}`);
      files.push({ file: relative, sha256: sha256(fs.readFileSync(full)) });
    }
  };
  for (const entry of entries.sort()) visit(entry);
  return { sha256: sha256(JSON.stringify(files)), files };
}

export function productionSourceSnapshot(root) {
  // Test fixtures and generated output are deliberately outside production input.
  // Dotenv files are hashed, never copied into evidence or printed as values.
  const entries = ["src", "public", "package.json", "package-lock.json", "next.config.ts", "postcss.config.mjs", "tsconfig.json",
    "scripts/run-next-build-stable.mjs", "scripts/ensure-next-build-artifacts.mjs", "scripts/fix-route-group-manifests.mjs", "scripts/web-build-provenance.mjs"];
  for (const file of [".env", ".env.local", ".env.production", ".env.production.local"]) {
    if (fs.existsSync(path.join(root, file))) entries.push(file);
  }
  return inventory(root, entries);
}

export function productionArtifactSnapshot(root) {
  for (const entry of ["BUILD_ID", "static", "server/app", "standalone/server.js"]) {
    requireValue(fs.existsSync(path.join(root, ".next", entry)), `Incomplete production artifacts: ${entry}`);
  }
  // Runtime caches and telemetry traces may change while serving requests.
  const entries = fs.readdirSync(path.join(root, ".next")).filter((entry) =>
    !["cache", "diagnostics", "trace", "trace-build", "africlub-build-provenance.json"].includes(entry));
  return inventory(path.join(root, ".next"), entries);
}

export function beginProductionBuild(root, command) {
  const source = productionSourceSnapshot(root);
  const declared = read(path.join(root, "package.json"));
  const environmentKeys = new Set(["NODE_ENV", "AFRICLUB_ALLOW_HTTP_PREVIEW", "AFRICLUB_CONTROLLED_ADMIN_EVIDENCE", "AFRICLUB_CONTROLLED_ROUTE_EVIDENCE"]);
  for (const entry of source.files.filter((entry) => /\.[cm]?[jt]sx?$/.test(entry.file))) {
    for (const match of fs.readFileSync(path.join(root, entry.file), "utf8").matchAll(/process\.env\.([A-Z][A-Z0-9_]*)/g)) environmentKeys.add(match[1]);
  }
  const environment = Object.fromEntries([...environmentKeys].sort().map((key) => [key,
    Object.hasOwn(process.env, key) ? sha256(process.env[key]) : null]));
  const record = { schema_version: 1, started_at: new Date().toISOString(), source,
    node: process.version, next: read(path.join(root, "node_modules/next/package.json")).version,
    declared_package_manager: declared.packageManager, command, environment_value_sha256: environment,
    environment_scope: "Hash-only explicit process values; absent keys may be resolved from the recorded dotenv files. No secret values are stored.", compiled: false };
  write(inputPath(root), record);
  return record;
}

export function markProductionCompilationComplete(root) {
  const record = read(inputPath(root));
  requireValue(record.source.sha256 === productionSourceSnapshot(root).sha256, "Production source changed during compilation");
  productionArtifactSnapshot(root);
  record.compiled = true;
  record.compiled_at = new Date().toISOString();
  write(inputPath(root), record);
}

export function sealProductionBuild(root) {
  const record = read(inputPath(root));
  requireValue(record.compiled === true, "No successful production compilation is recorded");
  requireValue(record.source.sha256 === productionSourceSnapshot(root).sha256, "Production source changed before sealing");
  const artifacts = productionArtifactSnapshot(root);
  const result = { ...record, finished_at: new Date().toISOString(), build_id: fs.readFileSync(path.join(root, ".next/BUILD_ID"), "utf8").trim(), artifacts };
  write(sealPath(root), result);
  return result;
}

export function validateProductionBuild(root) {
  requireValue(fs.existsSync(sealPath(root)), "Production build provenance is missing; rebuild with the governed build command");
  const record = read(sealPath(root));
  requireValue(record.schema_version === 1 && record.compiled === true, "Invalid production build provenance");
  requireValue(record.build_id === fs.readFileSync(path.join(root, ".next/BUILD_ID"), "utf8").trim(), "Production build ID differs from its source seal");
  requireValue(record.source.sha256 === productionSourceSnapshot(root).sha256, "Production build is stale for the current source");
  requireValue(record.artifacts.sha256 === productionArtifactSnapshot(root).sha256, "Production artifacts changed after their source seal");
  return { build_id: record.build_id, source_sha256: record.source.sha256, artifact_sha256: record.artifacts.sha256,
    provenance_sha256: sha256(fs.readFileSync(sealPath(root))), started_at: record.started_at, finished_at: record.finished_at };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    requireValue(process.argv.length === 3 && ["seal", "check"].includes(process.argv[2]), "Use seal or check");
    if (process.argv[2] === "seal") sealProductionBuild(process.cwd());
    console.log(JSON.stringify(validateProductionBuild(process.cwd()), null, 2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
