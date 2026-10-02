import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  admitVerifiedStaffCommand,
  type StaffCommand,
} from "./staff_command.ts";
import { HttpError } from "./auth.ts";

const actor = "99967000-0000-4000-8000-000000000001";
const command: StaffCommand = {
  operationId: "99967000-0000-4000-8000-000000000701",
  action: "fixture_settle",
  resourceId: "99967000-0000-4000-8000-000000000301",
  arguments: {
    home_score: 2,
    away_score: 1,
    ht_home_score: null,
    ht_away_score: null,
  },
};
const receipt = () => ({
  operation_id: command.operationId,
  actor_id: actor,
  action: command.action,
  resource_id: command.resourceId,
  club_id: null,
  status: "admitted",
  expires_at: new Date(Date.now() + 60_000).toISOString(),
});

Deno.test("actual bounded authenticated SDK admits the original command without actor or MFA parameters", async () => {
  const priorFetch = globalThis.fetch;
  const priorEnv = Object.fromEntries(
    ["SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS"].map((
      k,
    ) => [k, Deno.env.get(k)]),
  );
  Deno.env.set("SUPABASE_URL", "https://example.test");
  Deno.env.set("SUPABASE_ANON_KEY", "synthetic-publishable");
  Deno.env.delete("SUPABASE_PUBLISHABLE_KEYS");
  let called = 0;
  globalThis.fetch = async (input, init) => {
    called++;
    assertEquals(
      String(input),
      "https://example.test/rest/v1/rpc/admit_verified_staff_command",
    );
    assertEquals(
      new Headers(init?.headers).get("authorization"),
      "Bearer original-provider-verified-token",
    );
    assertEquals(JSON.parse(String(init?.body)), {
      p_operation_id: command.operationId,
      p_action: command.action,
      p_resource_id: command.resourceId,
      p_arguments: command.arguments,
    });
    assertEquals(init?.signal instanceof AbortSignal, true);
    return new Response(JSON.stringify(receipt()), {
      headers: { "content-type": "application/json" },
    });
  };
  try {
    assertEquals(
      (await admitVerifiedStaffCommand(
        "Bearer original-provider-verified-token",
        actor,
        command,
      )).operation_id,
      command.operationId,
    );
    assertEquals(called, 1);
  } finally {
    globalThis.fetch = priorFetch;
    for (const [key, value] of Object.entries(priorEnv)) {
      value == null ? Deno.env.delete(key) : Deno.env.set(key, value);
    }
  }
});

for (
  const [field, value] of [
    ["operation_id", "foreign-operation"],
    ["actor_id", "foreign-user"],
    ["resource_id", "foreign-fixture"],
    ["action", "predict_legacy_settle"],
    ["club_id", 7],
    ["status", "unknown"],
    ["expires_at", "not-a-time"],
    ["expires_at", new Date(0).toISOString()],
  ] as const
) {
  Deno.test(`admission rejects wrong or expired ${field} acknowledgement`, async () => {
    const error = await assertRejects(
      () =>
        admitVerifiedStaffCommand("Bearer original", actor, command, {
          createUserClient: () => ({
            rpc: async () => ({
              data: { ...receipt(), [field]: value },
              error: null,
            }),
          }),
        }),
      HttpError,
    );
    assertEquals(error.status, 502);
  });
}

Deno.test("completed original command recovery accepts only its bound narrow receipt", async () => {
  const result = await admitVerifiedStaffCommand(
    "Bearer original",
    actor,
    command,
    {
      createUserClient: () => ({
        rpc: async () => ({
          data: { ...receipt(), status: "completed", expires_at: null },
          error: null,
        }),
      }),
    },
  );
  assertEquals(result.status, "completed");
});

for (
  const [code, expected] of [["42501", 403], ["P0001", 409], ["22023", 409], [
    "08006",
    502,
  ]] as const
) {
  Deno.test(`admission ${code} fails closed with private error detail`, async () => {
    const error = await assertRejects(
      () =>
        admitVerifiedStaffCommand("Bearer original", actor, command, {
          createUserClient: () => ({
            rpc: async () => ({
              data: null,
              error: { code, message: "private SQL/session detail" },
            }),
          }),
        }),
      HttpError,
    );
    assertEquals(error.status, expected);
    assertEquals(error.message.includes("private SQL"), false);
  });
}
