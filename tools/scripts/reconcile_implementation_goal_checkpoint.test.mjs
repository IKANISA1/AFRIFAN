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
  const output = path.join(
    fixtureRoot,
    "output/implementation_goal_20260724",
  );
  fs.mkdirSync(path.dirname(fixtureScript), { recursive: true });
  fs.copyFileSync(sourceScript, fixtureScript);
  const fixtureReleaseGoal = path.join(
    fixtureRoot,
    "docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.json",
  );
  fs.mkdirSync(path.dirname(fixtureReleaseGoal), { recursive: true });
  fs.copyFileSync(
    sourceReleaseGoal,
    fixtureReleaseGoal,
  );

  writeJson(
    path.join(output, "route_inventory_current/route-inventory.json"),
    {
      route_count: 176,
      state_closure: {
        state_count: 16,
        cell_count: 2816,
        evidenced_cell_count: 2137,
        open_cell_count: 0,
        closure_complete: true,
      },
    },
  );
  writeJson(
    path.join(output, "design_compliance_current/VALIDATION.json"),
    {
      status: "pass",
      route_evidence_complete: true,
      design_complete: false,
      violation_count: 0,
      warning_count: 1,
    },
  );
  fs.writeFileSync(
    path.join(output, "design_compliance_current/report.md"),
    "# fixture report\n",
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
      ...Array.from({ length: 54 }, (_, index) => ({
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
      external_or_human_gates: [
        "clean controlled candidate and pinned CI",
      ],
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
  assert.doesNotMatch(task("REL-06").notes, /No backend or production mutation/);
  assert.match(task("REL-07").notes, /Android upload=false/);
  assert.match(task("STATE-03").notes, /production Supabase project is ACTIVE_HEALTHY/);
  assert.match(task("STATE-03").notes, /remains verified incomplete/);
  assert.match(task("STATE-06").notes, /minimum cohort contract of 20/);
  assert.match(task("STATE-06").notes, /production dashboard connection/);
  assert.match(task("ADMIN-05").notes, /all 14 target migrations/);
  assert.match(task("ADMIN-05").notes, /complete authenticated production/);

  const checkpoint = validation.current_checkpoint.external_execution_preflight;
  assert.deepEqual(checkpoint.release_artifacts, preflight.release_artifacts);
  assert.deepEqual(checkpoint.supabase_production, preflight.supabase_production);
  assert.deepEqual(checkpoint.analytics_production, preflight.analytics_production);
});

test("retains artifacts from a different source commit only as prior slice evidence", (t) => {
  const { validation } = runFixture(t, {
    release_artifacts: {
      android_upload_key_aab: { source_git_head: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
      ios_app_store_ipa: { source_git_head: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
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

test("fails exact-candidate derivation closed when preflight controls disagree", async (t) => {
  const cases = [
    {
      name: "remote verification is absent",
      overrides: { candidate: { candidate_commit_verified_remote: false } },
    },
    {
      name: "exact-head run does not match the candidate",
      overrides: { exact_head_run: { head_sha: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
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
  assert.equal(r66.candidate.preflight_candidate_head, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
  assert.equal(r66.candidate.exact_candidate, false);
  assert.equal(checkpoint.github_actions_exact_head_run, null);
  assert.match(task("GOV-06").notes, new RegExp(fixtureGitHead));
  assert.match(task("GOV-06").notes, /historical evidence only/);
  assert.match(task("REL-02").notes, /prior slice evidence/);
});

test("validates and checkpoints all 12 release workstreams without false closure", (t) => {
  const { r66, validation } = runFixture(t);
  const goal = validation.release_submission_goal;

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
    goal.current_checkpoint.completion_checks.google_play_mobile_submitted_for_review,
    false,
  );
  assert.equal(r66.release_submission_goal.completion_proven, false);
});

test("CI accepts the validated route-evidence-complete state", () => {
  const workflow = fs.readFileSync(
    path.join(repoRoot, ".github/workflows/ci.yaml"),
    "utf8",
  );
  assert.match(workflow, /\.route_evidence_complete == true/);
  assert.doesNotMatch(workflow, /\.route_evidence_complete == false/);
});
