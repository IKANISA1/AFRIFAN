import { extractTrustedClubId, validateRequest } from "./validation.ts";
import { syntheticStaffJwt } from "./staff_auth_test_support.ts";

for (
  const scenario of ["invalid", "oversized", "malformed", "closed"] as const
) {
  Deno.test(`actual Auth verification is bounded and fail-closed: ${scenario}`, async () => {
    const originalFetch = globalThis.fetch;
    const values = {
      SUPABASE_URL: "https://qa.invalid",
      SUPABASE_ANON_KEY: "qa-publishable",
      SUPABASE_PUBLISHABLE_KEYS: "",
    };
    const previous = Object.fromEntries(
      Object.keys(values).map((key) => [key, Deno.env.get(key)]),
    );
    for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
    let calls = 0;
    globalThis.fetch = async (input, init) => {
      calls++;
      assertEquals(
        String(input),
        "https://qa.invalid/auth/v1/user",
        "only current Auth identity lookup",
      );
      assertEquals(
        init?.signal instanceof AbortSignal,
        true,
        "verification deadline reaches actual transport",
      );
      if (scenario === "invalid") {
        return Response.json({ message: "private Auth detail" }, {
          status: 401,
        });
      }
      if (scenario === "oversized") {
        return Response.json({
          id: "actor",
          secret: "x".repeat(128 * 1024),
        });
      }
      if (scenario === "malformed") {
        return new Response(
          "private provider detail",
          { headers: { "content-type": "application/json" } },
        );
      }
      return Response.json({
        id: "actor",
        app_metadata: { account_lifecycle: "deletion_pending", is_admin: true },
      });
    };
    try {
      const response = await validateRequest(
        new Request("https://qa.invalid/edge", {
          headers: { authorization: "Bearer actor-token" },
        }),
      );
      assertEquals(
        response instanceof Response,
        true,
        "unverified or closed account denied",
      );
      assertEquals(
        (response as Response).status,
        scenario === "invalid" ? 401 : scenario === "closed" ? 403 : 503,
        "stable Auth failure status",
      );
      assertEquals(
        (await (response as Response).text()).includes("private"),
        false,
        "provider details never reach callers",
      );
      assertEquals(
        calls,
        1,
        "failed verification reaches no expensive work or assignment store",
      );
    } finally {
      globalThis.fetch = originalFetch;
      for (const [key, value] of Object.entries(previous)) {
        if (value === undefined) Deno.env.delete(key);
        else Deno.env.set(key, value);
      }
    }
  });
}

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

Deno.test("extractTrustedClubId accepts only positive trusted app metadata ids", () => {
  assertEquals(extractTrustedClubId({ club_id: 42 }), "42", "numeric id");
  assertEquals(extractTrustedClubId({ club_id: " 42 " }), "42", "string id");
  for (
    const value of [
      null,
      "",
      "0",
      "-1",
      "1.5",
      "club-42",
      "9007199254740993",
      0,
      -1,
      1.5,
    ]
  ) {
    assertEquals(
      extractTrustedClubId({ club_id: value }),
      null,
      `invalid id ${String(value)}`,
    );
  }
});

Deno.test("tenant scope cannot be derived from user metadata", () => {
  const user = {
    app_metadata: {},
    user_metadata: { club_id: "999" },
  };
  assertEquals(
    extractTrustedClubId(user.app_metadata),
    null,
    "user metadata must not establish tenant scope",
  );
});

for (
  const scenario of [
    {
      name: "stale metadata global role",
      rows: [],
      options: { requireAdmin: true },
      status: 403,
    },
    {
      name: "current club grant cannot satisfy global validation",
      rows: [{ role: "club_admin", club_id: 7, is_active: true }],
      options: { requireAdmin: true },
      status: 403,
    },
    {
      name: "current global grant",
      rows: [{ role: "admin", is_active: true }],
      options: { requireAdmin: true },
      status: 200,
    },
    {
      name: "current scoped club grant",
      rows: [{ role: "club_admin", club_id: 7, is_active: true }],
      options: { requireClubAdmin: 7 },
      status: 200,
    },
    {
      name: "cross-club grant",
      rows: [{ role: "club_admin", club_id: 7, is_active: true }],
      options: { requireClubAdmin: 8 },
      status: 403,
    },
    {
      name: "revoked active metadata grant",
      rows: [{
        role: "admin",
        is_active: true,
        revoked_at: "2026-10-01T10:00:00Z",
      }],
      options: { requireAdmin: true },
      status: 403,
    },
  ]
) {
  Deno.test(`actual validation resolves assignment authority: ${scenario.name}`, async () => {
    const originalFetch = globalThis.fetch;
    const values: Record<string, string> = {
      SUPABASE_URL: "https://qa.invalid",
      SUPABASE_ANON_KEY: "qa-publishable",
      SUPABASE_SERVICE_ROLE_KEY: "qa-service",
      SUPABASE_PUBLISHABLE_KEYS: "",
      SUPABASE_SECRET_KEYS: "",
    };
    const previous = Object.fromEntries(
      Object.keys(values).map((key) => [key, Deno.env.get(key)]),
    );
    for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
    let assignmentLookups = 0;
    globalThis.fetch = async (input) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      assertEquals(
        url.origin,
        "https://qa.invalid",
        "external calls are disabled",
      );
      if (url.pathname === "/auth/v1/user") {
        return Response.json({
          id: "verified-actor",
          app_metadata: { role: "super_admin", is_admin: true, club_id: 7 },
        });
      }
      assertEquals(
        url.pathname,
        "/rest/v1/admin_role_assignments",
        "current assignment authority",
      );
      assertEquals(
        url.searchParams.get("user_id"),
        "eq.verified-actor",
        "verified identity scopes the query",
      );
      assignmentLookups++;
      return Response.json(scenario.rows);
    };
    try {
      const result = await validateRequest(
        new Request("https://qa.invalid/edge", {
          headers: {
            authorization: `Bearer ${syntheticStaffJwt("verified-actor")}`,
          },
        }),
        scenario.options,
      );
      assertEquals(
        result instanceof Response ? result.status : 200,
        scenario.status,
        "actual validation result",
      );
      assertEquals(
        assignmentLookups,
        1,
        "metadata never short-circuits the assignment lookup",
      );
    } finally {
      globalThis.fetch = originalFetch;
      for (const [key, value] of Object.entries(previous)) {
        if (value === undefined) Deno.env.delete(key);
        else Deno.env.set(key, value);
      }
    }
  });
}
