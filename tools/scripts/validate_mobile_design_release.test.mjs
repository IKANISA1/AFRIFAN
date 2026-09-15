import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { generateKeyPairSync, sign } from "node:crypto";
import { crc32, deflateSync } from "node:zlib";
import { execFileSync } from "node:child_process";
import { requiredAuthorityFiles } from "./validate_design_authority.mjs";
import { VISUAL_CRITERIA, QUALITY_DIMENSIONS, CASE_DIMENSIONS, MATERIAL_STATES, canonical, digest, hashFile, artifactDigest, nativeSourceSnapshot, generateRequiredCases, validateMobileDesignRelease } from "./validate_mobile_design_release.mjs";

// All app binaries, people, review keys and evidence in these tests are fictional
// temporary fixtures. No production reviewer or acceptance registry is written.
const write = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, value); };
const writeJson = (file, value) => write(file, JSON.stringify(value, null, 2) + "\n");
const chunk = (name, data) => {
  const type = Buffer.from(name); const length = Buffer.alloc(4); length.writeUInt32BE(data.length);
  const checksum = Buffer.alloc(4); checksum.writeUInt32BE(crc32(Buffer.concat([type, data])));
  return Buffer.concat([length, type, data, checksum]);
};
function image(red = 30) {
  const header = Buffer.alloc(13); header.writeUInt32BE(2, 0); header.writeUInt32BE(2, 4); header[8] = 8; header[9] = 6;
  const row = Buffer.from([0, red, 20, 30, 255, red, 20, 30, 255]);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", header), chunk("IDAT", deflateSync(Buffer.concat([row, row]))), chunk("IEND", Buffer.alloc(0))]);
}
function fixture(t, platform = "android") {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-mobile-design-gate-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const root = path.join(directory, "product"); const authority = path.join(directory, "authority");
  fs.mkdirSync(root); fs.mkdirSync(authority);
  execFileSync("git", ["init", "-q", root]);
  const app = "fixture_club"; const familyId = "mobile|/home|tab";
  writeJson(path.join(root, `apps/${app}/assets/flavors/production.json`), { CLUB_ID: "1" });
  write(path.join(root, `apps/${app}/lib/main.dart`), "void main() {}\n");
  write(path.join(root, `apps/${app}/pubspec.yaml`), "name: fixture_club\nversion: 1.0.0+1\n");
  write(path.join(root, `apps/${app}/android/app/build.gradle.kts`), 'android {\n defaultConfig {\n applicationId = "rw.example.club"\n }\n}\n');
  write(path.join(root, `apps/${app}/ios/Runner.xcodeproj/project.pbxproj`), "PRODUCT_BUNDLE_IDENTIFIER = rw.example.club;\n");
  write(path.join(root, "DESIGN.md"), "Fictional product adapter for isolated unit tests.\n");
  const boundFiles = requiredAuthorityFiles.map(name => { write(path.join(authority, name), `Fictional authority fixture: ${name}\n`); return { path: name, sha256: hashFile(path.join(authority, name)) }; });
  const contract = { schema_version: 1, platforms: ["android", "ios"], visual_criteria: VISUAL_CRITERIA, quality_dimensions: QUALITY_DIMENSIONS, route_inventory_directory: "output/routes", case_registry: "docs/governance/route-state-evidence.json", reference_registry: "docs/governance/native-reference-map.json", release_registry: "docs/governance/evidence-bundles.json" };
  const document = { design_authority: { skill: "revolut-design", path: "SKILL.md", root_hint: authority, sha256: boundFiles[0].sha256, bound_files: boundFiles }, product_adapter: { path: "DESIGN.md", sha256: hashFile(path.join(root, "DESIGN.md")) }, mobile_acceptance: { rule: "MOBILE-DESIGN-100", path: "references/mobile-design-100.md", sha256: boundFiles.find(row => row.path === "references/mobile-design-100.md").sha256, contract } };
  const contractPath = path.join(root, "docs/governance/design-exceptions.json"); writeJson(contractPath, document);
  const codeRef = { path: `apps/${app}/lib/main.dart`, sha256: hashFile(path.join(root, `apps/${app}/lib/main.dart`)) };
  const context = { role: "signed_in_supporter", membership: "active", ownership: "self", permission: "granted", geography: "RW", payment_rail: "none", theme: "dark", viewport: "fixture", orientation: "portrait", keyboard: "closed", text_scale: 1, reduced_motion: false };
  const inventory = { status: "reviewed", owner_annotation_inventory_status: "reviewed", coverage_audit: Object.fromEntries(CASE_DIMENSIONS.map(name => [name, { status: "complete", evidence: [codeRef] }])), viewport_profiles: { fixture: { width: 2, height: 2, dpr: 1 } }, families: [{ id: familyId, kind: "route", route_key: familyId, states: MATERIAL_STATES, dimension_requirements: Object.fromEntries(CASE_DIMENSIONS.map(name => [name, [context[name]]])), contexts: [{ id: "fixture", apps: "all", platforms: ["android", "ios"], values: context }] }], overlay_dispositions: [], owner_annotations: [{ id: "OWNER-1", requirement: "Preserve the club identity." }] };
  const caseRegistry = { cells: {}, groups: [], mobile_release_inventory: inventory };
  const casesPath = path.join(root, contract.case_registry); writeJson(casesPath, caseRegistry);
  const referenceImage = path.join(authority, "private/reference.png"); write(referenceImage, image(60));
  const references = { reference_catalog: [{ id: "REF-1", cohort: "fictional-unit-test", platform: "ios", theme: "dark", region: null, captured_at: null, build: null, dimensions: { width: 2, height: 2 }, sha256: hashFile(referenceImage), private_location: "private/reference.png", intended_families: [familyId], state_scope: MATERIAL_STATES, limitations: "Fictional comparison used only by this unit test." }] };
  const referencesPath = path.join(root, contract.reference_registry); writeJson(referencesPath, references);
  const routes = { duplicate_keys: [], routes: [{ surface: "mobile", path: "/home", kind: "tab" }] };
  const routesPath = path.join(root, "output/routes/route-inventory.json"); writeJson(routesPath, routes);
  const source = nativeSourceSnapshot(root, app);
  const routeProofPath = path.join(root, "output/routes/route-inventory-provenance.json");
  const sealRoutes = () => writeJson(routeProofPath, { route_inventory_sha256: hashFile(routesPath), native_sources: { [app]: nativeSourceSnapshot(root, app).sha256 } });
  sealRoutes();
  const artifactPath = path.join(root, platform === "android" ? "output/release/fixture.apk" : "output/release/Fixture.app");
  const readbackPath = path.join(root, platform === "android" ? "output/readback/fixture.apk" : "output/readback/Fixture.app");
  const kind = platform === "android" ? "file" : "directory";
  if (kind === "file") { write(artifactPath, "Fictional compiled package fixture bytes."); write(readbackPath, "Fictional compiled package fixture bytes."); }
  else { write(path.join(artifactPath, "Fixture"), "Fictional executable bytes."); write(path.join(readbackPath, "Fixture"), "Fictional executable bytes."); }
  const artifactHash = artifactDigest(artifactPath, kind);
  const bundle = { id: "fixture-evidence", directory: "output/evidence/fixture", admission_status: "admitted", data_source: "controlled-production-test-account", fixture: false, artifacts: [] };
  const addEvidence = (name, contents) => {
    const relative = `output/evidence/fixture/${name}`;
    write(path.join(root, relative), Buffer.isBuffer(contents) || typeof contents === "string" ? contents : JSON.stringify(contents));
    const ref = { path: relative, sha256: hashFile(path.join(root, relative)), bundle_id: bundle.id };
    bundle.artifacts = bundle.artifacts.filter(item => item.path !== relative);
    bundle.artifacts.push({ path: relative, sha256: ref.sha256 });
    return ref;
  };
  const log = addEvidence("execution.txt", "Fictional unit-test build, device, quality and review log.\n");
  const capture = addEvidence("capture.png", image(30));
  const comparison = addEvidence("comparison.png", image(80));
  const buildProof = addEvidence("build.json", { source_sha256: source.sha256, artifact_sha256: artifactHash, version: "1.0.0", build_number: "1", profile: "release", flavor: "production", fixture: false, command: "fictional-native-build", tool_versions: { fixture: "1" }, finished_at: "2026-09-14T00:00:00Z", execution_log: log });
  const installProof = addEvidence("installation.json", { device_id: "fictional-device", package_id: "rw.example.club", source_artifact_sha256: artifactHash, readback_sha256: artifactHash, execution_log: log });
  const quality = () => Object.fromEntries(QUALITY_DIMENSIONS.map(name => [name, { status: "pass", critical_findings: [], high_findings: [], evidence: [log] }]));
  const requiredCases = generateRequiredCases({ routeInventory: routes, inventory, app, platform });
  const payload = { binding: { source_sha256: source.sha256, contract_sha256: hashFile(contractPath), reference_registry_sha256: digest(canonical(references)), case_inventory_sha256: digest(canonical({ routes: routes.routes, inventory })), version: "1.0.0", build_number: "1", artifact_sha256: artifactHash }, artifact: { path: path.relative(root, artifactPath), sha256: artifactHash, kind, package_id: "rw.example.club", build_profile: "release", flavor: "production", fixture: false, build_proof: buildProof }, installation: { artifact_sha256: artifactHash, readback: { path: path.relative(root, readbackPath), sha256: artifactHash }, device_id: "fictional-device", device_class: "physical", installed_at: "2026-09-14T01:00:00Z", proof: installProof }, cases: requiredCases.map(entry => ({ id: entry.id, case: entry, artifact_sha256: artifactHash, capture_kind: "native_screenshot", captured_at: "2026-09-14T02:00:00Z", screenshot: capture, comparison, comparator: { kind: "component_pattern", reference_ids: ["REF-1"], rationale: "Fictional component comparison in an isolated unit test." }, criteria: Object.fromEntries(VISUAL_CRITERIA.map(name => [name, { status: "pass", reviewer_id: "fixture-implementer", reviewed_at: "2026-09-14T03:00:00Z", evidence: [log] }])), quality: quality(), open_findings: [] })), quality: quality(), owner_annotations: [{ id: "OWNER-1", requirement_sha256: digest(inventory.owner_annotations[0].requirement), status: "closed", source_sha256: source.sha256, implementation_evidence: [codeRef] }], open_material_findings: [], waivers: [], skip_flags: [], baseline_regenerations: [] };
  const keys = new Map();
  const reviewers = ["implementer", "independent_visual", "owner"].map(role => {
    const id = `fixture-${role}`; const pair = generateKeyPairSync("ed25519"); keys.set(id, pair.privateKey);
    return { id, roles: [role], active: true, synthetic: false, public_key_pem: pair.publicKey.export({ type: "spki", format: "pem" }) };
  });
  const record = { id: "fixture-acceptance", app, platform, payload, reviews: [] };
  const ledger = { bundles: [bundle], mobile_reviewers: reviewers, mobile_release_acceptances: [record] };
  const ledgerPath = path.join(root, contract.release_registry);
  const save = () => writeJson(ledgerPath, ledger);
  const resign = () => {
    const payloadHash = digest(canonical(payload));
    record.reviews = ["implementer", "independent_visual", "owner"].map((role, index) => {
      const reviewer_id = `fixture-${role}`;
      const signed = { role, reviewer_id, reviewed_at: `2026-09-14T0${index + 4}:00:00Z`, payload_sha256: payloadHash };
      return { ...signed, synthetic: false, signature: sign(null, Buffer.from(canonical(signed)), keys.get(reviewer_id)).toString("base64") };
    });
    save();
  };
  resign();
  const run = () => validateMobileDesignRelease({ root, app, platform, acceptanceId: record.id, authorityRoot: authority, now: Date.parse("2026-09-14T12:00:00Z") });
  return { root, app, platform, authority, document, contractPath, references, referencesPath, inventory, caseRegistry, casesPath, routes, routesPath, routeProofPath, source, artifactPath, readbackPath, payload, record, ledger, ledgerPath, bundle, keys, addEvidence, save, resign, sealRoutes, run };
}
function blocked(f, expression) { const result = f.run(); assert.equal(result.status, "fail"); assert.equal(result.design_complete, false); assert.match(result.errors.join("\n"), expression); }

test("complete isolated Android fixture covers every required case and all distinct signed reviews", t => {
  const f = fixture(t); const result = f.run(); assert.equal(result.status, "pass", result.errors.join("\n")); assert.equal(result.reviewed_cases, MATERIAL_STATES.length);
});
test("iOS installed app directory compares every package file", t => {
  const f = fixture(t, "ios"); assert.equal(f.run().status, "pass"); write(path.join(f.readbackPath, "Fixture"), "changed"); blocked(f, /readback bytes/);
});
test("an empty registry is unverified rather than a vacuous acceptance", t => {
  const f = fixture(t); f.ledger.mobile_release_acceptances = []; f.save(); blocked(f, /No reviewed acceptance record/);
});
test("review signatures reject a changed decision payload", t => { const f = fixture(t); f.payload.waivers.push("changed"); f.save(); blocked(f, /payload hash/); });
test("fresh signatures cannot hide a missing required case", t => { const f = fixture(t); f.payload.cases.pop(); f.resign(); blocked(f, /Exact required case coverage/); });
test("new production routes and aliases cannot be omitted from governed families", t => {
  const f = fixture(t); f.routes.routes.push({ surface: "mobile", path: "/new-alias", kind: "redirect" }); writeJson(f.routesPath, f.routes); f.sealRoutes(); blocked(f, /all production routes and aliases/);
});
test("new dialog call sites cannot disappear from the surface inventory", t => {
  const f = fixture(t); write(path.join(f.root, "packages/fixture/lib/dialog.dart"), "void open() { showDialog(context: context, builder: builder); }\n"); f.sealRoutes(); blocked(f, /Overlay discovery inventory/);
});
test("stale route discovery does not prove the current source", t => { const f = fixture(t); write(path.join(f.root, `apps/${f.app}/lib/new.dart`), "const changedBuildInput = true;\n"); blocked(f, /Route discovery source revision/); });
test("unknown membership and geography coverage block inventory acceptance", t => {
  const f = fixture(t); f.inventory.coverage_audit.membership.status = "unverified"; writeJson(f.casesPath, f.caseRegistry); blocked(f, /Coverage audit is open: membership/);
});
test("a required context value must occur in the generated cases", t => {
  const f = fixture(t); f.inventory.families[0].dimension_requirements.theme.push("light"); writeJson(f.casesPath, f.caseRegistry); blocked(f, /Uncovered theme/);
});
test("changing contract criteria cannot redefine a passing score", t => { const f = fixture(t); f.document.mobile_acceptance.contract.visual_criteria = VISUAL_CRITERIA.slice(1); writeJson(f.contractPath, f.document); blocked(f, /Stable visual criteria/); });
test("every case must retain all ten visual criteria", t => { const f = fixture(t); delete f.payload.cases[0].criteria.typography; f.resign(); blocked(f, /Ten visual criteria/); });
test("not applicable requires a product reason and current source evidence", t => { const f = fixture(t); f.payload.cases[0].criteria.typography.status = "not_applicable"; f.resign(); blocked(f, /Unjustified inapplicable criterion/); });
test("a combined quality result cannot cancel a high accessibility finding", t => { const f = fixture(t); f.payload.quality.accessibility.high_findings.push("missing focus"); f.resign(); blocked(f, /high accessibility findings/); });
test("failure in case resilience is independent of platform quality", t => { const f = fixture(t); f.payload.cases[0].quality.resilience.status = "fail"; f.resign(); blocked(f, /resilience does not pass independently/); });
test("the exact installed package must be read back", t => { const f = fixture(t); write(f.readbackPath, "wrong installed bytes"); blocked(f, /readback bytes/); });
test("the build artifact cannot stand in for device readback", t => { const f = fixture(t); f.payload.installation.readback.path = path.relative(f.root, f.artifactPath); f.resign(); blocked(f, /Readback must be separate/); });
test("a simulator receipt cannot authorize physical release acceptance", t => { const f = fixture(t); f.payload.installation.device_class = "simulator"; f.resign(); blocked(f, /Physical installation evidence/); });
test("a fixture build cannot approve a production artifact", t => { const f = fixture(t); f.payload.artifact.fixture = true; f.resign(); blocked(f, /Only the production release artifact/); });
test("stale release bytes are rejected independently of signed metadata", t => { const f = fixture(t); write(f.artifactPath, "different release bytes"); blocked(f, /Release artifact bytes/); });
test("a comparison with the target image itself is rejected", t => { const f = fixture(t); f.payload.cases[0].comparison = f.payload.cases[0].screenshot; f.resign(); blocked(f, /cannot compare with itself/); });
test("a PNG header without actual image data cannot count as a screenshot", t => { const f = fixture(t); f.payload.cases[0].screenshot = f.addEvidence("truncated.png", image().subarray(0, 24)); f.resign(); blocked(f, /PNG/); });
test("widget golden captures cannot approve an installed candidate", t => { const f = fixture(t); f.payload.cases[0].capture_kind = "widget_golden"; f.resign(); blocked(f, /Fixture\/golden captures/); });
test("private source image changes invalidate the reference binding", t => { const f = fixture(t); write(path.join(f.authority, "private/reference.png"), image(90)); blocked(f, /Reference REF-1 current bytes/); });
test("a direct comparator must match the platform", t => { const f = fixture(t); f.payload.cases[0].comparator.kind = "direct"; f.resign(); blocked(f, /Direct reference REF-1 platform/); });
test("a registered reference must explicitly support the case state", t => { const f = fixture(t); f.references.reference_catalog[0].state_scope = ["default"]; writeJson(f.referencesPath, f.references); f.payload.binding.reference_registry_sha256 = digest(canonical(f.references)); f.resign(); blocked(f, /not state-appropriate/); });
test("unregistered evidence cannot close a visual criterion", t => { const f = fixture(t); f.bundle.admission_status = "pending"; f.save(); blocked(f, /not admitted/); });
test("synthetic approvals are rejected even if their cryptographic signature matches", t => { const f = fixture(t); f.record.reviews[0].synthetic = true; f.save(); blocked(f, /Synthetic reviews/); });
test("the visual reviewer cannot be the implementer", t => {
  const f = fixture(t); const review = f.record.reviews[1]; review.reviewer_id = "fixture-implementer"; f.ledger.mobile_reviewers[0].roles.push("independent_visual");
  const signed = { role: review.role, reviewer_id: review.reviewer_id, reviewed_at: review.reviewed_at, payload_sha256: review.payload_sha256 };
  review.signature = sign(null, Buffer.from(canonical(signed)), f.keys.get(review.reviewer_id)).toString("base64"); f.save(); blocked(f, /independent of the implementer/);
});
test("review metadata cannot forge a signature", t => { const f = fixture(t); f.record.reviews[2].signature = Buffer.alloc(64).toString("base64"); f.save(); blocked(f, /signature is unverifiable/); });
test("owner annotations cannot be silently reworded to close them", t => {
  const f = fixture(t); f.inventory.owner_annotations[0].requirement = "Remove the club identity."; writeJson(f.casesPath, f.caseRegistry); f.payload.binding.case_inventory_sha256 = digest(canonical({ routes: f.routes.routes, inventory: f.inventory })); f.resign(); blocked(f, /Owner requirement must remain intact/);
});
test("owner annotation discovery cannot be left unverified", t => { const f = fixture(t); f.inventory.owner_annotation_inventory_status = "unverified"; writeJson(f.casesPath, f.caseRegistry); blocked(f, /Owner annotation discovery/); });
test("regenerated baselines require independent visual review", t => { const f = fixture(t); f.payload.baseline_regenerations.push({ visual_reviewed_by: "fixture-implementer" }); f.resign(); blocked(f, /Regenerated baseline lacks independent/); });
test("open material findings and waivers cannot be overridden by approval metadata", t => { const f = fixture(t); f.payload.open_material_findings.push("payment-error"); f.resign(); blocked(f, /Open material findings/); });
test("skip flags cannot reduce release coverage", t => { const f = fixture(t); f.payload.skip_flags.push("skip-light-mode"); f.resign(); blocked(f, /Release skip flags/); });

test("ignored generated Dart code remains part of the native source fingerprint", t => {
  const f = fixture(t); const before = nativeSourceSnapshot(f.root, f.app).sha256;
  write(path.join(f.root, ".gitignore"), "*.g.dart\n");
  write(path.join(f.root, `apps/${f.app}/lib/model.g.dart`), "// Generated runtime code affects the compiled app.\n");
  assert.notEqual(nativeSourceSnapshot(f.root, f.app).sha256, before);
});

test("ignored native configuration and resources remain build inputs", t => {
  const f = fixture(t);
  write(path.join(f.root, ".gitignore"), "Generated.xcconfig\nGeneratedPluginRegistrant.*\nlocal.properties\n*.xml\n");
  let before = nativeSourceSnapshot(f.root, f.app).sha256;
  for (const relative of ["ios/Flutter/Generated.xcconfig", "ios/Runner/GeneratedPluginRegistrant.m", "android/local.properties", "android/app/src/main/res/values/generated.xml"]) {
    write(path.join(f.root, `apps/${f.app}`, relative), "fictional generated build input\n");
    const after = nativeSourceSnapshot(f.root, f.app).sha256;
    assert.notEqual(after, before, relative); before = after;
  }
});

test("package symlinks cannot leave unhashed bytes outside the artifact", t => {
  const f = fixture(t, "ios");
  const outside = path.join(f.root, "output/outside-binary"); write(outside, "external bytes");
  fs.symlinkSync(outside, path.join(f.artifactPath, "External"));
  assert.throws(() => artifactDigest(f.artifactPath, "directory"), /symlink escapes/);
});

test("internal framework links retain their target content in the artifact hash", t => {
  const f = fixture(t, "ios");
  write(path.join(f.artifactPath, "Versions/A/Binary"), "version one");
  fs.symlinkSync("A", path.join(f.artifactPath, "Versions/Current"));
  const before = artifactDigest(f.artifactPath, "directory");
  write(path.join(f.artifactPath, "Versions/A/Binary"), "version two");
  assert.notEqual(artifactDigest(f.artifactPath, "directory"), before);
});

test("delivery conversion binds source, delivered and installed package bytes", t => {
  const f = fixture(t);
  const deliveryPath = path.join(f.root, "output/delivery/fixture.apk");
  write(deliveryPath, "fictional APK transformed from reviewed bundle");
  write(f.readbackPath, fs.readFileSync(deliveryPath));
  const deliveredHash = hashFile(deliveryPath);
  const executionLog = f.addEvidence("conversion.txt", "fictional conversion and readback command output\n");
  const transformation = { input_artifact_sha256: f.payload.artifact.sha256, output_package_sha256: deliveredHash, package_id: "rw.example.club", command: "fictional-convert", tool_version: "1", execution_log: executionLog };
  f.payload.installation.delivery = { path: path.relative(f.root, deliveryPath), kind: "file", sha256: deliveredHash, proof: f.addEvidence("delivery.json", transformation) };
  f.payload.installation.readback.sha256 = deliveredHash;
  f.payload.installation.proof = f.addEvidence("delivered-install.json", { device_id: "fictional-device", package_id: "rw.example.club", source_artifact_sha256: f.payload.artifact.sha256, readback_sha256: deliveredHash, execution_log: executionLog });
  f.resign(); assert.equal(f.run().status, "pass", f.run().errors.join("\n"));
  transformation.input_artifact_sha256 = "0".repeat(64);
  f.payload.installation.delivery.proof = f.addEvidence("delivery.json", transformation);
  f.resign(); blocked(f, /Delivery input artifact/);
});

test("build provenance cannot assert a different source revision", t => {
  const f = fixture(t);
  const proof = JSON.parse(fs.readFileSync(path.join(f.root, f.payload.artifact.build_proof.path)));
  proof.source_sha256 = "0".repeat(64);
  f.payload.artifact.build_proof = f.addEvidence("build.json", proof);
  f.resign(); blocked(f, /Build source provenance/);
});

test("captures must occur after installation and before final reviews", t => {
  const f = fixture(t); f.payload.cases[0].captured_at = "2026-09-14T00:30:00Z";
  f.resign(); blocked(f, /outside the installed\/reviewed interval/);
});

test("inapplicable material states need a signed source-backed unavailability decision", t => {
  const f = fixture(t);
  f.inventory.families[0].states = MATERIAL_STATES.filter(state => state !== "focused");
  f.inventory.families[0].inapplicable_states = [{ state: "focused", product_reason: "This fictional surface declares no focusable controls.", reviewer_id: "fixture-implementer", reviewed_at: "2026-09-14T03:00:00Z", unavailability_evidence: f.inventory.coverage_audit.role.evidence }];
  writeJson(f.casesPath, f.caseRegistry);
  f.payload.binding.case_inventory_sha256 = digest(canonical({ routes: f.routes.routes, inventory: f.inventory }));
  f.payload.cases = f.payload.cases.filter(entry => entry.case.state !== "focused");
  f.resign(); assert.equal(f.run().status, "pass", f.run().errors.join("\n"));
  f.inventory.families[0].inapplicable_states[0].unavailability_evidence = [];
  writeJson(f.casesPath, f.caseRegistry);
  f.payload.binding.case_inventory_sha256 = digest(canonical({ routes: f.routes.routes, inventory: f.inventory }));
  f.resign(); blocked(f, /Unavailable state.*evidence is missing/);
});
