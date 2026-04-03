import {
  type SignedBiopayTokenPayload,
  verifyBiopayToken,
} from "./biopay_signed_token.ts";

function readTrimmedString(
  value: unknown,
  maxLength: number,
): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.slice(0, maxLength);
}

export function normalizeBiopayLivenessMetadata(
  input: unknown,
): Record<string, unknown> | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return null;
  }

  const source = input as Record<string, unknown>;
  const metadata: Record<string, unknown> = {};
  const version = readTrimmedString(source["version"], 64);
  const mode = readTrimmedString(source["mode"], 32);
  const result = readTrimmedString(source["result"], 32);
  const completedAt = readTrimmedString(source["completed_at"], 64);
  const challengeToken = readTrimmedString(source["challenge_token"], 4096);

  if (version) {
    metadata.version = version;
  }
  if (mode) {
    metadata.mode = mode;
  }
  if (result) {
    metadata.result = result;
  }
  if (completedAt) {
    metadata.completed_at = completedAt;
  }
  if (challengeToken) {
    metadata.challenge_token = challengeToken;
  }

  const steps = source["completed_steps"];
  if (Array.isArray(steps)) {
    const completedSteps = steps
      .filter((entry): entry is string => typeof entry === "string")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0)
      .slice(0, 6);
    if (completedSteps.length > 0) {
      metadata.completed_steps = completedSteps;
    }
  }

  const framesEvaluated = source["frames_evaluated"];
  if (typeof framesEvaluated === "number" && Number.isFinite(framesEvaluated)) {
    metadata.frames_evaluated = Math.max(0, Math.trunc(framesEvaluated));
  }

  const maxAbsHeadYaw = source["max_abs_head_yaw"];
  if (typeof maxAbsHeadYaw === "number" && Number.isFinite(maxAbsHeadYaw)) {
    metadata.max_abs_head_yaw = Number(maxAbsHeadYaw.toFixed(2));
  }

  const blinkDetected = source["blink_detected"];
  if (typeof blinkDetected === "boolean") {
    metadata.blink_detected = blinkDetected;
  }

  return Object.keys(metadata).length === 0 ? null : metadata;
}

type LivenessChallengeClient = {
  from(table: string): any;
};

type BiopayLivenessChallengePayload = SignedBiopayTokenPayload & {
  challenge_id?: unknown;
  requester_user_id?: unknown;
  club_id?: unknown;
  mode?: unknown;
};

export type BiopayLivenessMode = "enrollment" | "payment";

export type ValidateBiopayLivenessOptions = {
  adminClient: LivenessChallengeClient;
  requesterUserId: string;
  clubId: number;
  mode: BiopayLivenessMode;
};

export type BiopayLivenessValidationDependencies = {
  verifyToken: (
    token: string,
    options: { expectedKind: string },
  ) => Promise<SignedBiopayTokenPayload>;
  now: () => Date;
};

const defaultDependencies: BiopayLivenessValidationDependencies = {
  verifyToken: verifyBiopayToken,
  now: () => new Date(),
};

export async function validateBiopayLivenessMetadata(
  input: unknown,
  options: ValidateBiopayLivenessOptions,
  dependencies: Partial<BiopayLivenessValidationDependencies> = {},
): Promise<Record<string, unknown>> {
  const deps: BiopayLivenessValidationDependencies = {
    ...defaultDependencies,
    ...dependencies,
  };
  const metadata = normalizeBiopayLivenessMetadata(input);
  if (metadata == null) {
    throw new Error("BioPay liveness evidence is required.");
  }

  if (metadata["result"] !== "passed") {
    throw new Error("BioPay liveness challenge did not pass.");
  }

  const completedAt = metadata["completed_at"];
  if (
    typeof completedAt !== "string" || Number.isNaN(Date.parse(completedAt))
  ) {
    throw new Error("BioPay liveness evidence is missing a valid timestamp.");
  }
  const ageMs = Date.now() - Date.parse(completedAt);
  if (ageMs < 0 || ageMs > 2 * 60 * 1000) {
    throw new Error("BioPay liveness evidence is stale.");
  }

  const completedSteps = Array.isArray(metadata["completed_steps"])
    ? metadata["completed_steps"].filter((entry): entry is string =>
      typeof entry === "string"
    )
    : [];
  const mode = metadata["mode"] == "enrollment" ? "enrollment" : "payment";
  if (mode !== options.mode) {
    throw new Error("BioPay liveness evidence mode does not match this flow.");
  }
  const requiredSteps = mode == "enrollment"
    ? ["blink", "turn_side", "recenter"]
    : ["blink", "turn_side"];
  for (const step of requiredSteps) {
    if (!completedSteps.includes(step)) {
      throw new Error(`BioPay liveness evidence is missing the ${step} step.`);
    }
  }

  if (metadata["blink_detected"] !== true) {
    throw new Error("BioPay liveness evidence did not confirm a blink.");
  }

  const framesEvaluated = metadata["frames_evaluated"];
  if (
    typeof framesEvaluated !== "number" ||
    framesEvaluated < requiredSteps.length
  ) {
    throw new Error("BioPay liveness evidence is incomplete.");
  }

  const maxAbsHeadYaw = metadata["max_abs_head_yaw"];
  if (typeof maxAbsHeadYaw !== "number" || maxAbsHeadYaw < 12) {
    throw new Error(
      "BioPay liveness evidence did not include enough head movement.",
    );
  }

  const challengeToken = metadata["challenge_token"];
  if (typeof challengeToken !== "string" || challengeToken.trim().length === 0) {
    throw new Error("BioPay liveness evidence is missing the server challenge.");
  }

  const payload = await deps.verifyToken(challengeToken, {
    expectedKind: "liveness_challenge",
  }) as BiopayLivenessChallengePayload;
  const challengeId = readTrimmedString(payload.challenge_id, 128);
  if (challengeId == null) {
    throw new Error("BioPay liveness challenge is invalid.");
  }
  if (payload.requester_user_id?.toString() !== options.requesterUserId) {
    throw new Error("BioPay liveness challenge does not belong to this user.");
  }
  if (Number(payload.club_id ?? 0) !== options.clubId) {
    throw new Error("BioPay liveness challenge does not match this club.");
  }
  if (payload.mode?.toString() !== options.mode) {
    throw new Error("BioPay liveness challenge mode is invalid.");
  }

  const issuedAtMs = Date.parse(payload.iat);
  const completedAtMs = Date.parse(completedAt);
  if (!Number.isNaN(issuedAtMs) && completedAtMs < issuedAtMs - 15_000) {
    throw new Error(
      "BioPay liveness evidence predates the active server challenge.",
    );
  }

  const { data: challengeRow, error: challengeError } = await options.adminClient
    .from("biopay_liveness_challenges")
    .select("id, nonce, mode, expires_at, consumed_at")
    .eq("id", challengeId)
    .maybeSingle();

  if (challengeError) {
    throw challengeError;
  }
  if (!challengeRow) {
    throw new Error("BioPay liveness challenge could not be found.");
  }
  if (readTrimmedString(challengeRow["mode"], 32) !== options.mode) {
    throw new Error("BioPay liveness challenge mode is invalid.");
  }
  if (challengeRow["consumed_at"] != null) {
    throw new Error("BioPay liveness challenge has already been used.");
  }
  if (
    readTrimmedString(challengeRow["nonce"], 128) !=
      readTrimmedString(payload.nonce, 128)
  ) {
    throw new Error("BioPay liveness challenge nonce is invalid.");
  }

  const expiresAt = readTrimmedString(challengeRow["expires_at"], 64);
  if (expiresAt == null || Number.isNaN(Date.parse(expiresAt))) {
    throw new Error("BioPay liveness challenge expiry is invalid.");
  }
  if (Date.parse(expiresAt) <= deps.now().getTime()) {
    throw new Error("BioPay liveness challenge has expired.");
  }

  const consumedAt = deps.now().toISOString();
  const { data: consumedChallenge, error: consumeError } = await options.adminClient
    .from("biopay_liveness_challenges")
    .update({ consumed_at: consumedAt })
    .eq("id", challengeId)
    .is("consumed_at", null)
    .select("id")
    .maybeSingle();

  if (consumeError) {
    throw consumeError;
  }
  if (!consumedChallenge) {
    throw new Error("BioPay liveness challenge has already been used.");
  }

  metadata.challenge_id = challengeId;
  metadata.challenge_consumed_at = consumedAt;

  return metadata;
}
