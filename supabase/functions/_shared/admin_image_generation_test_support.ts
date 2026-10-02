import { assertEquals } from "jsr:@std/assert";
import { mediaSha256 } from "./admin_media_upload.ts";
import { syntheticStaffJwt } from "./staff_auth_test_support.ts";
import type {
  GenerationCommand,
  GenerationReceipt,
} from "./admin_image_generation.ts";
export const generationActor = "99968000-0000-4000-8000-000000000001";
export const generationOperation = "99968000-0000-4000-8000-000000000002";
export const generationUpload = "99968000-0000-4000-8000-000000000003";
export const generationProof = "99968000-0000-4000-8000-000000000004";
export const generationObject = "99968000-0000-4000-8000-000000000005";
export const generationPublicObject = "99968000-0000-4000-8000-000000000007";
export const generationBytes = new Uint8Array([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  42,
]);
export const generationContext = {
  model: "gemini-2.5-flash-image",
  public_origin: "https://qa.invalid",
  prompt_used: "Synthetic original prompt",
  aspect_ratio: "16:9",
};
export const generationCommand: GenerationCommand = {
  operationId: generationOperation,
  actorId: generationActor,
  clubId: 24,
  domain: "admin_image",
  kind: "home_banner",
  request: {
    kind: "home_banner",
    prompt: "Synthetic",
    subject: null,
    aspectRatio: "16:9",
  },
};
export type GenerationHarnessOptions = {
  providerFailure?: boolean;
  lostClaim?: boolean;
  lostStageUpload?: boolean;
  publicationDenied?: boolean;
  stageMismatch?: boolean;
  invalidProvider?: boolean;
  targetConflict?: boolean;
  foreignAdmission?: boolean;
  forbiddenAssignment?: boolean;
  jwtOverrides?: Record<string, unknown>;
  authFailure?: boolean;
  rateLimited?: boolean;
  claimDenied?: boolean;
};
export async function generationHarness(
  options: GenerationHarnessOptions = {},
) {
  const names = {
    SUPABASE_URL: "https://qa.invalid",
    SUPABASE_ANON_KEY: "qa-publishable",
    SUPABASE_SERVICE_ROLE_KEY: "qa-service",
    SUPABASE_PUBLISHABLE_KEYS: "",
    SUPABASE_SECRET_KEYS: "",
    GEMINI_API_KEY: "qa-only",
    GEMINI_IMAGE_MODEL: "",
  };
  const previous = Object.fromEntries(
    Object.keys(names).map((k) => [k, Deno.env.get(k)]),
  );
  for (const [k, v] of Object.entries(names)) Deno.env.set(k, v);
  const originalFetch = globalThis.fetch;
  const token = syntheticStaffJwt(generationActor, options.jwtOverrides);
  const authorization = `Bearer ${token}`;
  const sha = await mediaSha256(generationBytes);
  let command = { ...generationCommand };
  let provider = 0;
  let published = 0;
  let started = false;
  let staged = false;
  let complete = false;
  let state: GenerationReceipt["status"] = "pending";
  let proof = generationProof;
  let privateLease = "";
  let publicLease = "";
  let providerContext = { ...generationContext };
  const calls: Array<
    {
      name: string;
      body: Record<string, unknown>;
      authorization: string | null;
    }
  > = [];
  function receipt(
    status: GenerationReceipt["status"] = state,
  ): GenerationReceipt {
    return {
      operation_id: command.operationId,
      actor_id: command.actorId,
      club_id: command.clubId,
      domain: command.domain,
      kind: command.kind,
      request: command.request,
      status,
      target_conflict: !!options.targetConflict,
      ...(status === "completed"
        ? {
          image_url:
            `https://qa.invalid/storage/v1/object/public/africlub-product-images/club-24/admin/${command.kind}/${generationUpload}.png`,
          storage_path: `club-24/admin/${command.kind}/${generationUpload}.png`,
          prompt_used: providerContext.prompt_used,
          model: providerContext.model,
          aspect_ratio: providerContext.aspect_ratio,
          club: "Synthetic Club",
          success: true as const,
        }
        : {}),
    };
  }
  const media = (status: string) => ({
    operation_id: generationUpload,
    actor_id: generationActor,
    club_id: 24,
    kind: command.kind,
    mime_type: "image/png",
    byte_length: 9,
    content_sha256: sha,
    bucket: "africlub-product-images",
    storage_path: `club-24/admin/${command.kind}/${generationUpload}.png`,
    status,
    object_id: published ? generationPublicObject : null,
  });
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    const headers = new Headers(init.headers);
    const method = init.method ?? "GET";
    if (url.hostname === "generativelanguage.googleapis.com") {
      provider++;
      assertEquals(started, true);
      assertEquals(headers.get("x-goog-api-key"), "qa-only");
      assertEquals(url.searchParams.has("key"), false);
      const b = JSON.parse(String(init.body));
      assertEquals(b.generationConfig.candidateCount, 1);
      assertEquals(b.contents[0].parts[0].text, providerContext.prompt_used);
      if (options.providerFailure) throw new Error("Unknown provider outcome");
      return Response.json({
        candidates: [{
          content: {
            parts: [{
              inlineData: {
                mimeType: options.invalidProvider
                  ? "image/svg+xml"
                  : "image/png",
                data: btoa(String.fromCharCode(...generationBytes)),
              },
            }],
          },
        }],
      });
    }
    assertEquals(url.origin, "https://qa.invalid");
    if (url.pathname === "/auth/v1/user") {
      assertEquals(headers.get("authorization"), authorization);
      return Response.json({ id: generationActor, is_anonymous: false }, {
        status: options.authFailure ? 401 : 200,
      });
    }
    if (url.pathname === "/rest/v1/admin_role_assignments") {
      return Response.json(
        options.forbiddenAssignment ? [] : [{
          role: "club_admin",
          club_id: 24,
          is_active: true,
          revoked_at: null,
        }],
      );
    }
    if (url.pathname.startsWith("/rest/v1/rpc/")) {
      const name = url.pathname.split("/").pop()!;
      const body = JSON.parse(String(init.body));
      calls.push({ name, body, authorization: headers.get("authorization") });
      const caller = [
        "admit_admin_image_generation",
        "get_admin_image_generation_status",
        "commit_admin_image_generation",
        "admit_admin_media_upload",
      ].includes(name);
      assertEquals(
        headers.get("authorization"),
        caller ? authorization : "Bearer qa-service",
      );
      if (name === "admit_admin_image_generation") {
        command = {
          ...command,
          operationId: body.p_operation_id,
          clubId: body.p_club_id,
          domain: body.p_domain,
          request: body.p_request,
          kind: body.p_domain === "admin_image"
            ? body.p_request.kind
            : body.p_request.productType === "news"
            ? "news_article"
            : "shop_product",
        };
        return Response.json({
          ...receipt(),
          actor_id: options.foreignAdmission
            ? "99968000-0000-4000-8000-000000000099"
            : generationActor,
          dispatch_proof_id: proof,
          brand_snapshot: {
            club_name: "Synthetic Club",
            primary_brand_colors: "blue",
            nickname_brand_identity: "Fans",
            country_name: "Rwanda",
            region: "East",
            league: "League",
          },
        });
      }
      if (name === "get_admin_image_generation_status") {
        return Response.json(
          body.p_operation_id === command.operationId ? receipt() : null,
        );
      }
      if (name === "claim_admin_image_generation") {
        assertEquals(body.p_dispatch_proof_id, proof);
        if (options.claimDenied) {
          return Response.json({
            code: "42501",
            message: "Original proof expired after wait",
          }, { status: 403 });
        }
        if (options.rateLimited) {
          return Response.json({
            ...receipt(),
            claimed: false,
            reconcile: false,
            retry_after_seconds: 60,
          });
        }
        if (options.lostClaim) {
          started = true;
          state = "generating";
          throw new Error("Lost claim ack");
        }
        privateLease = body.p_lease_token;
        if (started && !staged) {
          return Response.json({
            ...receipt(),
            claimed: false,
            reconcile: false,
          });
        }
        const first = !started;
        started = true;
        if (first) providerContext = body.p_provider_context;
        state = first ? "generating" : "staged";
        return Response.json({
          ...receipt(),
          claimed: first,
          reconcile: !first,
          lease_token: privateLease,
          public_upload_id: generationUpload,
          provider_context: providerContext,
          staging_path: staged ? `club-24/${command.operationId}.png` : null,
          staging_object_id: staged ? generationObject : null,
          mime_type: staged ? "image/png" : null,
          byte_length: staged ? 9 : null,
          content_sha256: staged ? sha : null,
        });
      }
      if (name === "record_admin_image_generation_result") {
        assertEquals(body.p_lease_token, privateLease);
        if (body.p_outcome === "stored") {
          assertEquals(staged, true);
          assertEquals(body.p_object_id, generationObject);
          assertEquals(body.p_content_sha256, sha);
          state = "staged";
        } else if (
          body.p_outcome === "unknown" || body.p_outcome === "failed"
        ) state = staged ? "staged" : body.p_outcome;
        return Response.json(receipt());
      }
      if (name === "admit_admin_media_upload") {
        assertEquals(body.p_operation_id, generationUpload);
        assertEquals(body.p_content_sha256, sha);
        if (options.publicationDenied) {
          return Response.json({
            code: "42501",
            message: "Original assurance expired",
          }, { status: 403 });
        }
        return Response.json({
          ...media(complete ? "completed" : "pending"),
          dispatch_proof_id: "99968000-0000-4000-8000-000000000556",
        });
      }
      if (name === "consume_edge_rate_limit") {
        return Response.json([{ allowed: true, retry_after_seconds: 0 }]);
      }
      if (name === "claim_admin_media_upload") {
        assertEquals(
          body.p_dispatch_proof_id,
          "99968000-0000-4000-8000-000000000556",
        );
        publicLease = body.p_lease_token;
        return Response.json({
          ...media("uploading"),
          claimed: true,
          lease_token: publicLease,
        });
      }
      if (name === "begin_admin_media_upload") {
        assertEquals(body.p_operation_id, generationUpload);
        assertEquals(body.p_lease_token, publicLease);
        return Response.json({
          operation_id: generationUpload,
          lease_token: publicLease,
          upload_permitted: true,
        });
      }
      if (name === "complete_admin_media_upload") {
        assertEquals(body.p_lease_token, publicLease);
        assertEquals(body.p_outcome, "stored");
        complete = true;
        return Response.json(media("completed"));
      }
      if (name === "commit_admin_image_generation") {
        assertEquals(complete, true);
        state = options.targetConflict ? "staged" : "completed";
        return Response.json({
          ...receipt(),
          private_proof: "must be stripped",
        });
      }
      throw new Error(`Unexpected RPC ${name}`);
    }
    if (url.pathname.startsWith("/storage/v1/object/")) {
      const privateObject = url.pathname.includes(
        "africlub-generated-image-staging",
      );
      const info = url.pathname.includes("/info/");
      if (method === "POST") {
        assertEquals(headers.get("x-upsert"), "false");
        const metadata = JSON.parse(atob(headers.get("x-metadata")!));
        assertEquals(
          metadata.operation_id,
          privateObject ? command.operationId : generationUpload,
        );
        assertEquals(
          metadata.lease_token,
          privateObject ? privateLease : publicLease,
        );
        assertEquals(metadata.content_sha256, sha);
        if (!privateObject) {
          assertEquals(metadata.generation_operation_id, command.operationId);
          assertEquals(metadata.generation_lease_token, privateLease);
          assertEquals(metadata.generation_proof_id, proof);
        }
        if (privateObject) {
          staged = true;
          if (options.lostStageUpload) throw new Error("Lost stage upload ack");
        } else published++;
        return Response.json({
          Id: privateObject ? generationObject : generationPublicObject,
          Key: "canonical",
        });
      }
      if (privateObject ? !staged : !published) {
        return Response.json({ message: "not found" }, { status: 404 });
      }
      if (info) {
        return Response.json({
          id: privateObject ? generationObject : generationPublicObject,
        });
      }
      const data = options.stageMismatch && privateObject
        ? new Uint8Array([...generationBytes.slice(0, 8), 43])
        : generationBytes;
      return new Response(new Uint8Array(data), {
        headers: { "content-type": "image/png" },
      });
    }
    throw new Error(`Unexpected actual SDK URL ${url.pathname}`);
  };
  return {
    authorization,
    token,
    calls,
    context: () => providerContext,
    receipt,
    counts: () => ({ provider, published }),
    freshProof() {
      proof = "99968000-0000-4000-8000-000000000008";
      options.publicationDenied = false;
    },
    restore() {
      globalThis.fetch = originalFetch;
      for (const [k, v] of Object.entries(previous)) {
        v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
      }
    },
  };
}
