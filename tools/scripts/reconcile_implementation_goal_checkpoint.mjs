#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const output = path.join(root, "output/implementation_goal_20260724");
const manifestPath = path.join(output, "validation-manifest.json");
const r66Path = path.join(output, "R66_WORKING_CANDIDATE_MANIFEST.json");
const engagementPath = path.join(output, "engagement-manifest.json");
const routePath = path.join(output, "route_inventory_current/route-inventory.json");
const designPath = path.join(output, "design_compliance_current/VALIDATION.json");
const externalPreflightPath = path.join(
  output,
  "external-execution-preflight-20260802.json",
);
const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const write = (file, value) =>
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
const fileFacts = (file) => {
  const body = fs.readFileSync(file);
  return {
    sha256: crypto.createHash("sha256").update(body).digest("hex"),
    bytes: body.length,
  };
};

const route = read(routePath);
const design = read(designPath);
const externalPreflight = read(externalPreflightPath);
const candidate = externalPreflight.candidate ?? {};
const githubActions = externalPreflight.github_actions ?? {};
const exactHeadRun = githubActions.exact_head_run ?? {};
const physicalDevices = externalPreflight.physical_devices ?? {};
const iosDevices = Array.isArray(physicalDevices.ios)
  ? physicalDevices.ios
  : null;
const hasRecordedDirtyBoundary =
  candidate.dirty === false ||
  (candidate.dirty === true &&
    typeof candidate.working_tree_dirty_boundary === "string" &&
    candidate.working_tree_dirty_boundary.trim().length > 0);
const exactHeadMatchesCandidate =
  typeof candidate.git_head === "string" &&
  candidate.git_head.length > 0 &&
  candidate.git_head === exactHeadRun.head_sha;
const exactCandidate =
  candidate.exact_candidate === true &&
  candidate.candidate_commit_verified_remote === true &&
  exactHeadMatchesCandidate &&
  hasRecordedDirtyBoundary;
const candidateMetadata = {
  branch: candidate.branch ?? null,
  head: candidate.git_head ?? null,
  dirty: typeof candidate.dirty === "boolean" ? candidate.dirty : null,
  exact_candidate: exactCandidate,
  exact_candidate_reported_by_preflight: candidate.exact_candidate === true,
  candidate_commit_verified_remote:
    candidate.candidate_commit_verified_remote === true,
  exact_head_run_matches_candidate: exactHeadMatchesCandidate,
  working_tree_dirty_boundary:
    candidate.working_tree_dirty_boundary ?? null,
  observed_at_utc: externalPreflight.checked_at ?? null,
};
const exactHeadRunOutcome =
  exactHeadRun.conclusion ?? exactHeadRun.status ?? "unknown";
const exactHeadRunSummary = `exact-HEAD GitHub Actions run ${exactHeadRun.id ?? "unknown"} for ${exactHeadRun.head_sha ?? "unknown"} is ${exactHeadRun.status ?? "status unknown"} with outcome ${exactHeadRunOutcome}, ${exactHeadRun.job_count ?? "unknown"} jobs and ${exactHeadRun.log_available === true ? "available" : "no"} logs`;
const pinnedRuntimeExecutionProven =
  githubActions.pinned_runtime_execution_proven === true;
const pinnedRuntimeSummary = pinnedRuntimeExecutionProven
  ? `${exactHeadRunSummary}; the current preflight marks pinned-runtime execution as proven`
  : `${exactHeadRunSummary}; the current preflight does not mark pinned-runtime execution as proven${githubActions.interpretation ? ` (${githubActions.interpretation})` : ""}`;
const candidateSummary = `The current preflight records commit ${candidateMetadata.head ?? "unknown"} on branch ${candidateMetadata.branch ?? "unknown"}; remote verification is ${candidateMetadata.candidate_commit_verified_remote ? "confirmed" : "not confirmed"}, the exact-head run ${candidateMetadata.exact_head_run_matches_candidate ? "matches" : "does not match"} the candidate SHA, and exact_candidate=${candidateMetadata.exact_candidate}.`;
const workingTreeSummary = candidateMetadata.dirty
  ? `The working tree is dirty within the recorded preservation boundary: ${candidateMetadata.working_tree_dirty_boundary ?? "no boundary recorded"}.`
  : candidateMetadata.dirty === false
    ? "The working tree is recorded as clean."
    : "The working-tree state is not reported by the current preflight.";
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
const candidateCiRemainingCheck = exactCandidate
  ? "pinned_ci_signing_store_processing_and_deployment"
  : "exact_candidate_pinned_ci_signing_store_processing_and_deployment";
const candidateCiRemainingBoundary = exactCandidate
  ? "actual pinned CI execution"
  : "exact controlled candidate and actual pinned CI execution";
const closure = route.state_closure;
if (
  closure.open_cell_count !== 0 ||
  closure.evidenced_cell_count !== 2137 ||
  closure.closure_complete !== true ||
  design.route_evidence_complete !== true ||
  design.design_complete !== false
) {
  throw new Error("Current route/design checkpoint is not the expected route-complete, approval-open state");
}

const completedUpdates = {
  "GOV-04":
    "The fail-closed registrar admitted the visually reviewed, exact-current nine-route Admin PWA and seven-route Venue portal batch. The generated 176-route ledger now proves all 2,137 applicable cells, retains 679 explicit N/A decisions, has zero open cells and records closure_complete=true. Accountable design and media-rights decisions remain separately governed under GOV-01/03/05 and EVID-04/05.",
  "STATE-01":
    "All 176 product routes are mapped across 16 governed states in a 2,816-cell fail-closed ledger. Exact-current typed tests plus screenshot or response evidence prove all 2,137 applicable cells, 679 cells are explicitly not applicable, zero cells remain open and closure_complete=true.",
  "EVID-02":
    "The matrix links all 2,137 applicable route-state cells to typed test plus screenshot or response evidence, retains 679 explicit N/A decisions, and records zero open cells after reviewed admission of the final sixteen Admin PWA and Venue portal bundles.",
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
  "EVID-03":
    `One thousand three hundred seventy-nine deterministic Flutter/native-TV exact-pixel baselines remain hash-governed, and all applicable web routes now have admitted exact-current screenshot or response evidence. Local visual review, source freshness, privacy scanning and artifact retention controls pass. Current pinned-runtime execution state: ${pinnedRuntimeSummary}.`,
  "EVID-04":
    "All 176 routes retain governed screenshot or response evidence. The final sixteen Admin PWA/Venue bundles and the native-TV remote/context checkpoint passed controlled visual/accessibility review and admission. Accountable human design approval for the final product surfaces remains open and has not been inferred.",
  "ADMIN-09":
    "All Admin routes now retain admitted exact-current controlled evidence. Live authorization, physical-device accessibility/performance and accountable operator approval remain open and are not established by loopback synthetic evidence.",
};

const retainedTaskUpdates = {
  "GOV-06":
    `The controlled Flutter runtime is reconciled at 3.44.4 across local configuration and release tooling. ${candidateSummary} ${workingTreeSummary} Current CI state: ${pinnedRuntimeSummary}.`,
  "A11Y-02":
    `The native-TV AVD now provides exact directional focus, center, Menu overlay and focus-restoration evidence, while automated semantics tests remain green. The current device preflight reports ${physicalDeviceSummary}. Physical VoiceOver execution is ${physicalDevices.voiceover_execution_proven === true ? "proven" : "not proven"}, TalkBack execution is ${physicalDevices.talkback_execution_proven === true ? "proven" : "not proven"}, and physical TV remote or soak execution is ${physicalDevices.physical_tv_remote_or_soak_proven === true ? "proven" : "not proven"}; emulator and automated semantics evidence do not substitute for those physical-device controls.`,
  "EVID-06":
    "Exact-current Android production-main profile evidence records a 1,242 ms cold start against the 3,000 ms budget, 79.34% SurfaceFlinger jank against the 5% budget, 153,191 KiB total PSS with no approved memory threshold, and controlled settings, 120-item Shop, checkout and Perfetto workloads. EV-249 adds exact native-TV cold-launch and remote-interaction execution, but not a repeat/soak or performance profile. EVID-06 remains verified incomplete because the software-rendered mobile emulator fails frame/raster budgets and representative physical-device profiling, an approved memory budget, product-image and real checkout-submission workloads, live realtime, native-TV performance/soak and authenticated Admin-volume profiles remain open.",
  "EVID-07":
    `All 136 admitted local evidence bundles have exact provenance sidecars covering 1,367 artifacts, including the reviewed native-TV remote/context and generic mobile pairing-link checkpoint; 1,379 golden baselines remain separately hash-governed. ${candidateCiRemainingBoundary[0].toUpperCase()}${candidateCiRemainingBoundary.slice(1)} remains separate under GOV-06 and EVID-08.`,
  "EVID-08":
    `CI configuration generates and validates route, archetype and component ledgers, source compliance, all 1,379 golden digests, interaction differentiation, endpoint contracts, evidence provenance, privacy patterns and platform builds. Current CI state: ${pinnedRuntimeSummary}. The current local set has 136 admitted bundles, zero pending bundles, 2,137 admitted route cells and zero open cells, including exact-current native-TV remote/context and iOS generic-link registration evidence. External release gates remain separately governed.`,
  "TV-04":
    "Automated native-TV focus and remote contracts pass. EV-249 now proves exact-current Android TV AVD cold launch, D-pad up/down reachability, center renewal, dedicated Menu context behavior, localized retry/close actions and focus restoration from Android UI hierarchies and screenshots. Product-scope-dependent rows/details/overlays and physical TV/remote, overscan and screen-reader proof remain open, so TV-04 remains verified incomplete.",
  "TV-05":
    "Pairing, credential, retry, conflict, timeout, recovery, proxy and scoped-revocation contracts remain exact-tested. EV-249 fixes the TV-generated `africlub://` versus mobile manifest mismatch by explicitly registering and parser-allowlisting both `africlub://` and `gikundiro://` while rejecting unlisted schemes; the rebuilt iOS simulator now recognizes the generic TV URL. Authenticated production pairing/synchronization, multi-client idempotency/audit, physical QR handoff and real-remote proof remain open, so TV-05 remains verified incomplete.",
  "TV-09":
    `The current preflight reports ${physicalDeviceSummary}. Production signing credentials, a signed AAB and certificate fingerprint, managed-track/store processing, representative-hardware soak, crash/ANR dashboard evidence, device inventory/revocation drill, and operations-owner sign-off remain separately required.`,
  "REL-01":
    `Release configuration, runtime pins, validation contracts, provenance controls and current local platform-build evidence exist. ${candidateSummary} ${workingTreeSummary} Current CI state: ${pinnedRuntimeSummary}. REL-01 remains verified incomplete while its other release gates remain open.`,
  "REL-02":
    "An exact-current production-flavor Android AAB dry-run passes with a destroyed ephemeral self-signed key, and three release-readiness integration journeys pass on an Android API 36 emulator. REL-02 is verified incomplete because the artifact is not production-signed or store-processed and complete physical-Android runtime, TalkBack, permissions, deep links, offline/retry, destructive-flow, performance and live-backend proof is absent.",
  "REL-03":
    "An exact-current unsigned iOS release build succeeds for rw.ikanisa.rayonSports at minimum iOS 15.5, its app-level PrivacyInfo.xcprivacy is bundled with the SDK manifests, and three release-readiness integration journeys pass on an iPhone 17 / iOS 26.5 simulator. The earlier QA-06 checkpoint records a development-signed physical-iPhone install and launch subset. REL-03 remains verified incomplete because there is no distribution-signed archive, complete exact-candidate physical-iPhone runtime, VoiceOver, text sizing, permissions, deep links, offline/retry, destructive-flow, performance, App Store processing or live-backend proof.",
  "REL-04":
    `The rebuilt iOS simulator recognizes the generic native-TV pairing URL and the platform/parser contracts pass, but this proves simulator registration only. The current preflight reports ${physicalDeviceSummary}. Physical VoiceOver execution is ${physicalDevices.voiceover_execution_proven === true ? "proven" : "not proven"} and TalkBack execution is ${physicalDevices.talkback_execution_proven === true ? "proven" : "not proven"}. Complete physical mobile UAT, authenticated QR handoff and assistive-technology evidence remain separately governed. REL-04 remains unverified.`,
  "REL-05":
    `EV-249 proves exact-current Android TV AVD directional focus, center, Menu context overlay and challenge renewal against an isolated local backend. The current preflight reports ${nativeTvAttachedCount ?? "an unreported number of"} attached native-TV devices and marks physical TV remote or soak execution as ${physicalDevices.physical_tv_remote_or_soak_proven === true ? "proven" : "not proven"}. Emulator execution does not by itself establish real display, overscan, remote, screen-reader, reconnect, network, authenticated pairing, performance or soak behavior. REL-05 remains unverified.`,
  "REL-06":
    "Privacy-filtered Crashlytics diagnostics now exclude account identifiers, raw exception messages and unsafe diagnostic strings; the Firebase startup contract keeps diagnostics compile-time gated and the focused observability tests, analysis and store/privacy validator pass. Existing local backend/API/hook and web contract evidence remains valid. REL-06 remains incomplete because authorized target-schema and hook-secret/dashboard configuration, live Meta delivery and identity callback, migration execution, RLS/grants, authenticated role matrices, rollback, monitoring dashboards and alerts, incident rehearsal, pinned CI, deployment evidence, and accountable backend/security approval remain open. No backend or production mutation was performed.",
  "REL-07":
    "Fail-closed production-signing configuration, ephemeral Android/mobile-TV release dry-runs, unsigned iOS release builds, conservative store/privacy working declarations and automated release contracts exist. No production upload/distribution key was used, no signed archive or managed-track artifact was processed, and no store-console mutation, review or approval occurred. REL-07 remains verified incomplete.",
  "REL-08":
    "The controlled records name the required product, design, accessibility, privacy, security, operations, QA and release owners and preserve every approval boundary. No accountable named approval has been supplied or inferred. REL-08 remains unverified.",
};

const validation = read(manifestPath);
for (const task of validation.tasks) {
  if (completedUpdates[task.id]) {
    task.current_result = "verified_complete";
    task.notes = completedUpdates[task.id];
    task.evidence = [...new Set([...(task.evidence ?? []), "EV-248"] )];
  } else if (incompleteUpdates[task.id]) {
    task.current_result = "verified_incomplete";
    task.notes = incompleteUpdates[task.id];
    task.evidence = [...new Set([...(task.evidence ?? []), "EV-248"] )];
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
      task.evidence = [...new Set([...(task.evidence ?? []), "EV-243", "EV-246", "EV-247", "EV-249"] )];
    }
    if (["MOB-08", "A11Y-02", "EVID-04", "EVID-05", "EVID-06", "EVID-07", "EVID-08", "TV-04", "TV-05", "REL-04", "REL-05"].includes(task.id)) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "EV-249",
          "output/implementation_goal_20260724/native_tv_remote_context_checkpoint_20260802/native-tv-remote-context-checkpoint.json",
          "output/implementation_goal_20260724/native_tv_remote_context_checkpoint_20260802/native-tv-remote-context-checkpoint.md",
        ]),
      ];
    }
    if (["GOV-06", "EVID-06", "ADMIN-08", "REL-02", "REL-04"].includes(task.id)) {
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
    if (["GOV-06", "A11Y-02", "EVID-08", "TV-09", "REL-01", "REL-04", "REL-05", "REL-08"].includes(task.id)) {
      task.evidence = [
        ...new Set([
          ...(task.evidence ?? []),
          "output/implementation_goal_20260724/external-execution-preflight-20260802.json",
        ]),
      ];
    }
    if (["GOV-06", "EVID-08", "REL-01", "REL-02", "REL-03", "REL-04", "REL-07"].includes(task.id)) {
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
  if (!["GOV-06", "EVID-06", "ADMIN-08", "REL-02", "REL-04"].includes(task.id)) {
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
  latest_local_route_closure:
    "all 176 routes remain governed; all 2,137 applicable cells are admitted, 679 are explicitly N/A, zero cells are open and closure_complete=true",
  active_implementation_route: "external_device_live_ci_signing_store_and_accountable_approval_gates",
  active_implementation_stage:
    "all_locally_actionable_route_evidence_complete_external_and_accountable_gates_open",
  active_implementation_remaining_checks: [
    "dynamic_and_unrecognized_copy_review",
    "named_french_and_kinyarwanda_linguistic_approval",
    "approved_onboarding_and_live_club_content_rights_and_provenance",
    "source_secret_rotation_decision_by_authorized_owner",
    "authorized_target_backend_migration_rls_rpc_collision_and_rollback_execution",
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
      "No local route-evidence admission remains queued. The corrected sixteen-route batch passed exact-current execution, visual review, provenance preflight and explicit fail-closed admission.",
  },
  external_execution_preflight: {
    path: externalPreflightPath,
    ...fileFacts(externalPreflightPath),
    checked_at: externalPreflight.checked_at ?? null,
    candidate: candidateMetadata,
    github_actions_repository: githubActions.repository ?? null,
    github_actions_exact_head_run: exactHeadRun.id ?? null,
    github_actions_exact_head_sha: exactHeadRun.head_sha ?? null,
    github_actions_status: exactHeadRun.status ?? null,
    github_actions_conclusion: exactHeadRun.conclusion ?? null,
    github_actions_job_count: exactHeadRun.job_count ?? null,
    github_actions_log_available: exactHeadRun.log_available === true,
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
    closure_effect: externalPreflight.closure_effect ?? null,
  },
  closure_complete: closure.closure_complete,
  design_complete: design.design_complete,
};
validation.football_club_first_implementation = {
  ...validation.football_club_first_implementation,
  status: "all_176_routes_locally_evidence_complete_external_and_accountable_gates_open",
  post_plan_design_compliance: {
    ...validation.football_club_first_implementation.post_plan_design_compliance,
    status: design.status,
    design_complete: design.design_complete,
    route_evidence_complete: design.route_evidence_complete,
    violation_count: design.violation_count,
    warning_count: design.warning_count,
    open_route_state_cells: closure.open_cell_count,
  },
  route_evidence_regeneration_required: false,
};
const r66Deliverables = validation.r66_mandatory_deliverables.deliverables;
for (const deliverable of r66Deliverables) {
  if (deliverable.id === "DELIV-01") {
    deliverable.status = "current_local_audit_complete_accountable_review_open";
    deliverable.current_evidence =
      "current-source football-club-first UI/UX, architecture and journey audit is reconciled across 176 routes; all 2,137 applicable cells are admitted, zero remain pending, and 679 are explicit N/A";
  } else if (deliverable.id === "DELIV-02") {
    deliverable.status = "current_local_manifest_complete_unsealed_candidate";
    deliverable.current_evidence = `machine-readable 87-task accounting records ${resultCounts.verified_complete} complete, ${resultCounts.verified_incomplete} incomplete and ${resultCounts.unverified} unverified; every remaining item names an external, human, device, live, CI, signing, store, deployment or release boundary`;
  } else if (deliverable.id === "DELIV-03") {
    deliverable.status = "fresh_structural_inventory_and_route_state_closure_complete";
    deliverable.current_evidence =
      "current inventory has 176 routes, zero duplicates, 2,816 cells, 2,137 admitted applicable cells, zero open cells and 679 explicit N/A decisions; closure_complete=true";
  } else if (deliverable.id === "DELIV-04") {
    deliverable.status = "automated_pass_route_evidence_complete_overall_approval_open";
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
    applicable_cell_count: closure.evidenced_cell_count + closure.open_cell_count,
    not_applicable_cell_count:
      closure.cell_count - closure.evidenced_cell_count - closure.open_cell_count,
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
r66.closure.external_or_human_gates = (
  r66.closure.external_or_human_gates ?? []
).map((gate) =>
  exactCandidate && gate === "clean controlled candidate and pinned CI"
    ? "actual pinned CI execution"
    : gate,
);
delete r66.closure.all_38_tasks_complete;
r66.design_compliance = {
  ...r66.design_compliance,
  scope: "automated_source_plus_fail_closed_176_route_cross_surface_checkpoint",
  automated_status: "pass_with_route_evidence_complete_and_accountable_human_review_open",
  violation_count: design.violation_count,
  warning_count: design.warning_count,
  design_complete: design.design_complete,
  route_evidence_complete: design.route_evidence_complete,
  current_visual_review:
    "all 2,137 applicable route-state cells are admitted and 679 are explicit N/A; zero cells remain open after controlled review and explicit admission of the final sixteen-route batch",
};
r66.implementation.active_phase =
  "Local route evidence is complete; external device, live, CI, signing, store and accountable approval gates remain";
r66.implementation.first_tranche_status =
  "all_route_tranches_validated_and_admitted";
r66.implementation.not_implemented_or_not_closed = [
  "dynamic CMS and externally governed content approval",
  "named French and Kinyarwanda linguistic approval",
  "accountable onboarding-media and club-content rights approval",
  "authorized target-backend RLS, RPC, audit, collision and rollback execution",
  "physical mobile and native-TV device, remote, assistive-technology, performance and soak proof",
  candidateCiRemainingBoundary,
  "production signing, store processing, deployment and accountable release approval",
];
const currentRouteFacts = fileFacts(routePath);
const currentDesignReport = path.join(output, "design_compliance_current/report.md");
const currentDesignFacts = fileFacts(currentDesignReport);
const currentDesignValidationFacts = fileFacts(designPath);
r66.deliverables.DELIV03 = {
  ...r66.deliverables.DELIV03,
  json_path: routePath,
  json_sha256: currentRouteFacts.sha256,
  json_bytes: currentRouteFacts.bytes,
  freshness: "current_local_route_state_checkpoint_2137_admitted_0_open_679_na",
};
r66.deliverables.DELIV04 = {
  ...r66.deliverables.DELIV04,
  generated_report_path: currentDesignReport,
  generated_report_sha256: currentDesignFacts.sha256,
  generated_report_bytes: currentDesignFacts.bytes,
  validation_path: designPath,
  validation_sha256: currentDesignValidationFacts.sha256,
  validation_bytes: currentDesignValidationFacts.bytes,
  freshness: "current_local_route_evidence_complete_with_accountable_design_approval_open",
};
r66.contradictions_and_staleness = r66.contradictions_and_staleness.map(
  (item) =>
    item.id === "CONTRA-R66-03"
      ? {
          ...item,
          status: "superseded",
          description:
            "All earlier partial route ledgers are superseded by the current 176-route, 2,816-cell ledger with 2,137 admitted applicable cells, zero open cells, 679 explicit N/A decisions and closure_complete=true.",
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
engagement.goal =
  "Complete every locally actionable AFRICLUB implementation, test, validation and evidence requirement under the football-club-first contract; reconcile the 87 governed tasks and retain all external, human, live, device, CI, signing, store, deployment and release gates without inference.";
engagement.goal_revision = {
  ...engagement.goal_revision,
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
    status: "all_176_routes_locally_evidence_complete_external_and_accountable_gates_open",
    route_evidence_regeneration_required: false,
  },
  active_implementation_route: "external_device_live_ci_signing_store_and_accountable_approval_gates",
  active_implementation_stage:
    "all_locally_actionable_route_evidence_complete_external_and_accountable_gates_open",
  active_implementation_remaining_checks:
    validation.current_checkpoint.active_implementation_remaining_checks,
  active_code_owned_queue: validation.current_checkpoint.active_code_owned_queue,
  evidence_admission_queue: validation.current_checkpoint.evidence_admission_queue,
};
engagement.status = "local_route_evidence_complete_external_and_accountable_gates_open";
write(engagementPath, engagement);

console.log(
  `Checkpoint reconciled: ${resultCounts.verified_complete} complete, ${resultCounts.verified_incomplete} incomplete, ${resultCounts.unverified} unverified, ${remainingIds.length} remaining`,
);
