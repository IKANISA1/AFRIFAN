import { createAdminUploadImageHandler } from "./index.ts";
import { HttpError } from "../_shared/auth.ts";
import { syntheticStaffJwt } from "../_shared/staff_auth_test_support.ts";
import {
  mediaStoragePath,
  type MediaUploadCommand,
  type MediaUploadReceipt,
} from "../_shared/admin_media_upload.ts";
function equal(a: unknown, b: unknown) {
  if (a !== b) throw new Error(`Expected ${b}, got ${a}`);
}
const actor = "99969000-0000-4000-8000-000000000001";
const operation = "99969000-0000-4000-8000-000000000701";
const object = "99969000-0000-4000-8000-000000000801";
const png = btoa(
  String.fromCharCode(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1),
);
const body = {
  operation_id: operation,
  club_id: 24,
  kind: "shop_product",
  mime_type: "image/png",
  image_data_base64: png,
};
function request(value: unknown = body) {
  return new Request("https://example.test", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer original",
    },
    body: typeof value === "string" ? value : JSON.stringify(value),
  });
}
const defaults = {
  requireAuthenticatedCaller: async () => ({ userId: actor } as never),
  requireClubAdminCaller: async () => ({ userId: actor } as never),
  mediaUploadResponse: (r: MediaUploadReceipt) =>
    r.status === "completed"
      ? { ...r, image_url: `https://storage.test/${r.storage_path}` }
      : r,
};
function receipt(
  c: MediaUploadCommand,
  status: MediaUploadReceipt["status"] = "completed",
): MediaUploadReceipt {
  return {
    operation_id: c.operationId,
    actor_id: c.actorId,
    club_id: c.clubId,
    kind: c.kind,
    mime_type: c.mimeType,
    byte_length: c.byteLength,
    content_sha256: c.contentSha256,
    bucket: "africlub-product-images",
    storage_path: mediaStoragePath(c),
    status,
    object_id: status === "completed" ? object : null,
  };
}
Deno.test("upload binds original operation, verified actor and exact server bytes", async () => {
  let calls = 0;
  const response = await createAdminUploadImageHandler({
    ...defaults,
    requireClubAdminCaller: async (_r, club) => {
      equal(club, 24);
      return { userId: actor } as never;
    },
    executeMediaUpload: async (auth, c, bytes) => {
      calls++;
      equal(auth, "Bearer original");
      equal(c.operationId, operation);
      equal(c.actorId, actor);
      equal(c.byteLength, bytes.length);
      equal(c.contentSha256.length, 64);
      return receipt(c);
    },
  })(request());
  equal(response.status, 200);
  equal(calls, 1);
  const result = await response.json();
  equal(result.operation_id, operation);
  equal(result.storage_path, `club-24/admin/shop_product/${operation}.png`);
  equal(response.headers.get("cache-control"), "private, no-store");
});
for (
  const status of [
    "pending",
    "uploading",
    "unknown",
    "staged",
    "failed",
  ] as const
) {
  Deno.test(`upload exposes ${status} without public URL`, async () => {
    const response = await createAdminUploadImageHandler({
      ...defaults,
      executeMediaUpload: async (_a, c) => receipt(c, status),
    })(request());
    equal(response.status, status === "failed" ? 409 : 202);
    const result = await response.json();
    equal(result.status, status);
    equal(result.image_url, undefined);
  });
}
for (
  const operation_id of [
    undefined,
    "bad",
    "99969000-0000-1000-8000-000000000701",
  ]
) {
  Deno.test(`upload requires original v4 operation ${operation_id}`, async () => {
    let mutation = false;
    const response = await createAdminUploadImageHandler({
      ...defaults,
      executeMediaUpload: async () => {
        mutation = true;
        throw Error("No mutation");
      },
    })(request({ ...body, operation_id }));
    equal(response.status, 400);
    equal(mutation, false);
  });
}
for (const club_id of ["24extra", "24.5", "24e2", "24/../26", 24.5, null]) {
  Deno.test(`upload rejects ambiguous club ${JSON.stringify(club_id)}`, async () => {
    let authorized = false;
    const response = await createAdminUploadImageHandler({
      ...defaults,
      requireClubAdminCaller: async () => {
        authorized = true;
        return {} as never;
      },
      executeMediaUpload: async () => {
        throw Error("No mutation");
      },
    })(request({ ...body, club_id }));
    equal(response.status, 400);
    equal(authorized, false);
  });
}
for (const value of ["{broken", "null", "[]"]) {
  Deno.test(`upload rejects malformed body ${value}`, async () => {
    const response = await createAdminUploadImageHandler({
      ...defaults,
      executeMediaUpload: async () => {
        throw Error("No mutation");
      },
    })(request(value));
    equal(response.status, 400);
  });
}
Deno.test("MIME spoof never reaches admitted Storage", async () => {
  let called = false;
  const response = await createAdminUploadImageHandler({
    ...defaults,
    executeMediaUpload: async () => {
      called = true;
      throw Error("No mutation");
    },
  })(request({ ...body, image_data_base64: btoa("not PNG") }));
  equal(response.status, 400);
  equal(called, false);
});
Deno.test("foreign club rejection never reaches admission", async () => {
  let called = false;
  const response = await createAdminUploadImageHandler({
    ...defaults,
    requireClubAdminCaller: async () => {
      throw new HttpError(403, "Club denied");
    },
    executeMediaUpload: async () => {
      called = true;
      throw Error("No mutation");
    },
  })(request({ ...body, club_id: 26 }));
  equal(response.status, 403);
  equal(called, false);
});
Deno.test("status recovers original owner without bytes or new command", async () => {
  const pending: MediaUploadReceipt = {
    operation_id: operation,
    actor_id: actor,
    club_id: 24,
    kind: "shop_product",
    mime_type: "image/png",
    byte_length: 9,
    content_sha256: "a".repeat(64),
    bucket: "africlub-product-images",
    storage_path: `club-24/admin/shop_product/${operation}.png`,
    status: "unknown",
    object_id: null,
  };
  const response = await createAdminUploadImageHandler({
    ...defaults,
    getMediaUploadStatus: async (auth, id, user) => {
      equal(auth, "Bearer original");
      equal(id, operation);
      equal(user, actor);
      return pending;
    },
    executeMediaUpload: async () => {
      throw Error("No upload");
    },
  })(request({ operation_id: operation, mode: "status" }));
  equal(response.status, 202);
  equal((await response.json()).image_url, undefined);
});
Deno.test("unissued or foreign status returns404 rather than invented pending", async () => {
  const response = await createAdminUploadImageHandler({
    ...defaults,
    getMediaUploadStatus: async () => null,
  })(request({ operation_id: operation, mode: "status" }));
  equal(response.status, 404);
});
Deno.test("upload retains original Bearer across authorization await", async () => {
  const input = request();
  const response = await createAdminUploadImageHandler({
    ...defaults,
    requireClubAdminCaller: async () => {
      input.headers.set("authorization", "Bearer replacement");
      return {} as never;
    },
    executeMediaUpload: async (auth, c) => {
      equal(auth, "Bearer original");
      return receipt(c);
    },
  })(input);
  equal(response.status, 200);
});
Deno.test("unauthenticated upload never consumes large input", async () => {
  const input = new Request("https://example.test", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "content-length": "99999999",
    },
    body: "{}",
  });
  const response = await createAdminUploadImageHandler()(input);
  equal(response.status, 401);
  equal(input.bodyUsed, false);
});

for (const mode of ["upload", "release"] as const) {
  for (
    const scenario of [
      "club",
      "global",
      "stale",
      "missing",
      "foreign-subject",
      "provider-failure",
      "foreign-club",
      "revoked",
      "closure-pending",
    ] as const
  ) {
    Deno.test(`actual ${mode} caller JWT and current assignment ${scenario} before admission/Storage`, async () => {
      const now = Math.floor(Date.now() / 1000);
      const token = syntheticStaffJwt(
        actor,
        scenario === "stale"
          ? { amr: [{ method: "totp", timestamp: now - 301 }] }
          : scenario === "missing"
          ? { aal: "aal1", amr: [{ method: "password", timestamp: now }] }
          : scenario === "foreign-subject"
          ? { sub: "99969000-0000-4000-8000-000000000002" }
          : {},
      );
      const authorization = `Bearer ${token}`;
      const previousFetch = globalThis.fetch;
      const env = {
        SUPABASE_URL: "https://example.test",
        SUPABASE_ANON_KEY: "synthetic-publishable",
        SUPABASE_SERVICE_ROLE_KEY: "synthetic-service",
      };
      const previous = new Map(
        [
          ...Object.keys(env),
          "SUPABASE_PUBLISHABLE_KEYS",
          "SUPABASE_SECRET_KEYS",
        ]
          .map((key) => [key, Deno.env.get(key)]),
      );
      for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
      Deno.env.delete("SUPABASE_PUBLISHABLE_KEYS");
      Deno.env.delete("SUPABASE_SECRET_KEYS");
      let admissions = 0;
      let storageCalls = 0;
      globalThis.fetch = async (input, init) => {
        const url = new URL(String(input));
        const headers = new Headers(init?.headers);
        equal(
          init?.signal instanceof AbortSignal ||
            url.pathname.endsWith("admin_role_assignments"),
          true,
        );
        if (url.pathname === "/auth/v1/user") {
          equal(headers.get("authorization"), authorization);
          return new Response(
            JSON.stringify(
              scenario === "provider-failure"
                ? {
                  code: "bad_jwt",
                  message: "Synthetic private provider failure",
                }
                : {
                  id: actor,
                  is_anonymous: false,
                  app_metadata: scenario === "closure-pending"
                    ? { account_lifecycle: "deletion_pending" }
                    : { is_admin: true },
                },
            ),
            {
              status: scenario === "provider-failure" ? 401 : 200,
              headers: { "content-type": "application/json" },
            },
          );
        }
        if (url.pathname === "/rest/v1/admin_role_assignments") {
          equal(headers.get("authorization"), "Bearer synthetic-service");
          equal(url.searchParams.get("user_id"), `eq.${actor}`);
          return new Response(
            JSON.stringify(
              scenario === "revoked" ? [] : [{
                role: scenario === "global" ? "super_admin" : "club_admin",
                club_id: scenario === "global"
                  ? null
                  : scenario === "foreign-club"
                  ? 26
                  : 24,
                is_active: true,
                revoked_at: null,
              }],
            ),
            { headers: { "content-type": "application/json" } },
          );
        }
        if (
          url.pathname ===
            `/rest/v1/rpc/${
              mode === "release"
                ? "release_unadmitted_admin_media_upload"
                : "admit_admin_media_upload"
            }`
        ) {
          admissions++;
          equal(headers.get("authorization"), authorization);
          const args = JSON.parse(String(init?.body));
          equal(args.p_actor_id, undefined);
          equal(args.p_operation_id, operation);
          if (mode === "release") {
            equal(args.p_club_id, 24);
            equal(Object.keys(args).length, 2);
            return new Response(
              JSON.stringify({
                operation_id: operation,
                actor_id: actor,
                club_id: 24,
                released: true,
              }),
              {
                headers: { "content-type": "application/json" },
              },
            );
          }
          return new Response(
            JSON.stringify(receipt({
              operationId: args.p_operation_id,
              actorId: actor,
              clubId: args.p_club_id,
              kind: args.p_kind,
              mimeType: args.p_mime_type,
              byteLength: args.p_byte_length,
              contentSha256: args.p_content_sha256,
            })),
            { headers: { "content-type": "application/json" } },
          );
        }
        storageCalls++;
        throw Error("Denied caller must not reach private stage or Storage");
      };
      try {
        const input = request(
          mode === "release"
            ? { mode: "release", operation_id: operation, club_id: 24 }
            : body,
        );
        input.headers.set("authorization", authorization);
        const response = await createAdminUploadImageHandler()(input);
        const accepted = scenario === "club" || scenario === "global";
        equal(
          response.status,
          accepted ? 200 : scenario === "provider-failure" ? 401 : 403,
        );
        equal(admissions, accepted ? 1 : 0);
        equal(storageCalls, 0);
        const result = await response.json();
        equal(result.operation_id, accepted ? operation : undefined);
        equal(
          result.released,
          accepted && mode === "release" ? true : undefined,
        );
        equal(
          JSON.stringify(result).includes("Synthetic private provider failure"),
          false,
        );
      } finally {
        globalThis.fetch = previousFetch;
        for (const [key, value] of previous) {
          value === undefined ? Deno.env.delete(key) : Deno.env.set(key, value);
        }
      }
    });
  }
}
