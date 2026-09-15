#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { createHash, verify } from "node:crypto";
import { crc32, inflateSync } from "node:zlib";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { validateDesignAuthority } from "./validate_design_authority.mjs";
import { parseFlutterPubspecVersion, readDeclaredAndroidApplicationId } from "./android_release_contract.mjs";

export const VISUAL_CRITERIA = ["reference_fidelity", "hierarchy_density", "typography", "colour_elevation", "spacing_shape", "icons_assets", "copy_annotations", "interaction_states", "responsive_keyboard", "accessibility_native"];
export const QUALITY_DIMENSIONS = ["usability", "accessibility", "performance", "resilience"];
export const CASE_DIMENSIONS = ["role", "membership", "ownership", "permission", "geography", "payment_rail", "theme", "viewport", "orientation", "keyboard", "text_scale", "reduced_motion"];
export const MATERIAL_STATES = ["default", "loading", "empty", "no_results", "invalid", "disabled", "pending", "error", "offline", "recovery", "permission_denied", "focused", "pressed", "selected", "syncing", "conflict", "security_timeout"];
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const SHA = /^[a-f0-9]{64}$/;
const fail = (message) => { throw new Error(message); };
const must = (condition, message) => { if (!condition) fail(message); };
const nonempty = (value) => typeof value === "string" && value.trim().length > 0;
const exactKeys = (value, keys, label) => must(value && Object.keys(value).sort().join("|") === [...keys].sort().join("|"), `${label}: required keys differ`);
export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}
export const digest = (value) => createHash("sha256").update(value).digest("hex");
const json = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const same = (actual, expected, label) => must(canonical(actual) === canonical(expected), `${label}: mismatch`);
const unique = (values, label) => must(Array.isArray(values) && new Set(values).size === values.length, `${label}: missing or duplicate entries`);
const timestamp = (value, now, label) => {
  must(nonempty(value) && /(?:Z|[+-]\d\d:\d\d)$/.test(value) && Number.isFinite(Date.parse(value)), `${label}: timestamp missing or invalid`);
  must(Date.parse(value) <= now, `${label}: future timestamp`);
  return Date.parse(value);
};
function inside(parent, child) {
  const relative = path.relative(parent, child);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}
function resolveFile(root, name) {
  must(nonempty(name), "Evidence path is missing");
  return fs.realpathSync(path.resolve(root, name));
}
export function hashFile(file) {
  const hash = createHash("sha256");
  const handle = fs.openSync(file, "r");
  const buffer = Buffer.alloc(128 * 1024);
  try {
    let count;
    while ((count = fs.readSync(handle, buffer, 0, buffer.length, null)) > 0) hash.update(buffer.subarray(0, count));
  } finally { fs.closeSync(handle); }
  return hash.digest("hex");
}
export function artifactDigest(file, kind = "file") {
  if (kind === "file") {
    must(fs.statSync(file).isFile() && fs.statSync(file).size > 0, "Artifact must be a nonempty file");
    return hashFile(file);
  }
  must(kind === "directory" && fs.statSync(file).isDirectory(), "Unsupported artifact kind");
  const artifactRoot = fs.realpathSync(file);
  const entries = [];
  const visit = (directory) => {
    for (const name of fs.readdirSync(directory).sort()) {
      const full = path.join(directory, name);
      const stat = fs.lstatSync(full);
      if (stat.isSymbolicLink()) {
        // Framework version links are valid only while their targets remain in
        // the package tree, where the ordinary traversal hashes their bytes.
        must(inside(artifactRoot, fs.realpathSync(full)), "Artifact symlink escapes the package");
        entries.push({ path: path.relative(file, full), link: fs.readlinkSync(full) });
      }
      else if (stat.isDirectory()) visit(full);
      else { must(stat.isFile(), "Unsupported installed-package entry"); entries.push({ path: path.relative(file, full), sha256: hashFile(full), bytes: stat.size }); }
    }
  };
  visit(file);
  must(entries.length > 0, "Artifact directory is empty");
  return digest(canonical(entries));
}
export function nativeSourceSnapshot(root, app) {
  must(/^[a-z][a-z0-9_]*$/.test(app), "Invalid app slug");
  must(fs.existsSync(path.join(root, "apps", app, "assets/flavors/production.json")), "Unknown configured app");
  const paths = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "packages", `apps/${app}`, "tools/scripts", ".github/workflows", "pubspec.yaml", "pubspec.lock", ".fvmrc", "DESIGN.md"], { cwd: root, encoding: "utf8" }).split("\0").filter(Boolean)
    .filter((name) => !name.startsWith(`apps/${app}/web/`))
    .filter((name) => !name.startsWith("packages/") || /\/(?:lib|assets)\/|\/pubspec\.(?:yaml|lock)$/.test(name));
  for (const relative of [
    `apps/${app}/android/app/google-services.json`,
    `apps/${app}/android/local.properties`,
    `apps/${app}/ios/Runner/GoogleService-Info.plist`,
    `apps/${app}/ios/Flutter/Generated.xcconfig`,
    `apps/${app}/ios/Runner/GeneratedPluginRegistrant.h`,
    `apps/${app}/ios/Runner/GeneratedPluginRegistrant.m`,
    `apps/${app}/.flutter-plugins-dependencies`,
  ]) {
    if (fs.existsSync(path.join(root, relative))) paths.push(relative);
  }
  // Ignored generated Dart files and bundled assets still affect the binary.
  // Git's tracked/untracked listing alone is not a complete build-input list.
  const collect = (directory) => {
    if (!fs.existsSync(directory)) return;
    for (const name of fs.readdirSync(directory).sort()) {
      if (name.startsWith(".")) continue;
      const full = path.join(directory, name);
      const stat = fs.lstatSync(full);
      if (stat.isDirectory()) collect(full);
      else paths.push(path.relative(root, full));
    }
  };
  for (const directory of ["lib", "assets", "android/app/src"].map(relative => path.join(root, "apps", app, relative))) collect(directory);
  for (const packageFile of paths.filter((name) => /^packages\/.+\/pubspec\.yaml$/.test(name))) {
    const directory = path.dirname(path.join(root, packageFile));
    collect(path.join(directory, "lib")); collect(path.join(directory, "assets"));
  }
  const files = [...new Set(paths)].sort().map((name) => {
    const file = path.join(root, name);
    if (!fs.existsSync(file)) return { path: name, deleted: true };
    const stat = fs.lstatSync(file);
    if (stat.isSymbolicLink()) {
      must(fs.statSync(file).isFile(), "Native source directory links require an explicit build-input inventory");
      return { path: name, link: fs.readlinkSync(file), sha256: hashFile(file), bytes: fs.statSync(file).size };
    }
    return { path: name, sha256: hashFile(file), bytes: stat.size };
  });
  must(files.length > 0, "Native source input inventory is empty");
  return { app, sha256: digest(canonical(files)), files };
}
export function configuredApps(root) {
  return fs.readdirSync(path.join(root, "apps")).filter((app) => fs.existsSync(path.join(root, "apps", app, "assets/flavors/production.json"))).sort();
}
export function discoverOverlaySites(root) {
  const files = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "packages"], { cwd: root, encoding: "utf8" }).split("\0").filter((name) => /\/lib\/.*\.dart$/.test(name));
  const sites = [];
  for (const name of [...new Set(files)].sort()) {
    if (!fs.existsSync(path.join(root, name))) continue;
    const source = fs.readFileSync(path.join(root, name), "utf8").replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, (value) => value.replace(/[^\n]/g, " "));
    const pattern = /\b(showModalBottomSheet|showDialog|showMenu|showDatePicker|showTimePicker|showCupertinoModalPopup)\s*(?:<[^\n>]*>)?\s*\(/g;
    let ordinal = 0;
    for (const match of source.matchAll(pattern)) {
      ordinal += 1;
      sites.push({ id: digest(`${name}|${match[1]}|${ordinal}`).slice(0, 20), file: name, line: source.slice(0, match.index).split("\n").length, invocation: match[1] });
    }
  }
  return sites;
}
export function generateRequiredCases({ routeInventory, inventory, app, platform }) {
  must(["android", "ios"].includes(platform), "Unknown mobile platform");
  const routes = routeInventory.routes.filter((route) => ["mobile", "mobile_internal_admin"].includes(route.surface));
  const routeKeys = routes.map((route) => `${route.surface}|${route.path}|${route.kind}`);
  unique(routeKeys, "Native route inventory");
  const families = inventory.families;
  must(Array.isArray(families), "Mobile case families are missing");
  unique(families.map((family) => family.id), "Mobile family IDs");
  same(families.filter((family) => family.kind === "route").map((family) => family.route_key).sort(), [...routeKeys].sort(), "Governed families must cover all production routes and aliases");
  const cases = [];
  for (const family of families) {
    must(["route", "overlay"].includes(family.kind), `Unknown surface family ${family.id}`);
    must(Array.isArray(family.states) && family.states.length > 0, `Missing material states: ${family.id}`);
    unique(family.states, `States: ${family.id}`);
    const inapplicable = family.inapplicable_states ?? [];
    unique(inapplicable.map(entry => entry.state), `Inapplicable states: ${family.id}`);
    must(inapplicable.every(entry => MATERIAL_STATES.includes(entry.state) && !family.states.includes(entry.state)), `Conflicting state applicability: ${family.id}`);
    must(MATERIAL_STATES.every((state) => family.states.includes(state) || inapplicable.some(entry => entry.state === state)), `Material state omissions: ${family.id}`);
    must(Array.isArray(family.contexts) && family.contexts.length > 0, `Missing governed contexts: ${family.id}`);
    exactKeys(family.dimension_requirements, CASE_DIMENSIONS, `Dimensions: ${family.id}`);
    const contexts = family.contexts.filter((context) => context.platforms.includes(platform) && (context.apps === "all" || context.apps.includes(app)));
    must(contexts.length > 0, `Missing ${app}/${platform} coverage: ${family.id}`);
    for (const dimension of CASE_DIMENSIONS) {
      const required = family.dimension_requirements[dimension];
      must(Array.isArray(required) && required.length > 0, `Unspecified ${dimension}: ${family.id}`);
      must(required.every((value) => contexts.some((context) => canonical(context.values[dimension]) === canonical(value))), `Uncovered ${dimension}: ${family.id}`);
    }
    for (const context of contexts) {
      must(nonempty(context.id), "Context ID missing");
      exactKeys(context.values, CASE_DIMENSIONS, `Context ${context.id}`);
      for (const value of Object.values(context.values)) must(value !== null && value !== "unverified" && value !== "unknown" && value !== "not_applicable", `Unverified context ${context.id}`);
      must(["portrait", "landscape"].includes(context.values.orientation), "Orientation must be explicit");
      for (const state of family.states) cases.push({ id: `${app}|${platform}|${family.id}|${state}|${context.id}`, app, platform, family_id: family.id, route_key: family.route_key, kind: family.kind, state, context: context.values });
    }
  }
  unique(cases.map((entry) => entry.id), "Required case IDs");
  must(cases.length > 0, "No required mobile cases");
  return cases;
}
function evidenceFile(root, ref, bundles, label, { source = false } = {}) {
  must(ref && SHA.test(ref.sha256), `${label}: hash missing`);
  const file = resolveFile(root, ref.path);
  must(fs.statSync(file).isFile() && fs.statSync(file).size > 0, `${label}: file missing or empty`);
  same(hashFile(file), ref.sha256, `${label}: current bytes`);
  if (source) must(inside(root, file), `${label}: source evidence must be in the checkout`);
  else {
    const bundle = bundles.find((entry) => entry.id === ref.bundle_id);
    must(bundle?.admission_status === "admitted", `${label}: bundle is not admitted`);
    must(bundle.data_source !== "synthetic" && bundle.fixture !== true, `${label}: fixture evidence cannot approve a production artifact`);
    const directory = resolveFile(root, bundle.directory);
    must(inside(directory, file), `${label}: evidence escapes its registered bundle`);
    must(bundle.artifacts?.some((entry) => entry.path === ref.path && entry.sha256 === ref.sha256), `${label}: artifact is not registered by hash`);
  }
  return file;
}
function evidenceList(root, refs, bundles, label, options) {
  must(Array.isArray(refs) && refs.length > 0, `${label}: evidence is missing`);
  refs.forEach((ref) => evidenceFile(root, ref, bundles, label, options));
}
function pngSize(file) {
  const bytes = fs.readFileSync(file);
  must(bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), "Native capture/comparison must be a PNG");
  let offset = 8; let header; let ended = false; const compressed = [];
  while (offset + 12 <= bytes.length) {
    const length = bytes.readUInt32BE(offset);
    must(offset + length + 12 <= bytes.length, "Truncated PNG chunk");
    const type = bytes.toString("ascii", offset + 4, offset + 8);
    const data = bytes.subarray(offset + 8, offset + 8 + length);
    same(crc32(bytes.subarray(offset + 4, offset + 8 + length)), bytes.readUInt32BE(offset + 8 + length), "PNG chunk checksum");
    if (type === "IHDR") { must(offset === 8 && length === 13, "Invalid PNG header"); header = data; }
    if (type === "IDAT") compressed.push(data);
    offset += length + 12;
    if (type === "IEND") { must(length === 0 && offset === bytes.length, "Invalid PNG ending"); ended = true; break; }
  }
  must(header && ended && compressed.length > 0, "PNG image is incomplete");
  const width = header.readUInt32BE(0); const height = header.readUInt32BE(4);
  must(width > 0 && height > 0 && width * height <= 100_000_000, "Invalid capture dimensions");
  must(header[8] === 8 && [2, 6].includes(header[9]) && header[10] === 0 && header[11] === 0 && header[12] === 0, "Capture must be a non-interlaced 8-bit RGB/RGBA PNG");
  const channels = header[9] === 6 ? 4 : 3;
  const rowBytes = width * channels + 1;
  const decoded = inflateSync(Buffer.concat(compressed), { maxOutputLength: rowBytes * height });
  must(decoded.length === rowBytes * height, "Invalid PNG pixel data");
  for (let row = 0; row < height; row += 1) must(decoded[row * rowBytes] <= 4, "Invalid PNG scanline filter");
  return { width, height };
}
function reviewSignatures(record, reviewers, now) {
  unique(reviewers.map((reviewer) => reviewer.id), "Registered reviewers");
  const required = ["implementer", "independent_visual", "owner"];
  must(Array.isArray(record.reviews), "Distinct mobile reviews are missing");
  same(record.reviews.map((review) => review.role).sort(), [...required].sort(), "Three distinct review records are required");
  const payloadHash = digest(canonical(record.payload));
  const actors = {};
  const times = [];
  for (const review of record.reviews) {
    const person = reviewers.find((candidate) => candidate.id === review.reviewer_id);
    must(person && person.active === true && person.roles.includes(review.role), `Reviewer is not registered for ${review.role}`);
    must(person.synthetic === false && review.synthetic === false, "Synthetic reviews cannot authorize release");
    same(review.payload_sha256, payloadHash, `${review.role} review payload hash`);
    const at = timestamp(review.reviewed_at, now, `${review.role} review`); times.push(at);
    const signed = { role: review.role, reviewer_id: review.reviewer_id, reviewed_at: review.reviewed_at, payload_sha256: payloadHash };
    must(nonempty(review.signature) && verify(null, Buffer.from(canonical(signed)), person.public_key_pem, Buffer.from(review.signature, "base64")), `${review.role} review signature is unverifiable`);
    actors[review.role] = review.reviewer_id;
  }
  must(actors.independent_visual !== actors.implementer, "The visual reviewer must be independent of the implementer");
  return { actors, oldestReview: Math.min(...times) };
}
function qualityResult(root, quality, bundles, label) {
  exactKeys(quality, QUALITY_DIMENSIONS, `${label} quality dimensions`);
  for (const dimension of QUALITY_DIMENSIONS) {
    const result = quality[dimension];
    must(result.status === "pass", `${label}: ${dimension} does not pass independently`);
    same(result.critical_findings, [], `${label}: critical ${dimension} findings`);
    same(result.high_findings, [], `${label}: high ${dimension} findings`);
    evidenceList(root, result.evidence, bundles, `${label}: ${dimension}`);
  }
}

export function validateMobileDesignRelease({ root = ROOT, app, platform, acceptanceId, artifactPath, routeDirectory, authorityRoot, now = Date.now() }) {
  const report = { rule: "MOBILE-DESIGN-100", app, platform, status: "fail", design_complete: false, errors: [], non_certified: ["web", "admin_pwa", "deployment", "provider_activation", "signing", "store_review", "public_availability"] };
  try {
    root = fs.realpathSync(root);
    must(configuredApps(root).includes(app), "Unknown configured app");
    must(["android", "ios"].includes(platform), "Select Android or iOS explicitly");
    const contractPath = path.join(root, "docs/governance/design-exceptions.json");
    const document = json(contractPath);
    const authority = validateDesignAuthority({ root, register: contractPath, authorityRoot });
    must(authority.status === "pass", `Design authority is unverified: ${authority.errors.join("; ")}`);
    const contract = document.mobile_acceptance.contract;
    must(contract?.schema_version === 1, "Product mobile release contract is missing");
    same(contract.visual_criteria, VISUAL_CRITERIA, "Stable visual criteria");
    same(contract.quality_dimensions, QUALITY_DIMENSIONS, "Separate quality dimensions");
    same(contract.platforms, ["android", "ios"], "Declared platform scope");
    const ledger = json(path.join(root, contract.release_registry));
    const record = ledger.mobile_release_acceptances?.find((candidate) => candidate.id === acceptanceId && candidate.app === app && candidate.platform === platform);
    must(record, "No reviewed acceptance record for this app and platform");
    const reviews = reviewSignatures(record, ledger.mobile_reviewers ?? [], now);
    const payload = record.payload;
    const source = nativeSourceSnapshot(root, app);
    const references = json(path.join(root, contract.reference_registry));
    const caseRegistry = json(path.join(root, contract.case_registry));
    const inventory = caseRegistry.mobile_release_inventory;
    must(inventory?.status === "reviewed", "Governed mobile case inventory is incomplete");
    must(inventory.owner_annotation_inventory_status === "reviewed", "Owner annotation discovery is incomplete");
    exactKeys(inventory.coverage_audit, CASE_DIMENSIONS, "Coverage audit dimensions");
    for (const dimension of CASE_DIMENSIONS) {
      must(inventory.coverage_audit[dimension].status === "complete", `Coverage audit is open: ${dimension}`);
      evidenceList(root, inventory.coverage_audit[dimension].evidence, ledger.bundles, `Inventory ${dimension}`, { source: true });
    }
    const directory = path.resolve(root, routeDirectory ?? contract.route_inventory_directory);
    const routes = json(path.join(directory, "route-inventory.json"));
    const routeProof = json(path.join(directory, "route-inventory-provenance.json"));
    same(routeProof.route_inventory_sha256, hashFile(path.join(directory, "route-inventory.json")), "Generated route inventory bytes");
    same(routeProof.native_sources?.[app], source.sha256, "Route discovery source revision");
    same(routes.duplicate_keys, [], "Duplicate discovered routes");
    const cases = generateRequiredCases({ routeInventory: routes, inventory, app, platform });
    report.required_cases = cases.length;
    for (const family of inventory.families) {
      for (const decision of family.inapplicable_states ?? []) {
        must(nonempty(decision.product_reason) && Object.values(reviews.actors).includes(decision.reviewer_id), `Unjustified state applicability: ${family.id}/${decision.state}`);
        must(timestamp(decision.reviewed_at, now, "State applicability review") <= reviews.oldestReview, "State applicability was reviewed after acceptance");
        evidenceList(root, decision.unavailability_evidence, ledger.bundles, `Unavailable state ${family.id}/${decision.state}`, { source: true });
      }
    }
    const sites = discoverOverlaySites(root);
    const dispositions = inventory.overlay_dispositions ?? [];
    same(dispositions.map((entry) => entry.site_id).sort(), sites.map((entry) => entry.id).sort(), "Overlay discovery inventory");
    for (const entry of dispositions) {
      if (entry.disposition === "covered") must(inventory.families.some((family) => family.id === entry.family_id && family.kind === "overlay"), "Overlay has no governed family");
      else { must(entry.disposition === "not_ui_surface" && nonempty(entry.reason), "Unknown overlay disposition"); evidenceList(root, entry.evidence, ledger.bundles, "Overlay source disposition", { source: true }); }
    }
    const version = parseFlutterPubspecVersion(fs.readFileSync(path.join(root, "apps", app, "pubspec.yaml"), "utf8"));
    const artifact = payload.artifact;
    must(artifact?.build_profile === "release" && artifact.flavor === "production" && artifact.fixture === false, "Only the production release artifact can be accepted");
    const actualArtifact = resolveFile(root, artifactPath ?? artifact.path);
    same(actualArtifact, resolveFile(root, artifact.path), "Selected release artifact path");
    const artifactHash = artifactDigest(actualArtifact, artifact.kind);
    same(artifact.sha256, artifactHash, "Release artifact bytes");
    const binding = { source_sha256: source.sha256, contract_sha256: hashFile(contractPath), reference_registry_sha256: digest(canonical(references)), case_inventory_sha256: digest(canonical({ routes: routes.routes.filter((route) => String(route.surface).startsWith("mobile")), inventory })), version: version.buildName, build_number: version.buildNumber, artifact_sha256: artifactHash };
    same(payload.binding, binding, "Reviewed source, contract, references, cases, version and artifact binding");
    const buildProof = json(evidenceFile(root, artifact.build_proof, ledger.bundles, "Native build provenance"));
    same(buildProof.source_sha256, source.sha256, "Build source provenance");
    same(buildProof.artifact_sha256, artifactHash, "Build artifact provenance");
    same(buildProof.version, version.buildName, "Build version provenance");
    same(buildProof.build_number, version.buildNumber, "Build number provenance");
    must(buildProof.profile === "release" && buildProof.flavor === "production" && buildProof.fixture === false, "Build provenance is not for a production release");
    must(nonempty(buildProof.command) && buildProof.tool_versions && Object.keys(buildProof.tool_versions).length > 0, "Build command/tool provenance is missing");
    evidenceFile(root, buildProof.execution_log, ledger.bundles, "Native build execution log");
    if (platform === "android") same(artifact.package_id, readDeclaredAndroidApplicationId(path.join(root, "apps", app)), "Production Android package");
    else {
      const project = fs.readFileSync(path.join(root, "apps", app, "ios/Runner.xcodeproj/project.pbxproj"), "utf8");
      const ids = [...project.matchAll(/PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.]+);/g)].map((match) => match[1]).filter((id) => !id.includes(".qa.") && !id.endsWith(".RunnerTests"));
      must(ids.length > 0 && new Set(ids).size === 1, "Production iOS identity is ambiguous");
      same(artifact.package_id, ids[0], "Production iOS package");
    }
    const installation = payload.installation;
    same(installation?.artifact_sha256, artifactHash, "Installed release artifact binding");
    must(nonempty(installation.device_id) && installation.device_class === "physical", "Physical installation evidence is missing");
    const installedAt = timestamp(installation.installed_at, now, "Installation");
    const builtAt = timestamp(buildProof.finished_at, now, "Native build completion");
    must(builtAt <= installedAt, "Installation precedes the native build");
    must(installedAt <= reviews.oldestReview, "Reviews precede installation");
    let deliveredArtifact = actualArtifact; let deliveredHash = artifactHash; let deliveredKind = artifact.kind;
    if (installation.delivery) {
      const delivery = installation.delivery;
      deliveredArtifact = resolveFile(root, delivery.path);
      deliveredKind = delivery.kind;
      deliveredHash = artifactDigest(deliveredArtifact, deliveredKind);
      same(delivery.sha256, deliveredHash, "Delivered package bytes");
      const transformation = json(evidenceFile(root, delivery.proof, ledger.bundles, "Package delivery provenance"));
      same(transformation.input_artifact_sha256, artifactHash, "Delivery input artifact");
      same(transformation.output_package_sha256, deliveredHash, "Delivery output package");
      same(transformation.package_id, artifact.package_id, "Delivery package identity");
      must(nonempty(transformation.command) && nonempty(transformation.tool_version), "Package delivery tool provenance missing");
      evidenceFile(root, transformation.execution_log, ledger.bundles, "Package conversion execution log");
    }
    const readback = resolveFile(root, installation.readback?.path);
    must(readback !== actualArtifact && readback !== deliveredArtifact && !inside(actualArtifact, readback) && !inside(deliveredArtifact, readback), "Readback must be separate from the build artifact");
    same(artifactDigest(readback, deliveredKind), deliveredHash, "Installed package readback bytes");
    same(installation.readback.sha256, deliveredHash, "Recorded package readback hash");
    const installProof = json(evidenceFile(root, installation.proof, ledger.bundles, "Installation proof"));
    same(installProof.device_id, installation.device_id, "Installation device provenance");
    same(installProof.package_id, artifact.package_id, "Installed package identity");
    same(installProof.source_artifact_sha256, artifactHash, "Installation source provenance");
    same(installProof.readback_sha256, deliveredHash, "Installation readback provenance");
    evidenceFile(root, installProof.execution_log, ledger.bundles, "Device install/readback execution log");
    same(payload.open_material_findings, [], "Open material findings");
    same(payload.waivers, [], "Release waivers");
    same(payload.skip_flags, [], "Release skip flags");
    qualityResult(root, payload.quality, ledger.bundles, "Platform");
    must(Array.isArray(payload.cases), "Case evidence missing");
    same(payload.cases.map((entry) => entry.id).sort(), cases.map((entry) => entry.id).sort(), "Exact required case coverage");
    const catalog = references.reference_catalog ?? [];
    unique(catalog.map((entry) => entry.id), "Reference IDs");
    for (const expected of cases) {
      const evidence = payload.cases.find((entry) => entry.id === expected.id);
      same(evidence.case, expected, `Case definition ${expected.id}`);
      same(evidence.artifact_sha256, artifactHash, `Case artifact ${expected.id}`);
      must(evidence.capture_kind === "native_screenshot", "Fixture/golden captures cannot approve a production artifact");
      const captured = timestamp(evidence.captured_at, now, "Native capture");
      must(captured >= installedAt && captured <= reviews.oldestReview, "Capture is outside the installed/reviewed interval");
      const screenshot = evidenceFile(root, evidence.screenshot, ledger.bundles, "Native screenshot");
      const comparison = evidenceFile(root, evidence.comparison, ledger.bundles, "Visual comparison");
      must(evidence.screenshot.sha256 !== evidence.comparison.sha256, "A screenshot cannot compare with itself");
      const viewport = inventory.viewport_profiles?.[expected.context.viewport];
      must(viewport && viewport.width > 0 && viewport.height > 0 && viewport.dpr > 0, "Viewport profile is missing");
      const landscape = expected.context.orientation === "landscape";
      same(pngSize(screenshot), { width: Math.round((landscape ? viewport.height : viewport.width) * viewport.dpr), height: Math.round((landscape ? viewport.width : viewport.height) * viewport.dpr) }, "Native screenshot dimensions");
      pngSize(comparison);
      const comparator = evidence.comparator;
      must(["direct", "component_pattern", "explicit_adaptation"].includes(comparator?.kind), "Comparator classification is missing");
      must(nonempty(comparator.rationale) && Array.isArray(comparator.reference_ids) && comparator.reference_ids.length > 0, "Comparator evidence is missing");
      unique(comparator.reference_ids, "Case references");
      for (const id of comparator.reference_ids) {
        const reference = catalog.find((entry) => entry.id === id);
        must(reference && reference.intended_families.includes(expected.family_id), `Reference ${id} does not cover this family`);
        must(reference.state_scope.includes(expected.state), `Reference ${id} is not state-appropriate`);
        must(reference.cohort && reference.platform && reference.theme && reference.dimensions?.width > 0 && reference.dimensions?.height > 0 && nonempty(reference.limitations), `Reference ${id} metadata is incomplete`);
        must(Object.hasOwn(reference, "region") && Object.hasOwn(reference, "captured_at") && Object.hasOwn(reference, "build"), `Reference ${id} provenance fields are missing`);
        const original = resolveFile(authority.authority_root, reference.private_location);
        must(!inside(root, original), "Private comparator originals must stay outside the repository");
        same(hashFile(original), reference.sha256, `Reference ${id} current bytes`);
        if (comparator.kind === "direct") {
          same(reference.platform, platform, `Direct reference ${id} platform`);
          same(reference.theme, expected.context.theme, `Direct reference ${id} theme`);
        }
      }
      exactKeys(evidence.criteria, VISUAL_CRITERIA, "Ten visual criteria");
      for (const criterion of VISUAL_CRITERIA) {
        const decision = evidence.criteria[criterion];
        must(["pass", "not_applicable"].includes(decision.status), `Visual criterion does not pass: ${criterion}`);
        must(Object.values(reviews.actors).includes(decision.reviewer_id), `Unknown criterion reviewer: ${criterion}`);
        const reviewedAt = timestamp(decision.reviewed_at, now, "Criterion review");
        must(reviewedAt >= captured && reviewedAt <= reviews.oldestReview, "Criterion review is outside the capture/acceptance interval");
        if (decision.status === "not_applicable") {
          must(nonempty(decision.product_reason), `Unjustified inapplicable criterion: ${criterion}`);
          evidenceList(root, decision.evidence, ledger.bundles, `Criterion ${criterion}`, { source: true });
        } else evidenceList(root, decision.evidence, ledger.bundles, `Criterion ${criterion}`);
      }
      same(evidence.open_findings, [], "Open case findings");
      qualityResult(root, evidence.quality, ledger.bundles, `Case ${expected.id}`);
    }
    const annotations = inventory.owner_annotations ?? [];
    same(payload.owner_annotations?.map((entry) => entry.id).sort(), annotations.map((entry) => entry.id).sort(), "Owner annotation coverage");
    for (const annotation of payload.owner_annotations) {
      const original = annotations.find((entry) => entry.id === annotation.id);
      same(annotation.requirement_sha256, digest(original.requirement), "Owner requirement must remain intact");
      must(annotation.status === "closed" && annotation.source_sha256 === source.sha256, "Owner annotation is open or stale");
      evidenceList(root, annotation.implementation_evidence, ledger.bundles, "Owner annotation", { source: true });
    }
    must(Array.isArray(payload.baseline_regenerations), "Baseline regeneration history is missing");
    for (const entry of payload.baseline_regenerations) {
      must(entry.visual_reviewed_by === reviews.actors.independent_visual, "Regenerated baseline lacks independent visual review");
      must(timestamp(entry.reviewed_at, now, "Baseline review") <= reviews.oldestReview, "Baseline review is stale");
      evidenceList(root, entry.comparison_evidence, ledger.bundles, "Regenerated baseline comparison");
    }
    same(nativeSourceSnapshot(root, app).sha256, source.sha256, "Source changed while checking acceptance");
    Object.assign(report, { status: "pass", design_complete: true, acceptance_id: record.id, binding, reviewed_cases: cases.length, reviews: reviews.actors });
  } catch (error) { report.errors.push(error.message); }
  return report;
}

function options(argumentsList) {
  const values = {};
  for (let index = 0; index < argumentsList.length; index += 2) {
    must(argumentsList[index]?.startsWith("--") && argumentsList[index + 1] !== undefined, "Use named options with explicit values");
    must(!Object.hasOwn(values, argumentsList[index].slice(2)), "Duplicate command option");
    values[argumentsList[index].slice(2)] = argumentsList[index + 1];
  }
  return values;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = options(process.argv.slice(2));
    const allowed = ["app", "platform", "acceptance-id", "artifact", "route-directory", "output"];
    must(Object.keys(args).every((key) => allowed.includes(key)), "Unknown option; no skip/waiver mode exists");
    const report = validateMobileDesignRelease({ app: args.app, platform: args.platform, acceptanceId: args["acceptance-id"], artifactPath: args.artifact, routeDirectory: args["route-directory"], authorityRoot: process.env.REVOLUT_DESIGN_ROOT });
    if (args.output) fs.writeFileSync(args.output, `${JSON.stringify(report, null, 2)}\n`);
    console.log(JSON.stringify(report, null, 2));
    process.exitCode = report.status === "pass" ? 0 : 1;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
