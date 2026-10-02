import {
  getAuthorizationHeader,
  HttpError,
  metadataBool,
  requireAdminCaller,
  requireAuthenticatedCaller,
  requireClubAdminCaller,
  requireCronSecret,
} from "./auth.ts";
import { syntheticStaffJwt } from "./staff_auth_test_support.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEquals<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function expectHttpError(
  error: unknown,
  status: number,
  message: string,
): void {
  if (!(error instanceof HttpError)) {
    throw new Error(`${message}: expected HttpError`);
  }
  assertEquals(error.status, status, `${message}: status`);
}

Deno.test("metadataBool accepts common truthy encodings", () => {
  assert(metadataBool(true), "boolean true should be truthy");
  assert(metadataBool(1), "number 1 should be truthy");
  assert(metadataBool("true"), "string true should be truthy");
  assert(metadataBool("1"), "string 1 should be truthy");
  assert(!metadataBool("false"), "string false should be falsy");
});

Deno.test("getAuthorizationHeader reads either header casing", () => {
  const request = new Request("https://example.com", {
    headers: { Authorization: "Bearer token-1" },
  });

  assertEquals(
    getAuthorizationHeader(request),
    "Bearer token-1",
    "should read the authorization header",
  );
});

Deno.test("requireAuthenticatedCaller rejects requests without auth", async () => {
  try {
    await requireAuthenticatedCaller(new Request("https://example.com"));
    throw new Error("expected requireAuthenticatedCaller to throw");
  } catch (error) {
    expectHttpError(error, 401, "missing auth should fail");
  }
});

type Assignment = {
  role: string;
  club_id?: number | null;
  is_active: boolean;
  revoked_at?: string | null;
};

function authDependencies(
  rows: Assignment[],
  appMetadata: Record<string, unknown> = {},
  storeError: unknown = null,
) {
  return {
    createUserClient: () => ({
      auth: {
        getUser: async () => ({
          data: { user: { id: "actor-1", app_metadata: appMetadata } },
          error: null,
        }),
      },
    }),
    createAdminClient: () => ({
      from: (table: string) => {
        assertEquals(
          table,
          "admin_role_assignments",
          "current assignment store",
        );
        return {
          select: (columns: string) => {
            assert(
              columns.includes("revoked_at"),
              "query includes revocation state",
            );
            return {
              eq: (field: string, value: unknown) => {
                assertEquals(field, "user_id", "verified actor filter");
                assertEquals(value, "actor-1", "verified actor");
                return {
                  eq: async (activeField: string, activeValue: unknown) => {
                    assertEquals(
                      activeField,
                      "is_active",
                      "active assignment filter",
                    );
                    assertEquals(activeValue, true, "active value");
                    return { data: rows, error: storeError };
                  },
                };
              },
            };
          },
        };
      },
    }),
  };
}
const adminRequest = (token = syntheticStaffJwt("actor-1")) =>
  new Request("https://example.com", {
    headers: { authorization: `Bearer ${token}` },
  });

for (const role of ["admin", "super_admin"]) {
  Deno.test(`global admin requires current ${role} assignment`, async () => {
    const caller = await requireAdminCaller(
      adminRequest(),
      authDependencies([{ role, is_active: true }]),
    );
    assert(caller.isAdmin, "assignment-backed global authorization");
    assertEquals(caller.userId, "actor-1", "verified actor identity");
  });
}
for (
  const role of ["club_admin", "club_moderator", "supporter", "bank", "partner"]
) {
  Deno.test(`${role} cannot authorize a global operation`, async () => {
    try {
      await requireAdminCaller(
        adminRequest(),
        authDependencies([{ role, club_id: 7, is_active: true }], {
          role,
          club_id: 7,
        }),
      );
      throw new Error("global operation unexpectedly authorized");
    } catch (error) {
      expectHttpError(error, 403, "club staff are scoped");
    }
  });
}
for (
  const rows of [[], [{ role: "admin", is_active: false }], [{
    role: "super_admin",
    is_active: true,
    revoked_at: "2026-10-01T10:00:00Z",
  }]]
) {
  Deno.test(`stale metadata cannot grant admin access: ${JSON.stringify(rows)}`, async () => {
    try {
      await requireAdminCaller(
        adminRequest(),
        authDependencies(rows, { role: "super_admin", is_admin: true }),
      );
      throw new Error("stale grant unexpectedly accepted");
    } catch (error) {
      expectHttpError(error, 403, "revoked/absent grants fail closed");
    }
  });
}
Deno.test("assignment-store errors fail closed even for metadata admins", async () => {
  try {
    await requireAdminCaller(
      adminRequest(),
      authDependencies(
        [],
        { is_admin: true },
        new Error("private store detail"),
      ),
    );
    throw new Error("store error unexpectedly accepted");
  } catch (error) {
    expectHttpError(error, 500, "store error");
  }
});
Deno.test("authenticated metadata is never an authorization grant", async () => {
  const caller = await requireAuthenticatedCaller(
    adminRequest(),
    authDependencies([], { role: "super_admin" }),
  );
  assertEquals(
    caller.isAdmin,
    false,
    "metadata cannot establish authorization",
  );
});
for (const role of ["club_admin", "club_moderator"]) {
  Deno.test(`${role} is permitted only for its assigned club`, async () => {
    const deps = authDependencies([{ role, club_id: 42, is_active: true }]);
    assert(
      (await requireClubAdminCaller(adminRequest(), 42, deps)).isAdmin,
      "assigned club allowed",
    );
    try {
      await requireClubAdminCaller(adminRequest(), 7, deps);
      throw new Error("cross-tenant operation unexpectedly authorized");
    } catch (error) {
      expectHttpError(error, 403, "cross-tenant denied");
    }
  });
}
Deno.test("scoped authorization rejects malformed or revoked club assignments", async () => {
  for (const clubId of [0, -1, 1.5, NaN]) {
    try {
      await requireClubAdminCaller(
        adminRequest(),
        clubId,
        authDependencies([]),
      );
      throw new Error("invalid target accepted");
    } catch (error) {
      expectHttpError(error, 400, "invalid target");
    }
  }
  try {
    await requireClubAdminCaller(
      adminRequest(),
      42,
      authDependencies(
        [{ role: "club_admin", club_id: 42, is_active: false }],
        { role: "club_admin", club_id: 42 },
      ),
    );
    throw new Error("revoked club role accepted");
  } catch (error) {
    expectHttpError(error, 403, "revoked club assignment");
  }
});

Deno.test("requireCronSecret accepts bearer and x-cron-secret inputs", () => {
  const getEnv = (name: string) =>
    name == "TEST_CRON_SECRET" ? "secret-123" : undefined;

  requireCronSecret(
    new Request("https://example.com", {
      headers: { authorization: "Bearer secret-123" },
    }),
    ["TEST_CRON_SECRET"],
    { getEnv },
  );

  requireCronSecret(
    new Request("https://example.com", {
      headers: { "x-cron-secret": "secret-123" },
    }),
    ["TEST_CRON_SECRET"],
    { getEnv },
  );
});

Deno.test("current closure metadata revokes Edge access despite old staff hints", async () => {
  try {
    await requireAuthenticatedCaller(
      new Request("https://local.invalid", {
        headers: { authorization: "Bearer stale-token" },
      }),
      authDependencies([{ role: "admin", is_active: true }], {
        account_lifecycle: "deletion_pending",
        is_admin: true,
      }),
    );
    throw new Error("closed account must fail");
  } catch (error) {
    expectHttpError(error, 403, "closed account access");
  }
});

for (const scope of ["global", "club"] as const) {
  for (
    const scenario of [
      "aal1",
      "missing_amr",
      "untimestamped",
      "stale",
      "future",
      "fractional_time",
      "string_time",
      "too_many",
      "foreign_subject",
      "anonymous",
      "provider_anonymous",
      "missing_anonymous",
      "service_role",
      "expired",
      "missing_exp",
      "string_exp",
      "unsafe_exp",
      "dummy",
      "malformed_json",
    ] as const
  ) {
    Deno.test(`actual ${scope} staff guard rejects ${scenario} despite current grant and metadata hints`, async () => {
      const now = Math.floor(Date.now() / 1000);
      const changes: Record<string, unknown> = {};
      if (scenario === "aal1") changes.aal = "aal1";
      if (scenario === "missing_amr") changes.amr = undefined;
      if (
        ["untimestamped", "stale", "future", "fractional_time", "string_time"]
          .includes(scenario)
      ) {
        changes.amr = [{
          method: "totp",
          timestamp: scenario === "untimestamped"
            ? undefined
            : scenario === "stale"
            ? now - 301
            : scenario === "future"
            ? now + 31
            : scenario === "fractional_time"
            ? now - 0.5
            : String(now),
        }];
      }
      if (scenario === "too_many") {
        changes.amr = Array.from(
          { length: 17 },
          () => ({ method: "totp", timestamp: now }),
        );
      }
      if (scenario === "foreign_subject") changes.sub = "actor-foreign";
      if (scenario === "anonymous") changes.is_anonymous = true;
      if (scenario === "missing_anonymous") changes.is_anonymous = undefined;
      if (scenario === "service_role") changes.role = "service_role";
      if (scenario === "expired") changes.exp = now;
      if (scenario === "missing_exp") changes.exp = undefined;
      if (scenario === "string_exp") changes.exp = String(now + 600);
      if (scenario === "unsafe_exp") changes.exp = Number.MAX_SAFE_INTEGER + 1;
      const token = scenario === "dummy"
        ? "test-token"
        : scenario === "malformed_json"
        ? "e30.bm90LWpzb24.c2ln"
        : syntheticStaffJwt("actor-1", changes);
      const deps = authDependencies([{
        role: scope === "global" ? "admin" : "club_admin",
        club_id: 7,
        is_active: true,
      }], {
        aal: "aal2",
        mfa_verified: true,
        amr: [{ method: "totp", timestamp: now }],
      });
      const originalProvider = deps.createUserClient;
      let verified = 0;
      const currentDeps = {
        ...deps,
        createUserClient: (authorization: string) => {
          assertEquals(
            authorization,
            `Bearer ${token}`,
            "same bearer sent to provider client",
          );
          const client = originalProvider();
          return {
            auth: {
              getUser: async (jwt?: string) => {
                verified++;
                assertEquals(
                  jwt,
                  token,
                  "provider verifies exact same bearer JWT",
                );
                const result = await client.auth.getUser();
                if (scenario === "provider_anonymous") {
                  return {
                    ...result,
                    data: { user: { ...result.data.user, is_anonymous: true } },
                  };
                }
                return result;
              },
            },
          };
        },
      };
      try {
        if (scope === "global") {
          await requireAdminCaller(adminRequest(token), currentDeps);
        } else {await requireClubAdminCaller(
            adminRequest(token),
            7,
            currentDeps,
          );}
        throw new Error("unverified staff step-up accepted");
      } catch (error) {
        expectHttpError(error, 403, "invalid verified-token assurance");
      }
      assertEquals(verified, 1, "exact provider verification precedes denial");
    });
  }
}
Deno.test("valid timestamped mfa/totp authorizes current staff while aal1 supporter auth remains available", async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = syntheticStaffJwt("actor-1", {
    amr: [{ method: "mfa/totp", timestamp: now }],
  });
  assert(
    (await requireAdminCaller(
      adminRequest(token),
      authDependencies([{ role: "admin", is_active: true }]),
    )).isAdmin,
    "alternate canonical TOTP method admitted",
  );
  const supporter = await requireAuthenticatedCaller(
    adminRequest(syntheticStaffJwt("actor-1", { aal: "aal1", amr: [] })),
    authDependencies([]),
  );
  assertEquals(supporter.isAdmin, false, "supporter requires no staff MFA");
});
Deno.test("provider rejection prevents current assignment lookup and any MFA metadata fallback", async () => {
  let lookups = 0;
  try {
    await requireAdminCaller(adminRequest(), {
      createUserClient: () => ({
        auth: {
          getUser: async () => ({
            data: {
              user: {
                id: "actor-1",
                app_metadata: { aal: "aal2", mfa_verified: true },
              },
            },
            error: new Error("private provider refusal"),
          }),
        },
      }),
      createAdminClient: () => {
        lookups++;
        throw new Error("store must not be consulted");
      },
    });
    throw new Error("provider rejection accepted");
  } catch (error) {
    expectHttpError(error, 401, "invalid provider identity");
  }
  assertEquals(lookups, 0, "unverified bearer reaches no current-grant store");
});

Deno.test("staff assurance remains bound to the token verified before an asynchronous header change", async () => {
  const token = syntheticStaffJwt("actor-1", { aal: "aal1", amr: [] });
  const req = adminRequest(token);
  const deps = authDependencies([{ role: "admin", is_active: true }]);
  const provider = deps.createUserClient();
  try {
    await requireAdminCaller(req, {
      ...deps,
      createUserClient: () => ({
        auth: {
          getUser: async (jwt) => {
            assertEquals(jwt, token, "initial exact token verified");
            req.headers.set(
              "authorization",
              `Bearer ${syntheticStaffJwt("actor-1")}`,
            );
            return await provider.auth.getUser();
          },
        },
      }),
    });
    throw new Error("changed unverified bearer accepted");
  } catch (error) {
    expectHttpError(error, 403, "original verified token lacks MFA");
  }
});
