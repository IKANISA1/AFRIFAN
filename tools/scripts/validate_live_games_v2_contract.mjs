import { access, readFile } from "node:fs/promises";

const contractUrl = new URL(
  "../../docs/architecture/live-games-v2-contract.json",
  import.meta.url,
);
const contract = JSON.parse(await readFile(contractUrl, "utf8"));
const crossClientFixtureUrl = new URL(
  "../../docs/architecture/live-games-v2-cross-client-fixtures.json",
  import.meta.url,
);
const crossClientFixture = JSON.parse(
  await readFile(crossClientFixtureUrl, "utf8"),
);
const synchronizedSessionMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-synchronized-session-matrix.json",
  import.meta.url,
);
const synchronizedSessionMatrix = JSON.parse(
  await readFile(synchronizedSessionMatrixUrl, "utf8"),
);
const resilienceMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-resilience-matrix.json",
  import.meta.url,
);
const resilienceMatrix = JSON.parse(
  await readFile(resilienceMatrixUrl, "utf8"),
);
const tvAccessibilityMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-tv-accessibility-matrix.json",
  import.meta.url,
);
const tvAccessibilityMatrix = JSON.parse(
  await readFile(tvAccessibilityMatrixUrl, "utf8"),
);
const exactCandidateMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-exact-candidate-matrix.json",
  import.meta.url,
);
const exactCandidateMatrix = JSON.parse(
  await readFile(exactCandidateMatrixUrl, "utf8"),
);
const participantLayoutMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-participant-layout-matrix.json",
  import.meta.url,
);
const participantLayoutMatrix = JSON.parse(
  await readFile(participantLayoutMatrixUrl, "utf8"),
);
const participantRecoveryMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-participant-recovery-matrix.json",
  import.meta.url,
);
const participantRecoveryMatrix = JSON.parse(
  await readFile(participantRecoveryMatrixUrl, "utf8"),
);
const participantSyncMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-participant-sync-matrix.json",
  import.meta.url,
);
const participantSyncMatrix = JSON.parse(
  await readFile(participantSyncMatrixUrl, "utf8"),
);
const participantDiscoveryMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-participant-discovery-matrix.json",
  import.meta.url,
);
const participantDiscoveryMatrix = JSON.parse(
  await readFile(participantDiscoveryMatrixUrl, "utf8"),
);
const participantCodeRetirementMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-participant-code-retirement-matrix.json",
  import.meta.url,
);
const participantCodeRetirementMatrix = JSON.parse(
  await readFile(participantCodeRetirementMatrixUrl, "utf8"),
);
const organizerPlanningMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-organizer-planning-matrix.json",
  import.meta.url,
);
const organizerPlanningMatrix = JSON.parse(
  await readFile(organizerPlanningMatrixUrl, "utf8"),
);
const organizerGuardedOperationsMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-organizer-guarded-operations-matrix.json",
  import.meta.url,
);
const organizerGuardedOperationsMatrix = JSON.parse(
  await readFile(organizerGuardedOperationsMatrixUrl, "utf8"),
);
const ownerInventoryMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-owner-inventory-matrix.json",
  import.meta.url,
);
const ownerInventoryMatrix = JSON.parse(
  await readFile(ownerInventoryMatrixUrl, "utf8"),
);
const ownerManagementMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-owner-management-matrix.json",
  import.meta.url,
);
const ownerManagementMatrix = JSON.parse(
  await readFile(ownerManagementMatrixUrl, "utf8"),
);
const tvPairingMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-tv-pairing-matrix.json",
  import.meta.url,
);
const tvPairingMatrix = JSON.parse(
  await readFile(tvPairingMatrixUrl, "utf8"),
);
const tvProjectionMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-tv-projection-matrix.json",
  import.meta.url,
);
const tvProjectionMatrix = JSON.parse(
  await readFile(tvProjectionMatrixUrl, "utf8"),
);
const tvRealtimeMatrixUrl = new URL(
  "../../docs/architecture/live-games-v2-tv-realtime-matrix.json",
  import.meta.url,
);
const tvRealtimeMatrix = JSON.parse(
  await readFile(tvRealtimeMatrixUrl, "utf8"),
);
const crossClientTestSources = await Promise.all(
  [
    "../../packages/features/feat_gamification/test/participant_live_games_screen_test.dart",
    "../../packages/features/feat_game_operations/test/game_operations_screens_test.dart",
    "../../apps/rayon_sports_tv/test/tv_route_states_test.dart",
    "../../apps/rayon_sports/web/src/app/admin/games/games-control-client.test.tsx",
  ].map((path) => readFile(new URL(path, import.meta.url), "utf8")),
);
const resilienceTestPaths = [
  ...new Set(
    (resilienceMatrix.scenarios ?? []).flatMap((scenario) =>
      (scenario.tests ?? []).map((test) => test.path),
    ),
  ),
];
const resilienceTestSources = new Map(
  await Promise.all(
    resilienceTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const tvAccessibilityTestPaths = [
  ...new Set(
    (tvAccessibilityMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const tvAccessibilityTestSources = new Map(
  await Promise.all(
    tvAccessibilityTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const participantLayoutTestPaths = [
  ...new Set(
    (participantLayoutMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const participantLayoutTestSources = new Map(
  await Promise.all(
    participantLayoutTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const participantRecoveryTestPaths = [
  ...new Set(
    (participantRecoveryMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const participantRecoveryTestSources = new Map(
  await Promise.all(
    participantRecoveryTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const participantSyncTestPaths = [
  ...new Set(
    (participantSyncMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const participantSyncTestSources = new Map(
  await Promise.all(
    participantSyncTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const participantRepository = await readFile(
  new URL(
    "../../packages/features/feat_gamification/lib/src/repositories/live_game_v2_repository.dart",
    import.meta.url,
  ),
  "utf8",
);
const participantSynchronizer = await readFile(
  new URL(
    "../../packages/features/feat_gamification/lib/src/controllers/live_game_v2_synchronizer.dart",
    import.meta.url,
  ),
  "utf8",
);
const participantDiscoveryTestPaths = [
  ...new Set(
    (participantDiscoveryMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const participantDiscoveryTestSources = new Map(
  await Promise.all(
    participantDiscoveryTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const participantCodeRetirementTestPaths = [
  ...new Set(
    (participantCodeRetirementMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const participantCodeRetirementTestSources = new Map(
  await Promise.all(
    participantCodeRetirementTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const organizerPlanningTestPaths = [
  ...new Set(
    (organizerPlanningMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const organizerPlanningTestSources = new Map(
  await Promise.all(
    organizerPlanningTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const organizerGuardedOperationsTestPaths = [
  ...new Set(
    (organizerGuardedOperationsMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const organizerGuardedOperationsTestSources = new Map(
  await Promise.all(
    organizerGuardedOperationsTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const ownerInventoryTestPaths = [
  ...new Set(
    (ownerInventoryMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const ownerInventoryTestSources = new Map(
  await Promise.all(
    ownerInventoryTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const ownerManagementTestPaths = [
  ...new Set(
    (ownerManagementMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const ownerManagementTestSources = new Map(
  await Promise.all(
    ownerManagementTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const tvPairingTestPaths = [
  ...new Set(
    (tvPairingMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const tvPairingTestSources = new Map(
  await Promise.all(
    tvPairingTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const tvProjectionTestPaths = [
  ...new Set(
    (tvProjectionMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const tvProjectionTestSources = new Map(
  await Promise.all(
    tvProjectionTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const tvRealtimeTestPaths = [
  ...new Set(
    (tvRealtimeMatrix.clauses ?? []).flatMap((clause) =>
      (clause.tests ?? []).map((test) => test.path),
    ),
  ),
];
const tvRealtimeTestSources = new Map(
  await Promise.all(
    tvRealtimeTestPaths.map(async (path) => [
      path,
      await readFile(new URL(`../../${path}`, import.meta.url), "utf8"),
    ]),
  ),
);
const fanzoneModule = await readFile(
  new URL(
    "../../packages/features/feat_gamification/lib/src/fanzone_module.dart",
    import.meta.url,
  ),
  "utf8",
);
const fanzoneHubWidgets = await readFile(
  new URL(
    "../../packages/features/feat_gamification/lib/src/widgets/fanzone_hub_widgets.dart",
    import.meta.url,
  ),
  "utf8",
);
const gamificationBarrel = await readFile(
  new URL(
    "../../packages/features/feat_gamification/lib/feat_gamification.dart",
    import.meta.url,
  ),
  "utf8",
);
const gameSessionAction = await readFile(
  new URL(
    "../../supabase/functions/game-session-action/index.ts",
    import.meta.url,
  ),
  "utf8",
);
const participantArbSources = await Promise.all(
  ["en", "fr", "rw"].map((locale) =>
    readFile(
      new URL(
        `../../packages/core/core_l10n/lib/l10n/afri_${locale}.arb`,
        import.meta.url,
      ),
      "utf8",
    ),
  ),
);
const gameOperationsModule = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/game_operations_module.dart",
    import.meta.url,
  ),
  "utf8",
);
const pairTvScreen = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/screens/pair_tv_screen.dart",
    import.meta.url,
  ),
  "utf8",
);
const sessionPlannerScreen = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/screens/session_planner_screen.dart",
    import.meta.url,
  ),
  "utf8",
);
const liveGameControlScreen = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/screens/live_game_control_screen.dart",
    import.meta.url,
  ),
  "utf8",
);
const myTvsScreen = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/screens/my_tvs_screen.dart",
    import.meta.url,
  ),
  "utf8",
);
const tvDetailScreen = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/screens/tv_detail_screen.dart",
    import.meta.url,
  ),
  "utf8",
);
const gameOperationsModels = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/models/game_operations_models.dart",
    import.meta.url,
  ),
  "utf8",
);
const gameOperationsRepository = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/repositories/game_operations_repository.dart",
    import.meta.url,
  ),
  "utf8",
);
const gameOperationsControllers = await readFile(
  new URL(
    "../../packages/features/feat_game_operations/lib/src/controllers/game_operations_controllers.dart",
    import.meta.url,
  ),
  "utf8",
);
const adminGameRuntime = await readFile(
  new URL(
    "../../apps/rayon_sports/web/src/lib/game-runtime.ts",
    import.meta.url,
  ),
  "utf8",
);
const adminGameActionRoute = await readFile(
  new URL(
    "../../apps/rayon_sports/web/src/app/api/game-session-action/route.ts",
    import.meta.url,
  ),
  "utf8",
);
const pushNotificationService = await readFile(
  new URL(
    "../../packages/core/core_network/lib/src/push_notification_service.dart",
    import.meta.url,
  ),
  "utf8",
);
const coreApp = await readFile(
  new URL("../../packages/core/core_app/lib/src/app.dart", import.meta.url),
  "utf8",
);
const migrationUrl = new URL(
  "../../supabase/migrations/20260730143000_live_games_v2_authoritative_runtime.sql",
  import.meta.url,
);
const migration = await readFile(migrationUrl, "utf8");
const contentMigrationUrl = new URL(
  "../../supabase/migrations/20260730152000_game_content_provenance_preview_gate.sql",
  import.meta.url,
);
const contentMigration = await readFile(contentMigrationUrl, "utf8");
const tvRealtimeMigrationUrl = new URL(
  "../../supabase/migrations/20260801153000_native_tv_realtime_identity.sql",
  import.meta.url,
);
const tvRealtimeMigration = await readFile(tvRealtimeMigrationUrl, "utf8");
const authRoleMigrationUrl = new URL(
  "../../supabase/migrations/20260801154500_preserve_authenticated_jwt_role.sql",
  import.meta.url,
);
const authRoleMigration = await readFile(authRoleMigrationUrl, "utf8");
const pgTapUrl = new URL(
  "../../supabase/tests/live_games_v2_contract.sql",
  import.meta.url,
);
const pgTapContract = await readFile(pgTapUrl, "utf8");
const tvRuntimeUrl = new URL(
  "../../apps/rayon_sports_tv/lib/src/tv_runtime.dart",
  import.meta.url,
);
const tvRuntime = await readFile(tvRuntimeUrl, "utf8");
const tvRuntimeController = await readFile(
  new URL(
    "../../apps/rayon_sports_tv/lib/src/tv_runtime_controller.dart",
    import.meta.url,
  ),
  "utf8",
);
const tvMain = await readFile(
  new URL("../../apps/rayon_sports_tv/lib/main.dart", import.meta.url),
  "utf8",
);
const retiredMatchQuizUrl = new URL(
  "../../apps/rayon_sports/web/src/components/engagement/match-quiz.tsx",
  import.meta.url,
);
const pgTapPlanMatch = pgTapContract.match(/select plan\((\d+)\)/i);
const pgTapChecks = Number(pgTapPlanMatch?.[1] ?? 0);

const failures = [];

function requireCondition(condition, message) {
  if (!condition) failures.push(message);
}

function unique(values) {
  return new Set(values).size === values.length;
}

async function pathExists(url) {
  try {
    await access(url);
    return true;
  } catch {
    return false;
  }
}

function sourceBetween(start, end) {
  const startIndex = migration.indexOf(start);
  const endIndex =
    startIndex < 0 ? -1 : migration.indexOf(end, startIndex + start.length);
  if (startIndex < 0 || endIndex < 0) return "";
  return migration.slice(startIndex, endIndex);
}

function sourceBetweenIn(source, start, end) {
  const startIndex = source.indexOf(start);
  const endIndex =
    startIndex < 0 ? -1 : source.indexOf(end, startIndex + start.length);
  if (startIndex < 0 || endIndex < 0) return "";
  return source.slice(startIndex, endIndex);
}

const states = contract.lifecycle?.states ?? [];
const transitions = contract.lifecycle?.transitions ?? [];
const roles = contract.roles ?? [];

requireCondition(contract.schema_version === "1.0", "schema_version must be 1.0");
const tvPairingScreenSource = sourceBetweenIn(
  tvMain,
  "class TvPairingChallengeScreen extends StatelessWidget",
  "class _TvGameProjectionScreen extends StatelessWidget",
);
requireCondition(
  contract.contract_id === "africlub_live_games_v2",
  "contract_id is invalid",
);
requireCondition(states.length >= 8 && unique(states), "lifecycle states invalid");
requireCondition(roles.length >= 7 && unique(roles), "roles invalid");
requireCondition(
  transitions.length >= 10 &&
    transitions.every((transition) => unique(transition.from)),
  "transitions must be complete and have unique source states",
);

for (const transition of transitions) {
  requireCondition(
    transition.from.every((state) => states.includes(state)),
    `transition ${transition.action} has an unknown source state`,
  );
  requireCondition(
    states.includes(transition.to),
    `transition ${transition.action} has an unknown target state`,
  );
  requireCondition(
    transition.roles.every((role) => roles.includes(role)),
    `transition ${transition.action} has an unknown role`,
  );
}

const requiredTransitionChecks = new Set(
  contract.lifecycle?.transition_requirements ?? [],
);
for (const requirement of [
  "expected_session_version",
  "idempotency_key",
  "audit_event",
  "new_projection",
]) {
  requireCondition(
    requiredTransitionChecks.has(requirement),
    `missing transition requirement ${requirement}`,
  );
}

requireCondition(
  contract.pairing?.participant_uses_pairing_challenge === false,
  "participants must not use the pairing challenge",
);
requireCondition(
  contract.pairing?.challenge_properties?.includes("hashed_at_rest"),
  "pairing challenge must be hashed at rest",
);
requireCondition(
  contract.pairing?.challenge_properties?.includes("single_use"),
  "pairing challenge must be single use",
);
requireCondition(
  contract.pairing?.credential_properties?.includes("projection_only"),
  "TV credential must be projection only",
);
requireCondition(
  contract.pairing?.credential_properties?.includes("realtime_identity_bound"),
  "TV credential must bind a separate Realtime identity",
);

requireCondition(
  contract.realtime?.channel_template ===
    "{club_id}:game_session:{session_id}",
  "Realtime channel template is invalid",
);
requireCondition(
  contract.realtime?.event_role === "invalidation_hint",
  "Realtime event must be an invalidation hint",
);
requireCondition(
  contract.realtime?.authoritative_source === "role_projection_rpc",
  "role projection RPC must remain authoritative",
);
requireCondition(
  contract.realtime?.native_tv_identity ===
    "anonymous_auth_bound_to_device_credential" &&
    contract.realtime?.native_tv_event_scope ===
      "actively_assigned_sessions_only",
  "native TV Realtime identity and event scope are invalid",
);

const participantForbidden = new Set(
  contract.projections?.participant?.forbidden_fields ?? [],
);
for (const field of [
  "join_code",
  "pairing_challenge",
  "correct_answer_before_reveal",
]) {
  requireCondition(
    participantForbidden.has(field),
    `participant projection must forbid ${field}`,
  );
}
const organizerRequired = new Set(
  contract.projections?.organizer?.required_fields ?? [],
);
for (const field of [
  "allowed_actions",
  "participant_count",
  "current_question_control",
  "question_controls",
]) {
  requireCondition(
    organizerRequired.has(field),
    `organizer projection must require ${field}`,
  );
}

const discovery = contract.projections?.discovery ?? {};
const discoverySources = discovery.sources ?? [];
const discoverablePhases = new Set(discovery.discoverable_phases ?? []);
const discoveryRequired = new Set(discovery.required_fields ?? []);
const discoveryForbidden = new Set(discovery.forbidden_fields ?? []);
requireCondition(
  discovery.join_key === "session_id",
  "participant discovery must join by session_id",
);
requireCondition(
  discoverySources.length === 5 && unique(discoverySources),
  "participant discovery sources are invalid",
);
for (const source of [
  "club_membership",
  "invitation",
  "home_owner",
  "venue",
  "deep_link",
]) {
  requireCondition(
    discoverySources.includes(source),
    `participant discovery must support ${source}`,
  );
}
for (const phase of [
  "scheduled",
  "activated_lobby",
  "question_open",
  "reveal",
  "paused",
]) {
  requireCondition(
    discoverablePhases.has(phase),
    `participant discovery must support ${phase}`,
  );
}
for (const field of [
  "club_id",
  "feed_version",
  "server_time",
  "public_alias",
  "sessions",
  "eligibility",
]) {
  requireCondition(
    discoveryRequired.has(field),
    `participant discovery must require ${field}`,
  );
}
for (const field of [
  "join_code",
  "tv_code",
  "pairing_challenge",
  "device_credential",
  "display_name",
  "real_name",
  "phone",
  "email",
  "auth_uid",
]) {
  requireCondition(
    discoveryForbidden.has(field),
    `participant discovery must forbid ${field}`,
  );
}

const tvForbidden = new Set(contract.projections?.tv?.forbidden_fields ?? []);
for (const field of [
  "auth_uid",
  "real_name",
  "phone",
  "email",
  "wallet_balance",
  "check_in_identity",
  "order_queue",
  "device_credential",
  "pairing_challenge",
  "correct_answer_before_reveal",
]) {
  requireCondition(tvForbidden.has(field), `TV projection must forbid ${field}`);
}

const serviceLevels = contract.service_levels ?? {};
requireCondition(
  serviceLevels.normal_propagation_p95_ms <= 2000,
  "normal propagation p95 must be at most 2000ms",
);
requireCondition(
  serviceLevels.reconnect_to_current_snapshot_ms <= 5000,
  "reconnect must be at most 5000ms",
);
for (const metric of [
  "cross_club_exposure_allowed",
  "duplicate_lifecycle_advance_allowed",
  "pre_reveal_answer_leak_allowed",
  "participant_tv_code_dependency_allowed",
  "personal_data_on_tv_allowed",
]) {
  requireCondition(serviceLevels[metric] === 0, `${metric} must be zero`);
}

requireCondition(
  contract.required_owner_decisions?.length === 6,
  "six owner decisions must remain explicitly traceable",
);
const resolvedProductDecisions = contract.resolved_product_decisions ?? {};
for (const decisionId of ["DEC-01", "DEC-02", "DEC-03", "DEC-04", "DEC-05"]) {
  requireCondition(
    resolvedProductDecisions[decisionId]?.status === "approved" &&
      typeof resolvedProductDecisions[decisionId]?.decision === "string" &&
      resolvedProductDecisions[decisionId].decision.length > 0,
    `${decisionId} must retain an approved product decision`,
  );
}
requireCondition(
  typeof contract.open_rollout_decisions?.["DEC-06"] === "string" &&
    contract.open_rollout_decisions["DEC-06"].length > 0,
  "DEC-06 must remain an explicit open rollout decision",
);
const qa01 = contract.quality_contract?.["GAME-QA-01"] ?? {};
const qa01Areas = new Set(qa01.required_areas ?? []);
for (const area of [
  "projection_serialization_and_sanitization",
  "role_and_action_matrices",
  "rls_and_relation_grants",
  "lifecycle_preconditions",
  "idempotency",
  "ordering_and_version_rejection",
  "authoritative_deadlines",
  "append_only_audit_events",
  "no_premature_answer_exposure",
]) {
  requireCondition(qa01Areas.has(area), `GAME-QA-01 must retain ${area}`);
}
requireCondition(
  qa01.status === "local_source_and_isolated_database_contract_passed" &&
    qa01.pgtap_checks_passed >= 77 &&
    qa01.shared_or_live_environment_claimed === false,
  "GAME-QA-01 must preserve its exact local acceptance boundary",
);
const qa02 = contract.quality_contract?.["GAME-QA-02"] ?? {};
const qa02States = [
  "lobby",
  "open",
  "reveal",
  "next",
  "completion",
  "cancellation",
];
const qa02Surfaces = [
  "participant_mobile",
  "organizer_mobile",
  "native_tv",
  "admin",
];
requireCondition(
  qa02.status === "local_deterministic_cross_client_render_contract_passed" &&
    qa02.focused_tests_passed >= 62 &&
    qa02.shared_or_live_session_claimed === false &&
    qa02.physical_device_claimed === false &&
    qa02.release_claimed === false,
  "GAME-QA-02 must preserve its exact deterministic local boundary",
);
requireCondition(
  JSON.stringify(qa02.required_states) === JSON.stringify(qa02States),
  "GAME-QA-02 must retain all six ordered authoritative states",
);
requireCondition(
  JSON.stringify(qa02.required_surfaces) === JSON.stringify(qa02Surfaces),
  "GAME-QA-02 must retain all four client surfaces",
);
requireCondition(
  crossClientFixture.contract === "GAME-QA-02" &&
    JSON.stringify(crossClientFixture.states?.map((state) => state.id)) ===
      JSON.stringify(qa02States),
  "GAME-QA-02 fixture must retain the six required states",
);
requireCondition(
  crossClientFixture.states?.every(
    (state, index) =>
      state.session_version === index + 1 &&
      Number.isInteger(state.question_version) &&
      state.event_sequence === index + 1 &&
      [
        state.participant_render_text,
        state.organizer_render_text,
        state.tv_render_text,
        state.admin_render_text,
      ].every((value) => typeof value === "string" && value.trim().length > 0),
  ),
  "GAME-QA-02 fixture versions and surface render expectations are invalid",
);
const qa03 = contract.quality_contract?.["GAME-QA-03"] ?? {};
const qa03Clauses = [
  "authorized_shared_backend",
  "two_independent_phones",
  "native_tv_target",
  "single_session_correlation",
  "synchronized_phase_version_sequence",
  "measured_network_timing_loss_recovery",
  "exact_build_logs_and_video",
  "privacy_accessibility_approvals",
];
requireCondition(
  qa03.status === "preflight_complete_execution_evidence_open" &&
    qa03.criterion_complete === false &&
    qa03.preflight_complete === true &&
    qa03.available_physical_ios_count === 0 &&
    qa03.paired_physical_ios_inventory_count === 1 &&
    qa03.physical_android_count === 0 &&
    qa03.physical_native_tv_count === 0 &&
    qa03.authorized_shared_backend_claimed === false &&
    qa03.synchronized_session_claimed === false &&
    qa03.network_timing_claimed === false &&
    qa03.video_and_correlated_logs_claimed === false &&
    qa03.named_approvals_claimed === false &&
    qa03.release_claimed === false,
  "GAME-QA-03 must preserve its completed preflight and open physical synchronized-session boundary",
);
requireCondition(
  JSON.stringify(qa03.required_clauses) === JSON.stringify(qa03Clauses) &&
    synchronizedSessionMatrix.contract === "GAME-QA-03" &&
    synchronizedSessionMatrix.status === qa03.status &&
    synchronizedSessionMatrix.criterion_complete === false &&
    JSON.stringify(synchronizedSessionMatrix.required_clauses) ===
      JSON.stringify(qa03Clauses) &&
    JSON.stringify(
      synchronizedSessionMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(qa03Clauses),
  "GAME-QA-03 matrix must retain all eight ordered execution clauses and remain open",
);
for (const clause of synchronizedSessionMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" &&
      clause.assertion.length > 0 &&
      (clause.status === "open_external_evidence" ||
        clause.status === "open_protected_approval"),
    `GAME-QA-03 ${clause.id} must remain explicitly open with an assertion`,
  );
}
const qa03Preflight = synchronizedSessionMatrix.preflight_evidence ?? {};
requireCondition(
  qa03Preflight.available_physical_ios_count === 0 &&
    qa03Preflight.paired_physical_ios_inventory_count === 1 &&
    qa03Preflight.paired_physical_ios_state === "unavailable" &&
    qa03Preflight.physical_android_count === 0 &&
    qa03Preflight.physical_native_tv_count === 0 &&
    qa03Preflight.ios_simulators_available === 2 &&
    qa03Preflight.android_tv_emulator_available === true &&
    typeof qa03Preflight.checkpoint === "string" &&
    await pathExists(new URL(`../../${qa03Preflight.checkpoint}`, import.meta.url)),
  "GAME-QA-03 must retain the exact current device preflight checkpoint",
);
const qa03Boundary = synchronizedSessionMatrix.environment_boundary ?? {};
requireCondition(
  qa03Boundary.preflight_complete === true &&
    qa03Boundary.authorized_shared_backend_claimed === false &&
    qa03Boundary.two_available_physical_phones_claimed === false &&
    qa03Boundary.physical_native_tv_claimed === false &&
    qa03Boundary.single_session_correlation_claimed === false &&
    qa03Boundary.synchronized_phase_version_sequence_claimed === false &&
    qa03Boundary.network_timing_and_recovery_claimed === false &&
    qa03Boundary.exact_build_logs_and_video_claimed === false &&
    qa03Boundary.privacy_accessibility_approvals_claimed === false &&
    qa03Boundary.release_claimed === false,
  "GAME-QA-03 must fail closed for shared backend, physical devices, synchronized execution, timing, video, approvals, and release",
);
const qa04 = contract.quality_contract?.["GAME-QA-04"] ?? {};
const qa04Scenarios = [
  "interruption",
  "late_join",
  "app_resume",
  "tv_restart",
  "duplicate_tap",
  "stale_or_out_of_order_event",
  "clock_skew",
  "role_revocation",
  "device_revocation",
  "partial_failure",
  "recovery",
];
requireCondition(
  qa04.status === "local_deterministic_resilience_contract_passed" &&
    qa04.focused_tests_passed >= 86 &&
    qa04.shared_or_live_session_claimed === false &&
    qa04.physical_device_claimed === false &&
    qa04.network_timing_claimed === false &&
    qa04.release_claimed === false,
  "GAME-QA-04 must preserve its exact deterministic local boundary",
);
requireCondition(
  JSON.stringify(qa04.required_scenarios) === JSON.stringify(qa04Scenarios),
  "GAME-QA-04 must retain all eleven ordered resilience scenarios",
);
requireCondition(
  resilienceMatrix.contract === "GAME-QA-04" &&
    JSON.stringify(resilienceMatrix.required_scenarios) ===
      JSON.stringify(qa04Scenarios) &&
    JSON.stringify(resilienceMatrix.scenarios?.map((scenario) => scenario.id)) ===
      JSON.stringify(qa04Scenarios),
  "GAME-QA-04 matrix must retain the eleven required scenarios",
);
requireCondition(
  resilienceMatrix.environment_boundary?.deterministic_local_tests === true &&
    resilienceMatrix.environment_boundary?.shared_or_live_session_claimed === false &&
    resilienceMatrix.environment_boundary?.physical_device_claimed === false &&
    resilienceMatrix.environment_boundary?.network_timing_claimed === false &&
    resilienceMatrix.environment_boundary?.release_claimed === false,
  "GAME-QA-04 matrix must remain fail-closed for live, device, timing and release claims",
);
for (const scenario of resilienceMatrix.scenarios ?? []) {
  requireCondition(
    typeof scenario.assertion === "string" && scenario.assertion.length > 0,
    `GAME-QA-04 ${scenario.id} must retain an explicit assertion`,
  );
  requireCondition(
    Array.isArray(scenario.tests) && scenario.tests.length > 0,
    `GAME-QA-04 ${scenario.id} must retain executable test evidence`,
  );
  for (const test of scenario.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        test.name.length > 0 &&
        resilienceTestSources.get(test.path)?.includes(test.name),
      `GAME-QA-04 ${scenario.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
const qa05 = contract.quality_contract?.["GAME-QA-05"] ?? {};
const qa05Clauses = [
  "resolution_layout_720_1080_4k",
  "overscan_safe_area",
  "long_copy_locales",
  "text_scaling_200_percent",
  "light_and_dark_themes",
  "focus_and_dpad",
  "reduced_motion",
  "screen_reader_semantics",
  "automated_privacy_boundary",
  "native_current_resolution_captures",
  "physical_tv_assistive_technology",
  "burn_in_soak",
  "accountable_privacy_review",
];
requireCondition(
  qa05.status ===
      "local_deterministic_and_native_emulator_subset_passed_external_evidence_open" &&
    qa05.focused_tests_passed >= 55 &&
    qa05.criterion_complete === false &&
    qa05.native_current_1080p_capture_claimed === true &&
    qa05.native_current_4k_capture_claimed === true &&
    qa05.physical_tv_claimed === false &&
    qa05.four_hour_burn_in_claimed === false &&
    qa05.accountable_privacy_approval_claimed === false &&
    qa05.shared_or_live_session_claimed === false &&
    qa05.release_claimed === false,
  "GAME-QA-05 must retain its partial local boundary and remain open",
);
requireCondition(
  JSON.stringify(qa05.required_clauses) === JSON.stringify(qa05Clauses),
  "GAME-QA-05 must retain all thirteen ordered clauses",
);
requireCondition(
  tvAccessibilityMatrix.contract === "GAME-QA-05" &&
    tvAccessibilityMatrix.status ===
      "local_deterministic_and_native_emulator_subset_passed_external_evidence_open" &&
    tvAccessibilityMatrix.criterion_complete === false &&
    JSON.stringify(tvAccessibilityMatrix.required_clauses) ===
      JSON.stringify(qa05Clauses) &&
    JSON.stringify(
      tvAccessibilityMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(qa05Clauses),
  "GAME-QA-05 matrix must retain the thirteen required clauses and remain open",
);
for (const clause of tvAccessibilityMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0,
    `GAME-QA-05 ${clause.id} must retain an explicit assertion`,
  );
  if (clause.status === "passed_local_deterministic") {
    requireCondition(
      Array.isArray(clause.tests) && clause.tests.length > 0,
      `GAME-QA-05 ${clause.id} must retain executable local evidence`,
    );
  } else if (clause.status === "passed_current_native_emulator") {
    requireCondition(
      clause.id === "native_current_resolution_captures" &&
        Array.isArray(clause.tests) &&
        clause.tests.length === 0,
      "GAME-QA-05 native capture clause must be backed by governed emulator artifacts rather than widget tests",
    );
  } else {
    requireCondition(
      clause.status === "open_external_evidence" ||
        clause.status === "open_protected_approval",
      `GAME-QA-05 ${clause.id} must remain explicitly open`,
    );
  }
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        test.name.length > 0 &&
        tvAccessibilityTestSources.get(test.path)?.includes(test.name),
      `GAME-QA-05 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of tvAccessibilityMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-QA-05 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  tvAccessibilityMatrix.deterministic_golden_evidence?.length === 7,
  "GAME-QA-05 must retain all seven deterministic 720p goldens",
);
const qa05NativeEvidence =
  tvAccessibilityMatrix.native_current_resolution_evidence ?? [];
requireCondition(
  qa05NativeEvidence.length === 2 &&
    qa05NativeEvidence[0]?.width === 1920 &&
    qa05NativeEvidence[0]?.height === 1080 &&
    qa05NativeEvidence[0]?.sha256 ===
      "275cc7db17f80782b1bc7a9c6f74de899eb384d9bd5cf3a890cd66da1f0ef367" &&
    qa05NativeEvidence[1]?.width === 3840 &&
    qa05NativeEvidence[1]?.height === 2160 &&
    qa05NativeEvidence[1]?.sha256 ===
      "a39008291791495c1a4c565809cff67feac840e31ca05fc32811147eec01da91",
  "GAME-QA-05 must retain exact current native emulator resolution evidence",
);
for (const evidence of qa05NativeEvidence) {
  requireCondition(
    await pathExists(new URL(`../../${evidence.path}`, import.meta.url)),
    `GAME-QA-05 must retain native capture ${evidence.path}`,
  );
}
const qa05Boundary = tvAccessibilityMatrix.environment_boundary ?? {};
requireCondition(
  qa05Boundary.deterministic_local_tests === true &&
    qa05Boundary.flutter_golden_720p_claimed === true &&
    qa05Boundary.native_current_1080p_capture_claimed === true &&
    qa05Boundary.native_current_4k_capture_claimed === true &&
    qa05Boundary.physical_tv_claimed === false &&
    qa05Boundary.physical_overscan_claimed === false &&
    qa05Boundary.physical_remote_claimed === false &&
    qa05Boundary.physical_screen_reader_claimed === false &&
    qa05Boundary.four_hour_burn_in_claimed === false &&
    qa05Boundary.accountable_privacy_approval_claimed === false &&
    qa05Boundary.shared_or_live_session_claimed === false &&
    qa05Boundary.release_claimed === false,
  "GAME-QA-05 matrix must retain native emulator evidence and fail closed for physical, soak, approval, live, and release claims",
);
const qa06 = contract.quality_contract?.["GAME-QA-06"] ?? {};
const qa06Clauses = [
  "clean_controlled_candidate_and_pinned_ci",
  "mobile_ios_release_build",
  "mobile_android_release_aab",
  "native_tv_release_apk",
  "web_typecheck_lint_tests_and_build",
  "physical_device_uat",
  "production_signing_and_store_processing",
  "authorized_backend_migration_and_rollback",
  "named_accountable_approvals",
];
requireCondition(
  qa06.status ===
      "exact_current_dirty_local_build_subset_passed_external_release_evidence_open" &&
    qa06.local_build_clauses_passed === 4 &&
    qa06.physical_ios_install_and_launch_partial === true &&
    qa06.criterion_complete === false &&
    qa06.clean_candidate_claimed === false &&
    qa06.pinned_ci_claimed === false &&
    qa06.full_physical_uat_claimed === false &&
    qa06.production_signing_claimed === false &&
    qa06.store_processing_claimed === false &&
    qa06.authorized_target_migration_and_rollback_claimed === false &&
    qa06.named_approvals_claimed === false &&
    qa06.release_claimed === false,
  "GAME-QA-06 must retain its exact-current local build subset and external release boundary",
);
requireCondition(
  JSON.stringify(qa06.required_clauses) === JSON.stringify(qa06Clauses) &&
    exactCandidateMatrix.contract === "GAME-QA-06" &&
    exactCandidateMatrix.status === qa06.status &&
    exactCandidateMatrix.criterion_complete === false &&
    JSON.stringify(exactCandidateMatrix.required_clauses) ===
      JSON.stringify(qa06Clauses) &&
    JSON.stringify(exactCandidateMatrix.clauses?.map((clause) => clause.id)) ===
      JSON.stringify(qa06Clauses),
  "GAME-QA-06 matrix must retain all nine ordered clauses and remain open",
);
const qa06AllowedStatuses = new Set([
  "passed_exact_current_local_dry_run",
  "partial_physical_ios_install_and_launch",
  "open_external_evidence",
  "open_protected_approval",
]);
for (const clause of exactCandidateMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" &&
      clause.assertion.length > 0 &&
      qa06AllowedStatuses.has(clause.status),
    `GAME-QA-06 ${clause.id} must retain an explicit assertion and governed status`,
  );
  if (
    clause.status === "passed_exact_current_local_dry_run" ||
    clause.status === "partial_physical_ios_install_and_launch"
  ) {
    requireCondition(
      typeof clause.evidence === "string" &&
        await pathExists(new URL(`../../${clause.evidence}`, import.meta.url)),
      `GAME-QA-06 ${clause.id} must retain its local evidence checkpoint`,
    );
  }
}
const qa06Boundary = exactCandidateMatrix.environment_boundary ?? {};
requireCondition(
  qa06Boundary.dirty_working_candidate === true &&
    qa06Boundary.pinned_ci_claimed === false &&
    qa06Boundary.ios_unsigned_release_build_claimed === true &&
    qa06Boundary.android_ephemeral_signed_aab_claimed === true &&
    qa06Boundary.native_tv_ephemeral_signed_apk_claimed === true &&
    qa06Boundary.web_production_build_claimed === true &&
    qa06Boundary.physical_ios_install_and_launch_claimed === true &&
    qa06Boundary.full_physical_uat_claimed === false &&
    qa06Boundary.production_signing_claimed === false &&
    qa06Boundary.store_processing_claimed === false &&
    qa06Boundary.authorized_target_migration_and_rollback_claimed === false &&
    qa06Boundary.named_approvals_claimed === false &&
    qa06Boundary.release_claimed === false,
  "GAME-QA-06 must fail closed for clean candidate, CI, full device, signing, store, backend target, approval, and release claims",
);
const mob05 = contract.quality_contract?.["GAME-MOB-05"] ?? {};
const mob05Clauses = [
  "safe_area_full_screen_no_bottom_nav",
  "compact_layout",
  "keyboard_inset",
  "text_scaling_200_percent",
  "light_dark",
  "reduced_motion",
  "permission_denial",
  "offline_retention",
  "reconnect_last_update",
  "timeout",
  "exact_visual_evidence",
];
requireCondition(
  mob05.status === "local_source_visual_and_accessibility_contract_passed" &&
    mob05.focused_tests_passed >= 37 &&
    mob05.governed_goldens === 4 &&
    mob05.criterion_complete === true &&
    mob05.shared_or_live_session_claimed === false &&
    mob05.physical_device_claimed === false &&
    mob05.physical_assistive_technology_claimed === false &&
    mob05.network_timing_claimed === false &&
    mob05.accountable_human_approval_claimed === false &&
    mob05.release_claimed === false,
  "GAME-MOB-05 must preserve its exact local completion and external fail-closed boundary",
);
requireCondition(
  JSON.stringify(mob05.required_clauses) === JSON.stringify(mob05Clauses),
  "GAME-MOB-05 must retain all eleven ordered participant-layout clauses",
);
requireCondition(
  participantLayoutMatrix.contract === "GAME-MOB-05" &&
    participantLayoutMatrix.status ===
      "local_source_visual_and_accessibility_contract_passed" &&
    participantLayoutMatrix.criterion_complete === true &&
    JSON.stringify(participantLayoutMatrix.required_clauses) ===
      JSON.stringify(mob05Clauses) &&
    JSON.stringify(
      participantLayoutMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(mob05Clauses),
  "GAME-MOB-05 matrix must retain the eleven required clauses",
);
for (const clause of participantLayoutMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0,
    `GAME-MOB-05 ${clause.id} must retain an explicit assertion`,
  );
  requireCondition(
    Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-MOB-05 ${clause.id} must retain executable test evidence`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        test.name.length > 0 &&
        participantLayoutTestSources.get(test.path)?.includes(test.name),
      `GAME-MOB-05 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of participantLayoutMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-MOB-05 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  participantLayoutMatrix.deterministic_golden_evidence?.length === 4,
  "GAME-MOB-05 must retain all four exact current-source goldens",
);
const mob05Boundary = participantLayoutMatrix.environment_boundary ?? {};
requireCondition(
  mob05Boundary.deterministic_local_tests === true &&
    mob05Boundary.current_source_goldens_claimed === true &&
    mob05Boundary.shared_or_live_session_claimed === false &&
    mob05Boundary.physical_device_claimed === false &&
    mob05Boundary.physical_assistive_technology_claimed === false &&
    mob05Boundary.network_timing_claimed === false &&
    mob05Boundary.accountable_human_approval_claimed === false &&
    mob05Boundary.release_claimed === false,
  "GAME-MOB-05 matrix must fail closed for live, device, AT, timing, approval, and release claims",
);
const mob04 = contract.quality_contract?.["GAME-MOB-04"] ?? {};
const mob04Clauses = [
  "network_change",
  "missed_event",
  "foreground_resume",
  "session_version_conflict",
  "retained_safe_state",
  "reconnect_last_update",
  "privacy_safe_recovery",
];
requireCondition(
  mob04.status ===
      "local_deterministic_reconnect_and_lifecycle_recovery_passed" &&
    mob04.focused_tests_passed >= 67 &&
    mob04.governed_goldens === 1 &&
    mob04.criterion_complete === true &&
    mob04.shared_or_live_session_claimed === false &&
    mob04.physical_device_claimed === false &&
    mob04.network_timing_claimed === false &&
    mob04.accountable_human_approval_claimed === false &&
    mob04.release_claimed === false,
  "GAME-MOB-04 must preserve its local recovery completion and external fail-closed boundary",
);
requireCondition(
  JSON.stringify(mob04.required_clauses) === JSON.stringify(mob04Clauses) &&
    participantRecoveryMatrix.contract === "GAME-MOB-04" &&
    participantRecoveryMatrix.criterion_complete === true &&
    JSON.stringify(participantRecoveryMatrix.required_clauses) ===
      JSON.stringify(mob04Clauses) &&
    JSON.stringify(
      participantRecoveryMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(mob04Clauses),
  "GAME-MOB-04 matrix must retain the seven ordered recovery clauses",
);
for (const clause of participantRecoveryMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-MOB-04 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        participantRecoveryTestSources.get(test.path)?.includes(test.name),
      `GAME-MOB-04 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of participantRecoveryMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-MOB-04 must retain golden ${goldenPath}`,
  );
}
const mob04Boundary = participantRecoveryMatrix.environment_boundary ?? {};
requireCondition(
  participantRecoveryMatrix.deterministic_golden_evidence?.length === 1 &&
    mob04Boundary.deterministic_local_tests === true &&
    mob04Boundary.current_source_golden_claimed === true &&
    mob04Boundary.shared_or_live_session_claimed === false &&
    mob04Boundary.physical_device_claimed === false &&
    mob04Boundary.network_timing_claimed === false &&
    mob04Boundary.accountable_human_approval_claimed === false &&
    mob04Boundary.release_claimed === false,
  "GAME-MOB-04 matrix must fail closed for live, device, timing, approval, and release claims",
);
const mob03 = contract.quality_contract?.["GAME-MOB-03"] ?? {};
const mob03Clauses = [
  "authorized_club_session_subscription",
  "invalidation_hint_only",
  "authoritative_versioned_projection_fetch",
  "stale_and_out_of_order_rejection",
  "server_deadline_authority",
  "client_scoring_and_phase_advance_prohibited",
  "subscription_close_recovery_and_cleanup",
];
requireCondition(
  mob03.status === "local_authoritative_participant_synchronization_passed" &&
    mob03.focused_tests_passed >= 68 &&
    mob03.criterion_complete === true &&
    mob03.shared_or_live_session_claimed === false &&
    mob03.physical_device_claimed === false &&
    mob03.real_network_timing_claimed === false &&
    mob03.accountable_human_approval_claimed === false &&
    mob03.release_claimed === false,
  "GAME-MOB-03 must preserve its local synchronization completion and external fail-closed boundary",
);
requireCondition(
  JSON.stringify(mob03.required_clauses) === JSON.stringify(mob03Clauses) &&
    participantSyncMatrix.contract === "GAME-MOB-03" &&
    participantSyncMatrix.status ===
      "local_authoritative_participant_synchronization_passed" &&
    participantSyncMatrix.criterion_complete === true &&
    JSON.stringify(participantSyncMatrix.required_clauses) ===
      JSON.stringify(mob03Clauses) &&
    JSON.stringify(participantSyncMatrix.clauses?.map((clause) => clause.id)) ===
      JSON.stringify(mob03Clauses),
  "GAME-MOB-03 matrix must retain the seven ordered synchronization clauses",
);
for (const clause of participantSyncMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-MOB-03 ${clause.id} must retain an assertion and executable or database-contract tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        participantSyncTestSources.get(test.path)?.includes(test.name),
      `GAME-MOB-03 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const requiredSource of [
  "_requirePositiveClubId",
  "_requireUuid",
  "get_participant_game_projection_v2",
  "participant-game:$topic",
  "schema: 'africlub_game'",
  "table: 'game_events'",
  "column: 'topic'",
  "RealtimeSubscribeStatus.channelError",
  "RealtimeSubscribeStatus.timedOut",
  "RealtimeSubscribeStatus.closed",
  "removeChannel(active)",
  "submit_participant_answer_v2",
  "p_expected_session_version",
  "p_expected_question_version",
]) {
  requireCondition(
    participantRepository.includes(requiredSource),
    `GAME-MOB-03 participant gateway must retain ${requiredSource}`,
  );
}
for (const prohibitedClientAuthority of [
  "transition_managed_game_session_v2",
  "settle_game_session",
  "score_game_session",
]) {
  requireCondition(
    !participantRepository.includes(prohibitedClientAuthority) &&
      !participantSynchronizer.includes(prohibitedClientAuthority),
    `GAME-MOB-03 participant synchronization must not own ${prohibitedClientAuthority}`,
  );
}
requireCondition(
  participantSynchronizer.includes(
    "deadline.difference(projection.version.serverTime)",
  ),
  "GAME-MOB-03 recovery timing must derive from authoritative server time",
);
const mob03Boundary = participantSyncMatrix.environment_boundary ?? {};
requireCondition(
  mob03Boundary.deterministic_local_tests === true &&
    mob03Boundary.isolated_database_contract_present === true &&
    mob03Boundary.shared_or_live_session_claimed === false &&
    mob03Boundary.physical_device_claimed === false &&
    mob03Boundary.real_network_timing_claimed === false &&
    mob03Boundary.accountable_human_approval_claimed === false &&
    mob03Boundary.release_claimed === false,
  "GAME-MOB-03 matrix must fail closed for shared/live, device, network, approval, and release claims",
);
const mob01 = contract.quality_contract?.["GAME-MOB-01"] ?? {};
const mob01Clauses = [
  "code_free_authoritative_feed",
  "governed_eligibility_sources",
  "live_and_scheduled_separation",
  "validated_deep_link",
  "validated_push_notification",
  "ineligible_stale_and_private_data_rejection",
  "legacy_join_excluded_from_participant_entry",
];
requireCondition(
  mob01.status === "local_code_free_eligible_game_discovery_passed" &&
    mob01.focused_tests_passed >= 63 &&
    mob01.isolated_database_contract_checks_passed === 77 &&
    mob01.criterion_complete === true &&
    mob01.shared_or_live_session_claimed === false &&
    mob01.physical_device_claimed === false &&
    mob01.platform_notification_delivery_claimed === false &&
    mob01.real_network_timing_claimed === false &&
    mob01.accountable_human_approval_claimed === false &&
    mob01.release_claimed === false,
  "GAME-MOB-01 must preserve its local discovery completion and external fail-closed boundary",
);
requireCondition(
  JSON.stringify(mob01.required_clauses) === JSON.stringify(mob01Clauses) &&
    participantDiscoveryMatrix.contract === "GAME-MOB-01" &&
    participantDiscoveryMatrix.status ===
      "local_code_free_eligible_game_discovery_passed" &&
    participantDiscoveryMatrix.criterion_complete === true &&
    JSON.stringify(participantDiscoveryMatrix.required_clauses) ===
      JSON.stringify(mob01Clauses) &&
    JSON.stringify(
      participantDiscoveryMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(mob01Clauses),
  "GAME-MOB-01 matrix must retain the seven ordered discovery clauses",
);
for (const clause of participantDiscoveryMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-MOB-01 ${clause.id} must retain an assertion and executable or database-contract tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        participantDiscoveryTestSources.get(test.path)?.includes(test.name),
      `GAME-MOB-01 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const requiredSource of [
  "FirebaseMessaging.onMessageOpenedApp",
  "getInitialMessage()",
  "PushNotificationRouteParser.parse",
  "type != 'live_game'",
  "'/fanzone/game/$sessionId'",
]) {
  requireCondition(
    pushNotificationService.includes(requiredSource),
    `GAME-MOB-01 push routing must retain ${requiredSource}`,
  );
}
for (const requiredSource of [
  "PushNotificationService.openedRoutes",
  "notificationRouteStream",
  "_handleNotificationRoute",
  "InternalRouteUriPolicy.validate",
]) {
  requireCondition(
    coreApp.includes(requiredSource),
    `GAME-MOB-01 app routing must retain ${requiredSource}`,
  );
}
const discoveryFunctionSource = sourceBetween(
  "create or replace function public.get_eligible_game_sessions_v2(",
  "create or replace function public.get_participant_game_projection_v2(",
);
for (const requiredSource of [
  "'club_membership'",
  "'invitation'",
  "'home_owner'",
  "'venue'",
  "'deep_link'",
]) {
  requireCondition(
    discoveryFunctionSource.includes(requiredSource),
    `GAME-MOB-01 discovery RPC must retain ${requiredSource}`,
  );
}
for (const prohibitedCode of ["'join_code'", "'tv_code'", "'pairing_code'"]) {
  requireCondition(
    !discoveryFunctionSource.includes(prohibitedCode),
    `GAME-MOB-01 participant discovery must not expose ${prohibitedCode}`,
  );
}
const mob01Boundary = participantDiscoveryMatrix.environment_boundary ?? {};
requireCondition(
  mob01Boundary.deterministic_local_tests === true &&
    mob01Boundary.isolated_database_contract_executed === true &&
    mob01Boundary.shared_or_live_session_claimed === false &&
    mob01Boundary.physical_device_claimed === false &&
    mob01Boundary.platform_notification_delivery_claimed === false &&
    mob01Boundary.real_network_timing_claimed === false &&
    mob01Boundary.accountable_human_approval_claimed === false &&
    mob01Boundary.release_claimed === false,
  "GAME-MOB-01 matrix must fail closed for live, device, notification-delivery, network, approval, and release claims",
);
const mob02 = contract.quality_contract?.["GAME-MOB-02"] ?? {};
const mob02Clauses = [
  "fan_zone_live_games_identity",
  "participant_join_source_removed",
  "session_id_only_participant_action",
  "code_free_participant_routes",
  "retired_participant_localization",
  "owner_my_tvs_pairing_preserved",
  "pairing_excluded_from_participant_data",
];
requireCondition(
  mob02.status === "local_participant_tv_code_retirement_passed" &&
    mob02.focused_flutter_tests_passed >= 98 &&
    mob02.focused_web_tests_passed >= 42 &&
    mob02.source_files_removed === 11 &&
    mob02.governed_fanzone_goldens === 20 &&
    mob02.changed_goldens_reviewed === 4 &&
    mob02.criterion_complete === true &&
    mob02.shared_or_live_session_claimed === false &&
    mob02.physical_device_claimed === false &&
    mob02.platform_notification_delivery_claimed === false &&
    mob02.real_network_timing_claimed === false &&
    mob02.accountable_human_approval_claimed === false &&
    mob02.release_claimed === false,
  "GAME-MOB-02 must preserve its local retirement completion and external fail-closed boundary",
);
requireCondition(
  JSON.stringify(mob02.required_clauses) === JSON.stringify(mob02Clauses) &&
    participantCodeRetirementMatrix.contract === "GAME-MOB-02" &&
    participantCodeRetirementMatrix.status ===
      "local_participant_tv_code_retirement_passed" &&
    participantCodeRetirementMatrix.criterion_complete === true &&
    JSON.stringify(participantCodeRetirementMatrix.required_clauses) ===
      JSON.stringify(mob02Clauses) &&
    JSON.stringify(
      participantCodeRetirementMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(mob02Clauses),
  "GAME-MOB-02 matrix must retain the seven ordered retirement clauses",
);
for (const clause of participantCodeRetirementMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-MOB-02 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        participantCodeRetirementTestSources
          .get(test.path)
          ?.includes(test.name),
      `GAME-MOB-02 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const retiredPath of participantCodeRetirementMatrix.retired_source_paths ?? []) {
  requireCondition(
    !(await pathExists(new URL(`../../${retiredPath}`, import.meta.url))),
    `GAME-MOB-02 retired source must remain absent: ${retiredPath}`,
  );
}
requireCondition(
  participantCodeRetirementMatrix.retired_source_paths?.length === 11,
  "GAME-MOB-02 must retain all eleven retired source paths",
);
requireCondition(
  fanzoneHubWidgets.includes("gameLiveGamesTitle") &&
    !fanzoneHubWidgets.includes("gameTvCode"),
  "GAME-MOB-02 Fan Zone must present Live games without a TV Code action",
);
requireCondition(
  fanzoneModule.includes("const ParticipantLiveGamesScreen()") &&
    fanzoneModule.includes("ParticipantLiveGamesScreen(") &&
    !fanzoneModule.includes("GameSessionJoinScreen") &&
    !fanzoneModule.includes("GameSessionControllerScreen"),
  "GAME-MOB-02 participant routes must remain code-free V2 routes",
);
requireCondition(
  !gamificationBarrel.includes("game_session_providers") &&
    !gamificationBarrel.includes("game_session_models"),
  "GAME-MOB-02 must not re-export the retired participant stack",
);
const joinSessionActionSource = sourceBetweenIn(
  gameSessionAction,
  'if (action === "join_session")',
  'if (action === "submit_answer")',
);
requireCondition(
  joinSessionActionSource.includes(
    'requireUuid(body.session_id, "session_id")',
  ) &&
    !joinSessionActionSource.includes("join_code") &&
    !gameSessionAction.includes("optionalJoinCode") &&
    !gameSessionAction.includes("join_code") &&
    !adminGameRuntime.includes("join_code") &&
    !adminGameActionRoute.includes("join_code"),
  "GAME-MOB-02 participant action must accept only a validated session UUID",
);
for (const retiredKey of [
  '"gameTvCode"',
  '"gameSelectedJoinMethodTvCode"',
  '"gameTvCodeUpper"',
  '"gameTvCodeInstructions"',
  '"gameSessionCode"',
  '"gameSessionCodeRequired"',
  '"gameSessionCodeInvalid"',
]) {
  requireCondition(
    participantArbSources.every((source) => !source.includes(retiredKey)),
    `GAME-MOB-02 participant catalogs must omit ${retiredKey}`,
  );
}
requireCondition(
  gameOperationsModule.includes("path: '/my-tvs'") &&
    gameOperationsModule.includes("path: 'pair'") &&
    gameOperationsModule.includes("PairTvScreen(") &&
    pairTvScreen.includes("initialChallenge") &&
    pairTvScreen.includes("challenge.length != 8") &&
    pairTvScreen.includes("claim(") &&
    !gameSessionAction.includes('"pair_tv_device"') &&
    !gameSessionAction.includes("pairing_code") &&
    !adminGameRuntime.includes("pair_tv_device") &&
    !adminGameRuntime.includes("pairing_code") &&
    !adminGameActionRoute.includes('"pair_tv_device"') &&
    !adminGameActionRoute.includes("pairing_code"),
  "GAME-MOB-02 must preserve the owner-only My TVs pairing challenge",
);
const mob02Boundary = participantCodeRetirementMatrix.environment_boundary ?? {};
requireCondition(
  mob02Boundary.deterministic_local_tests === true &&
    mob02Boundary.static_source_contract === true &&
    mob02Boundary.current_fanzone_visual_comparison === true &&
    mob02Boundary.shared_or_live_session_claimed === false &&
    mob02Boundary.physical_device_claimed === false &&
    mob02Boundary.platform_notification_delivery_claimed === false &&
    mob02Boundary.real_network_timing_claimed === false &&
    mob02Boundary.accountable_human_approval_claimed === false &&
    mob02Boundary.release_claimed === false,
  "GAME-MOB-02 matrix must fail closed for live, device, delivery, timing, approval, and release claims",
);
const org01 = contract.quality_contract?.["GAME-ORG-01"] ?? {};
const org01Clauses = [
  "role_gated_managed_games",
  "approved_pack_selection",
  "bounded_schedule",
  "eligibility_and_invitations",
  "approved_display_assignment",
  "activation_and_start",
  "authoritative_supervision",
  "governed_completion",
];
requireCondition(
  org01.status === "local_organizer_planning_and_control_passed" &&
    org01.focused_flutter_tests_passed >= 36 &&
    org01.isolated_database_contract_checks_passed >= 80 &&
    org01.governed_goldens === 1 &&
    org01.criterion_complete === true &&
    org01.shared_or_live_session_claimed === false &&
    org01.physical_device_claimed === false &&
    org01.real_network_timing_claimed === false &&
    org01.accountable_human_approval_claimed === false &&
    org01.release_claimed === false,
  "GAME-ORG-01 must preserve local organizer completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(org01.required_clauses) === JSON.stringify(org01Clauses) &&
    organizerPlanningMatrix.contract === "GAME-ORG-01" &&
    organizerPlanningMatrix.status ===
      "local_organizer_planning_and_control_passed" &&
    organizerPlanningMatrix.criterion_complete === true &&
    JSON.stringify(organizerPlanningMatrix.required_clauses) ===
      JSON.stringify(org01Clauses) &&
    JSON.stringify(
      organizerPlanningMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(org01Clauses),
  "GAME-ORG-01 matrix must retain the eight ordered organizer clauses",
);
for (const clause of organizerPlanningMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-ORG-01 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        organizerPlanningTestSources.get(test.path)?.includes(test.name),
      `GAME-ORG-01 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of organizerPlanningMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-ORG-01 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  organizerPlanningMatrix.deterministic_golden_evidence?.length === 1,
  "GAME-ORG-01 must retain one exact current-source organizer golden",
);
const org01Boundary = organizerPlanningMatrix.environment_boundary ?? {};
requireCondition(
  org01Boundary.deterministic_local_tests === true &&
    org01Boundary.static_source_contract === true &&
    org01Boundary.isolated_database_contract_executed === true &&
    org01Boundary.current_visual_comparison === true &&
    org01Boundary.shared_or_live_session_claimed === false &&
    org01Boundary.physical_device_claimed === false &&
    org01Boundary.real_network_timing_claimed === false &&
    org01Boundary.accountable_human_approval_claimed === false &&
    org01Boundary.release_claimed === false,
  "GAME-ORG-01 matrix must fail closed for live, device, timing, approval, and release claims",
);
for (const required of [
  "invitation_only",
  "planner-invitee-",
  "inviteeUserIds",
  "gameInviteesRequiredDescription",
]) {
  requireCondition(
    sessionPlannerScreen.includes(required),
    `GAME-ORG-01 planner must implement ${required}`,
  );
}
requireCondition(
  gameOperationsRepository.includes("p_invitee_user_ids") &&
    gameOperationsControllers.includes("inviteeUserIds") &&
    gameOperationsControllers.includes("..sort()"),
  "GAME-ORG-01 invitation intent must be normalized and forwarded to the authoritative RPC",
);
const plannerOptionsSource = sourceBetween(
  "create or replace function public.get_game_planner_options_v2()",
  "create or replace function public.create_managed_game_session_v2(",
);
for (const required of [
  "africlub_game.can_plan_games(v_club_id)",
  "pack.status = 'published'",
  ") = 20",
  "display.status = 'paired'",
  "'invitees', v_invitees",
  "'invitation_only'",
  "membership.status = 'active'",
  "membership.payment_status = 'verified'::public.payment_status",
  "membership.expires_at > timezone('utc', now())",
  "limit 100",
]) {
  requireCondition(
    plannerOptionsSource.includes(required),
    `GAME-ORG-01 planner options must enforce ${required}`,
  );
}
const inviteeProjectionSource = sourceBetweenIn(
  plannerOptionsSource,
  "'user_id', invitee.user_id::text",
  ") invitee;",
);
requireCondition(
  inviteeProjectionSource.includes("'display_name'") &&
    inviteeProjectionSource.includes("'public_user_id'") &&
    !inviteeProjectionSource.includes("'phone'") &&
    !inviteeProjectionSource.includes("'email'") &&
    !inviteeProjectionSource.includes("'full_name'"),
  "GAME-ORG-01 invitee projection must expose only privacy-safe Fan-ID identity",
);
const managedCreationSource = sourceBetween(
  "create or replace function public.create_managed_game_session_v2(",
  "create or replace function public.transition_managed_game_session_v2(",
);
for (const required of [
  "p_invitee_user_ids uuid[]",
  "Invitation-only sessions require at least one supporter",
  "Selected invitee is not an eligible club supporter",
  "insert into africlub_game.session_invitations",
  "'invitation'",
  "'invitee_count'",
  "Published question pack must contain exactly 20 questions",
  "africlub_game.assign_display_v2",
]) {
  requireCondition(
    managedCreationSource.includes(required),
    `GAME-ORG-01 managed creation must enforce ${required}`,
  );
}
const org02 = contract.quality_contract?.["GAME-ORG-02"] ?? {};
const org02Clauses = [
  "single_normal_next_transition",
  "separated_exception_controls",
  "reasoned_skip",
  "reasoned_early_end",
  "pause_resume_authority",
  "stale_duplicate_lockout",
  "audit_backed_recovery",
];
requireCondition(
  org02.status === "local_guarded_organizer_operations_passed" &&
    org02.focused_flutter_tests_passed >= 45 &&
    org02.isolated_database_contract_checks_passed >= 80 &&
    org02.governed_goldens === 1 &&
    org02.criterion_complete === true &&
    org02.shared_or_live_session_claimed === false &&
    org02.physical_device_claimed === false &&
    org02.real_network_timing_claimed === false &&
    org02.accountable_human_approval_claimed === false &&
    org02.release_claimed === false,
  "GAME-ORG-02 must preserve guarded local completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(org02.required_clauses) === JSON.stringify(org02Clauses) &&
    organizerGuardedOperationsMatrix.contract === "GAME-ORG-02" &&
    organizerGuardedOperationsMatrix.status ===
      "local_guarded_organizer_operations_passed" &&
    organizerGuardedOperationsMatrix.criterion_complete === true &&
    JSON.stringify(organizerGuardedOperationsMatrix.required_clauses) ===
      JSON.stringify(org02Clauses) &&
    JSON.stringify(
      organizerGuardedOperationsMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(org02Clauses),
  "GAME-ORG-02 matrix must retain the seven ordered guarded-operation clauses",
);
for (const clause of organizerGuardedOperationsMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-ORG-02 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        organizerGuardedOperationsTestSources
          .get(test.path)
          ?.includes(test.name),
      `GAME-ORG-02 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of organizerGuardedOperationsMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-ORG-02 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  organizerGuardedOperationsMatrix.deterministic_golden_evidence?.length === 1,
  "GAME-ORG-02 must retain one exact current-source guarded-control golden",
);
const org02Boundary = organizerGuardedOperationsMatrix.environment_boundary ?? {};
requireCondition(
  org02Boundary.deterministic_local_tests === true &&
    org02Boundary.static_source_contract === true &&
    org02Boundary.isolated_database_contract_executed === true &&
    org02Boundary.current_visual_comparison === true &&
    org02Boundary.shared_or_live_session_claimed === false &&
    org02Boundary.physical_device_claimed === false &&
    org02Boundary.real_network_timing_claimed === false &&
    org02Boundary.accountable_human_approval_claimed === false &&
    org02Boundary.release_claimed === false,
  "GAME-ORG-02 matrix must fail closed for live, device, timing, approval, and release claims",
);
for (const required of [
  "control-next-",
  "control-exception-",
  "gameNextAction",
  "gameExceptionActions",
  "controller.skipQuestion",
  "controller.endEarly",
  "control-exception-reason",
]) {
  requireCondition(
    liveGameControlScreen.includes(required),
    `GAME-ORG-02 live controls must implement ${required}`,
  );
}
for (const required of [
  "skip_managed_game_question_v2",
  "end_managed_game_session_v2",
  "p_expected_session_version",
  "p_idempotency_key",
  "p_reason",
]) {
  requireCondition(
    gameOperationsRepository.includes(required),
    `GAME-ORG-02 repository must preserve ${required}`,
  );
}
requireCondition(
  gameOperationsControllers.includes("phase == 'skip_question'") &&
    gameOperationsControllers.includes("phase == 'end_early'") &&
    gameOperationsControllers.includes("GameOperationsFailureKind.conflict") &&
    gameOperationsControllers.includes("nextSessionQuestionId") &&
    gameOperationsControllers.includes("normalizedReason.length < 3") &&
    gameOperationsModels.includes("question_controls") &&
    gameOperationsModels.includes("ManagedQuestionSummary? get nextQuestion"),
  "GAME-ORG-02 clients must block reasoned exceptions from ordinary transitions and fail closed on stale authority",
);
const skipManagedGameSource = sourceBetween(
  "create or replace function public.skip_managed_game_question_v2(",
  "create or replace function public.end_managed_game_session_v2(",
);
const endManagedGameSource = sourceBetween(
  "create or replace function public.end_managed_game_session_v2(",
  "create or replace function public.assign_managed_game_display_v2(",
);
for (const required of [
  "p_expected_session_version",
  "p_idempotency_key",
  "p_reason",
  "A different next session question is required",
  "A bounded skip reason is required",
  "'skip: ' || btrim(p_reason)",
]) {
  requireCondition(
    skipManagedGameSource.includes(required),
    `GAME-ORG-02 skip RPC must enforce ${required}`,
  );
}
for (const required of [
  "p_expected_session_version",
  "p_idempotency_key",
  "p_reason",
  "A bounded end reason is required",
  "'end: ' || btrim(p_reason)",
]) {
  requireCondition(
    endManagedGameSource.includes(required),
    `GAME-ORG-02 early-end RPC must enforce ${required}`,
  );
}
const own01 = contract.quality_contract?.["GAME-OWN-01"] ?? {};
const own01Clauses = [
  "role_scoped_inventory",
  "complete_display_projection",
  "connection_health_and_last_seen",
  "capabilities_and_app_version",
  "assigned_session_context",
  "safe_empty_denied_offline",
  "private_pairing_credential_exclusion",
];
requireCondition(
  own01.status === "local_owner_inventory_contract_passed" &&
    own01.focused_flutter_tests_passed >= 49 &&
    own01.isolated_database_contract_checks_passed >= 80 &&
    own01.governed_goldens === 1 &&
    own01.criterion_complete === true &&
    own01.shared_or_live_session_claimed === false &&
    own01.physical_device_claimed === false &&
    own01.real_network_timing_claimed === false &&
    own01.accountable_human_approval_claimed === false &&
    own01.release_claimed === false,
  "GAME-OWN-01 must preserve local owner-inventory completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(own01.required_clauses) === JSON.stringify(own01Clauses) &&
    ownerInventoryMatrix.contract === "GAME-OWN-01" &&
    ownerInventoryMatrix.status === "local_owner_inventory_contract_passed" &&
    ownerInventoryMatrix.criterion_complete === true &&
    JSON.stringify(ownerInventoryMatrix.required_clauses) ===
      JSON.stringify(own01Clauses) &&
    JSON.stringify(ownerInventoryMatrix.clauses?.map((clause) => clause.id)) ===
      JSON.stringify(own01Clauses),
  "GAME-OWN-01 matrix must retain the seven ordered owner-inventory clauses",
);
for (const clause of ownerInventoryMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" && clause.assertion.length > 0 &&
      Array.isArray(clause.tests) && clause.tests.length > 0,
    `GAME-OWN-01 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        ownerInventoryTestSources.get(test.path)?.includes(test.name),
      `GAME-OWN-01 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of ownerInventoryMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-OWN-01 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  ownerInventoryMatrix.deterministic_golden_evidence?.length === 1,
  "GAME-OWN-01 must retain one exact current-source owner-inventory golden",
);
const own01Boundary = ownerInventoryMatrix.environment_boundary ?? {};
requireCondition(
  own01Boundary.deterministic_local_tests === true &&
    own01Boundary.static_source_contract === true &&
    own01Boundary.isolated_database_contract_executed === true &&
    own01Boundary.current_visual_comparison === true &&
    own01Boundary.shared_or_live_session_claimed === false &&
    own01Boundary.physical_device_claimed === false &&
    own01Boundary.real_network_timing_claimed === false &&
    own01Boundary.accountable_human_approval_claimed === false &&
    own01Boundary.release_claimed === false,
  "GAME-OWN-01 matrix must fail closed for live, device, timing, approval, and release claims",
);
const ownedDisplaysSource = sourceBetween(
  "create or replace function public.get_owned_displays_v2()",
  "create or replace function public.update_owned_display_v2(",
);
for (const required of [
  "africlub_game.can_manage_display(display.id)",
  "'scope_type'",
  "'health'",
  "'last_seen_at'",
  "'app_version'",
  "'capabilities'",
  "'assigned_session'",
  "'session_id'",
  "'title'",
  "'phase'",
]) {
  requireCondition(
    ownedDisplaysSource.includes(required),
    `GAME-OWN-01 owner projection must preserve ${required}`,
  );
}
requireCondition(
  !ownedDisplaysSource.includes("device_credential") &&
    !ownedDisplaysSource.includes("pairing_code"),
  "GAME-OWN-01 owner projection must exclude credential and pairing material",
);
requireCondition(
  gameOperationsModels.includes("class OwnedAssignedSession") &&
    gameOperationsModels.includes("json['assigned_session']") &&
    gameOperationsModels.includes("_safeCapabilities") &&
    gameOperationsModels.includes("Invalid display capabilities") &&
    myTvsScreen.includes("gameTvLastSeen") &&
    myTvsScreen.includes("gameTvAppVersion") &&
    myTvsScreen.includes("gameTvCapabilities") &&
    myTvsScreen.includes("formattedAssignedSession") &&
    myTvsScreen.includes("gameTvInventoryStale") &&
    myTvsScreen.includes("enabled: state.canStartPairingOperation"),
  "GAME-OWN-01 client must render complete bounded inventory data and disable pairing while authority is stale",
);
requireCondition(
  pgTapContract.includes(
    "owner claim creates a complete scoped inventory item without pairing or credential material",
  ),
  "GAME-OWN-01 pgTAP must preserve the complete credential-free owner inventory assertion",
);
const own02 = contract.quality_contract?.["GAME-OWN-02"] ?? {};
const own02Clauses = [
  "qr_or_manual_bootstrap_entry",
  "authorized_named_scope_selection",
  "confirmed_audited_rename_and_move",
  "confirmed_audited_revocation",
  "bootstrap_credential_recovery",
  "idempotent_uncertain_mutation_lockout",
  "privacy_safe_pairing_material_boundary",
];
requireCondition(
  own02.status === "local_owner_pairing_and_management_contract_passed" &&
    own02.focused_flutter_tests_passed >= 57 &&
    own02.isolated_database_contract_checks_passed >= 80 &&
    own02.governed_goldens === 1 &&
    own02.criterion_complete === true &&
    own02.shared_or_live_session_claimed === false &&
    own02.physical_device_claimed === false &&
    own02.real_network_timing_claimed === false &&
    own02.accountable_human_approval_claimed === false &&
    own02.release_claimed === false,
  "GAME-OWN-02 must preserve local owner-management completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(own02.required_clauses) === JSON.stringify(own02Clauses) &&
    ownerManagementMatrix.contract === "GAME-OWN-02" &&
    ownerManagementMatrix.status ===
      "local_owner_pairing_and_management_contract_passed" &&
    ownerManagementMatrix.criterion_complete === true &&
    JSON.stringify(ownerManagementMatrix.required_clauses) ===
      JSON.stringify(own02Clauses) &&
    JSON.stringify(
      ownerManagementMatrix.clauses?.map((clause) => clause.id),
    ) === JSON.stringify(own02Clauses),
  "GAME-OWN-02 matrix must retain the seven ordered owner-management clauses",
);
for (const clause of ownerManagementMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" &&
      clause.assertion.length > 0 &&
      Array.isArray(clause.tests) &&
      clause.tests.length > 0,
    `GAME-OWN-02 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        ownerManagementTestSources.get(test.path)?.includes(test.name),
      `GAME-OWN-02 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of
  ownerManagementMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-OWN-02 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  ownerManagementMatrix.deterministic_golden_evidence?.length === 1,
  "GAME-OWN-02 must retain one exact current-source owner-management golden",
);
const own02Boundary = ownerManagementMatrix.environment_boundary ?? {};
requireCondition(
  own02Boundary.deterministic_local_tests === true &&
    own02Boundary.static_source_contract === true &&
    own02Boundary.isolated_database_contract_executed === true &&
    own02Boundary.current_visual_comparison === true &&
    own02Boundary.shared_or_live_session_claimed === false &&
    own02Boundary.physical_device_claimed === false &&
    own02Boundary.real_network_timing_claimed === false &&
    own02Boundary.accountable_human_approval_claimed === false &&
    own02Boundary.release_claimed === false,
  "GAME-OWN-02 matrix must fail closed for live, device, timing, approval, and release claims",
);
const updateOwnedDisplaySource = sourceBetween(
  "create or replace function public.update_owned_display_v2(",
  "create or replace function public.revoke_owned_display_v2(",
);
for (const required of [
  "venue.club_id = v_display.club_id",
  "venue.status = 'approved'",
  "array['owner', 'manager']",
  "'display_updated'",
  "operation_requests",
]) {
  requireCondition(
    updateOwnedDisplaySource.includes(required),
    `GAME-OWN-02 display update must enforce ${required}`,
  );
}
const recoverOwnedDisplaySource = sourceBetween(
  "create or replace function public.recover_owned_display_from_bootstrap_v2(",
  "create or replace function public.exchange_display_pairing_challenge_v2(",
);
for (const required of [
  "display_bootstrap_challenges",
  "africlub_game.can_manage_display(v_display.id)",
  "credential_token_hash = null",
  "'recovery_pending_tv_exchange'",
  "'display_recovery_started'",
  "operation_requests",
]) {
  requireCondition(
    recoverOwnedDisplaySource.includes(required),
    `GAME-OWN-02 recovery must enforce ${required}`,
  );
}
requireCondition(
  ownedDisplaysSource.includes("'scope_options'") &&
    ownedDisplaysSource.includes("venue.club_id = v_club_id") &&
    ownedDisplaysSource.includes("venue.status = 'approved'") &&
    ownedDisplaysSource.includes("array['owner', 'manager']"),
  "GAME-OWN-02 owner inventory must expose only named club-scoped authorized locations",
);
requireCondition(
  pairTvScreen.includes("gameTvAuthorizedScope") &&
    pairTvScreen.includes("recover-tv-confirm") &&
    !pairTvScreen.includes("issuePairingChallenge") &&
    tvDetailScreen.includes("tv-detail-save-confirm") &&
    tvDetailScreen.includes("tv-detail-revoke-confirm") &&
    tvDetailScreen.includes("recoverDisplayId") &&
    gameOperationsRepository.includes(
      "'recover_owned_display_from_bootstrap_v2'",
    ),
  "GAME-OWN-02 client must use named scope, confirmed management, and native-TV bootstrap recovery",
);
requireCondition(
  migration.includes(
    "drop function if exists public.issue_owned_display_pairing_challenge_v2(uuid)",
  ) &&
    migration.includes(
      "drop function if exists public.claim_display_pairing_challenge_v2(text,text,text,uuid)",
    ) &&
    migration.includes(
      "drop function if exists africlub_game.issue_display_pairing_challenge(uuid)",
    ) &&
    !gameOperationsRepository.includes(
      "issue_owned_display_pairing_challenge_v2",
    ),
  "GAME-OWN-02 must retire obsolete owner-issued pairing interfaces",
);
requireCondition(
  pgTapContract.includes(
    "owner rename, revocation, and credential recovery are idempotent and audited once",
  ) &&
    pgTapContract.includes("cross-club venue move unexpectedly succeeded"),
  "GAME-OWN-02 pgTAP must preserve audited recovery and cross-club move denial",
);
const tv02 = contract.quality_contract?.["GAME-TV-02"] ?? {};
const tv02Clauses = [
  "credential_bound_auth_identity",
  "assigned_session_subscription",
  "privacy_safe_invalidation_only",
  "ordered_event_delivery_and_authoritative_refresh",
  "unbound_identity_rls_filtering",
  "revocation_stops_delivery",
  "channel_failure_snapshot_recovery_and_bounded_polling",
];
requireCondition(
  tv02.status === "local_isolated_realtime_network_contract_passed" &&
    tv02.focused_flutter_tests_passed >= 58 &&
    tv02.isolated_database_contract_checks_passed >= 80 &&
    tv02.isolated_network_events_received === 5 &&
    tv02.isolated_network_local_p95_ms > 0 &&
    tv02.criterion_complete === true &&
    tv02.shared_or_live_session_claimed === false &&
    tv02.physical_tv_claimed === false &&
    tv02.real_network_timing_claimed === false &&
    tv02.packet_loss_or_wan_soak_claimed === false &&
    tv02.accountable_human_approval_claimed === false &&
    tv02.production_signing_or_store_claimed === false &&
    tv02.release_claimed === false,
  "GAME-TV-02 must preserve local isolated-network completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(tv02.required_clauses) === JSON.stringify(tv02Clauses) &&
    tvRealtimeMatrix.contract === "GAME-TV-02" &&
    tvRealtimeMatrix.status ===
      "local_isolated_realtime_network_contract_passed" &&
    tvRealtimeMatrix.criterion_complete === true &&
    JSON.stringify(tvRealtimeMatrix.required_clauses) ===
      JSON.stringify(tv02Clauses) &&
    JSON.stringify(tvRealtimeMatrix.clauses?.map((clause) => clause.id)) ===
      JSON.stringify(tv02Clauses),
  "GAME-TV-02 matrix must retain the seven ordered Realtime clauses",
);
for (const clause of tvRealtimeMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" &&
      clause.assertion.length > 0 &&
      Array.isArray(clause.tests) &&
      clause.tests.length > 0,
    `GAME-TV-02 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        tvRealtimeTestSources.get(test.path)?.includes(test.name),
      `GAME-TV-02 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
const tv02Evidence = tvRealtimeMatrix.isolated_network_evidence ?? {};
requireCondition(
  tv02Evidence.realtime_image ===
      "public.ecr.aws/supabase/realtime:v2.120.3" &&
    tv02Evidence.auth_issued_access_tokens === true &&
    tv02Evidence.authorized_events_received === 5 &&
    tv02Evidence.unbound_events_received === 0 &&
    JSON.stringify(tv02Evidence.ordered_sequences) ===
      JSON.stringify([1, 2, 3, 4, 5]) &&
    tv02Evidence.local_delivery_p95_ms === 542 &&
    tv02Evidence.revoked_event_delivered === false &&
    tv02Evidence.pgtap_checks_passed === 80,
  "GAME-TV-02 must retain the exact isolated Realtime execution evidence",
);
const tv02Boundary = tvRealtimeMatrix.environment_boundary ?? {};
requireCondition(
  tv02Boundary.isolated_local_network_execution === true &&
    tv02Boundary.shared_or_live_session_claimed === false &&
    tv02Boundary.physical_tv_claimed === false &&
    tv02Boundary.real_network_timing_claimed === false &&
    tv02Boundary.packet_loss_or_wan_soak_claimed === false &&
    tv02Boundary.accountable_human_approval_claimed === false &&
    tv02Boundary.production_signing_or_store_claimed === false &&
    tv02Boundary.release_claimed === false,
  "GAME-TV-02 matrix must fail closed for shared/live, physical-TV, WAN, approval, signing, store, and release claims",
);
for (const required of [
  "bindRealtimeIdentity(_credential!)",
  "watchInvalidations(clubId: projection.clubId, sessionId: sessionId)",
  "_queuedRealtimeRefresh = true",
  "await _cancelRealtimeSubscription()",
  "projectionRefreshInterval = const Duration(seconds: 5)",
]) {
  requireCondition(
    tvRuntimeController.includes(required),
    `GAME-TV-02 controller must retain ${required}`,
  );
}
requireCondition(
  tvRealtimeMigration.includes("bind_tv_realtime_identity_v2") &&
    tvRealtimeMigration.includes("is_tv_session_subscriber") &&
    tvRealtimeMigration.includes("device_auth_user_id := null") &&
    authRoleMigration.includes("'{user_role}'") &&
    !authRoleMigration.includes("'{role}'") &&
    pgTapContract.includes(
      "revoking a TV credential clears its Realtime identity and event access",
    ),
  "GAME-TV-02 database contract must retain authenticated identity binding, RLS, and revocation",
);
const tv01 = contract.quality_contract?.["GAME-TV-01"] ?? {};
const tv01ProjectionSource = sourceBetween(
  "create or replace function public.get_tv_game_projection_v2",
  "alter table africlub_game.role_grants enable row level security",
);
const tv01Clauses = [
  "paired_empty_and_scheduled",
  "lobby_projection",
  "current_question_choices_and_countdown",
  "reveal_and_public_result",
  "privacy_safe_live_standings",
  "completion_and_final_standings",
  "cancellation_and_pause",
  "retained_offline_and_reconnect",
  "strict_authoritative_projection_boundary",
];
requireCondition(
  tv01.status === "local_native_tv_projection_contract_passed" &&
    tv01.focused_flutter_tests_passed >= 58 &&
    tv01.isolated_database_contract_checks_passed >= 80 &&
    tv01.governed_goldens === 5 &&
    tv01.criterion_complete === true &&
    tv01.shared_or_live_session_claimed === false &&
    tv01.physical_tv_claimed === false &&
    tv01.real_network_timing_claimed === false &&
    tv01.accountable_human_approval_claimed === false &&
    tv01.production_signing_or_store_claimed === false &&
    tv01.release_claimed === false,
  "GAME-TV-01 must preserve local full-projection completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(tv01.required_clauses) === JSON.stringify(tv01Clauses) &&
    tvProjectionMatrix.contract === "GAME-TV-01" &&
    tvProjectionMatrix.status ===
      "local_native_tv_projection_contract_passed" &&
    tvProjectionMatrix.criterion_complete === true &&
    JSON.stringify(tvProjectionMatrix.required_clauses) ===
      JSON.stringify(tv01Clauses) &&
    JSON.stringify(tvProjectionMatrix.clauses?.map((clause) => clause.id)) ===
      JSON.stringify(tv01Clauses),
  "GAME-TV-01 matrix must retain the nine ordered projection clauses",
);
for (const clause of tvProjectionMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" &&
      clause.assertion.length > 0 &&
      Array.isArray(clause.tests) &&
      clause.tests.length > 0,
    `GAME-TV-01 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        tvProjectionTestSources.get(test.path)?.includes(test.name),
      `GAME-TV-01 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of tvProjectionMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-TV-01 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  tvProjectionMatrix.deterministic_golden_evidence?.length === 5,
  "GAME-TV-01 must retain five exact current-source projection goldens",
);
const tv01Boundary = tvProjectionMatrix.environment_boundary ?? {};
requireCondition(
  tv01Boundary.current_source_goldens_claimed === true &&
    tv01Boundary.isolated_database_contract_claimed === true &&
    tv01Boundary.shared_or_live_session_claimed === false &&
    tv01Boundary.physical_tv_claimed === false &&
    tv01Boundary.real_network_timing_claimed === false &&
    tv01Boundary.accountable_human_approval_claimed === false &&
    tv01Boundary.production_signing_or_store_claimed === false &&
    tv01Boundary.release_claimed === false,
  "GAME-TV-01 matrix must fail closed for live, physical-TV, timing, approval, signing, store, and release claims",
);
for (const phase of [
  "scheduled",
  "activated_lobby",
  "question_open",
  "reveal",
  "paused",
  "completed",
  "cancelled",
]) {
  requireCondition(
    tvRuntime.includes(`'${phase}'`),
    `GAME-TV-01 runtime must retain supported phase ${phase}`,
  );
}
for (const required of [
  "tvSupportedProjectionPhases.contains(phase)",
  "phase == 'question_open') != (phaseDeadline != null)",
  "question?.correctOptionKey == null",
  "leaderboard[index].rank != index + 1",
]) {
  requireCondition(
    tvRuntime.includes(required),
    `GAME-TV-01 runtime must fail closed through ${required}`,
  );
}
for (const required of [
  "class _TvEmptyDisplayScreen",
  "class _TvGameProjectionScreen",
  "class _GameStagePanel",
  "class _LeaderboardPanel",
  "tvOfflineLastConfirmed",
  "tvGameCompletedTitle",
  "tvGameCancelledTitle",
  "gameLeaderboardTitle",
]) {
  requireCondition(
    tvMain.includes(required),
    `GAME-TV-01 UI must retain ${required}`,
  );
}
requireCondition(
  tv01ProjectionSource.includes("interval '30 minutes'") &&
    tv01ProjectionSource.includes("'correct_option_key'") &&
    tv01ProjectionSource.includes("'leaderboard'") &&
    pgTapContract.includes(
      "completed TV projection remains visible briefly with reveal-safe answer and public leaderboard",
    ),
  "GAME-TV-01 backend must retain bounded result visibility, reveal-safe answer, and public standings",
);
const tv03 = contract.quality_contract?.["GAME-TV-03"] ?? {};
const tv03Clauses = [
  "generated_short_lived_challenge",
  "validated_owner_deep_link_qr",
  "no_tv_secret_input_or_participant_discovery",
  "pending_until_authenticated_owner_claim",
  "single_use_secure_credential_exchange",
  "pairing_material_removed_after_binding",
  "revocation_and_recovery",
];
requireCondition(
  tv03.status === "local_native_tv_pairing_only_contract_passed" &&
    tv03.focused_flutter_tests_passed >= 56 &&
    tv03.isolated_database_contract_checks_passed >= 80 &&
    tv03.governed_goldens === 1 &&
    tv03.criterion_complete === true &&
    tv03.shared_or_live_session_claimed === false &&
    tv03.physical_tv_claimed === false &&
    tv03.real_network_timing_claimed === false &&
    tv03.accountable_human_approval_claimed === false &&
    tv03.release_claimed === false,
  "GAME-TV-03 must preserve local pairing-only completion and the external fail-closed boundary",
);
requireCondition(
  JSON.stringify(tv03.required_clauses) === JSON.stringify(tv03Clauses) &&
    tvPairingMatrix.contract === "GAME-TV-03" &&
    tvPairingMatrix.status ===
      "local_native_tv_pairing_only_contract_passed" &&
    tvPairingMatrix.criterion_complete === true &&
    JSON.stringify(tvPairingMatrix.required_clauses) ===
      JSON.stringify(tv03Clauses) &&
    JSON.stringify(tvPairingMatrix.clauses?.map((clause) => clause.id)) ===
      JSON.stringify(tv03Clauses),
  "GAME-TV-03 matrix must retain the seven ordered pairing-only clauses",
);
for (const clause of tvPairingMatrix.clauses ?? []) {
  requireCondition(
    typeof clause.assertion === "string" &&
      clause.assertion.length > 0 &&
      Array.isArray(clause.tests) &&
      clause.tests.length > 0,
    `GAME-TV-03 ${clause.id} must retain an assertion and executable tests`,
  );
  for (const test of clause.tests ?? []) {
    requireCondition(
      typeof test.path === "string" &&
        typeof test.name === "string" &&
        tvPairingTestSources.get(test.path)?.includes(test.name),
      `GAME-TV-03 ${clause.id} must retain test ${test.name ?? "<missing>"}`,
    );
  }
}
for (const goldenPath of tvPairingMatrix.deterministic_golden_evidence ?? []) {
  requireCondition(
    await pathExists(new URL(`../../${goldenPath}`, import.meta.url)),
    `GAME-TV-03 must retain golden ${goldenPath}`,
  );
}
requireCondition(
  tvPairingMatrix.deterministic_golden_evidence?.length === 1,
  "GAME-TV-03 must retain one exact current-source pairing golden",
);
const tv03Boundary = tvPairingMatrix.environment_boundary ?? {};
requireCondition(
  tv03Boundary.deterministic_local_tests === true &&
    tv03Boundary.static_source_contract === true &&
    tv03Boundary.isolated_database_contract_executed === true &&
    tv03Boundary.current_visual_comparison === true &&
    tv03Boundary.shared_or_live_session_claimed === false &&
    tv03Boundary.physical_tv_claimed === false &&
    tv03Boundary.real_network_timing_claimed === false &&
    tv03Boundary.accountable_human_approval_claimed === false &&
    tv03Boundary.release_claimed === false,
  "GAME-TV-03 matrix must fail closed for live, device, timing, approval, and release claims",
);
const createPairingChallengeSource = sourceBetween(
  "create or replace function public.create_display_pairing_challenge_v2(",
  "create or replace function public.claim_display_bootstrap_challenge_v2(",
);
for (const required of [
  "display_bootstrap_challenges",
  "digest(v_challenge, 'sha256')",
  "interval '8 minutes'",
  "africlub://my-tvs/pair?challenge=",
  "Pairing challenge rate limit exceeded",
]) {
  requireCondition(
    createPairingChallengeSource.includes(required),
    `GAME-TV-03 challenge creation must enforce ${required}`,
  );
}
const exchangePairingChallengeSource = sourceBetween(
  "create or replace function public.exchange_display_pairing_challenge_v2(",
  "create or replace function africlub_game.issue_display_pairing_challenge(",
);
for (const required of [
  "installation_nonce_hash",
  "'pending_owner_claim'",
  "credential_token_hash is not null",
  "'credential_already_issued'",
  "'device_credential'",
]) {
  requireCondition(
    exchangePairingChallengeSource.includes(required),
    `GAME-TV-03 credential exchange must enforce ${required}`,
  );
}
requireCondition(
  tvRuntime.includes("qrUri.scheme != 'africlub'") &&
    tvRuntime.includes("qrUri.host != 'my-tvs'") &&
    tvRuntime.includes("qrUri.path != '/pair'") &&
    tvRuntime.includes("qrUri.queryParameters.length != 1") &&
    tvRuntimeController.includes("await _persistCredential(credential!)") &&
    tvRuntimeController.includes("challenge: challenge") &&
    tvRuntimeController.includes("unawaited(_clearRevokedCredential())") &&
    tvMain.includes("data: challenge.qrPayload") &&
    !tvPairingScreenSource.includes("TextField("),
  "GAME-TV-03 native TV must validate, render, exchange, clear, and revoke pairing state",
);
requireCondition(
  pgTapContract.includes(
    "unpaired TV challenge is hashed, short-lived, deep-linked, and pending until owner claim",
  ) &&
    pgTapContract.includes(
      "TV receives one revocable credential exactly once after owner claim",
    ) &&
    pgTapContract.includes(
      "revoking a TV credential clears its Realtime identity and event access",
    ),
  "GAME-TV-03 pgTAP must preserve challenge, exchange, and revocation behavior",
);
requireCondition(
  crossClientFixture.environment_boundary?.deterministic_local_fixture ===
    true &&
    crossClientFixture.environment_boundary?.shared_or_live_session_claimed ===
      false &&
    crossClientFixture.environment_boundary?.physical_device_claimed === false &&
    crossClientFixture.environment_boundary?.release_claimed === false,
  "GAME-QA-02 fixture must remain fail-closed outside local deterministic scope",
);
requireCondition(
  crossClientTestSources.every(
    (source) =>
      source.includes("GAME-QA-02") && source.includes("crossClientFixture"),
  ),
  "GAME-QA-02 each client surface must retain fixture-driven render tests",
);
requireCondition(
  contract.required_protected_approvals?.length === 5,
  "five protected approvals must remain explicit",
);

for (const relation of [
  "role_grants",
  "display_assignments",
  "session_eligibility",
  "session_invitations",
  "transition_requests",
  "game_events",
  "display_pairing_challenges",
]) {
  requireCondition(
    migration.includes(
      `create table if not exists africlub_game.${relation}`,
    ),
    `migration must create ${relation}`,
  );
  requireCondition(
    migration.includes(
      `alter table africlub_game.${relation} enable row level security`,
    ),
    `migration must enable RLS on ${relation}`,
  );
}

for (const column of [
  "owner_user_id",
  "scope_type",
  "venue_id",
  "app_version",
  "capabilities",
]) {
  requireCondition(
    migration.includes(`add column if not exists ${column}`),
    `TV installation must add ${column}`,
  );
}

for (const column of [
  "lifecycle_phase",
  "session_version",
  "question_version",
  "event_sequence",
  "phase_deadline",
  "eligibility_scope",
]) {
  requireCondition(
    migration.includes(`add column if not exists ${column}`),
    `game session must add ${column}`,
  );
}

for (const rpc of [
  "public.get_eligible_game_sessions_v2",
  "public.get_participant_game_projection_v2",
  "public.submit_participant_answer_v2",
  "africlub_game.transition_session_v2",
  "africlub_game.assign_display_v2",
  "public.create_display_pairing_challenge_v2",
  "public.exchange_display_pairing_challenge_v2",
  "public.get_tv_game_projection_v2",
  "public.skip_managed_game_question_v2",
  "public.end_managed_game_session_v2",
]) {
  requireCondition(
    migration.includes(`create or replace function ${rpc}`),
    `migration must implement ${rpc}`,
  );
}

for (const rpc of [
  "create_display_pairing_challenge_v2",
  "exchange_display_pairing_challenge_v2",
  "bind_tv_realtime_identity_v2",
  "get_tv_game_projection_v2",
]) {
  requireCondition(
    tvRuntime.includes(`'${rpc}'`),
    `native TV runtime must call ${rpc}`,
  );
}
for (const retiredRpc of [
  "exchange_tv_pairing_code",
  "get_tv_display_state_with_credential",
]) {
  requireCondition(
    !tvRuntime.includes(`'${retiredRpc}'`),
    `native TV runtime must not call retired ${retiredRpc}`,
  );
}
requireCondition(
  tvRuntime.includes("FlutterSecureStorage") &&
    tvRuntime.includes("africlub_tv_device_credential_v2"),
  "native TV runtime must keep the v2 credential in secure storage",
);
for (const required of [
  "add column if not exists device_auth_user_id",
  "public.bind_tv_realtime_identity_v2",
  "africlub_game.is_tv_session_subscriber",
  "device_auth_user_id = auth.uid()",
  "assignment.unassigned_at is null",
  "credential_revoked_at is null",
  "game_events_authorized_subscriber_read",
]) {
  requireCondition(
    tvRealtimeMigration.includes(required),
    `native TV Realtime migration must enforce ${required}`,
  );
}
requireCondition(
  authRoleMigration.includes("'{user_role}'") &&
    !authRoleMigration.includes("jsonb_set(claims, '{role}'"),
  "access-token hook must preserve the PostgreSQL role and separate the product user role",
);
for (const required of [
  "signInAnonymously",
  "auth_purpose",
  "watchInvalidations",
  "schema: 'africlub_game'",
  "table: 'game_events'",
  "requires_projection_refresh",
]) {
  requireCondition(
    tvRuntime.includes(required),
    `native TV runtime must implement ${required}`,
  );
}
requireCondition(
  !(await pathExists(retiredMatchQuizUrl)),
  "retired MatchQuiz must not restore client-owned answer scoring or rewards",
);

const discoverySource = sourceBetween(
  "create or replace function public.get_eligible_game_sessions_v2",
  "create or replace function public.get_participant_game_projection_v2",
);
for (const forbidden of [
  "'join_code'",
  "'tv_code'",
  "'pairing_challenge'",
  "'device_credential'",
]) {
  requireCondition(
    !discoverySource.includes(forbidden),
    `discovery RPC must not emit ${forbidden}`,
  );
}
for (const required of [
  "from public.fan_memberships membership",
  "membership.status = 'active'",
  "membership.payment_status = 'verified'::public.payment_status",
  "membership.expires_at > timezone('utc', now())",
]) {
  requireCondition(
    discoverySource.includes(required),
    `club-membership discovery must enforce ${required}`,
  );
}

const participantProjectionSource = sourceBetween(
  "create or replace function public.get_participant_game_projection_v2",
  "create or replace function africlub_game.transition_session_v2",
);
requireCondition(
  participantProjectionSource.includes(
    "v_session.lifecycle_phase in ('reveal', 'completed')",
  ),
  "participant projection must gate correct answers until reveal",
);
requireCondition(
  participantProjectionSource.includes("'correct_option_key'"),
  "participant projection must include the answer only in its reveal branch",
);
for (const forbidden of ["'join_code'", "'phone'", "'email'"]) {
  requireCondition(
    !participantProjectionSource.includes(forbidden),
    `participant projection must not emit ${forbidden}`,
  );
}

const transitionSource = sourceBetween(
  "create or replace function africlub_game.transition_session_v2",
  "create or replace function africlub_game.assign_display_v2",
);
for (const required of [
  "p_expected_session_version",
  "p_idempotency_key",
  "transition_requests",
  "game_events",
  "audit_log",
]) {
  requireCondition(
    transitionSource.includes(required),
    `transition RPC must enforce ${required}`,
  );
}
for (const required of ["'skip_question'", "'end_early'"]) {
  requireCondition(
    migration.includes(required),
    `transition contract must advertise the explicit exception action ${required}`,
  );
}
const answerSource = sourceBetween(
  "create or replace function public.submit_participant_answer_v2",
  "create or replace function africlub_game.transition_session_v2",
);
for (const required of [
  "from africlub_game.answer_attempts attempt",
  "return public.get_participant_game_projection_v2(v_session.id)",
  "event_sequence = event_sequence + 1",
]) {
  requireCondition(
    answerSource.includes(required),
    `answer RPC must enforce repeat-safe behavior through ${required}`,
  );
}
for (const required of [
  "table_name || '_admin_read'",
  "create policy game_sessions_assigned_operator_read",
  "africlub_game.can_organize_session(id)",
  "drop policy if exists tv_devices_club_read",
  "revoke insert on africlub_game.session_players from authenticated",
  "revoke insert on africlub_game.answer_attempts from authenticated",
  "revoke all on function africlub_game.get_tv_session_state(uuid)",
  "revoke all on function africlub_game.join_session(uuid,text,bigint,text)",
]) {
  requireCondition(
    migration.includes(required),
    `migration must close raw or legacy participant access through ${required}`,
  );
}
requireCondition(
  migration.includes(
    "v_session.club_id::text || ':game_session:' || v_session.id::text",
  ),
  "migration must use the club-scoped Realtime channel contract",
);
requireCondition(
  migration.includes(
    "on conflict (session_id, display_id) where unassigned_at is null",
  ),
  "display assignment must be repeat-safe while allowing several displays",
);
requireCondition(
  migration.includes("tv_devices_capabilities_check") &&
    migration.includes("octet_length(capabilities::text) <= 2048"),
  "TV capability metadata must be bounded by the installation relation",
);
const tvProjectionSource = sourceBetween(
  "create or replace function public.get_tv_game_projection_v2",
  "alter table africlub_game.role_grants enable row level security",
);
for (const required of ["'allowed_actions'", "'freshness'", "'last_event_at'"]) {
  requireCondition(
    tvProjectionSource.includes(required),
    `TV projection must expose reconnect metadata through ${required}`,
  );
}
requireCondition(
  pgTapChecks >= 77,
  "Live Games V2 pgTAP contract must declare at least 77 checks",
);
requireCondition(
  migration.includes("requires_projection_refresh") &&
    migration.includes("alter publication supabase_realtime add table africlub_game.game_events") &&
    migration.includes("grant select on africlub_game.game_events to authenticated") &&
    migration.includes("grant select on africlub_game.display_assignments to authenticated") &&
    migration.includes("africlub_game.is_session_participant(session_id)"),
  "game events must be published privacy-safe invalidation hints that require projection refresh",
);
requireCondition(
  migration.includes("then public.get_admin_game_projection_v2(session_row.id)") &&
    migration.includes("else public.get_organizer_game_projection_v2(session_row.id)"),
  "managed sessions must expose admin previews only through the authorized admin projection",
);
for (const required of [
  "generationMode",
  "reviewerName",
  "qaChecks",
  "citationFragment",
  "schemaVersion",
  "question_drafts_require_human_review",
  "draft approval blocked by deterministic checks",
  "ambiguitySignalsAbsent",
  "answerConsistent",
  "languageSupported",
  "policyCompliant",
  "all pack questions must retain source evidence",
  "mobile and TV publication previews must be reviewed",
  "p_preview_fingerprint",
]) {
  requireCondition(
    contentMigration.includes(required),
    `content governance migration must enforce ${required}`,
  );
}
const draftProjectionSource = sourceBetweenIn(
  contentMigration,
  "create or replace function africlub_game.admin_list_question_drafts(",
  "create or replace function africlub_game.admin_review_question_draft(",
);
requireCondition(
  draftProjectionSource.length > 0 &&
    !draftProjectionSource.includes("correct_option_key") &&
    !draftProjectionSource.includes("'options'"),
  "draft governance projection must not expose correct answers",
);
requireCondition(
  pgTapContract.includes("participant projection gates answers"),
  "pgTAP contract must verify pre-reveal answer protection",
);
for (const requiredBehavior of [
  "a suspended member cannot discover",
  "an answer retry is idempotent",
  "an organizer transition is versioned",
  "the correct answer is exposed only after",
  "a participant club claim cannot bypass",
  "an organizer can read only an explicitly assigned session",
  "a club member without a planning role cannot create",
  "an organizer cannot schedule an incomplete question pack",
  "managed planning creates exactly 20 questions",
  "public unassignment converges without duplicate audit",
  "completed TV projection remains visible briefly",
  "terminal TV projection clears after the bounded thirty-minute window",
  "planner options expose complete packs, authorized credential-free displays, and one active privacy-safe Fan-ID invitee",
  "pack publication requires the exact reviewed-preview fingerprint",
  "draft projection exposes provenance and QA without answer-bearing content",
  "legacy participant RPCs and direct writes",
  "reasoned skip closes the current question",
  "reasoned early end completes the session",
  "TV capability metadata is bounded by an enforced database constraint",
  "a display owner can read and inventory only their authorized installation",
  "a venue manager can manage only displays scoped to their authorized venue",
  "an organizer can read only owned or explicitly assigned displays",
  "club admins remain club-scoped while platform admins retain governed cross-club access",
  "an unrelated display owner cannot subscribe to game-session invalidation events",
  "a participant subscribes only to invalidation events for their joined session",
  "runtime events are club-scoped privacy-safe hints that require snapshot reconciliation",
  "native TV Realtime identity is bound only through a valid device credential",
  "a bound native TV reads only its actively assigned session events",
  "a different authenticated identity cannot take over a bound TV credential",
  "revoking a TV credential clears its Realtime identity and event access",
  "the access-token hook preserves authenticated and separates the product role",
]) {
  requireCondition(
    pgTapContract.includes(requiredBehavior),
    `pgTAP contract must verify ${requiredBehavior}`,
  );
}

if (failures.length > 0) {
  process.stderr.write(
    `Live Games V2 contract validation failed:\n- ${failures.join("\n- ")}\n`,
  );
  process.exitCode = 1;
} else {
  process.stdout.write(
    `Live Games V2 contract validation passed: ${states.length} states, ` +
      `${transitions.length} transitions, ${roles.length} roles, ` +
      `${discoverySources.length} discovery sources, authoritative SQL and ` +
      `${pgTapChecks} pgTAP checks.\n`,
  );
}
