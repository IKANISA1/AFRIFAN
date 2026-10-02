import {
  processAccountClosures,
  requestAccountClosure,
} from "./account_lifecycle.ts";
function assert(value: unknown, message: string) {
  if (!value) throw new Error(message);
}
const requestId = "99963000-0000-4000-8000-000000000999";
Deno.test("request records durable pending receipt without irreversible Auth call", async () => {
  const calls: any[] = [];
  const client = {
    rpc: async (name: string, args?: any) => {
      calls.push({ name, args });
      return {
        data: {
          request_id: requestId,
          status: "deletion_pending",
          access_revoked: true,
          requested_at: "2026-10-01",
        },
        error: null,
      };
    },
  };
  const receipt = await requestAccountClosure(
    client,
    "verified-user",
    requestId,
  );
  assert(receipt.status === "deletion_pending", "acceptance is pending");
  assert(
    calls[0].args.p_user_id === "verified-user" &&
      calls[0].args.p_request_id === requestId,
    "verified identity and durable original capability passed to atomic RPC",
  );
  assert(
    calls.length === 1 && calls[0].name === "request_account_erasure",
    "no processor calls before durable receipt",
  );
});
function workerFixture(failure?: string, hasMore = false) {
  const calls: any[] = [];
  let remaining = true;
  const client = {
    rpc: async (name: string, args?: any) => {
      calls.push({ name, args });
      let data: any = {};
      if (name === "claim_account_erasure_jobs") {
        data = [{
          request_id: requestId,
          user_id: "verified-user",
          lease_token: "lease",
          steps: {
            local_data: "pending",
            storage: "pending",
            auth: "pending",
            processors: "pending",
            backups: "pending",
          },
        }];
      }
      if (name === "erase_account_local_batch") {
        if (failure === "local") {
          return { data: null, error: "private SQL detail" };
        }
        data = { has_more: hasMore };
      }
      if (name === "account_erasure_storage_batch") {
        data = remaining
          ? [{ bucket: "private", name: "private-avatar.png" }]
          : [];
      }
      return { data, error: null };
    },
    storage: {
      from: (bucket: string) => ({
        remove: async (names: string[]) => {
          calls.push({ name: "storage.remove", bucket, names });
          if (failure === "storage") {
            return { error: "private provider detail" };
          }
          remaining = false;
          return { error: null };
        },
      }),
    },
    auth: {
      admin: {
        deleteUser: async (user: string, soft: boolean) => {
          calls.push({ name: "auth.deleteUser", user, soft });
          return { error: failure === "auth" ? "private Auth detail" : null };
        },
      },
    },
  };
  return { client, calls };
}
Deno.test("worker calls actual Storage API then soft Auth delete and keeps external steps pending", async () => {
  const { client, calls } = workerFixture();
  const result = await processAccountClosures(client);
  assert(
    result.pending === 1 && result.failed === 0,
    "external work truthfully pending",
  );
  assert(
    calls.find((x) => x.name === "storage.remove")?.names[0] ===
      "private-avatar.png",
    "actual exact owned object removal",
  );
  assert(
    calls.find((x) => x.name === "auth.deleteUser")?.soft === true,
    "retained Auth subject uses soft deletion",
  );
  assert(
    calls.findIndex((x) => x.name === "storage.remove") <
      calls.findIndex((x) => x.name === "auth.deleteUser"),
    "storage acknowledgement precedes irreversible Auth call",
  );
  assert(
    !calls.some((x) => x.name === "acknowledge_account_erasure_obligation"),
    "never fabricate processor/backup acknowledgements",
  );
});
for (const failure of ["local", "storage", "auth"]) {
  Deno.test(`worker ${failure} failure is attributable and resumable`, async () => {
    const { client, calls } = workerFixture(failure);
    const result = await processAccountClosures(client);
    assert(result.failed === 1, "failure reported");
    const record = calls.find((x) =>
      x.name === "record_account_erasure_step" && x.args.p_success === false
    );
    assert(
      record?.args.p_step === (failure === "local" ? "local_data" : failure),
      "correct stage failure",
    );
    assert(
      calls.some((x) => x.name === "release_account_erasure_lease"),
      "lease released for resumable retry",
    );
    if (failure !== "auth") {
      assert(
        !calls.some((x) => x.name === "auth.deleteUser"),
        "Auth untouched until preceding steps complete",
      );
    }
  });
}
Deno.test("bounded local backlog defers Storage and Auth until local erasure completes", async () => {
  const { client, calls } = workerFixture(undefined, true);
  const result = await processAccountClosures(client);
  assert(result.pending === 1, "backlog retained");
  assert(
    !calls.some((x) =>
      x.name === "storage.remove" || x.name === "auth.deleteUser"
    ),
    "deferred external writes",
  );
});
