import {
  createMediaUploadAdminClient,
  executeMediaUpload,
  getMediaUploadStatus,
  type MediaAdminClient,
  mediaSha256,
  mediaStoragePath,
  type MediaUploadCommand,
  type MediaUploadReceipt,
  releaseUnadmittedMediaUpload,
  validateMediaUploadReceipt,
} from "./admin_media_upload.ts";
import { HttpError } from "./auth.ts";
function equal(a: unknown, b: unknown) {
  if (a !== b) throw Error(`Expected ${b}, got ${a}`);
}
async function rejects(fn: () => Promise<unknown>, status: number) {
  try {
    await fn();
  } catch (e) {
    if (e instanceof HttpError && e.status === status) return;
    throw e;
  }
  throw Error("Expected denial");
}
const actor = "99969000-0000-4000-8000-000000000001",
  operation = "99969000-0000-4000-8000-000000000701",
  object = "99969000-0000-4000-8000-000000000801",
  lease = "99969000-0000-4000-8000-000000000901",
  proof = "99969000-0000-4000-8000-000000001001";
const bytes = new Uint8Array([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  1,
]);
async function fixture(
  options: {
    committedThrow?: boolean;
    downloadUnavailable?: boolean;
    mismatch?: boolean;
    staged?: boolean;
    busy?: boolean;
    completionLost?: boolean;
    beginLost?: boolean;
    beginDenied?: boolean;
    uploadUnconfirmed?: boolean;
  } = {},
) {
  const command: MediaUploadCommand = {
    operationId: operation,
    actorId: actor,
    clubId: 24,
    kind: "shop_product",
    mimeType: "image/png",
    byteLength: bytes.length,
    contentSha256: await mediaSha256(bytes),
  };
  let state: MediaUploadReceipt["status"] = "pending",
    blob: Blob | null = options.mismatch
      ? new Blob([new Uint8Array(bytes.length)], { type: "image/png" })
      : null,
    uploads = 0,
    admissions = 0,
    reserved = false;
  const remote: string[] = [];
  const receipt = (): MediaUploadReceipt => ({
    operation_id: operation,
    actor_id: actor,
    club_id: 24,
    kind: command.kind,
    mime_type: command.mimeType,
    byte_length: bytes.length,
    content_sha256: command.contentSha256,
    bucket: "africlub-product-images",
    storage_path: mediaStoragePath(command),
    status: state,
    object_id: blob ? object : null,
  });
  const user = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      equal(name, "admit_admin_media_upload");
      equal(args.p_operation_id, operation);
      equal(args.p_content_sha256, command.contentSha256);
      equal(args.p_actor_id, undefined);
      admissions++;
      return { data: { ...receipt(), dispatch_proof_id: proof }, error: null };
    },
  };
  const admin: MediaAdminClient = {
    rpc: async (name, args) => {
      remote.push(name);
      if (name === "claim_admin_media_upload") {
        equal(args.p_dispatch_proof_id, proof);
        if (!options.busy) state = "uploading";
        return {
          data: {
            ...receipt(),
            claimed: !options.busy,
            lease_token: options.busy ? null : lease,
          },
          error: null,
        };
      }
      if (name === "begin_admin_media_upload") {
        equal(args.p_operation_id, operation);
        equal(args.p_lease_token, lease);
        if (options.beginDenied) {
          return { data: null, error: { code: "42501" } };
        }
        const permitted = !reserved;
        reserved = true;
        if (options.beginLost && permitted) throw Error("Lost begin ACK");
        return {
          data: {
            operation_id: operation,
            lease_token: lease,
            upload_permitted: permitted,
          },
          error: null,
        };
      }
      equal(name, "complete_admin_media_upload");
      equal(args.p_lease_token, lease);
      if (options.completionLost) {
        return {
          data: null,
          error: { code: "08006", message: "private SQL info" },
        };
      }
      if (args.p_outcome === "stored") {
        equal(args.p_object_id, object);
        equal(args.p_verified_sha256, command.contentSha256);
        state = options.staged ? "staged" : "completed";
      } else state = args.p_outcome as "unknown" | "failed";
      return { data: receipt(), error: null };
    },
    storage: {
      from: (bucket) => {
        equal(bucket, "africlub-product-images");
        return {
          upload: async (path, data, opts) => {
            remote.push("upload");
            uploads++;
            equal(path, mediaStoragePath(command));
            equal(opts.upsert, false);
            equal(opts.metadata.operation_id, operation);
            equal(opts.metadata.lease_token, lease);
            if (options.uploadUnconfirmed) return { error: { status: 503 } };
            blob = new Blob([new Uint8Array(data)], { type: opts.contentType });
            if (options.committedThrow) {
              throw Error("Lost response after commit");
            }
            return { error: null };
          },
          download: async (path) => {
            remote.push("download");
            equal(path, mediaStoragePath(command));
            if (options.downloadUnavailable) {
              return {
                data: null,
                error: { status: 503 },
              };
            }
            return blob
              ? { data: blob, error: null }
              : { data: null, error: { statusCode: "404" } };
          },
          info: async () => {
            remote.push("info");
            return { data: { id: object }, error: null };
          },
          getPublicUrl: () => {
            throw Error("URL is not evidence");
          },
        };
      },
    },
  };
  const run = () =>
    executeMediaUpload("Bearer original", command, bytes, {
      createUserClient: (auth) => {
        equal(auth, "Bearer original");
        return user;
      },
      createAdminClient: () => admin,
      enforceRateLimit: async (_client, id, name, config) => {
        equal(id, actor);
        equal(name, "admin-upload-image");
        equal(config.clubId, 24);
        remote.push("rate");
      },
      leaseId: () => lease,
    });
  return {
    command,
    run,
    remote,
    receipt,
    get uploads() {
      return uploads;
    },
    get admissions() {
      return admissions;
    },
  };
}
Deno.test("upload journals admission and private proof before Storage and verifies actual bytes", async () => {
  const f = await fixture();
  equal((await f.run()).status, "completed");
  equal(f.uploads, 1);
  equal(
    f.remote.join(","),
    "rate,claim_admin_media_upload,download,begin_admin_media_upload,upload,download,info,complete_admin_media_upload",
  );
  await f.run();
  equal(f.uploads, 1);
  equal(f.admissions, 2);
});
Deno.test("lost committed provider response recovers same object without another upload", async () => {
  const f = await fixture({ committedThrow: true });
  equal((await f.run()).status, "unknown");
  equal((await f.run()).status, "completed");
  equal(f.uploads, 1);
  equal(f.admissions, 2);
});
Deno.test("unknown object read never risks another upload or false acknowledgement", async () => {
  const f = await fixture({ downloadUnavailable: true });
  equal((await f.run()).status, "unknown");
  equal(f.uploads, 0);
});
Deno.test("unknown original upload never repeats cost when the object is still absent", async () => {
  const f = await fixture({ uploadUnconfirmed: true });
  equal((await f.run()).status, "unknown");
  equal((await f.run()).status, "unknown");
  equal(f.uploads, 1);
});
Deno.test("lost original begin ACK cannot grant an upload on retry", async () => {
  const f = await fixture({ beginLost: true });
  equal((await f.run()).status, "unknown");
  equal((await f.run()).status, "unknown");
  equal(f.uploads, 0);
});
Deno.test("original proof expiry at the begin boundary denies Storage cost", async () => {
  const f = await fixture({ beginDenied: true });
  equal((await f.run()).status, "unknown");
  equal(f.uploads, 0);
});
Deno.test("conflicting existing digest fails without replacing object", async () => {
  const f = await fixture({ mismatch: true });
  equal((await f.run()).status, "failed");
  equal(f.uploads, 0);
});
Deno.test("expired original proof after remote commit stays staged without success", async () => {
  const f = await fixture({ staged: true });
  equal((await f.run()).status, "staged");
  equal((await f.run()).status, "staged");
  equal(f.uploads, 1);
});
Deno.test("another active lease cannot initiate Storage", async () => {
  const f = await fixture({ busy: true });
  equal((await f.run()).status, "pending");
  equal(f.uploads, 0);
  equal(f.remote.join(","), "rate,claim_admin_media_upload");
});
Deno.test("lost completion RPC remains unknown with original operation", async () => {
  const f = await fixture({ completionLost: true });
  const r = await f.run();
  equal(r.status, "unknown");
  equal(r.operation_id, operation);
  equal(f.uploads, 1);
});
Deno.test("admission denial precedes any service or Storage call", async () => {
  const f = await fixture();
  let admin = false;
  await rejects(
    () =>
      executeMediaUpload("Bearer original", f.command, bytes, {
        createUserClient: () => ({
          rpc: async () => ({
            data: null,
            error: { code: "42501", message: "private identity" },
          }),
        }),
        createAdminClient: () => {
          admin = true;
          throw Error("No cost");
        },
      }),
    403,
  );
  equal(admin, false);
});
Deno.test("foreign and changed receipts fail before private service stage", async () => {
  const f = await fixture();
  for (
    const patch of [
      { actor_id: "99969000-0000-4000-8000-000000000002" },
      { club_id: 26 },
      { kind: "match" },
      { byte_length: 8 },
      { content_sha256: "b".repeat(64) },
      { storage_path: "club-26/forged.png" },
    ]
  ) {
    let cost = false;
    await rejects(
      () =>
        executeMediaUpload("Bearer original", f.command, bytes, {
          createUserClient: () => ({
            rpc: async () => ({
              data: { ...f.receipt(), ...patch },
              error: null,
            }),
          }),
          createAdminClient: () => {
            cost = true;
            throw Error("No cost");
          },
        }),
      502,
    );
    equal(cost, false);
  }
});
Deno.test("foreign private lease receipt never reaches Storage", async () => {
  const f = await fixture();
  let storage = false;
  await rejects(() =>
    executeMediaUpload("Bearer original", f.command, bytes, {
      createUserClient: () => ({
        rpc: async () => ({
          data: { ...f.receipt(), dispatch_proof_id: proof },
          error: null,
        }),
      }),
      createAdminClient: () => ({
        rpc: async () => ({
          data: { ...f.receipt(), claimed: true, lease_token: "foreign" },
          error: null,
        }),
        get storage(): MediaAdminClient["storage"] {
          storage = true;
          throw Error("No Storage");
        },
      }),
      enforceRateLimit: async () => {},
      leaseId: () => lease,
    }), 502);
  equal(storage, false);
});
Deno.test("unissued original status is null rather than fabricated pending", async () => {
  equal(
    await getMediaUploadStatus("Bearer original", operation, actor, {
      rpc: async (name, args) => {
        equal(name, "get_admin_media_upload_status");
        equal(args.p_operation_id, operation);
        return { data: null, error: null };
      },
    }),
    null,
  );
});
Deno.test("receipt strips private lease and session fields", async () => {
  const f = await fixture();
  const r = validateMediaUploadReceipt({
    ...f.receipt(),
    lease_token: lease,
    session_id: "private",
  }, f.command) as unknown as Record<string, unknown>;
  equal(r.lease_token, undefined);
  equal(r.session_id, undefined);
});

async function withSdkTransport(
  fetcher: typeof fetch,
  run: () => Promise<void>,
) {
  const previousFetch = globalThis.fetch;
  const env = {
    SUPABASE_URL: "https://example.test",
    SUPABASE_ANON_KEY: "synthetic-publishable",
    SUPABASE_SERVICE_ROLE_KEY: "synthetic-service",
  };
  const names = [
    ...Object.keys(env),
    "SUPABASE_PUBLISHABLE_KEYS",
    "SUPABASE_SECRET_KEYS",
  ];
  const previous = new Map(names.map((key) => [key, Deno.env.get(key)]));
  for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
  Deno.env.delete("SUPABASE_PUBLISHABLE_KEYS");
  Deno.env.delete("SUPABASE_SECRET_KEYS");
  globalThis.fetch = fetcher;
  try {
    await run();
  } finally {
    globalThis.fetch = previousFetch;
    for (const [key, value] of previous) {
      value === undefined ? Deno.env.delete(key) : Deno.env.set(key, value);
    }
  }
}

Deno.test("actual caller SDK admits immutable original bytes with same Bearer and no supplied authority", async () => {
  const f = await fixture();
  let calls = 0;
  await withSdkTransport(async (input, init) => {
    calls++;
    equal(
      String(input),
      "https://example.test/rest/v1/rpc/admit_admin_media_upload",
    );
    equal(
      new Headers(init?.headers).get("authorization"),
      "Bearer original-provider-verified-token",
    );
    equal(init?.signal instanceof AbortSignal, true);
    equal(
      JSON.stringify(JSON.parse(String(init?.body))),
      JSON.stringify({
        p_operation_id: operation,
        p_club_id: 24,
        p_kind: "shop_product",
        p_mime_type: "image/png",
        p_byte_length: 9,
        p_content_sha256: f.command.contentSha256,
      }),
    );
    return new Response(
      JSON.stringify({
        ...f.receipt(),
        status: "completed",
        object_id: object,
      }),
      {
        headers: { "content-type": "application/json" },
      },
    );
  }, async () => {
    const result = await executeMediaUpload(
      "Bearer original-provider-verified-token",
      f.command,
      bytes,
    );
    equal(result.operation_id, operation);
    equal(result.status, "completed");
    equal(calls, 1);
  });
});

Deno.test("actual service Storage SDK bounds streamed image bytes despite false Content-Length", async () => {
  let cancelled = false;
  let chunks = 0;
  await withSdkTransport(async (input, init) => {
    equal(
      String(input),
      `https://example.test/storage/v1/object/africlub-product-images/club-24/admin/shop_product/${operation}.png`,
    );
    equal(
      new Headers(init?.headers).get("authorization"),
      "Bearer synthetic-service",
    );
    equal(init?.signal instanceof AbortSignal, true);
    return new Response(
      new ReadableStream({
        pull(controller) {
          chunks++;
          controller.enqueue(new Uint8Array(1024 * 1024));
        },
        cancel() {
          cancelled = true;
        },
      }),
      { headers: { "content-type": "image/png", "content-length": "1" } },
    );
  }, async () => {
    const result = await createMediaUploadAdminClient().storage.from(
      "africlub-product-images",
    )
      .download(`club-24/admin/shop_product/${operation}.png`);
    equal(result.data, null);
    equal(result.error !== null, true);
    equal(cancelled, true);
    equal(chunks <= 7, true);
  });
});

Deno.test("actual service RPC SDK bounds streamed acknowledgements rather than accepting oversized JSON", async () => {
  let cancelled = false;
  await withSdkTransport(async (_input, init) => {
    equal(init?.signal instanceof AbortSignal, true);
    return new Response(
      new ReadableStream({
        start(controller) {
          controller.enqueue(new Uint8Array(64 * 1024 + 1));
        },
        cancel() {
          cancelled = true;
        },
      }),
      {
        headers: { "content-type": "application/json", "content-length": "1" },
      },
    );
  }, async () => {
    const result = await createMediaUploadAdminClient().rpc(
      "claim_admin_media_upload",
      {
        p_operation_id: operation,
        p_lease_token: lease,
        p_dispatch_proof_id: proof,
      },
    );
    equal(result.data, null);
    equal(result.error !== null, true);
    equal(cancelled, true);
  });
});

for (const loseCommitResponse of [false, true]) {
  Deno.test(`actual SDK upload/readback/info/receipt workflow preserves original operation after lost response=${loseCommitResponse}`, async () => {
    const f = await fixture();
    let state: MediaUploadReceipt["status"] = "pending";
    let committed: Uint8Array | null = null;
    let uploads = 0;
    let failedReadback = false;
    let reserved = false;
    const projection = () => ({
      ...f.receipt(),
      status: state,
      object_id: committed ? object : null,
    });
    await withSdkTransport(async (input, init) => {
      const url = new URL(String(input));
      const headers = new Headers(init?.headers);
      equal(init?.signal instanceof AbortSignal, true);
      const json = (value: unknown, status = 200) =>
        new Response(JSON.stringify(value), {
          status,
          headers: { "content-type": "application/json" },
        });
      if (url.pathname.startsWith("/rest/v1/rpc/")) {
        const args = JSON.parse(String(init?.body));
        if (url.pathname.endsWith("/admit_admin_media_upload")) {
          equal(
            headers.get("authorization"),
            "Bearer original-provider-verified-token",
          );
          equal(args.p_operation_id, operation);
          equal(args.p_content_sha256, f.command.contentSha256);
          return json({ ...projection(), dispatch_proof_id: proof });
        }
        equal(headers.get("authorization"), "Bearer synthetic-service");
        if (url.pathname.endsWith("/consume_edge_rate_limit")) {
          equal(
            args.p_bucket_key,
            JSON.stringify([actor, "admin-upload-image", 24]),
          );
          return json([{ allowed: true, retry_after_seconds: 0 }]);
        }
        equal(args.p_operation_id, operation);
        equal(args.p_lease_token, lease);
        if (url.pathname.endsWith("/claim_admin_media_upload")) {
          equal(args.p_dispatch_proof_id, proof);
          state = "uploading";
          return json({ ...projection(), claimed: true, lease_token: lease });
        }
        if (url.pathname.endsWith("/begin_admin_media_upload")) {
          const permitted = !reserved;
          reserved = true;
          return json({
            operation_id: operation,
            lease_token: lease,
            upload_permitted: permitted,
          });
        }
        equal(url.pathname.endsWith("/complete_admin_media_upload"), true);
        if (args.p_outcome === "stored") {
          equal(args.p_object_id, object);
          equal(args.p_verified_sha256, f.command.contentSha256);
          state = "completed";
        } else {
          equal(args.p_outcome, "unknown");
          state = "unknown";
        }
        return json(projection());
      }
      equal(headers.get("authorization"), "Bearer synthetic-service");
      if (
        url.pathname ===
          `/storage/v1/object/africlub-product-images/${
            mediaStoragePath(f.command)
          }`
      ) {
        if (init?.method === "POST") {
          uploads++;
          equal(headers.get("x-upsert"), "false");
          const metadata = JSON.parse(atob(headers.get("x-metadata") ?? ""));
          equal(metadata.operation_id, operation);
          equal(metadata.lease_token, lease);
          equal(metadata.content_sha256, f.command.contentSha256);
          equal(init.body instanceof Uint8Array, true);
          committed = new Uint8Array(init.body as Uint8Array);
          equal(await mediaSha256(committed), f.command.contentSha256);
          if (loseCommitResponse) {
            throw Error("Synthetic response lost after object commit");
          }
          return json({
            Id: object,
            Key: `africlub-product-images/${mediaStoragePath(f.command)}`,
          });
        }
        if (!committed) {
          return json({ statusCode: "404", message: "Absent" }, 404);
        }
        if (loseCommitResponse && !failedReadback) {
          failedReadback = true;
          return json({
            statusCode: "503",
            message: "Synthetic read unavailable",
          }, 503);
        }
        return new Response(new Uint8Array(committed), {
          headers: { "content-type": "image/png" },
        });
      }
      equal(
        url.pathname,
        `/storage/v1/object/info/africlub-product-images/${
          mediaStoragePath(f.command)
        }`,
      );
      return json({ id: object });
    }, async () => {
      const run = () =>
        executeMediaUpload(
          "Bearer original-provider-verified-token",
          f.command,
          bytes,
          { leaseId: () => lease },
        );
      equal((await run()).status, loseCommitResponse ? "unknown" : "completed");
      equal((await run()).status, "completed");
      equal(uploads, 1);
    });
  });
}

for (
  const boundary of [
    "claim_denied",
    "begin_lost",
    "upload_unknown",
    "begin_foreign",
  ]
) {
  Deno.test(`actual SDK original proof and durable attempt boundary ${boundary}`, async () => {
    const f = await fixture();
    let reserved = false;
    let uploads = 0;
    let reads = 0;
    let state: MediaUploadReceipt["status"] = "pending";
    await withSdkTransport(async (input, init) => {
      const url = new URL(String(input));
      const headers = new Headers(init?.headers);
      const json = (value: unknown, status = 200) =>
        Response.json(value, { status });
      const projection = () => ({ ...f.receipt(), status: state });
      if (url.pathname.startsWith("/rest/v1/rpc/")) {
        const args = JSON.parse(String(init?.body));
        if (url.pathname.endsWith("/admit_admin_media_upload")) {
          equal(
            headers.get("authorization"),
            "Bearer provider-verified-original",
          );
          equal(args.p_operation_id, operation);
          equal(args.p_dispatch_proof_id, undefined);
          equal(args.p_actor_id, undefined);
          return json({ ...projection(), dispatch_proof_id: proof });
        }
        equal(headers.get("authorization"), "Bearer synthetic-service");
        if (url.pathname.endsWith("/consume_edge_rate_limit")) {
          return json([{ allowed: true, retry_after_seconds: 0 }]);
        }
        equal(args.p_operation_id, operation);
        equal(args.p_lease_token, lease);
        if (url.pathname.endsWith("/claim_admin_media_upload")) {
          equal(args.p_dispatch_proof_id, proof);
          if (boundary === "claim_denied") {
            return json({
              code: "42501",
              message: "private original session data",
            }, 403);
          }
          state = "uploading";
          return json({ ...projection(), claimed: true, lease_token: lease });
        }
        if (url.pathname.endsWith("/begin_admin_media_upload")) {
          const permitted = !reserved;
          reserved = true;
          if (boundary === "begin_lost" && permitted) {
            throw Error("Lost first reservation ACK");
          }
          return json({
            operation_id: boundary === "begin_foreign" ? object : operation,
            lease_token: lease,
            upload_permitted: permitted,
          });
        }
        equal(url.pathname.endsWith("/complete_admin_media_upload"), true);
        equal(args.p_outcome, "unknown");
        equal(args.p_object_id, null);
        equal(args.p_verified_sha256, null);
        state = "unknown";
        return json(projection());
      }
      equal(headers.get("authorization"), "Bearer synthetic-service");
      equal(
        url.pathname,
        `/storage/v1/object/africlub-product-images/${
          mediaStoragePath(f.command)
        }`,
      );
      if (init?.method === "POST") {
        uploads++;
        equal(headers.get("x-upsert"), "false");
        const metadata = JSON.parse(atob(headers.get("x-metadata") ?? ""));
        equal(metadata.operation_id, operation);
        equal(metadata.dispatch_proof_id, undefined);
        return json({ statusCode: "503", message: "Unconfirmed object" }, 503);
      }
      reads++;
      return json({ statusCode: "404", message: "Absent" }, 404);
    }, async () => {
      const run = () =>
        executeMediaUpload(
          "Bearer provider-verified-original",
          f.command,
          bytes,
          { leaseId: () => lease },
        );
      if (boundary === "claim_denied") {
        await rejects(run, 403);
        equal(reads, 0);
        equal(uploads, 0);
      } else {
        for (let n = 0; n < 2; n++) {
          const result = await run();
          equal(result.operation_id, operation);
          equal(result.status, "unknown");
          equal(
            (result as unknown as Record<string, unknown>).dispatch_proof_id,
            undefined,
          );
        }
        equal(uploads, boundary === "upload_unknown" ? 1 : 0);
      }
    });
  });
}

Deno.test("actual caller SDK replays an unadmitted release original after lost acknowledgement without service or Storage", async () => {
  let calls = 0;
  await withSdkTransport(async (input, init) => {
    calls++;
    equal(
      String(input),
      "https://example.test/rest/v1/rpc/release_unadmitted_admin_media_upload",
    );
    equal(
      new Headers(init?.headers).get("authorization"),
      "Bearer original-provider-verified-token",
    );
    equal(init?.signal instanceof AbortSignal, true);
    equal(
      JSON.stringify(JSON.parse(String(init?.body))),
      JSON.stringify({
        p_operation_id: operation,
        p_club_id: 24,
      }),
    );
    if (calls === 1) throw Error("Synthetic lost release response");
    return new Response(
      JSON.stringify({
        operation_id: operation,
        actor_id: actor,
        club_id: 24,
        released: true,
        private_session: "never expose",
      }),
      { headers: { "content-type": "application/json" } },
    );
  }, async () => {
    const run = () =>
      releaseUnadmittedMediaUpload(
        "Bearer original-provider-verified-token",
        operation,
        actor,
        24,
      );
    await rejects(run, 503);
    const result = await run();
    equal(result.operation_id, operation);
    equal(result.released, true);
    equal(
      (result as unknown as Record<string, unknown>).private_session,
      undefined,
    );
    equal(calls, 2);
  });
});

for (
  const patch of [
    { operation_id: "99969000-0000-4000-8000-000000000702" },
    { actor_id: "99969000-0000-4000-8000-000000000002" },
    { club_id: 26 },
    { released: false },
    { released: "true" },
  ]
) {
  Deno.test(`release acknowledgement rejects changed binding ${JSON.stringify(patch)}`, async () => {
    await rejects(
      () =>
        releaseUnadmittedMediaUpload("Bearer original", operation, actor, 24, {
          rpc: async () => ({
            data: {
              operation_id: operation,
              actor_id: actor,
              club_id: 24,
              released: true,
              ...patch,
            },
            error: null,
          }),
        }),
      502,
    );
  });
}
Deno.test("admitted and foreign release SQL denials never become release acknowledgement", async () => {
  for (const code of ["22023", "42501"]) {
    await rejects(
      () =>
        releaseUnadmittedMediaUpload("Bearer original", operation, actor, 24, {
          rpc: async () => ({
            data: null,
            error: { code, message: "private command/storage details" },
          }),
        }),
      code === "42501" ? 403 : 409,
    );
  }
});
