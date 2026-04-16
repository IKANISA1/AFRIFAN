import { HttpError } from "../_shared/auth.ts";
import {
  type BioPayRevokeHandlerDependencies,
  createBioPayRevokeHandler,
} from "./index.ts";

function assertEquals<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function buildRequest() {
  return new Request("https://example.com/functions/v1/BioPay-revoke", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
      "x-firebase-appcheck": "fresh-token",
    },
    body: JSON.stringify({ reason: "user_request" }),
  });
}

function buildDeps(): BioPayRevokeHandlerDependencies {
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
              profile_id: "profile-1",
              public_id: "public-1",
            },
            error: null,
          };
        },
      }) as unknown as ReturnType<
        BioPayRevokeHandlerDependencies["createAdminClient"]
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
        BioPayRevokeHandlerDependencies["createUserClient"]
      >,
    requireAppCheckToken: async () => "fresh-token",
    recordOperationalHealthEvent: async () => undefined,
    recordEdgeFunctionFailure: async () => undefined,
  };
}

Deno.test("BioPay-revoke rejects requests without valid App Check attestation", async () => {
  const handler = createBioPayRevokeHandler({
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

Deno.test("BioPay-revoke succeeds when App Check attestation is valid", async () => {
  const handler = createBioPayRevokeHandler(buildDeps());
  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 200, "should accept attested requests");
  assertEquals(payload.success, true, "should report success");
  assertEquals(
    payload.data.profile_id,
    "profile-1",
    "should return the revoked profile payload",
  );
});
