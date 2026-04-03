import { HttpError } from "../_shared/auth.ts";
import { BIOPAY_EMBEDDING_LENGTH } from "../_shared/biopay_embedding.ts";
import {
  type BiopayEnrollHandlerDependencies,
  createBiopayEnrollHandler,
} from "./index.ts";

function buildLivenessEvidence() {
  return {
    version: "biopay-liveness-v1",
    mode: "enrollment",
    result: "passed",
    completed_at: new Date().toISOString(),
    completed_steps: ["blink", "turn_side", "recenter"],
    frames_evaluated: 8,
    max_abs_head_yaw: 18,
    blink_detected: true,
  };
}

function assertEquals<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function buildRequest() {
  return new Request("https://example.com/functions/v1/biopay-enroll", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
      "x-firebase-appcheck": "fresh-token",
    },
    body: JSON.stringify({
      display_name: "Marie",
      route_type: "phone_number",
      recipient_value: "0781234567",
      country_code: "RW",
      embedding: Array.from(
        { length: BIOPAY_EMBEDDING_LENGTH },
        (_, index) => index / 1000,
      ),
      liveness: buildLivenessEvidence(),
    }),
  });
}

function buildDeps(): BiopayEnrollHandlerDependencies {
  return {
    createAdminClient: () =>
      ({
        rpc: async (fn: string) => {
          if (fn == "normalize_club_id") {
            return {
              data: 24,
              error: null,
            };
          }
          return {
            data: {
              id: "profile-1",
              route_type: "phone_number",
              country_code: "RW",
            },
            error: null,
          };
        },
      }) as unknown as ReturnType<
        BiopayEnrollHandlerDependencies["createAdminClient"]
      >,
    createUserClient: () =>
      ({
        auth: {
          getUser: async () => ({
            data: {
              user: { id: "user-1", app_metadata: { club_id: "24" } },
            },
            error: null,
          }),
        },
      }) as unknown as ReturnType<
        BiopayEnrollHandlerDependencies["createUserClient"]
      >,
    requireAppCheckToken: async () => "fresh-token",
    validateLiveness: async (input) => input as Record<string, unknown>,
    recordOperationalHealthEvent: async () => undefined,
    recordEdgeFunctionFailure: async () => undefined,
  };
}

Deno.test("biopay-enroll rejects requests without valid App Check attestation", async () => {
  const handler = createBiopayEnrollHandler({
    ...buildDeps(),
    requireAppCheckToken: async () => {
      throw new HttpError(401, "Device attestation required.");
    },
  });

  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 401, "should reject unattested requests");
  assertEquals(
    payload.message,
    "Device attestation required.",
    "should surface attestation failure",
  );
});

Deno.test("biopay-enroll succeeds when App Check attestation is valid", async () => {
  let capturedArgs: Record<string, unknown> | null = null;
  const instrumented = createBiopayEnrollHandler({
    ...buildDeps(),
    createAdminClient: () =>
      ({
        rpc: async (fn: string, args: Record<string, unknown>) => {
          if (fn == "normalize_club_id") {
            return {
              data: 24,
              error: null,
            };
          }
          capturedArgs = args;
          return {
            data: {
              id: "profile-1",
              route_type: "phone_number",
              country_code: "RW",
            },
            error: null,
          };
        },
      }) as unknown as ReturnType<
        BiopayEnrollHandlerDependencies["createAdminClient"]
      >,
  });
  const response = await instrumented(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 200, "should accept attested requests");
  assertEquals(payload.success, true, "should report success");
  assertEquals(
    payload.data.id,
    "profile-1",
    "should return the enrolled profile",
  );
  if (!capturedArgs) {
    throw new Error("expected RPC arguments to be captured");
  }
  assertEquals(
    capturedArgs["p_route_type"],
    "phone_number",
    "should forward the route type",
  );
  assertEquals(
    capturedArgs["p_recipient_value"],
    "0781234567",
    "should forward the recipient value",
  );
  assertEquals(
    capturedArgs["p_country_code"],
    "RW",
    "should forward the country code",
  );
  assertEquals(
    capturedArgs["p_requester_user_id"],
    "user-1",
    "should pass the requester user id",
  );
  assertEquals(
    capturedArgs["p_club_id"],
    24,
    "should pass the numeric club id",
  );
});
