#!/usr/bin/env node

import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const output = path.join(root, "output/implementation_goal_20260724");
const manifestPath = path.join(output, "validation-manifest.json");
const r66Path = path.join(output, "R66_WORKING_CANDIDATE_MANIFEST.json");
const engagementPath = path.join(output, "engagement-manifest.json");
const releaseGoalDefinitionPath = path.join(
  root,
  "docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.json",
);
const releaseGoalPath = path.join(
  output,
  "release-submission-execution-goal.json",
);
const routePath = path.join(
  output,
  "route_inventory_current/route-inventory.json",
);
const designPath = path.join(
  output,
  "design_compliance_current/VALIDATION.json",
);
const externalPreflightPath = path.join(
  output,
  "external-execution-preflight-20260802.json",
);
const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const write = (file, value) =>
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
const runRaw = (command, args) => {
  try {
    return execFileSync(command, args, {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 15_000,
    });
  } catch {
    return null;
  }
};
const run = (command, args) => runRaw(command, args)?.trim() ?? null;
const readJsonCommand = (command, args) => {
  const body = run(command, args);
  if (!body) return null;
  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
};
const fileFacts = (file) => {
  const body = fs.readFileSync(file);
  return {
    sha256: crypto.createHash("sha256").update(body).digest("hex"),
    bytes: body.length,
  };
};

const route = read(routePath);
const design = read(designPath);
const releaseGoal = structuredClone(read(releaseGoalDefinitionPath));
const externalPreflight = read(externalPreflightPath);
const candidate = externalPreflight.candidate ?? {};
const githubActions = externalPreflight.github_actions ?? {};
const preflightExactHeadRun = githubActions.exact_head_run ?? {};
const physicalDevices = externalPreflight.physical_devices ?? {};
const releaseArtifacts = externalPreflight.release_artifacts ?? {};
const androidReleaseArtifact = releaseArtifacts.android_upload_key_aab ?? {};
const iosReleaseArtifact = releaseArtifacts.ios_app_store_ipa ?? {};
const storeDeliveryAudit = externalPreflight.store_delivery_audit ?? {};
const supabaseProduction = externalPreflight.supabase_production ?? {};
const analyticsProduction = externalPreflight.analytics_production ?? {};
const emulatorAndSimulatorValidation =
  externalPreflight.emulator_and_simulator_validation ?? {};
const state03ProductionValidation =
  externalPreflight.state03_production_validation ?? {};
const liveGitHead = run("git", ["rev-parse", "HEAD"]);
const liveGitBranch = run("git", ["branch", "--show-current"]);
const liveGitPorcelain = runRaw("git", ["status", "--porcelain=v1"]);
const liveDirtyPaths = liveGitPorcelain
  ? liveGitPorcelain
      .split("\n")
      .filter(Boolean)
      .map((line) => line.slice(3).trim())
  : [];
const liveGitDirty =
  liveGitPorcelain === null ? null : liveDirtyPaths.length > 0;
const localOriginMain = run("git", [
  "rev-parse",
  "--verify",
  "refs/remotes/origin/main",
]);
const skipRemoteLookups =
  process.env.AFRICLUB_RECONCILE_SKIP_REMOTE_LOOKUPS === "1";
const remoteMainLine =
  liveGitHead && !skipRemoteLookups
    ? run("git", ["ls-remote", "--heads", "origin", "refs/heads/main"])
    : null;
const remoteMain = remoteMainLine?.split(/\s+/)[0] ?? null;
const checkoutHead = liveGitHead ?? candidate.git_head ?? null;
const checkoutBranch = liveGitBranch || candidate.branch || null;
const checkoutDirty =
  typeof liveGitDirty === "boolean"
    ? liveGitDirty
    : typeof candidate.dirty === "boolean"
      ? candidate.dirty
      : null;
const preflightMatchesCheckout =
  typeof checkoutHead === "string" &&
  checkoutHead.length > 0 &&
  candidate.git_head === checkoutHead;
const repository = githubActions.repository ?? null;
const liveRunList =
  liveGitHead && repository && !skipRemoteLookups
    ? readJsonCommand("gh", [
        "run",
        "list",
        "--repo",
        repository,
        "--commit",
        liveGitHead,
        "--limit",
        "1",
        "--json",
        "databaseId,headSha,status,conclusion,event,url,createdAt",
      ])
    : null;
const liveRunEntry = Array.isArray(liveRunList) ? liveRunList[0] : null;
const liveRunView =
  liveRunEntry?.databaseId && !skipRemoteLookups
    ? readJsonCommand("gh", [
        "run",
        "view",
        String(liveRunEntry.databaseId),
        "--repo",
        repository,
        "--json",
        "databaseId,headSha,status,conclusion,event,jobs,url,createdAt,updatedAt",
      ])
    : null;
const liveExactHeadRun = liveRunEntry
  ? {
      id: liveRunEntry.databaseId,
      url: liveRunEntry.url,
      event: liveRunEntry.event,
      head_sha: liveRunEntry.headSha,
      status: liveRunEntry.status,
      conclusion: liveRunEntry.conclusion,
      created_at: liveRunEntry.createdAt,
      updated_at: liveRunView?.updatedAt ?? null,
      job_count: Array.isArray(liveRunView?.jobs)
        ? liveRunView.jobs.length
        : null,
      log_available:
        Array.isArray(liveRunView?.jobs) && liveRunView.jobs.length > 0,
      observation_source: "live_gh_read_only",
    }
  : null;
const exactHeadRun =
  liveExactHeadRun ?? (preflightMatchesCheckout ? preflightExactHeadRun : {});
const iosDevices = Array.isArray(physicalDevices.ios)
  ? physicalDevices.ios
  : null;
const remoteHeadObserved =
  remoteMain ??
  localOriginMain ??
  (!liveGitHead && candidate.candidate_commit_verified_remote === true
    ? candidate.git_head
    : null);
const remoteVerificationMethod = remoteMain
  ? "git_ls_remote"
  : localOriginMain
    ? "local_origin_main_tracking_ref"
    : !liveGitHead && candidate.candidate_commit_verified_remote === true
      ? "preflight_attestation"
      : "unverified";
const candidateCommitVerifiedRemote =
  typeof checkoutHead === "string" &&
  checkoutHead.length > 0 &&
  remoteHeadObserved === checkoutHead &&
  (remoteMain !== null ||
    (!liveGitHead && candidate.candidate_commit_verified_remote === true));
const exactHeadMatchesCandidate =
  typeof checkoutHead === "string" &&
  checkoutHead.length > 0 &&
  checkoutHead === exactHeadRun.head_sha;
const exactCandidate =
  checkoutDirty === false &&
  candidateCommitVerifiedRemote &&
  exactHeadMatchesCandidate &&
  (liveGitHead !== null || candidate.exact_candidate === true);
const candidateMetadata = {
  branch: checkoutBranch,
  head: checkoutHead,
  dirty: checkoutDirty,
  dirty_paths: liveGitHead ? liveDirtyPaths : null,
  exact_candidate: exactCandidate,
  exact_candidate_reported_by_preflight: candidate.exact_candidate === true,
  candidate_commit_verified_remote: candidateCommitVerifiedRemote,
  remote_verification_method: remoteVerificationMethod,
  remote_head: remoteHeadObserved,
  exact_head_run_matches_candidate: exactHeadMatchesCandidate,
  working_tree_dirty_boundary: liveGitHead
    ? null
    : (candidate.working_tree_dirty_boundary ?? null),
  observed_at_utc: liveGitHead ? now : (externalPreflight.checked_at ?? null),
  preflight_matches_checkout: preflightMatchesCheckout,
  preflight_candidate_head: candidate.git_head ?? null,
  preflight_checked_at: externalPreflight.checked_at ?? null,
};
const exactHeadRunOutcome =
  exactHeadRun.conclusion ?? exactHeadRun.status ?? "unknown";
const exactHeadRunSummary = `exact-HEAD GitHub Actions run ${exactHeadRun.id ?? "unknown"} for ${exactHeadRun.head_sha ?? "unknown"} is ${exactHeadRun.status ?? "status unknown"} with outcome ${exactHeadRunOutcome}, ${exactHeadRun.job_count ?? "unknown"} jobs and ${exactHeadRun.log_available === true ? "available" : "no"} logs`;
const exactHeadCiPassed =
  exactHeadMatchesCandidate &&
  exactHeadRun.status === "completed" &&
  exactHeadRun.conclusion === "success" &&
  Number.isInteger(exactHeadRun.job_count) &&
  exactHeadRun.job_count > 0 &&
  exactHeadRun.log_available === true;
const pinnedRuntimeExecutionProven =
  preflightMatchesCheckout &&
  githubActions.pinned_runtime_execution_proven === true &&
  exactHeadCiPassed;
const preflightFreshnessSummary = preflightMatchesCheckout
  ? `The retained preflight is bound to the live checkout ${checkoutHead}.`
  : `The retained preflight is bound to ${candidate.git_head ?? "an unreported commit"}, not the live checkout ${checkoutHead ?? "whose HEAD is unavailable"}; it is historical evidence only.`;
const pinnedRuntimeSummary = pinnedRuntimeExecutionProven
  ? `${exactHeadRunSummary}; the current preflight and run prove pinned-runtime execution`
  : `${exactHeadRunSummary}; pinned-runtime execution is not proven${preflightMatchesCheckout && githubActions.interpretation ? ` (${githubActions.interpretation})` : ""}`;
const candidateSummary = `The live checkout records commit ${candidateMetadata.head ?? "unknown"} on branch ${candidateMetadata.branch ?? "unknown"}; remote verification is ${candidateMetadata.candidate_commit_verified_remote ? `confirmed by ${candidateMetadata.remote_verification_method}` : "not confirmed"}, the retained exact-head run ${candidateMetadata.exact_head_run_matches_candidate ? "matches" : "does not match"} the checkout SHA, and exact_candidate=${candidateMetadata.exact_candidate}. ${preflightFreshnessSummary}`;
const workingTreeSummary = candidateMetadata.dirty
  ? `The working tree is dirty with ${candidateMetadata.dirty_paths?.length ?? "an unreported number of"} changed paths; a release candidate cannot be sealed from this state.`
  : candidateMetadata.dirty === false
    ? "The live working tree is clean."
    : "The live working-tree state is not available.";
const describeDevice = (device) => {
  const identity = [device?.name, device?.model].filter(Boolean).join(" / ");
  return `${identity || "unnamed iOS device"}: ${device?.state ?? "state unknown"}`;
};
const iosDeviceSummary =
  iosDevices === null
    ? "not reported"
    : iosDevices.length > 0
      ? iosDevices.map(describeDevice).join(", ")
      : "none reported";
const androidAttachedCount = physicalDevices.android_attached_count ?? null;
const nativeTvAttachedCount = physicalDevices.native_tv_attached_count ?? null;
const physicalDeviceSummary = `iOS devices: ${iosDeviceSummary}; attached Android devices: ${androidAttachedCount ?? "not reported"}; attached native-TV devices: ${nativeTvAttachedCount ?? "not reported"}`;
const formatBytes = (bytes) =>
  Number.isInteger(bytes) ? bytes.toLocaleString("en-US") : "unreported";
const androidJourney = emulatorAndSimulatorValidation.android_api_36 ?? {};
const iosJourney = emulatorAndSimulatorValidation.ios_simulator ?? {};
const artifactMatchesCandidate = (artifact) =>
  typeof checkoutHead === "string" &&
  checkoutHead.length > 0 &&
  artifact.source_git_head === checkoutHead;
const androidArtifactMatchesCandidate = artifactMatchesCandidate(
  androidReleaseArtifact,
);
const iosArtifactMatchesCandidate =
  artifactMatchesCandidate(iosReleaseArtifact);
const androidReleaseSummary =
  typeof androidReleaseArtifact.sha256 === "string" &&
  androidReleaseArtifact.sha256.length > 0 &&
  androidArtifactMatchesCandidate
    ? `The exact-candidate Android AAB is upload-key signed, ${formatBytes(androidReleaseArtifact.bytes)} bytes, SHA-256 ${androidReleaseArtifact.sha256}, and jarsigner verification is ${androidReleaseArtifact.jarsigner_verified === true ? "passed" : "not proven"}. The Android API 36 emulator records ${androidJourney.journeys_passed ?? "an unreported number of"}/${androidJourney.journeys_total ?? "an unreported number of"} release-readiness journeys, ${androidJourney.fatal_exceptions ?? "an unreported number of"} fatal exceptions and ${androidJourney.anrs ?? "an unreported number of"} ANRs.`
    : typeof androidReleaseArtifact.sha256 === "string" &&
        androidReleaseArtifact.sha256.length > 0
      ? `The recorded upload-key-signed Android AAB is bound to ${androidReleaseArtifact.source_git_head ?? "an unreported source commit"}, not the live checkout ${checkoutHead ?? "whose source commit is unreported"}; it is retained only as prior slice evidence.`
      : "The current preflight does not record a verified upload-key-signed Android AAB.";
const iosReleaseSummary =
  typeof iosReleaseArtifact.sha256 === "string" &&
  iosReleaseArtifact.sha256.length > 0 &&
  iosArtifactMatchesCandidate
    ? `The exact-candidate iOS IPA is App Store distribution signed, ${formatBytes(iosReleaseArtifact.bytes)} bytes, SHA-256 ${iosReleaseArtifact.sha256}, and signature verification is ${iosReleaseArtifact.signature_verified === true ? "passed" : "not proven"}. The iOS simulator records ${iosJourney.journeys_passed ?? "an unreported number of"}/${iosJourney.journeys_total ?? "an unreported number of"} release-readiness journeys.`
    : typeof iosReleaseArtifact.sha256 === "string" &&
        iosReleaseArtifact.sha256.length > 0
      ? `The recorded App Store distribution-signed iOS IPA is bound to ${iosReleaseArtifact.source_git_head ?? "an unreported source commit"}, not the live checkout ${checkoutHead ?? "whose source commit is unreported"}; it is retained only as prior slice evidence.`
      : "The current preflight does not record a verified App Store distribution-signed iOS IPA.";
const targetBackendApplied =
  supabaseProduction.status === "ACTIVE_HEALTHY" &&
  Number.isInteger(supabaseProduction.exact_target_migrations) &&
  supabaseProduction.exact_target_migrations >= 14 &&
  Array.isArray(supabaseProduction.exact_target_migration_versions) &&
  new Set(supabaseProduction.exact_target_migration_versions).size ===
    supabaseProduction.exact_target_migrations &&
  supabaseProduction.target_migration_set_verified === true &&
  supabaseProduction.generated_history_residue === 0;
const backendProductionSummary = targetBackendApplied
  ? `The production Supabase project is ACTIVE_HEALTHY on PostgreSQL ${supabaseProduction.postgres_version ?? "version unreported"}; exact-version comparison verifies all ${supabaseProduction.exact_target_migrations} target migrations with zero generated history residue. Current catalog validation records ${supabaseProduction.core_invariants_passed ?? "an unreported number of"} core invariants, ${supabaseProduction.function_contract_rows_passed ?? "an unreported number of"} function-contract rows and ${supabaseProduction.relation_acl_cells_passed ?? "an unreported number of"} relation-ACL cells passing, while the fresh local reset and ${supabaseProduction.local_pgtap_tests_passed ?? "an unreported number of"} pgTAP tests pass.`
  : "Authorized production migration and catalog validation are not fully recorded by the current preflight.";
const state03RepresentativeSliceProven =
  state03ProductionValidation.representative_slice_proven === true &&
  state03ProductionValidation.state03_complete !== true;
const state03RemainingCheck = targetBackendApplied
  ? state03RepresentativeSliceProven
    ? "remaining authenticated production cross-surface collision, RLS, actor/audit, rollback and recovery matrix"
    : "authenticated production two-client concurrency, RLS, actor/audit, rollback and recovery proof"
  : "authorized target backend migration, RLS, RPC, collision and rollback execution";
const candidateCiRemainingCheck = exactCandidate
  ? "pinned_ci_signing_store_processing_and_deployment"
  : "exact_candidate_pinned_ci_signing_store_processing_and_deployment";
const candidateCiRemainingBoundary = exactCandidate
  ? "actual pinned CI execution"
  : "exact controlled candidate and actual pinned CI execution";
const closure = route.state_closure;
const notApplicableRouteStateCellCount =
  closure.cell_count - closure.evidenced_cell_count - closure.open_cell_count;
if (
  route.route_count !== 180 ||
  closure.cell_count !== 2880 ||
  closure.open_cell_count !== 0 ||
  closure.evidenced_cell_count !== 2149 ||
  notApplicableRouteStateCellCount !== 731 ||
  closure.closure_complete !== true ||
  design.route_evidence_complete !== true ||
  design.design_complete !== false
) {
  throw new Error(
    "Current route/design checkpoint is not the expected route-complete, approval-open state",
  );
}

const completedUpdates = {
  "GOV-04":
    "The fail-closed registrar retains the reviewed Admin PWA and Venue portal evidence and admits exact-current evidence for the new consumer support-policy surfaces, while deterministic association documents receive explicit structural N/A classifications for inapplicable visual states. The generated 180-route ledger now proves all 2,149 applicable cells, retains 731 explicit N/A decisions, has zero open cells and records closure_complete=true. Accountable design and media-rights decisions remain separately governed under GOV-01/03/05 and EVID-04/05.",
  "STATE-01":
    "All 180 product routes are mapped across 16 governed states in a 2,880-cell fail-closed ledger. Exact-current typed tests plus screenshot or response evidence prove all 2,149 applicable cells, 731 cells are explicitly not applicable, zero cells remain open and closure_complete=true.",
  "EVID-02":
    "The matrix links all 2,149 applicable route-state cells to typed test plus screenshot or response evidence, retains 731 explicit N/A decisions, and records zero open cells after controlled admission of the new public support-policy states and explicit structural N/A classification of deterministic verifier documents.",
  "ADMIN-03":
    "The canonical Next/PWA implementation has adaptive source, unit coverage and admitted exact-current desktop, tablet and compact evidence for every governed Admin route, including the corrected Settings compact-overflow behavior. Live authorization and accountable operator review remain under ADMIN-01/05/07/08/09 and REL-06/08.",
  "ADMIN-06":
    "The controlled-state contracts, shared manifests, syncing/theme/compact assertions and fail-closed registrar are implemented and admitted for every Admin PWA and Venue portal route. Authorized live role/RLS and cross-role mutation UAT remain separately governed under ADMIN-05/07/09 and REL-06.",
};

const incompleteUpdates = {
  "MOB-08":
    "The shared generated catalog now has exact EN/FR/RW parity across 3,378 messages, including the four native-TV Menu context labels added in EV-249. Route-wide static Flutter migration and fail-closed inventory remain locally complete. Dynamic and unrecognized source review, approved localized route/state visuals, and accountable French/Kinyarwanda linguistic approval remain open; draft translations and static-source closure are not treated as approved route-visible copy.",
  "MOB-09":
    "Settings recovery, destructive behavior and the corrected compact-overflow presentation have local source, test and admitted browser evidence. Physical-device and assistive-technology proof remains open.",
  "EVID-03": `One thousand three hundred seventy-nine deterministic Flutter/native-TV exact-pixel baselines remain hash-governed, and all applicable web routes now have admitted exact-current screenshot or response evidence. Local visual review, source freshness, privacy scanning and artifact retention controls pass. Current pinned-runtime execution state: ${pinnedRuntimeSummary}.`,
  "EVID-04":
    "All 180 routes retain governed screenshot or response evidence or an explicit structural N/A classification for inapplicable states. The new support-policy surfaces passed controlled visual/accessibility review, and the deterministic verifier documents retain route-response contract coverage. Accountable human design approval for the final product surfaces remains open and has not been inferred.",
  "ADMIN-09":
    "All Admin routes now retain admitted exact-current controlled evidence. Live authorization, physical-device accessibility/performance and accountable operator approval remain open and are not established by loopback synthetic evidence.",
};

const retainedTaskUpdates = {
  "GOV-06": `The controlled Flutter runtime is reconciled at 3.44.4 across local configuration and release tooling. ${candidateSummary} ${workingTreeSummary} Current CI state: ${pinnedRuntimeSummary}.`,
  "A11Y-02": `The native-TV AVD now provides exact directional focus, center, Menu overlay and focus-restoration evidence, while automated semantics tests remain green. The current device preflight reports ${physicalDeviceSummary}. Physical VoiceOver execution is ${physicalDevices.voiceover_execution_proven === true ? "proven" : "not proven"}, TalkBack execution is ${physicalDevices.talkback_execution_proven === true ? "proven" : "not proven"}, and physical TV remote or soak execution is ${physicalDevices.physical_tv_remote_or_soak_proven === true ? "proven" : "not proven"}; emulator and automated semantics evidence do not substitute for those physical-device controls.`,
  "STATE-03": `${backendProductionSummary} ${state03RepresentativeSliceProven ? "The governed production validation proves a representative shop-order cancellation and contribution-review slice with real two-client collision handling, RLS/grants, actor/audit attribution, rollback cleanup and authenticated recovery. STATE-03 remains verified incomplete because profile/settings, representative admin editing, membership review, feature aggregate copy-on-write, ticket bulk review, the full role matrix and physical application recovery are not all proven." : "STATE-03 remains verified incomplete because the current preflight does not yet prove the complete real two-client collision, authenticated RLS/grant, actor/audit, rollback-cleanup and recovery matrix through the application boundary."}`,
  "STATE-06": `The production privacy baseline contains ${supabaseProduction.privacy_rows_before_after ?? "an unreported number of"} governed preference rows and preserves ${supabaseProduction.analytics_enabled_before_after ?? "an unreported number of"} existing analytics choices. The exact signed artifacts keep ${analyticsProduction.compile_time_gate ?? "the observability compile-time gate"} ${analyticsProduction.compile_time_gate_enabled_in_exact_signed_artifacts === true ? "enabled" : "disabled"}; the closed taxonomy, explicit-consent rule and minimum cohort contract of ${analyticsProduction.minimum_reporting_threshold_contract ?? "unreported"} are ${analyticsProduction.small_cohort_suppression_contract_present === true ? "present" : "not proven"}. STATE-06 remains verified incomplete because a production dashboard connection, live dashboard suppression evidence and accountable privacy/product approval are ${analyticsProduction.production_dashboard_connected === true && analyticsProduction.production_dashboard_suppression_evidenced === true && analyticsProduction.accountable_privacy_product_approval_evidenced === true ? "recorded" : "not all recorded"}.`,
  "ADMIN-05": `${backendProductionSummary} Twenty-six destructive-action contracts retain their role, scope, selection-limit, review, recovery, concurrency and audit controls; ticket cancellation remains the only reviewed bulk workflow and is capped at 100. ADMIN-05 remains verified incomplete until the complete authenticated production platform-admin, club-admin, moderator, supporter, revoked-role, cross-club, stale-write, timeout-reload, rollback and audit-query matrix plus accountable operator approval pass.`,
  "EVID-06":
    "Exact-current Android production-main profile evidence records a 1,242 ms cold start against the 3,000 ms budget, 79.34% SurfaceFlinger jank against the 5% budget, 153,191 KiB total PSS with no approved memory threshold, and controlled settings, 120-item Shop, checkout and Perfetto workloads. EV-249 adds exact native-TV cold-launch and remote-interaction execution, but not a repeat/soak or performance profile. EVID-06 remains verified incomplete because the software-rendered mobile emulator fails frame/raster budgets and representative physical-device profiling, an approved memory budget, product-image and real checkout-submission workloads, live realtime, native-TV performance/soak and authenticated Admin-volume profiles remain open.",
  "EVID-07": `All 136 admitted local evidence bundles have exact provenance sidecars covering 1,367 artifacts, including the reviewed native-TV remote/context and generic mobile pairing-link checkpoint; 1,379 golden baselines remain separately hash-governed. ${candidateCiRemainingBoundary[0].toUpperCase()}${candidateCiRemainingBoundary.slice(1)} remains separate under GOV-06 and EVID-08.`,
  "EVID-08": `CI configuration generates and validates route, archetype and component ledgers, source compliance, all 1,379 golden digests, interaction differentiation, endpoint contracts, evidence provenance, privacy patterns and platform builds. Current CI state: ${pinnedRuntimeSummary}. The current local set has 136 admitted bundles, zero pending bundles, 2,149 admitted route cells and zero open cells, including exact-current native-TV remote/context and iOS generic-link registration evidence. External release gates remain separately governed.`,
  "TV-04":
    "Automated native-TV focus and remote contracts pass. EV-249 now proves exact-current Android TV AVD cold launch, D-pad up/down reachability, center renewal, dedicated Menu context behavior, localized retry/close actions and focus restoration from Android UI hierarchies and screenshots. Product-scope-dependent rows/details/overlays and physical TV/remote, overscan and screen-reader proof remain open, so TV-04 remains verified incomplete.",
  "TV-05":
    "Pairing, credential, retry, conflict, timeout, recovery, proxy and scoped-revocation contracts remain exact-tested. EV-249 fixes the TV-generated `africlub://` versus mobile manifest mismatch by explicitly registering and parser-allowlisting both `africlub://` and `gikundiro://` while rejecting unlisted schemes; the rebuilt iOS simulator now recognizes the generic TV URL. Authenticated production pairing/synchronization, multi-client idempotency/audit, physical QR handoff and real-remote proof remain open, so TV-05 remains verified incomplete.",
  "TV-09": `${androidReleaseSummary} The signed mobile package rw.gikundiro.app does not establish the separately required production-signed native-TV package rw.ikanisa.rayonSports.tv, its credential fingerprint or store processing. The current preflight reports ${physicalDeviceSummary}. Native-TV representative-hardware soak, crash/ANR dashboard evidence, device inventory/revocation drill and operations-owner sign-off remain separately required.`,
  "REL-01": `Release configuration, runtime pins, validation contracts, provenance controls and current local platform-build evidence exist. ${candidateSummary} ${workingTreeSummary} Current CI state: ${pinnedRuntimeSummary}. REL-01 remains verified incomplete while its other release gates remain open.`,
  "REL-02": `${androidReleaseSummary} REL-02 remains verified incomplete because complete physical-Android runtime, TalkBack, permissions, deep links, offline/retry, destructive-flow, representative performance and live-backend proof remain open. Store acceptance is tracked separately under REL-07.`,
  "REL-03": `${iosReleaseSummary} Its app-level PrivacyInfo.xcprivacy remains bundled with the SDK manifests. REL-03 remains verified incomplete because complete exact-candidate physical-iPhone runtime, VoiceOver, text sizing, permissions, deep links, offline/retry, destructive-flow, representative performance and live-backend proof remain open. App Store acceptance is tracked separately under REL-07.`,
  "REL-04": `The rebuilt iOS simulator recognizes the generic native-TV pairing URL and the platform/parser contracts pass, but this proves simulator registration only. The current preflight reports ${physicalDeviceSummary}. Physical VoiceOver execution is ${physicalDevices.voiceover_execution_proven === true ? "proven" : "not proven"} and TalkBack execution is ${physicalDevices.talkback_execution_proven === true ? "proven" : "not proven"}. Complete physical mobile UAT, authenticated QR handoff and assistive-technology evidence remain separately governed. REL-04 remains unverified.`,
  "REL-05": `EV-249 proves exact-current Android TV AVD directional focus, center, Menu context overlay and challenge renewal against an isolated local backend. The current preflight reports ${nativeTvAttachedCount ?? "an unreported number of"} attached native-TV devices and marks physical TV remote or soak execution as ${physicalDevices.physical_tv_remote_or_soak_proven === true ? "proven" : "not proven"}. Emulator execution does not by itself establish real display, overscan, remote, screen-reader, reconnect, network, authenticated pairing, performance or soak behavior. REL-05 remains unverified.`,
  "REL-06": `${backendProductionSummary} Privacy-filtered Crashlytics diagnostics, compile-time observability gating and local backend/API/hook contracts remain valid. REL-06 remains incomplete because the complete authenticated production role, RLS/grant, collision, actor/audit, rollback and recovery matrix; hook-secret/dashboard configuration; live Meta delivery and identity callback; monitoring dashboards and alerts; incident rehearsal; pinned CI; custom-domain cutover; and accountable backend/security approval remain open.`,
  "REL-07": `${androidReleaseSummary} ${iosReleaseSummary} The store-delivery audit records Android upload=${storeDeliveryAudit.android?.uploaded === true ? "true" : "false"} and iOS upload=${storeDeliveryAudit.ios?.uploaded === true ? "true" : "false"}; authenticated publisher paths and remote processing are not proven. Production signing and store processing for the separate native-TV package rw.ikanisa.rayonSports.tv are also not recorded. REL-07 remains verified incomplete until the governed Android, iOS and native-TV candidates are signed where applicable and accepted and processed by their stores. Named accountable approvals remain separately governed under REL-08.`,
  "REL-08":
    "The controlled records name the required product, design, accessibility, privacy, security, operations, QA and release owners and preserve every approval boundary. No accountable named approval has been supplied or inferred. REL-08 remains unverified.",
};

const validation = read(manifestPath);
const releaseGoalTaskIds = releaseGoal.scope?.baseline_remaining_task_ids ?? [];
const releaseGoalWorkstreams = releaseGoal.workstreams ?? [];
const expectedReleaseWorkstreamIds = Array.from(
  { length: 12 },
  (_, index) => `RSG-${String(index + 1).padStart(2, "0")}`,
);
const releaseWorkstreamIds = releaseGoalWorkstreams.map((item) => item.id);
const releaseWorkstreamTaskIds = [
  ...new Set(
    releaseGoalWorkstreams.flatMap((item) => item.mapped_task_ids ?? []),
  ),
];
const allTaskIds = new Set(validation.tasks.map((task) => task.id));
const failGoalContract = (message) => {
  throw new Error(`Release-submission goal contract invalid: ${message}`);
};
if (releaseGoal.scope?.governed_task_total !== validation.tasks.length) {
  failGoalContract("governed task total does not match validation manifest");
}
if (
  releaseGoal.scope?.baseline_remaining_count !== releaseGoalTaskIds.length ||
  new Set(releaseGoalTaskIds).size !== releaseGoalTaskIds.length
) {
  failGoalContract("baseline remaining count or uniqueness is invalid");
}
if (releaseWorkstreamIds.join("|") !== expectedReleaseWorkstreamIds.join("|")) {
  failGoalContract("expected ordered workstreams RSG-01 through RSG-12");
}
if (releaseGoalTaskIds.some((id) => !allTaskIds.has(id))) {
  failGoalContract("baseline references an unknown governed task");
}
if (
  releaseWorkstreamTaskIds.some((id) => !releaseGoalTaskIds.includes(id)) ||
  releaseGoalTaskIds.some((id) => !releaseWorkstreamTaskIds.includes(id))
) {
  failGoalContract(
    "workstream mappings do not cover exactly the 33-task baseline",
  );
}
for (const workstream of releaseGoalWorkstreams) {
  if (
    !workstream.name ||
    !Array.isArray(workstream.mapped_task_ids) ||
    workstream.mapped_task_ids.length === 0 ||
    !Array.isArray(workstream.completion_evidence) ||
    workstream.completion_evidence.length === 0
  ) {
    failGoalContract(
      `${workstream.id ?? "unknown"} is missing execution or evidence fields`,
    );
  }
}
for (const task of validation.tasks) {
  if (completedUpdates[task.id]) {
    task.current_result = "verified_complete";
    task.notes = completedUpdates[task.id];
    task.evidence = [...new Set([...(task.evidence ?? []), "EV-248"])];
  } else if (incompleteUpdates[task.id]) {
    task.current_result = "verified_incomplete";
    task.notes = incompleteUpdates[task.id];
    task.evidence = [...new Set([...(task.evidence ?? []), "EV-248"])];
  } else if (retainedTaskUpdates[task.id]) {
    task.notes = retainedTaskUpdates[task.id];
    if (task.id === "REL-02") {
      task.current_result = "verified_incomplete";
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-246",
          "output/implementation_goal_20260724/release_platform_checkpoint_20260802/release-platform-checkpoint.json",
          "tools/scripts/dry_run_android_release.sh",
          "apps/rayon_sports/integration_test/release_readiness_smoke_test.dart",
        ]),
      ];
    }
    if (task.id === "REL-03") {
      task.current_result = "verified_incomplete";
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-245",
          "EV-246",
          "output/implementation_goal_20260724/release_platform_checkpoint_20260802/release-platform-checkpoint.json",
          "apps/rayon_sports/ios/Runner/PrivacyInfo.xcprivacy",
          "apps/rayon_sports/store_metadata/app_store/privacy_nutrition.md",
          "apps/rayon_sports/store_metadata/play_store/data_safety.md",
          "apps/rayon_sports/store_metadata/release_policy_assessment.md",
          "tools/scripts/validate_store_privacy_contract.sh",
        ]),
      ];
    }
    if (task.id === "REL-06") {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-245",
          "packages/core/core_network/lib/src/crashlytics_service.dart",
          "packages/core/core_network/test/crashlytics_service_test.dart",
          "tools/scripts/validate_store_privacy_contract.sh",
        ]),
      ];
    }
    if (task.id === "EVID-07") {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-243",
          "EV-246",
          "EV-247",
          "EV-249",
        ]),
      ];
    }
    if (
      [
        "MOB-08",
        "A11Y-02",
        "EVID-04",
        "EVID-05",
        "EVID-06",
        "EVID-07",
        "EVID-08",
        "TV-04",
        "TV-05",
        "REL-04",
        "REL-05",
      ].includes(task.id)
    ) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-249",
          "output/implementation_goal_20260724/native_tv_remote_context_checkpoint_20260802/native-tv-remote-context-checkpoint.json",
          "output/implementation_goal_20260724/native_tv_remote_context_checkpoint_20260802/native-tv-remote-context-checkpoint.md",
        ]),
      ];
    }
    if (
      ["GOV-06", "EVID-06", "ADMIN-08", "REL-02", "REL-04"].includes(task.id)
    ) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-247",
          "output/implementation_goal_20260724/android_profile_performance_checkpoint_20260802/android-profile-performance-checkpoint.md",
          "output/implementation_goal_20260724/android_profile_performance_checkpoint_20260802/android-profile-performance.json",
          "output/implementation_goal_20260724/android_profile_performance_checkpoint_20260802/flutter-profile-performance.json",
        ]),
      ];
    }
    if (
      [
        "GOV-06",
        "STATE-03",
        "STATE-06",
        "A11Y-02",
        "EVID-08",
        "TV-09",
        "ADMIN-05",
        "REL-01",
        "REL-02",
        "REL-03",
        "REL-04",
        "REL-05",
        "REL-06",
        "REL-07",
        "REL-08",
      ].includes(task.id)
    ) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "output/implementation_goal_20260724/external-execution-preflight-20260802.json",
        ]),
      ];
    }
    if (
      [
        "GOV-06",
        "EVID-08",
        "REL-01",
        "REL-02",
        "REL-03",
        "REL-04",
        "REL-07",
      ].includes(task.id)
    ) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-246",
          "output/implementation_goal_20260724/release_platform_checkpoint_20260802/release-platform-checkpoint.json",
        ]),
      ];
    }
    if (["GOV-06", "EVID-03", "EVID-08", "REL-01"].includes(task.id)) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-250",
          "output/implementation_goal_20260724/external-execution-preflight-20260802.json",
        ]),
      ];
    }
    if (["REL-07", "REL-08"].includes(task.id)) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-245",
          "apps/rayon_sports/store_metadata/release_policy_assessment.md",
          "tools/scripts/validate_store_privacy_contract.sh",
        ]),
      ];
    }
  }
}

for (const task of validation.tasks) {
  if (
    !["GOV-06", "EVID-06", "ADMIN-08", "REL-02", "REL-04"].includes(task.id)
  ) {
    continue;
  }
  task.evidence = [
    ...new Set([
      ...(task.evidence ?? []),
      "EV-247",
      "output/implementation_goal_20260724/android_profile_performance_checkpoint_20260802/android-profile-performance-checkpoint.md",
      "output/implementation_goal_20260724/android_profile_performance_checkpoint_20260802/android-profile-performance.json",
      "output/implementation_goal_20260724/android_profile_performance_checkpoint_20260802/flutter-profile-performance.json",
    ]),
  ];
}

const resultCounts = Object.fromEntries(
  ["verified_complete", "verified_incomplete", "unverified"].map((result) => [
    result,
    validation.tasks.filter((task) => task.current_result === result).length,
  ]),
);
const remainingIds = validation.tasks
  .filter((task) => task.current_result !== "verified_complete")
  .map((task) => task.id);
const taskResultById = Object.fromEntries(
  validation.tasks.map((task) => [task.id, task.current_result]),
);
const statusProvesSubmission = (value) => {
  if (typeof value !== "string") return false;
  return new Set([
    "submitted",
    "submitted_for_review",
    "under_review",
    "changes_in_review",
    "waiting_for_review",
    "in_review",
    "approved",
    "ready_for_sale",
    "published",
    "production",
  ]).has(value.trim().toLowerCase().replaceAll(" ", "_"));
};
const androidTvReleaseArtifact =
  releaseArtifacts.android_tv_aab ?? releaseArtifacts.native_tv_aab ?? {};
const androidStore = storeDeliveryAudit.android ?? {};
const iosStore = storeDeliveryAudit.ios ?? {};
const androidTvStore =
  storeDeliveryAudit.android_tv ?? storeDeliveryAudit.native_tv ?? {};
const cloudflareDelivery =
  externalPreflight.cloudflare ??
  externalPreflight.cloudflare_delivery_audit ??
  {};
const accountableApprovals = externalPreflight.accountable_approvals ?? {};
const exactAndroidArtifact =
  androidArtifactMatchesCandidate &&
  androidReleaseArtifact.jarsigner_verified === true;
const exactIosArtifact =
  iosArtifactMatchesCandidate && iosReleaseArtifact.signature_verified === true;
const exactAndroidTvArtifact =
  artifactMatchesCandidate(androidTvReleaseArtifact) &&
  androidTvReleaseArtifact.jarsigner_verified === true;
const cloudflareExpectedHosts = releaseGoal.scope?.cloudflare_hosts ?? [];
const cloudflareProvenHosts = Array.isArray(
  cloudflareDelivery.exact_candidate_worker_custom_domains,
)
  ? cloudflareDelivery.exact_candidate_worker_custom_domains
  : [];
const cloudflareFourHostCutoverProven =
  cloudflareDelivery.exact_candidate_deployed === true &&
  cloudflareDelivery.public_contracts_passed === true &&
  cloudflareDelivery.rollback_validated === true &&
  cloudflareExpectedHosts.every((host) => cloudflareProvenHosts.includes(host));
const productionBackendAndOperationsProven =
  targetBackendApplied &&
  state03ProductionValidation.state03_complete === true &&
  analyticsProduction.production_dashboard_connected === true &&
  analyticsProduction.production_dashboard_suppression_evidenced === true &&
  analyticsProduction.accountable_privacy_product_approval_evidenced === true &&
  externalPreflight.production_operations?.monitoring_and_rollback_proven ===
    true;
const physicalUatProven =
  physicalDevices.android_store_distributed_uat_proven === true &&
  physicalDevices.ios_testflight_uat_proven === true &&
  physicalDevices.native_tv_store_distributed_uat_proven === true &&
  physicalDevices.admin_authenticated_uat_proven === true &&
  physicalDevices.two_phone_plus_tv_session_proven === true &&
  physicalDevices.voiceover_execution_proven === true &&
  physicalDevices.talkback_execution_proven === true &&
  physicalDevices.physical_tv_remote_or_soak_proven === true;
const googlePlayMobileSubmitted =
  androidStore.production_submitted_for_review === true ||
  statusProvesSubmission(
    androidStore.production_review_status ?? androidStore.review_status,
  );
const appleAppStoreSubmitted =
  iosStore.submitted_for_review === true ||
  statusProvesSubmission(
    iosStore.app_store_review_status ?? iosStore.review_status,
  );
const googlePlayTvSubmitted =
  releaseGoal.scope?.android_tv_in_scope !== true ||
  androidTvStore.submitted_to_approved_track === true ||
  statusProvesSubmission(
    androidTvStore.review_status ?? androidTvStore.track_status,
  );
const allNamedApprovalsRecorded =
  accountableApprovals.all_required_approved === true;
const releaseCompletionChecks = {
  all_87_tasks_verified_complete:
    validation.tasks.length === 87 && resultCounts.verified_complete === 87,
  remaining_task_count_is_zero: remainingIds.length === 0,
  exact_candidate_clean_remote_aligned: exactCandidate,
  exact_head_ci_success_with_jobs_and_logs: exactHeadCiPassed,
  all_signed_artifacts_bound_to_exact_candidate:
    exactAndroidArtifact && exactIosArtifact && exactAndroidTvArtifact,
  production_backend_and_operations_proven:
    productionBackendAndOperationsProven,
  physical_android_ios_tv_and_admin_uat_proven: physicalUatProven,
  cloudflare_four_host_exact_candidate_cutover_proven:
    cloudflareFourHostCutoverProven,
  google_play_mobile_submitted_for_review: googlePlayMobileSubmitted,
  apple_app_store_submitted_for_review: appleAppStoreSubmitted,
  google_play_tv_submitted_or_approved_track_receipt: googlePlayTvSubmitted,
  all_named_approvals_recorded: allNamedApprovalsRecorded,
};
const goalPredicateKeys = Object.keys(releaseGoal.completion_predicate ?? {});
if (
  goalPredicateKeys.join("|") !== Object.keys(releaseCompletionChecks).join("|")
) {
  failGoalContract("completion predicate keys do not match reconciler checks");
}
const releaseGoalCompletionProven = Object.values(
  releaseCompletionChecks,
).every((value) => value === true);
const releaseWorkstreamCheckpoint = releaseGoalWorkstreams.map((workstream) => {
  const openTaskIds = workstream.mapped_task_ids.filter(
    (id) => taskResultById[id] !== "verified_complete",
  );
  return {
    id: workstream.id,
    status:
      openTaskIds.length > 0
        ? "active_open_tasks"
        : releaseGoalCompletionProven
          ? "complete"
          : "mapped_tasks_complete_goal_predicate_open",
    open_task_ids: openTaskIds,
    mapped_task_results: Object.fromEntries(
      workstream.mapped_task_ids.map((id) => [id, taskResultById[id]]),
    ),
  };
});
releaseGoal.status = releaseGoalCompletionProven ? "complete" : "active";
releaseGoal.current_checkpoint = {
  generated_at: now,
  status: releaseGoalCompletionProven
    ? "complete"
    : "active_fail_closed_not_submission_ready",
  completion_proven: releaseGoalCompletionProven,
  candidate: candidateMetadata,
  current_head_ci: exactHeadRun,
  current_head_ci_passed: exactHeadCiPassed,
  governed_task_counts: resultCounts,
  remaining_task_count: remainingIds.length,
  remaining_task_ids: remainingIds,
  completion_checks: releaseCompletionChecks,
  workstreams: releaseWorkstreamCheckpoint,
};
write(releaseGoalPath, releaseGoal);

validation.generated_at = now;
validation.summary.current_evidence_result_counts = resultCounts;
validation.current_checkpoint = {
  ...validation.current_checkpoint,
  route_count: route.route_count,
  route_state_cell_count: closure.cell_count,
  route_state_evidenced: closure.evidenced_cell_count,
  route_state_open: closure.open_cell_count,
  route_state_not_applicable:
    closure.cell_count - closure.evidenced_cell_count - closure.open_cell_count,
  surface_open_cells: {
    admin_pwa: 0,
    consumer_web: 0,
    mobile: 0,
    mobile_internal_admin: 0,
    native_tv: 0,
    venue_portal: 0,
    web_api: 0,
  },
  latest_evidence: "EV-250",
  latest_decision: "DEC-243",
  latest_issue: "ISS-233",
  affected_remaining_task_ids: remainingIds,
  release_submission_goal: {
    definition_path: releaseGoalDefinitionPath,
    definition_sha256: fileFacts(releaseGoalDefinitionPath).sha256,
    checkpoint_path: releaseGoalPath,
    ...fileFacts(releaseGoalPath),
    goal_id: releaseGoal.goal_id,
    revision: releaseGoal.revision,
    status: releaseGoal.current_checkpoint.status,
    completion_proven: releaseGoal.current_checkpoint.completion_proven,
    workstream_count: releaseGoalWorkstreams.length,
    baseline_remaining_count: releaseGoal.scope.baseline_remaining_count,
    current_remaining_count: remainingIds.length,
  },
  latest_local_route_closure:
    "all 180 routes remain governed; all 2,149 applicable cells are admitted, 731 are explicitly N/A, zero cells are open and closure_complete=true",
  active_implementation_route:
    "r67_store_cloudflare_submission_execution_across_remaining_r66_tasks",
  active_implementation_stage: "release_submission_program_active_fail_closed",
  active_release_workstream_ids: releaseWorkstreamIds,
  active_implementation_remaining_checks: [
    "dynamic_and_unrecognized_copy_review",
    "named_french_and_kinyarwanda_linguistic_approval",
    "approved_onboarding_and_live_club_content_rights_and_provenance",
    "source_secret_rotation_decision_by_authorized_owner",
    state03RemainingCheck,
    "physical_mobile_and_native_tv_device_assistive_technology_and_soak_execution",
    "authorized_two_phone_plus_physical_native_tv_synchronized_session",
    candidateCiRemainingCheck,
    "named_product_design_privacy_security_operations_qa_and_release_approval",
  ],
  active_code_owned_queue: {
    mobile_internal_admin_routes: 0,
    admin_pwa_routes: 0,
    venue_portal_routes: 0,
    route_wide_copy_workstreams: 0,
  },
  evidence_admission_queue: {
    admin_pwa_routes: 0,
    venue_portal_routes: 0,
    new_club_routes: 0,
    owner_organizer_routes: 0,
    admin_and_venue_open_cells: 0,
    club_open_cells: 0,
    owner_organizer_open_cells: 0,
    global_open_cells: 0,
    permission_gate:
      "No local route-evidence admission remains queued. The current 180-route ledger passed exact-current execution, controlled visual or response review, provenance preflight and explicit fail-closed admission.",
  },
  external_execution_preflight: {
    path: externalPreflightPath,
    ...fileFacts(externalPreflightPath),
    checked_at: externalPreflight.checked_at ?? null,
    preflight_matches_checkout: preflightMatchesCheckout,
    raw_preflight_candidate: candidate,
    candidate: candidateMetadata,
    github_actions_repository: githubActions.repository ?? null,
    github_actions_exact_head_run: exactHeadRun.id ?? null,
    github_actions_exact_head_sha: exactHeadRun.head_sha ?? null,
    github_actions_status: exactHeadRun.status ?? null,
    github_actions_conclusion: exactHeadRun.conclusion ?? null,
    github_actions_job_count: exactHeadRun.job_count ?? null,
    github_actions_log_available: exactHeadRun.log_available === true,
    github_actions_observation_source:
      exactHeadRun.observation_source ?? "retained_preflight",
    exact_head_ci_passed: exactHeadCiPassed,
    pinned_runtime_execution_proven: pinnedRuntimeExecutionProven,
    github_actions_interpretation: githubActions.interpretation ?? null,
    ios_devices: iosDevices,
    paired_ios_device_state:
      iosDevices?.length === 1 ? (iosDevices[0]?.state ?? null) : null,
    attached_android_device_count: androidAttachedCount,
    attached_native_tv_device_count: nativeTvAttachedCount,
    voiceover_execution_proven:
      physicalDevices.voiceover_execution_proven === true,
    talkback_execution_proven:
      physicalDevices.talkback_execution_proven === true,
    physical_tv_remote_or_soak_proven:
      physicalDevices.physical_tv_remote_or_soak_proven === true,
    browser_evidence: externalPreflight.browser_evidence ?? null,
    release_artifacts: releaseArtifacts,
    store_delivery_audit: storeDeliveryAudit,
    supabase_production: supabaseProduction,
    analytics_production: analyticsProduction,
    emulator_and_simulator_validation: emulatorAndSimulatorValidation,
    state03_production_validation: state03ProductionValidation,
    cloudflare_delivery_audit: cloudflareDelivery,
    accountable_approvals: accountableApprovals,
    closure_effect: externalPreflight.closure_effect ?? null,
  },
  closure_complete: closure.closure_complete,
  design_complete: design.design_complete,
};
validation.football_club_first_implementation = {
  ...validation.football_club_first_implementation,
  status:
    "all_180_routes_locally_evidence_complete_external_and_accountable_gates_open",
  post_plan_design_compliance: {
    ...validation.football_club_first_implementation
      .post_plan_design_compliance,
    status: design.status,
    design_complete: design.design_complete,
    route_evidence_complete: design.route_evidence_complete,
    violation_count: design.violation_count,
    warning_count: design.warning_count,
    open_route_state_cells: closure.open_cell_count,
  },
  route_evidence_regeneration_required: false,
};
validation.release_submission_goal = {
  goal_id: releaseGoal.goal_id,
  revision: releaseGoal.revision,
  definition_path: releaseGoalDefinitionPath,
  definition_sha256: fileFacts(releaseGoalDefinitionPath).sha256,
  checkpoint_path: releaseGoalPath,
  checkpoint_sha256: fileFacts(releaseGoalPath).sha256,
  workstream_count: releaseGoalWorkstreams.length,
  baseline_remaining_task_ids: releaseGoalTaskIds,
  current_checkpoint: releaseGoal.current_checkpoint,
};
const r66Deliverables = validation.r66_mandatory_deliverables.deliverables;
for (const deliverable of r66Deliverables) {
  if (deliverable.id === "DELIV-01") {
    deliverable.status = "current_local_audit_complete_accountable_review_open";
    deliverable.current_evidence =
      "current-source football-club-first UI/UX, architecture and journey audit is reconciled across 180 routes; all 2,149 applicable cells are admitted, zero remain pending, and 731 are explicit N/A";
  } else if (deliverable.id === "DELIV-02") {
    deliverable.status = "current_local_manifest_complete_unsealed_candidate";
    deliverable.current_evidence = `machine-readable 87-task accounting records ${resultCounts.verified_complete} complete, ${resultCounts.verified_incomplete} incomplete and ${resultCounts.unverified} unverified; every remaining item names an external, human, device, live, CI, signing, store, deployment or release boundary`;
  } else if (deliverable.id === "DELIV-03") {
    deliverable.status =
      "fresh_structural_inventory_and_route_state_closure_complete";
    deliverable.current_evidence =
      "current inventory has 180 routes, zero duplicates, 2,880 cells, 2,149 admitted applicable cells, zero open cells and 731 explicit N/A decisions; closure_complete=true";
  } else if (deliverable.id === "DELIV-04") {
    deliverable.status =
      "automated_pass_route_evidence_complete_overall_approval_open";
    deliverable.current_evidence =
      "current source gate records zero violations, one governed approval warning, route_evidence_complete=true and design_complete=false";
  }
}
validation.r66_mandatory_deliverables.all_deliverables_complete = false;
write(manifestPath, validation);

const r66 = read(r66Path);
r66.generated_at_utc = now;
r66.candidate = candidateMetadata;
r66.external_execution_preflight =
  validation.current_checkpoint.external_execution_preflight;
r66.route_inventory = {
  ...r66.route_inventory,
  generated_at_utc: route.generated_at,
  state_closure: {
    state_count: closure.state_count,
    cell_count: closure.cell_count,
    applicable_cell_count:
      closure.evidenced_cell_count + closure.open_cell_count,
    not_applicable_cell_count:
      closure.cell_count -
      closure.evidenced_cell_count -
      closure.open_cell_count,
    evidenced_cell_count: closure.evidenced_cell_count,
    open_cell_count: closure.open_cell_count,
    closure_complete: closure.closure_complete,
  },
};
r66.task_accounting = {
  total: validation.tasks.length,
  ...resultCounts,
  remaining: remainingIds.length,
  denominator_changed_by_game_or_deliverable_criteria: false,
  remaining_task_ids: remainingIds,
};
r66.release_submission_goal = {
  goal_id: releaseGoal.goal_id,
  revision: releaseGoal.revision,
  definition_path: releaseGoalDefinitionPath,
  definition_sha256: fileFacts(releaseGoalDefinitionPath).sha256,
  checkpoint_path: releaseGoalPath,
  checkpoint_sha256: fileFacts(releaseGoalPath).sha256,
  status: releaseGoal.current_checkpoint.status,
  completion_proven: releaseGoal.current_checkpoint.completion_proven,
  workstreams: releaseGoal.current_checkpoint.workstreams,
  completion_checks: releaseCompletionChecks,
};
r66.closure = {
  ...r66.closure,
  sealed: false,
  exact_candidate: exactCandidate,
  all_87_tasks_complete: remainingIds.length === 0,
  all_39_game_criteria_complete: false,
  all_4_deliverables_complete: false,
  route_evidence_complete: design.route_evidence_complete,
  design_complete: design.design_complete,
  game_flow_complete: false,
  release_ready: false,
  closure_complete: false,
};
r66.closure.external_or_human_gates = [
  "product, payment, contest, UGC, age, territory, rights and language decisions",
  candidateCiRemainingBoundary,
  "exact-candidate Android mobile, iOS and Android TV signing and provenance",
  "authenticated production backend, analytics, monitoring and rollback proof",
  "store-distributed physical Android, iOS, native-TV, cross-surface and Admin UAT",
  "four-host exact-candidate Cloudflare Worker custom-domain cutover",
  "Google Play mobile, App Store and Google Play TV submission receipts",
  "named accountable product, design, privacy, security, accessibility, legal, operations, QA, rights, language and release approvals",
];
delete r66.closure.all_38_tasks_complete;
r66.design_compliance = {
  ...r66.design_compliance,
  scope: "automated_source_plus_fail_closed_180_route_cross_surface_checkpoint",
  automated_status:
    "pass_with_route_evidence_complete_and_accountable_human_review_open",
  violation_count: design.violation_count,
  warning_count: design.warning_count,
  design_complete: design.design_complete,
  route_evidence_complete: design.route_evidence_complete,
  current_visual_review:
    "all 2,149 applicable route-state cells are admitted and 731 are explicit N/A; zero cells remain open after controlled review of the current 180-route ledger",
};
r66.implementation.active_phase =
  "R67 store and Cloudflare submission execution is active across the remaining R66 tasks";
r66.implementation.first_tranche_status =
  "all_route_tranches_validated_and_admitted";
r66.implementation.not_implemented_or_not_closed = [
  "dynamic CMS and externally governed content approval",
  "named French and Kinyarwanda linguistic approval",
  "accountable onboarding-media and club-content rights approval",
  state03RemainingCheck,
  "physical mobile and native-TV device, remote, assistive-technology, performance and soak proof",
  candidateCiRemainingBoundary,
  "exact-candidate Android mobile, iOS and Android TV artifacts",
  "Google Play mobile, App Store and Google Play TV metadata, testing, processing and submission receipts",
  "four-host Cloudflare custom-domain cutover and public-contract validation",
  "named accountable release approval",
];
const currentRouteFacts = fileFacts(routePath);
const currentDesignReport = path.join(
  output,
  "design_compliance_current/report.md",
);
const currentDesignFacts = fileFacts(currentDesignReport);
const currentDesignValidationFacts = fileFacts(designPath);
r66.deliverables.DELIV03 = {
  ...r66.deliverables.DELIV03,
  json_path: routePath,
  json_sha256: currentRouteFacts.sha256,
  json_bytes: currentRouteFacts.bytes,
  freshness: "current_local_route_state_checkpoint_2149_admitted_0_open_731_na",
};
r66.deliverables.DELIV04 = {
  ...r66.deliverables.DELIV04,
  generated_report_path: currentDesignReport,
  generated_report_sha256: currentDesignFacts.sha256,
  generated_report_bytes: currentDesignFacts.bytes,
  validation_path: designPath,
  validation_sha256: currentDesignValidationFacts.sha256,
  validation_bytes: currentDesignValidationFacts.bytes,
  freshness:
    "current_local_route_evidence_complete_with_accountable_design_approval_open",
};
r66.contradictions_and_staleness = r66.contradictions_and_staleness.map(
  (item) =>
    item.id === "CONTRA-R66-03"
      ? {
          ...item,
          status: "superseded",
          description:
            "All earlier partial route ledgers are superseded by the current 180-route, 2,880-cell ledger with 2,149 admitted applicable cells, zero open cells, 731 explicit N/A decisions and closure_complete=true.",
        }
      : item.id === "CONTRA-R66-04"
        ? {
            ...item,
            status: "resolved_in_current_register",
            description: `The current task register preserves the authoritative 87-task denominator at ${resultCounts.verified_complete} complete, ${resultCounts.verified_incomplete} incomplete and ${resultCounts.unverified} unverified; ${remainingIds.length} tasks remain including route-state admission and external or accountable gates.`,
          }
        : item,
);
write(r66Path, r66);

const engagement = read(engagementPath);
engagement.goal = releaseGoal.objective;
engagement.authority_status =
  "Project-owner authorization covers in-scope workspace implementation, validation, Git commit/push to main, and permitted external execution; credentials, identity verification, one-time codes, specialist approvals, store acceptance, and release evidence remain separately controlled.";
engagement.external_mutation_authorized = true;
engagement.goal_revision = {
  ...engagement.goal_revision,
  id: releaseGoal.revision,
  parent_goal_revision: "2026-07-30-R66",
  updated_at: now,
  governed_total: validation.tasks.length,
  verified_complete: resultCounts.verified_complete,
  verified_incomplete: resultCounts.verified_incomplete,
  unverified: resultCounts.unverified,
  remaining: remainingIds.length,
  route_count: route.route_count,
  route_state_cell_count: closure.cell_count,
  route_state_evidenced: closure.evidenced_cell_count,
  route_state_open: closure.open_cell_count,
  route_state_not_applicable:
    closure.cell_count - closure.evidenced_cell_count - closure.open_cell_count,
  football_club_first_implementation: {
    ...engagement.goal_revision.football_club_first_implementation,
    status:
      "all_180_routes_locally_evidence_complete_external_and_accountable_gates_open",
    route_evidence_regeneration_required: false,
  },
  release_submission_execution: {
    goal_id: releaseGoal.goal_id,
    definition_path: releaseGoalDefinitionPath,
    definition_sha256: fileFacts(releaseGoalDefinitionPath).sha256,
    checkpoint_path: releaseGoalPath,
    checkpoint_sha256: fileFacts(releaseGoalPath).sha256,
    workstream_count: releaseGoalWorkstreams.length,
    completion_proven: releaseGoalCompletionProven,
    completion_checks: releaseCompletionChecks,
  },
  active_implementation_route:
    "r67_store_cloudflare_submission_execution_across_remaining_r66_tasks",
  active_implementation_stage: "release_submission_program_active_fail_closed",
  active_implementation_remaining_checks:
    validation.current_checkpoint.active_implementation_remaining_checks,
  active_code_owned_queue:
    validation.current_checkpoint.active_code_owned_queue,
  evidence_admission_queue:
    validation.current_checkpoint.evidence_admission_queue,
};
engagement.status = releaseGoalCompletionProven
  ? "complete"
  : "active_release_submission_program_fail_closed";
write(engagementPath, engagement);

console.log(
  `Checkpoint reconciled: ${resultCounts.verified_complete} complete, ${resultCounts.verified_incomplete} incomplete, ${resultCounts.unverified} unverified, ${remainingIds.length} remaining`,
);
