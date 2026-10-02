import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert";
import {
  decodeGeneratedImage,
  executeImageGeneration,
  getImageGenerationStatus,
  validateGenerationReceipt,
} from "./admin_image_generation.ts";
import {
  generationActor,
  generationCommand,
  generationContext,
  generationHarness,
  generationOperation,
} from "./admin_image_generation_test_support.ts";
import { HttpError } from "./auth.ts";
for (
  const scenario of [
    "success",
    "lost_stage_ack",
    "provider_unknown",
    "lost_claim",
    "expired_publication",
    "wrong_bytes",
    "invalid_provider",
    "target_conflict",
  ] as const
) {
  Deno.test(`actual SDK generation ${scenario} binds original proof/command and never repeats paid work`, async () => {
    const h = await generationHarness({
      lostStageUpload: scenario === "lost_stage_ack",
      providerFailure: scenario === "provider_unknown",
      lostClaim: scenario === "lost_claim",
      publicationDenied: scenario === "expired_publication",
      stageMismatch: scenario === "wrong_bytes",
      invalidProvider: scenario === "invalid_provider",
      targetConflict: scenario === "target_conflict",
    });
    try {
      const one = await executeImageGeneration(
        h.authorization,
        generationCommand,
        () => generationContext,
        "qa-only",
      );
      const expected =
        scenario === "provider_unknown" || scenario === "lost_claim"
          ? "unknown"
          : scenario === "wrong_bytes"
          ? "staged"
          : scenario === "invalid_provider"
          ? "failed"
          : scenario === "expired_publication" || scenario === "target_conflict"
          ? "staged"
          : "completed";
      assertEquals(one.status, expected);
      assertEquals("dispatch_proof_id" in one, false);
      assertEquals("private_proof" in one, false);
      assertEquals("public_upload_id" in one, false);
      if (one.status !== "completed") assertEquals(one.image_url, undefined);
      assertEquals(h.counts().provider, scenario === "lost_claim" ? 0 : 1);
      if (scenario === "expired_publication") h.freshProof();
      const two = await executeImageGeneration(
        h.authorization,
        generationCommand,
        () => ({ ...generationContext, prompt_used: "Changed runtime prompt" }),
        "qa-only",
      );
      assertEquals(h.counts().provider, scenario === "lost_claim" ? 0 : 1);
      if (scenario === "expired_publication") {
        assertEquals(two.status, "completed");
        assertEquals(two.prompt_used, generationContext.prompt_used);
      }
      assertEquals(two.operation_id, generationOperation);
      assertEquals(two.actor_id, generationActor);
      const claim = h.calls.find((c) =>
        c.name === "claim_admin_image_generation"
      )!;
      assertEquals(
        claim.body.p_dispatch_proof_id,
        "99968000-0000-4000-8000-000000000004",
      );
      assertEquals(
        h.counts().published,
        one.status === "completed" || scenario === "expired_publication" ||
          scenario === "target_conflict"
          ? 1
          : 0,
      );
    } finally {
      h.restore();
    }
  });
}
Deno.test("actual SDK rejects foreign admission before provider or Storage", async () => {
  const h = await generationHarness({ foreignAdmission: true });
  try {
    await assertRejects(
      () =>
        executeImageGeneration(
          h.authorization,
          generationCommand,
          () => generationContext,
          "qa-only",
        ),
      HttpError,
    );
    assertEquals(h.counts(), { provider: 0, published: 0 });
  } finally {
    h.restore();
  }
});
Deno.test("actual SDK status is original actor/club/domain bound and unknown stays null", async () => {
  const h = await generationHarness();
  try {
    const r = await getImageGenerationStatus(
      h.authorization,
      generationOperation,
      generationActor,
      24,
      "admin_image",
    );
    assertEquals(r!.status, "pending");
    assertEquals(
      await getImageGenerationStatus(
        h.authorization,
        "99968000-0000-4000-8000-000000000099",
        generationActor,
        24,
        "admin_image",
      ),
      null,
    );
    await assertRejects(
      () =>
        getImageGenerationStatus(
          h.authorization,
          generationOperation,
          generationActor,
          25,
          "admin_image",
        ),
      HttpError,
    );
  } finally {
    h.restore();
  }
});
Deno.test("receipt rejects changed original arguments and unsupported completion; never returns private stage bytes", () => {
  const r = {
    operation_id: generationOperation,
    actor_id: generationActor,
    club_id: 24,
    domain: "admin_image",
    kind: "home_banner",
    request: generationCommand.request,
    status: "staged",
    target_conflict: false,
    session_id: "private",
    image_url: "https://unconfirmed.invalid",
  };
  assertEquals(
    validateGenerationReceipt(r, generationCommand).image_url,
    undefined,
  );
  assertEquals(
    "session_id" in validateGenerationReceipt(r, generationCommand),
    false,
  );
  assertThrows(
    () =>
      validateGenerationReceipt({
        ...r,
        request: { ...r.request, prompt: "other" },
      }, generationCommand),
    HttpError,
  );
  assertThrows(
    () =>
      validateGenerationReceipt(
        { ...r, status: "completed" },
        generationCommand,
      ),
    HttpError,
  );
});
Deno.test("provider output requires allowed MIME, bounded binary and matching magic", () => {
  for (
    const image of [
      { mimeType: "image/svg+xml", data: "eA==" },
      { mimeType: "image/png", data: "%%%=" },
      { mimeType: "image/png", data: btoa("wrong bytes") },
      {
        mimeType: "image/jpeg",
        data: "a".repeat(Math.ceil(5 * 1024 * 1024 / 3) * 4 + 1),
      },
    ]
  ) {
    assertThrows(
      () =>
        decodeGeneratedImage({
          candidates: [{ content: { parts: [{ inlineData: image }] } }],
        }),
      HttpError,
    );
  }
});
for (const limited of [true, false]) {
  Deno.test(`actual SDK ${limited ? "atomic budget" : "postwait assurance"} rejection makes no provider or Storage call`, async () => {
    const h = await generationHarness({
      rateLimited: limited,
      claimDenied: !limited,
    });
    try {
      const error = await assertRejects(
        () =>
          executeImageGeneration(
            h.authorization,
            generationCommand,
            () => generationContext,
            "qa-only",
          ),
        HttpError,
      );
      assertEquals(error.status, limited ? 429 : 403);
      if (limited) {
        assertEquals(new Headers(error.headers).get("retry-after"), "60");
      }
      assertEquals(h.counts(), { provider: 0, published: 0 });
    } finally {
      h.restore();
    }
  });
}
