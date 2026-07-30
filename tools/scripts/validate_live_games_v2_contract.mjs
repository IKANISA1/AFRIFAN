import { readFile } from "node:fs/promises";

const contractUrl = new URL(
  "../../docs/architecture/live-games-v2-contract.json",
  import.meta.url,
);
const contract = JSON.parse(await readFile(contractUrl, "utf8"));

const failures = [];

function requireCondition(condition, message) {
  if (!condition) failures.push(message);
}

function unique(values) {
  return new Set(values).size === values.length;
}

const states = contract.lifecycle?.states ?? [];
const transitions = contract.lifecycle?.transitions ?? [];
const roles = contract.roles ?? [];

requireCondition(contract.schema_version === "1.0", "schema_version must be 1.0");
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
  discoverySources.length === 3 && unique(discoverySources),
  "participant discovery sources are invalid",
);
for (const source of ["club_membership", "invitation", "deep_link"]) {
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
  "six owner decisions must remain explicit",
);
requireCondition(
  contract.required_protected_approvals?.length === 5,
  "five protected approvals must remain explicit",
);

if (failures.length > 0) {
  process.stderr.write(
    `Live Games V2 contract validation failed:\n- ${failures.join("\n- ")}\n`,
  );
  process.exitCode = 1;
} else {
  process.stdout.write(
    `Live Games V2 contract validation passed: ${states.length} states, ` +
      `${transitions.length} transitions, ${roles.length} roles, ` +
      `${discoverySources.length} discovery sources.\n`,
  );
}
