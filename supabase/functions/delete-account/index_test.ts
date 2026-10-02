import { createHandler } from "./index.ts";
import { HttpError } from "../_shared/auth.ts";
function assert(value: unknown, message: string) {
  if (!value) throw new Error(message);
}
const id = "99963000-0000-4000-8000-000000000999";
function fixture({ user = true, rpcError = false, limited = false } = {}) {
  const calls: any[] = [];
  const admin = {
    rpc: async (name: string, args: any) => {
      calls.push({ name, args });
      return {
        data: {
          request_id: args.p_request_id,
          status: "deletion_pending",
          access_revoked: true,
        },
        error: rpcError ? "private SQL information" : null,
      };
    },
  };
  const handler = createHandler(
    {
      createAdminClient: () => admin,
      createUserClient: () => ({
        auth: {
          getUser: async () => ({
            data: { user: user ? { id: "verified-user" } : null },
            error: null,
          }),
        },
      }),
      enforceRateLimit: async () => {
        if (limited) {
          throw new HttpError(429, "Too many requests", {
            "Retry-After": "60",
          });
        }
      },
      requireCronSecret: () => {
        throw new HttpError(401, "Unauthorized.");
      },
    } as any,
  );
  return { handler, calls };
}
function request(body: any = {}, action = "request") {
  return new Request("https://local.invalid/delete-account?action=" + action, {
    method: "POST",
    headers: {
      authorization: "Bearer original",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}
Deno.test("actual closure request authenticates own subject and returns 202 pending receipt", async () => {
  const { handler, calls } = fixture();
  const response = await handler(
    request({ user_id: "verified-user", request_id: id }),
  );
  const body = await response.json();
  assert(
    response.status === 202 && body.data.status === "deletion_pending",
    "truthful pending acceptance",
  );
  assert(
    calls[0].args.p_user_id === "verified-user" &&
      calls[0].args.p_request_id === id,
    "server identity and original capability",
  );
  assert(
    response.headers.get("cache-control") === "private, no-store",
    "private receipt",
  );
});
Deno.test("foreign requested account cannot mutate erasure jobs", async () => {
  const { handler, calls } = fixture();
  assert(
    (await handler(request({ user_id: "foreign" }))).status === 403,
    "foreign denied",
  );
  assert(!calls.length, "no lifecycle mutation");
});
Deno.test("missing current Auth identity denies closure before RPC", async () => {
  const { handler, calls } = fixture({ user: false });
  assert(
    (await handler(request())).status === 401,
    "invalid current Auth denied",
  );
  assert(!calls.length, "no lifecycle mutation");
});
Deno.test("provider/SQL failure returns stable private error and does not claim deleted", async () => {
  const { handler } = fixture({ rpcError: true });
  const response = await handler(request({ request_id: id }));
  const body = await response.text();
  assert(
    response.status === 503 && !body.includes("private SQL") &&
      !body.includes("success"),
    "failed request has no false acknowledgement",
  );
});
Deno.test("closure 429 preserves Retry-After without lifecycle mutation", async () => {
  const { handler, calls } = fixture({ limited: true });
  const response = await handler(request());
  assert(
    response.status === 429 && response.headers.get("retry-after") === "60",
    "quota semantics preserved",
  );
  assert(!calls.length, "no mutation");
});
Deno.test("status accepts only opaque original UUID capability and worker requires secret", async () => {
  const { handler, calls } = fixture();
  assert(
    (await handler(request({ request_id: "1" }, "status"))).status === 400,
    "guessable numeric status identifier rejected",
  );
  assert(
    (await handler(request({}, "process"))).status === 401,
    "worker secret required",
  );
  assert(!calls.length, "unauthorized consumers cannot reach service RPC");
});
Deno.test("original status capability recovers after Auth revocation without exposing user identity", async () => {
  const { handler, calls } = fixture({ user: false });
  const response = await handler(request({ request_id: id }, "status"));
  const body = await response.json();
  assert(
    response.status === 200 && body.data.request_id === id &&
      body.data.access_revoked === true,
    "issued capability recovers narrow status",
  );
  assert(
    calls.length === 1 && calls[0].name === "get_account_erasure_status" &&
      calls[0].args.p_request_id === id,
    "only capability status RPC reached",
  );
  assert(
    !JSON.stringify(body).includes("verified-user") &&
      !("user_id" in body.data),
    "no subject or tenant details exposed",
  );
});
