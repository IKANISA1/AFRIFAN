import { HttpError } from "./auth.ts";
import { createLifecycleUserClient } from "./account_lifecycle_client.ts";

export type StaffCommandAction =
  | "fixture_settle"
  | "predict_legacy_settle"
  | "predict_legacy_confirm"
  | "partner_legacy_settle";
export interface StaffCommand {
  operationId: string;
  action: StaffCommandAction;
  resourceId: string;
  arguments: Record<string, unknown>;
}
type RpcResult = {
  data: unknown;
  error: { code?: string; message?: string } | null;
};
export interface StaffCommandClient {
  rpc(
    name: string,
    arguments_: Record<string, unknown>,
  ): PromiseLike<RpcResult>;
}
export interface StaffCommandAdmission {
  operation_id: string;
  actor_id: string;
  action: StaffCommandAction;
  resource_id: string;
  club_id: number | null;
  status: "admitted" | "completed";
  expires_at: string | null;
}

/**
 * Call only after provider verification and current staff authorization. The
 * original bearer is carried into the bounded authenticated SDK transport;
 * PostgreSQL admits its verified JWT. No actor/MFA/session claims are submitted.
 */
export async function admitVerifiedStaffCommand(
  authorization: string,
  verifiedActorId: string,
  command: StaffCommand,
  dependencies: {
    createUserClient?: (authorization: string) => StaffCommandClient;
  } = {},
): Promise<StaffCommandAdmission> {
  const client = dependencies.createUserClient?.(authorization) ??
    createLifecycleUserClient(authorization) as unknown as StaffCommandClient;
  const { data, error } = await client.rpc("admit_verified_staff_command", {
    p_operation_id: command.operationId,
    p_action: command.action,
    p_resource_id: command.resourceId,
    p_arguments: command.arguments,
  });
  if (error?.code === "42501") {
    throw new HttpError(
      403,
      "Verify your authenticator and current staff access.",
    );
  }
  if (error?.code === "22023" || error?.code === "P0001") {
    throw new HttpError(
      409,
      "The original staff command could not be admitted.",
    );
  }
  if (
    error || data == null || typeof data !== "object" || Array.isArray(data)
  ) {
    throw new HttpError(502, "Staff command admission was not confirmed.");
  }
  const receipt = data as Record<string, unknown>;
  const club = receipt.club_id;
  const completed = receipt.status === "completed";
  if (
    receipt.operation_id !== command.operationId ||
    receipt.actor_id !== verifiedActorId || receipt.action !== command.action ||
    receipt.resource_id !== command.resourceId ||
    !(club === null || (Number.isSafeInteger(club) && Number(club) > 0)) ||
    (command.action === "fixture_settle" ? club !== null : club === null) ||
    (!completed && receipt.status !== "admitted") ||
    (completed
      ? receipt.expires_at !== null
      : typeof receipt.expires_at !== "string" ||
        !Number.isFinite(Date.parse(receipt.expires_at)) ||
        Date.parse(receipt.expires_at) <= Date.now())
  ) {
    throw new HttpError(502, "Staff command admission was not confirmed.");
  }
  return receipt as unknown as StaffCommandAdmission;
}
