import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const scriptName = "reconcile_implementation_goal_checkpoint.mjs";
const sourceScript = path.join(repoRoot, "tools/scripts", scriptName);
const sourceReleaseGoal = path.join(
  repoRoot,
  "docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.json",
);
const releaseGoalDefinition = JSON.parse(
  fs.readFileSync(sourceReleaseGoal, "utf8"),
);

const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};

function runFixture(t, preflightOverrides = {}, options = {}) {
  const fixtureRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "africlub-reconcile-test-"),
  );
  t.after(() => fs.rmSync(fixtureRoot, { recursive: true, force: true }));

  const fixtureScript = path.join(fixtureRoot, "tools/scripts", scriptName);
  const output = path.join(fixtureRoot, "output/implementation_goal_20260724");
  fs.mkdirSync(path.dirname(fixtureScript), { recursive: true });
  fs.copyFileSync(sourceScript, fixtureScript);
  const fixtureReleaseGoal = path.join(
    fixtureRoot,
    "docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.json",
  );
  fs.mkdirSync(path.dirname(fixtureReleaseGoal), { recursive: true });
  fs.copyFileSync(sourceReleaseGoal, fixtureReleaseGoal);

  writeJson(path.join(output, "route_inventory_current/route-inventory.json"), {
    route_count: options.routeCount ?? 180,
    state_closure: {
      state_count: 16,
      cell_count: 2880,
      evidenced_cell_count: 2149,
      open_cell_count: 0,
      closure_complete: true,
      routes: [],
      ...(options.routeStateOverrides ?? {}),
    },
  });
  writeJson(
    path.join(output, "route_inventory_current/route-state-closure.json"),
    {
      route_count: options.routeCount ?? 180,
      state_count: 16,
      cell_count: 2880,
      evidenced_cell_count: 2149,
      open_cell_count: 0,
      not_applicable_cell_count: 731,
      closure_complete: true,
      routes: [],
      ...(options.routeStateOverrides ?? {}),
    },
  );
  writeJson(path.join(output, "design_compliance_current/VALIDATION.json"), {
    status: "pass",
    route_evidence_complete: true,
    design_complete: false,
    violation_count: 0,
    warning_count: 1,
    ...(options.designOverrides ?? {}),
  });
  fs.writeFileSync(
    path.join(output, "design_compliance_current/report.md"),
    "# fixture report\n",
  );
  const gameRows = [
    ...Array.from(
      { length: 36 },
      (_, index) =>
        `- [x] **GAME-FIX-${String(index + 1).padStart(2, "0")} — complete.**`,
    ),
    "- [ ] **GAME-QA-03 — open.**",
    "- [ ] **GAME-QA-05 — open.**",
    "- [ ] **GAME-QA-06 — open.**",
  ];
  fs.writeFileSync(
    path.join(
      output,
      "GAME_ARCHITECTURE_UX_REVIEW_REMAINING_TASKS_2026-07-30.md",
    ),
    `${gameRows.join("\n")}\n`,
  );
  fs.writeFileSync(
    path.join(
      output,
      "AFRICLUB_CURRENT_UI_UX_ARCHITECTURE_JOURNEY_AUDIT_2026-08-13.md",
    ),
    "# fixture current audit\n",
  );
  writeJson(
    path.join(output, "RELEASE_MODE_DRY_RUN_EVIDENCE_2026-08-13.json"),
    {
      conclusion: {
        current_source_release_mode_builds_pass: true,
        corrected_native_icons_compile_and_package: true,
        exact_candidate_proven: false,
        release_ready: false,
      },
    },
  );
  const fixtureEvidenceDirectory =
    "output/implementation_goal_20260724/fixture-evidence";
  writeJson(path.join(fixtureRoot, "docs/governance/evidence-bundles.json"), {
    schema_version: "1.0",
    manifest_name: "build-provenance.json",
    bundles: [
      {
        id: "fixture-evidence",
        directory: fixtureEvidenceDirectory,
        artifact_scope: "immediate",
        admission_status: "admitted",
      },
    ],
  });
  if (options.state03Receipt != null) {
    const evidenceRegistryPath = path.join(
      fixtureRoot,
      "docs/governance/evidence-bundles.json",
    );
    const evidenceRegistry = JSON.parse(
      fs.readFileSync(evidenceRegistryPath, "utf8"),
    );
    evidenceRegistry.bundles.push({
      id: "state03-production-concurrency-20260808",
      directory:
        "output/implementation_goal_20260724/state03_production_concurrency_20260808",
      artifact_scope: "immediate",
      admission_status: "admitted",
    });
    writeJson(evidenceRegistryPath, evidenceRegistry);
    writeJson(
      path.join(
        output,
        "state03_production_concurrency_20260808/receipt.json",
      ),
      options.state03Receipt,
    );
  }
  if (options.physicalMobileCheckpoint != null) {
    const evidenceRegistryPath = path.join(
      fixtureRoot,
      "docs/governance/evidence-bundles.json",
    );
    const evidenceRegistry = JSON.parse(
      fs.readFileSync(evidenceRegistryPath, "utf8"),
    );
    evidenceRegistry.bundles.push({
      id: "physical-mobile-uat-current-20260813",
      directory:
        "output/implementation_goal_20260724/physical_mobile_uat_current",
      artifact_scope: "immediate",
      admission_status: "admitted",
    });
    writeJson(evidenceRegistryPath, evidenceRegistry);
    writeJson(
      path.join(
        output,
        "physical_mobile_uat_current/physical-mobile-uat-checkpoint.json",
      ),
      options.physicalMobileCheckpoint,
    );
  }
  if (options.iosIsolatedQaCheckpoint != null) {
    const evidenceRegistryPath = path.join(
      fixtureRoot,
      "docs/governance/evidence-bundles.json",
    );
    const evidenceRegistry = JSON.parse(
      fs.readFileSync(evidenceRegistryPath, "utf8"),
    );
    evidenceRegistry.bundles.push({
      id: "ios-isolated-qa-build-20260813",
      directory:
        "output/implementation_goal_20260724/ios_isolated_qa_build_20260813",
      artifact_scope: "immediate",
      admission_status: "admitted",
    });
    writeJson(evidenceRegistryPath, evidenceRegistry);
    writeJson(
      path.join(
        output,
        "ios_isolated_qa_build_20260813/ios-isolated-qa-build.json",
      ),
      options.iosIsolatedQaCheckpoint,
    );
  }
  if (options.physicalAndroidPerformanceCheckpoint != null) {
    const evidenceRegistryPath = path.join(
      fixtureRoot,
      "docs/governance/evidence-bundles.json",
    );
    const evidenceRegistry = JSON.parse(
      fs.readFileSync(evidenceRegistryPath, "utf8"),
    );
    evidenceRegistry.bundles.push({
      id: "physical-android-performance-current-20260813",
      directory:
        "output/implementation_goal_20260724/physical_android_performance_current",
      artifact_scope: "immediate",
      admission_status: "admitted",
    });
    writeJson(evidenceRegistryPath, evidenceRegistry);
    writeJson(
      path.join(
        output,
        "physical_android_performance_current/physical-android-performance.json",
      ),
      options.physicalAndroidPerformanceCheckpoint,
    );
  }
  writeJson(path.join(fixtureRoot, "docs/governance/golden-baselines.json"), {
    schema_version: "1.0",
    baselines: [{ path: "fixture-golden.png", sha256: "fixture-sha256" }],
  });
  for (const locale of ["en", "fr", "rw"]) {
    writeJson(
      path.join(
        fixtureRoot,
        `packages/core/core_l10n/lib/l10n/afri_${locale}.arb`,
      ),
      {
        "@@locale": locale,
        fixtureTitle: `fixture-${locale}`,
        fixtureAction: `action-${locale}`,
      },
    );
  }
  writeJson(
    path.join(
      output,
      "localization_copy_matrix/flutter-copy-inventory.json",
    ),
    {
      summary: {
        dart_files_scanned: 3,
        candidate_literals: 2,
        pending_candidate_literals: 0,
      },
    },
  );
  writeJson(
    path.join(
      output,
      "localization_copy_matrix/dynamic-copy-inventory.json",
    ),
    {
      summary: {
        dart_files_scanned: 4,
        dynamic_copy_candidates: 3,
        reviewed_dynamic_copy_candidates: 3,
        pending_dynamic_copy_candidates: 0,
        ...(options.dynamicCopyOverrides ?? {}),
      },
    },
  );
  fs.mkdirSync(path.join(fixtureRoot, fixtureEvidenceDirectory), {
    recursive: true,
  });
  fs.writeFileSync(
    path.join(fixtureRoot, fixtureEvidenceDirectory, "fixture-artifact.txt"),
    "fixture artifact\n",
  );

  const preflight = {
    checked_at: "2026-08-08T13:18:10Z",
    candidate: {
      git_head: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      branch: "release/control-integrity",
      dirty: false,
      exact_candidate: true,
      candidate_commit_verified_remote: true,
      working_tree_dirty_boundary: "preserved unrelated local files",
      ...(preflightOverrides.candidate ?? {}),
    },
    github_actions: {
      repository: "example/africlub",
      exact_head_run: {
        id: 42,
        head_sha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        status: "completed",
        conclusion: "success",
        job_count: 7,
        log_available: true,
        ...(preflightOverrides.exact_head_run ?? {}),
      },
      pinned_runtime_execution_proven: false,
      interpretation: "Fixture CI interpretation.",
    },
    physical_devices: {
      ios: [
        { name: "Fixture One", model: "iPhone A", state: "available" },
        { name: "Fixture Two", model: "iPhone B", state: "unavailable" },
      ],
      android_attached_count: 3,
      native_tv_attached_count: 2,
      voiceover_execution_proven: true,
      talkback_execution_proven: false,
      physical_tv_remote_or_soak_proven: true,
      ...(preflightOverrides.physical_devices ?? {}),
    },
    release_artifacts: {
      android_upload_key_aab: {
        bytes: 151063922,
        sha256: "android-fixture-sha",
        source_git_head: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        jarsigner_verified: true,
        store_uploaded: false,
        ...(preflightOverrides.release_artifacts?.android_upload_key_aab ?? {}),
      },
      ios_app_store_ipa: {
        bytes: 27552960,
        sha256: "ios-fixture-sha",
        source_git_head: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        signature_verified: true,
        store_uploaded: false,
        ...(preflightOverrides.release_artifacts?.ios_app_store_ipa ?? {}),
      },
    },
    store_delivery_audit: {
      android: { uploaded: false, remote_processing_evidenced: false },
      ios: { uploaded: false, remote_processing_evidenced: false },
    },
    supabase_production: {
      status: "ACTIVE_HEALTHY",
      postgres_version: "17.6.1.063",
      exact_target_migrations: 14,
      exact_target_migration_versions: Array.from(
        { length: 14 },
        (_, index) => `fixture-${index + 1}`,
      ),
      target_migration_set_verified: true,
      generated_history_residue: 0,
      core_invariants_passed: 11,
      function_contract_rows_passed: 67,
      relation_acl_cells_passed: 504,
      privacy_rows_before_after: 152,
      analytics_enabled_before_after: 152,
      local_pgtap_tests_passed: 95,
      ...(preflightOverrides.supabase_production ?? {}),
    },
    analytics_production: {
      compile_time_gate: "ENABLE_FIREBASE_OBSERVABILITY",
      compile_time_gate_enabled_in_exact_signed_artifacts: false,
      minimum_reporting_threshold_contract: 20,
      small_cohort_suppression_contract_present: true,
      production_dashboard_connected: false,
      production_dashboard_suppression_evidenced: false,
      accountable_privacy_product_approval_evidenced: false,
    },
    emulator_and_simulator_validation: {
      android_api_36: {
        journeys_passed: 3,
        journeys_total: 3,
        fatal_exceptions: 0,
        anrs: 0,
      },
      ios_simulator: { journeys_passed: 3, journeys_total: 3 },
    },
    browser_evidence: { pending_bundle_count: 0 },
    closure_effect: { release_ready: false },
  };
  writeJson(
    path.join(output, "external-execution-preflight-20260802.json"),
    preflight,
  );
  writeJson(path.join(output, "validation-manifest.json"), {
    tasks: [
      ...releaseGoalDefinition.scope.baseline_remaining_task_ids.map((id) => ({
        id,
        current_result: "verified_incomplete",
        evidence: [],
        notes: "stale fixture note",
      })),
      ...["GOV-04", "STATE-01", "EVID-02", "ADMIN-03", "ADMIN-06"].map(
        (id) => ({
          id,
          current_result: "verified_complete",
          evidence: ["fixture"],
          notes: "fixture route-owned complete",
        }),
      ),
      {
        id: "EVID-07",
        current_result: "verified_complete",
        evidence: ["fixture"],
        notes: "fixture provenance complete",
      },
      ...Array.from({ length: 48 }, (_, index) => ({
        id: `FIX-COMPLETE-${String(index + 1).padStart(2, "0")}`,
        current_result: "verified_complete",
        evidence: ["fixture"],
        notes: "fixture complete",
      })),
    ],
    summary: {},
    current_checkpoint: {},
    football_club_first_implementation: {
      post_plan_design_compliance: {},
    },
    r66_mandatory_deliverables: {
      deliverables: [],
      all_deliverables_complete: false,
    },
  });
  writeJson(path.join(output, "R66_WORKING_CANDIDATE_MANIFEST.json"), {
    candidate: {
      branch: "stale-branch",
      head: "stale-head",
      porcelain_sha256: "stale-fingerprint",
    },
    route_inventory: {},
    closure: {
      external_or_human_gates: ["clean controlled candidate and pinned CI"],
    },
    design_compliance: {},
    implementation: {},
    deliverables: { DELIV03: {}, DELIV04: {} },
    contradictions_and_staleness: [],
  });
  writeJson(path.join(output, "engagement-manifest.json"), {
    goal_revision: { football_club_first_implementation: {} },
  });

  let fixtureGitHead = null;
  if (options.initializeGit === true) {
    execFileSync("git", ["init", "-b", "main"], {
      cwd: fixtureRoot,
      stdio: "pipe",
    });
    execFileSync("git", ["config", "user.name", "Fixture"], {
      cwd: fixtureRoot,
      stdio: "pipe",
    });
    execFileSync("git", ["config", "user.email", "fixture@example.test"], {
      cwd: fixtureRoot,
      stdio: "pipe",
    });
    execFileSync("git", ["add", "."], { cwd: fixtureRoot, stdio: "pipe" });
    execFileSync("git", ["commit", "-m", "fixture"], {
      cwd: fixtureRoot,
      stdio: "pipe",
    });
    fixtureGitHead = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: fixtureRoot,
      encoding: "utf8",
    }).trim();
  }

  execFileSync(process.execPath, [fixtureScript], {
    cwd: fixtureRoot,
    stdio: "pipe",
    env: {
      ...process.env,
      AFRICLUB_RECONCILE_SKIP_REMOTE_LOOKUPS: "1",
    },
  });
  return {
    preflight,
    fixtureGitHead,
    r66: JSON.parse(
      fs.readFileSync(
        path.join(output, "R66_WORKING_CANDIDATE_MANIFEST.json"),
        "utf8",
      ),
    ),
    validation: JSON.parse(
      fs.readFileSync(path.join(output, "validation-manifest.json"), "utf8"),
    ),
  };
}

test("derives current candidate and device metadata from the preflight", (t) => {
  const { preflight, r66, validation } = runFixture(t);
  const checkpoint = validation.current_checkpoint.external_execution_preflight;

  assert.deepEqual(r66.candidate, {
    branch: preflight.candidate.branch,
    head: preflight.candidate.git_head,
    dirty: false,
    dirty_paths: null,
    exact_candidate: true,
    exact_candidate_reported_by_preflight: true,
    candidate_commit_verified_remote: true,
    remote_verification_method: "preflight_attestation",
    remote_head: preflight.candidate.git_head,
    exact_head_run_matches_candidate: true,
    working_tree_dirty_boundary:
      preflight.candidate.working_tree_dirty_boundary,
    observed_at_utc: preflight.checked_at,
    preflight_matches_checkout: true,
    preflight_candidate_head: preflight.candidate.git_head,
    preflight_checked_at: preflight.checked_at,
  });
  assert.equal(r66.closure.exact_candidate, true);
  assert.equal("porcelain_sha256" in r66.candidate, false);
  assert.deepEqual(checkpoint.ios_devices, preflight.physical_devices.ios);
  assert.equal(checkpoint.paired_ios_device_state, null);
  assert.equal(checkpoint.attached_android_device_count, 3);
  assert.equal(checkpoint.attached_native_tv_device_count, 2);
  assert.equal(checkpoint.voiceover_execution_proven, true);
  assert.equal(checkpoint.talkback_execution_proven, false);
  assert.equal(checkpoint.physical_tv_remote_or_soak_proven, true);
  assert.deepEqual(r66.external_execution_preflight, checkpoint);
});

test("does not invent device inventory when preflight fields are absent", (t) => {
  const { validation } = runFixture(t, {
    physical_devices: {
      ios: undefined,
      android_attached_count: undefined,
      native_tv_attached_count: undefined,
    },
  });
  const checkpoint = validation.current_checkpoint.external_execution_preflight;

  assert.equal(checkpoint.ios_devices, null);
  assert.equal(checkpoint.paired_ios_device_state, null);
  assert.equal(checkpoint.attached_android_device_count, null);
  assert.equal(checkpoint.attached_native_tv_device_count, null);
});

test("derives release, production-backend and analytics task notes from the preflight", (t) => {
  const { preflight, validation } = runFixture(t);
  const task = (id) => validation.tasks.find((entry) => entry.id === id);

  assert.match(task("REL-02").notes, /upload-key signed/);
  assert.match(task("REL-02").notes, /android-fixture-sha/);
  assert.doesNotMatch(task("REL-02").notes, /ephemeral self-signed/);
  assert.match(task("REL-03").notes, /App Store distribution signed/);
  assert.match(task("REL-03").notes, /ios-fixture-sha/);
  assert.doesNotMatch(task("REL-03").notes, /exact-current unsigned/);
  assert.match(task("REL-06").notes, /all 14 target migrations/);
  assert.doesNotMatch(
    task("REL-06").notes,
    /No backend or production mutation/,
  );
  assert.match(task("REL-07").notes, /Android upload=false/);
  assert.match(
    task("STATE-03").notes,
    /production Supabase project is ACTIVE_HEALTHY/,
  );
  assert.match(task("STATE-03").notes, /remains verified incomplete/);
  assert.match(task("STATE-06").notes, /minimum cohort contract of 20/);
  assert.match(task("STATE-06").notes, /production dashboard connection/);
  assert.match(task("ADMIN-05").notes, /all 14 target migrations/);
  assert.match(task("ADMIN-05").notes, /complete authenticated production/);

  const checkpoint = validation.current_checkpoint.external_execution_preflight;
  assert.deepEqual(checkpoint.release_artifacts, preflight.release_artifacts);
  assert.deepEqual(
    checkpoint.supabase_production,
    preflight.supabase_production,
  );
  assert.deepEqual(
    checkpoint.analytics_production,
    preflight.analytics_production,
  );
});

test("retains artifacts from a different source commit only as prior slice evidence", (t) => {
  const { validation } = runFixture(t, {
    release_artifacts: {
      android_upload_key_aab: {
        source_git_head: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      },
      ios_app_store_ipa: {
        source_git_head: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      },
    },
  });
  const task = (id) => validation.tasks.find((entry) => entry.id === id);

  assert.match(task("REL-02").notes, /prior slice evidence/);
  assert.doesNotMatch(task("REL-02").notes, /exact-candidate Android AAB/);
  assert.match(task("REL-03").notes, /prior slice evidence/);
  assert.doesNotMatch(task("REL-03").notes, /exact-candidate iOS IPA/);
});

test("fails the production-backend summary closed without an exact migration set", (t) => {
  const { validation } = runFixture(t, {
    supabase_production: { target_migration_set_verified: false },
  });
  const state03 = validation.tasks.find((entry) => entry.id === "STATE-03");

  assert.match(state03.notes, /not fully recorded/);
  assert.doesNotMatch(state03.notes, /exact-version comparison verifies/);
});

test("recovers the admitted representative STATE-03 production slice from its receipt", (t) => {
  const { validation } = runFixture(t, {}, {
    state03Receipt: {
      captured_at: "2026-08-08T20:46:35Z",
      acceptance: {
        migration_present_in_production_history: true,
        real_two_client_collision: true,
        exact_stale_version_rejection: true,
        rls_and_execute_grants_for_tested_functions: true,
        actor_and_audit_rows_for_contribution_review: true,
        transaction_rollback: true,
        authenticated_refresh_and_retry: true,
        synthetic_fixture_cleanup: true,
        state03_complete: false,
      },
      remaining_proof_gaps: ["fixture representative-only boundary"],
    },
  });
  const state03 = validation.tasks.find((entry) => entry.id === "STATE-03");

  assert.match(state03.notes, /representative shop-order cancellation/);
  assert.match(state03.notes, /profile\/settings/);
  assert.equal(
    validation.current_checkpoint.external_execution_preflight
      .state03_production_validation.representative_slice_proven,
    true,
  );
  for (const taskId of [
    "STATE-03",
    "ADMIN-05",
    "EVID-07",
    "EVID-08",
    "REL-06",
  ]) {
    const task = validation.tasks.find((entry) => entry.id === taskId);
    assert.ok(task.evidence.includes("EV-257"), `${taskId} must retain EV-257`);
  }
});

test("advances REL-04 only for the admitted five-journey isolated physical Android smoke", (t) => {
  const { validation } = runFixture(t, {}, {
    physicalMobileCheckpoint: {
      android: {
        device: "physical Pixel 4a",
        device_identifier_retained: false,
        isolated_application_id: true,
        synthetic_smoke_tests_passed: 5,
        synthetic_smoke_tests_total: 5,
        warm_custom_deep_link_executed: true,
        deep_link_injection_scope:
          "validated parser and in-app stream on physical runtime; not Android OS intent resolver",
        android_os_custom_scheme_resolution_executed: true,
        os_custom_schemes_resolved: ["gikundiro", "africlub"],
        unlisted_scheme_rejected: true,
        top_resumed_activity:
          "rw.gikundiro.app.qa.codex/rw.gikundiro.app.MainActivity",
        verified_https_app_link_executed: false,
        controlled_offline_state_executed: true,
        physical_network_state_changed: false,
        destructive_confirmation_cancellation_executed: true,
        destructive_mutation_executed: false,
        fatal_exceptions_observed: 0,
        anrs_observed: 0,
        fatal_signals_observed: 0,
        production_backend_used: false,
        customer_data_used: false,
        existing_customer_app_replaced: false,
      },
    },
  });
  const rel04 = validation.tasks.find((entry) => entry.id === "REL-04");

  assert.equal(rel04.current_result, "verified_incomplete");
  assert.match(rel04.notes, /physical Pixel 4a/);
  assert.match(rel04.notes, /production Gikundiro bundle is installed/);
  assert.doesNotMatch(rel04.notes, /REL-04 remains unverified/);
  for (const taskId of [
    "MOB-09",
    "A11Y-02",
    "EVID-04",
    "EVID-06",
    "EVID-07",
    "EVID-08",
    "REL-02",
    "REL-04",
  ]) {
    const task = validation.tasks.find((entry) => entry.id === taskId);
    assert.ok(task.evidence.includes("EV-258"), `${taskId} must retain EV-258`);
  }
});

test("retains the production iOS identity while admitting an unsigned isolated QA path", (t) => {
  const { validation } = runFixture(t, {}, {
    iosIsolatedQaCheckpoint: {
      configuration: "Debug-qa",
      scheme: "qa",
      production_bundle_identifier: "rw.ikanisa.rayonSports",
      qa_bundle_identifier: "rw.ikanisa.rayonSports.qa.codex",
      qa_entitlements_empty: true,
      production_identity_preserved: true,
      unsigned_device_build: {
        bundle_identifier: "rw.ikanisa.rayonSports.qa.codex",
        code_signed: false,
        installed_on_physical_device: false,
      },
      simulator_configuration_build: { passed: true },
      contract_validation: { passed: true },
      production_app_replaced: false,
      physical_iphone_modified: false,
      signing_or_provisioning_performed: false,
      release_ready: false,
    },
  });

  for (const taskId of [
    "MOB-09",
    "A11Y-02",
    "EVID-04",
    "EVID-07",
    "EVID-08",
    "REL-03",
    "REL-04",
  ]) {
    const task = validation.tasks.find((entry) => entry.id === taskId);
    assert.ok(task.evidence.includes("EV-259"), `${taskId} must retain EV-259`);
  }
  const rel03 = validation.tasks.find((entry) => entry.id === "REL-03");
  assert.match(rel03.notes, /rw\.ikanisa\.rayonSports\.qa\.codex/);
  assert.match(rel03.notes, /without modifying the physical iPhone/);
});

test("admits physical profile measurements without treating a failed frame budget as performance closure", (t) => {
  const { validation } = runFixture(t, {}, {
    physicalAndroidPerformanceCheckpoint: {
      device: {
        model: "Pixel 4a",
        physical: true,
        device_identifier_retained: false,
      },
      application: {
        package_id: "rw.gikundiro.app.qa.codex",
        isolated_application_id: true,
        build_mode: "profile",
        production_package_present_before_or_after: false,
        existing_customer_app_replaced: false,
      },
      runtime: {
        physical_device_claimed: true,
        test_passed: true,
        fatal_exceptions_observed: 0,
        anrs_observed: 0,
        fatal_signals_observed: 0,
        production_backend_used: false,
        customer_data_used: false,
      },
      profile_scope: {
        frame_budget_ms: 16,
        shop_images_profiled: false,
        checkout_submission_profiled: false,
        memory_budget_declared: false,
        realtime_profiled: false,
      },
      aggregate: {
        frames_measured: 999,
        declared_frame_budget_passed: false,
      },
      release_ready: false,
    },
  });

  for (const taskId of [
    "MOB-09",
    "EVID-06",
    "EVID-07",
    "EVID-08",
    "ADMIN-08",
    "REL-02",
    "REL-04",
  ]) {
    const task = validation.tasks.find((entry) => entry.id === taskId);
    assert.ok(task.evidence.includes("EV-260"), `${taskId} must retain EV-260`);
  }
  const performance = validation.tasks.find((entry) => entry.id === "EVID-06");
  assert.equal(performance.current_result, "verified_incomplete");
  assert.match(performance.notes, /declared 16 ms budget is not met/);
  assert.match(performance.notes, /passing rerun/);
});

test("fails exact-candidate derivation closed when preflight controls disagree", async (t) => {
  const cases = [
    {
      name: "remote verification is absent",
      overrides: { candidate: { candidate_commit_verified_remote: false } },
    },
    {
      name: "exact-head run does not match the candidate",
      overrides: {
        exact_head_run: {
          head_sha: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        },
      },
    },
    {
      name: "dirty worktree remains inexact even with a preservation note",
      overrides: {
        candidate: {
          dirty: true,
          working_tree_dirty_boundary: "preserved unrelated local files",
        },
      },
    },
    {
      name: "preflight does not attest an exact candidate",
      overrides: { candidate: { exact_candidate: false } },
    },
  ];

  for (const fixtureCase of cases) {
    await t.test(fixtureCase.name, (subtest) => {
      const { r66 } = runFixture(subtest, fixtureCase.overrides);
      assert.equal(r66.candidate.exact_candidate, false);
      assert.equal(r66.closure.exact_candidate, false);
    });
  }
});

test("binds current controls to the live checkout and demotes a stale preflight", (t) => {
  const { fixtureGitHead, r66, validation } = runFixture(
    t,
    {},
    { initializeGit: true },
  );
  const checkpoint = validation.current_checkpoint.external_execution_preflight;
  const task = (id) => validation.tasks.find((entry) => entry.id === id);

  assert.equal(r66.candidate.head, fixtureGitHead);
  assert.equal(r66.candidate.branch, "main");
  assert.equal(r66.candidate.dirty, false);
  assert.equal(r66.candidate.preflight_matches_checkout, false);
  assert.equal(
    r66.candidate.preflight_candidate_head,
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  );
  assert.equal(r66.candidate.exact_candidate, false);
  assert.equal(checkpoint.github_actions_exact_head_run, null);
  assert.match(task("GOV-06").notes, new RegExp(fixtureGitHead));
  assert.match(task("GOV-06").notes, /historical evidence only/);
  assert.match(task("REL-02").notes, /prior slice evidence/);
});

test("validates and checkpoints all 12 release workstreams without false closure", (t) => {
  const { r66, validation } = runFixture(t);
  const goal = validation.release_submission_goal;
  const localizationTask = validation.tasks.find(
    (entry) => entry.id === "MOB-08",
  );

  assert.equal(goal.workstream_count, 12);
  assert.equal(goal.baseline_remaining_task_ids.length, 33);
  assert.equal(goal.current_checkpoint.workstreams.length, 12);
  assert.equal(goal.current_checkpoint.remaining_task_count, 33);
  assert.equal(goal.current_checkpoint.completion_proven, false);
  assert.equal(
    goal.current_checkpoint.completion_checks.all_87_tasks_verified_complete,
    false,
  );
  assert.equal(
    goal.current_checkpoint.completion_checks
      .google_play_mobile_submitted_for_review,
    false,
  );
  assert.equal(r66.release_submission_goal.completion_proven, false);
  assert.match(localizationTask.notes, /exact EN\/FR\/RW parity across 2 messages/);
  assert.match(localizationTask.notes, /scans 3 production Dart files/);
  assert.match(localizationTask.notes, /all 2 detected conservative candidates/);
  assert.match(localizationTask.notes, /leaves zero pending/);
  assert.match(localizationTask.notes, /separately scans 4 production Dart files/);
  assert.match(localizationTask.notes, /reviews all 3 detected ingestion boundaries/);
});

test("fails the checkpoint closed when dynamic copy review has pending candidates", (t) => {
  assert.throws(
    () =>
      runFixture(
        t,
        {},
        {
          dynamicCopyOverrides: {
            reviewed_dynamic_copy_candidates: 2,
            pending_dynamic_copy_candidates: 1,
          },
        },
      ),
    /Command failed/,
  );
});

test("reopens route-owned tasks when current-source routes lack evidence", (t) => {
  const { validation } = runFixture(
    t,
    {},
    {
      routeCount: 182,
      routeStateOverrides: {
        cell_count: 2912,
        evidenced_cell_count: 2149,
        open_cell_count: 22,
        not_applicable_cell_count: 741,
        closure_complete: false,
        routes: [
          {
            surface: "venue_portal",
            states: Object.fromEntries(
              Array.from({ length: 16 }, (_, index) => [
                `state-${index}`,
                { evidence_status: "open" },
              ]),
            ),
          },
          {
            surface: "web_api",
            states: Object.fromEntries(
              Array.from({ length: 6 }, (_, index) => [
                `state-${index}`,
                { evidence_status: "open" },
              ]),
            ),
          },
        ],
      },
      designOverrides: { route_evidence_complete: false },
    },
  );
  const task = (id) => validation.tasks.find((entry) => entry.id === id);

  for (const id of ["GOV-04", "STATE-01", "EVID-02", "ADMIN-03", "ADMIN-06"]) {
    assert.equal(task(id).current_result, "verified_incomplete");
    assert.match(task(id).notes, /open/);
  }
  assert.equal(validation.current_checkpoint.route_count, 182);
  assert.equal(validation.current_checkpoint.route_state_open, 22);
  assert.equal(
    validation.current_checkpoint.surface_open_cells.venue_portal,
    16,
  );
  assert.equal(validation.current_checkpoint.surface_open_cells.web_api, 6);
  assert.equal(validation.current_checkpoint.closure_complete, false);
  assert.equal(
    validation.football_club_first_implementation
      .route_evidence_regeneration_required,
    true,
  );
});

test("CI accepts the validated route-evidence-complete state", () => {
  const workflow = fs.readFileSync(
    path.join(repoRoot, ".github/workflows/ci.yaml"),
    "utf8",
  );
  assert.match(workflow, /\.route_evidence_complete == true/);
  assert.doesNotMatch(workflow, /\.route_evidence_complete == false/);
});
