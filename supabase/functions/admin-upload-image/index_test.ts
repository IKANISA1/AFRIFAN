import { createAdminUploadImageHandler } from "./index.ts";
import { HttpError } from "../_shared/auth.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

const png = btoa(String.fromCharCode(
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  1,
));

Deno.test("admin-upload-image binds upload to authorized club path", async () => {
  const paths: string[] = [];
  const handler = createAdminUploadImageHandler({
    requireClubAdminCaller: async (_request, clubId) => {
      assertEquals(clubId, 24, "club id");
      return {} as never;
    },
    createAdminClient: () =>
      ({
        storage: {
          from: (bucket: string) => ({
            upload: async (path: string) => {
              assertEquals(bucket, "africlub-product-images", "bucket");
              paths.push(path);
              return { error: null };
            },
            getPublicUrl: (path: string) => ({
              data: { publicUrl: `https://storage.test/${path}` },
            }),
          }),
        },
      }) as never,
    now: () => 123,
    randomId: () => "deadbeef",
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        club_id: 24,
        kind: "shop_product",
        mime_type: "image/png",
        image_data_base64: png,
      }),
    }),
  );
  assertEquals(response.status, 200, "status");
  assertEquals(paths[0], "club-24/admin/shop_product/123-deadbeef.png", "path");
});

Deno.test("admin-upload-image rejects MIME spoofing before storage", async () => {
  let storageCalled = false;
  const handler = createAdminUploadImageHandler({
    requireClubAdminCaller: async () => ({} as never),
    createAdminClient: () => {
      storageCalled = true;
      return {} as never;
    },
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        club_id: 24,
        kind: "shop_product",
        mime_type: "image/png",
        image_data_base64: btoa("not-a-png"),
      }),
    }),
  );
  assertEquals(response.status, 400, "status");
  assertEquals(storageCalled, false, "storage called");
});

for (const clubId of ["24extra", "24.5", "24e2", "24/../26", 24.5, null]) {
  Deno.test(`admin-upload-image rejects ambiguous club identity ${JSON.stringify(clubId)}`, async () => {
    let authorized = false;
    const handler = createAdminUploadImageHandler({
      requireClubAdminCaller: async () => {
        authorized = true;
        return {} as never;
      },
      createAdminClient: () => {
        throw new Error("Storage must not be called");
      },
    });
    const response = await handler(
      new Request("https://example.test", {
        method: "POST",
        body: JSON.stringify({
          club_id: clubId,
          kind: "shop_product",
          mime_type: "image/png",
          image_data_base64: png,
        }),
      }),
    );
    assertEquals(response.status, 400, "invalid identity status");
    assertEquals(
      authorized,
      false,
      "identity must be valid before authorization",
    );
  });
}

for (const body of ["{broken", "null", "[]"]) {
  Deno.test(`admin-upload-image rejects malformed request ${body}`, async () => {
    const handler = createAdminUploadImageHandler({
      requireClubAdminCaller: async () => {
        throw new Error("Authorization must not be called");
      },
      createAdminClient: () => {
        throw new Error("Storage must not be called");
      },
    });
    const response = await handler(
      new Request("https://example.test", { method: "POST", body }),
    );
    assertEquals(response.status, 400, "request status");
  });
}

Deno.test("admin-upload-image preserves cross-club authorization rejection without writing", async () => {
  let storageCalled = false;
  const handler = createAdminUploadImageHandler({
    requireClubAdminCaller: async (_request, clubId) => {
      assertEquals(clubId, 26, "requested club");
      throw new HttpError(403, "Club access denied.");
    },
    createAdminClient: () => {
      storageCalled = true;
      return {} as never;
    },
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        club_id: 26,
        kind: "shop_product",
        mime_type: "image/png",
        image_data_base64: png,
      }),
    }),
  );
  assertEquals(response.status, 403, "cross-club status");
  assertEquals(storageCalled, false, "cross-club storage write");
});

Deno.test("admin-upload-image does not return a public URL after storage failure", async () => {
  let publicUrlCalled = false;
  const handler = createAdminUploadImageHandler({
    requireClubAdminCaller: async () => ({} as never),
    createAdminClient: () =>
      ({
        storage: {
          from: () => ({
            upload: async () => ({
              error: new Error("Synthetic storage unavailable"),
            }),
            getPublicUrl: () => {
              publicUrlCalled = true;
              return { data: { publicUrl: "https://storage.test/unwritten" } };
            },
          }),
        },
      }) as never,
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        club_id: 24,
        kind: "shop_product",
        mime_type: "image/png",
        image_data_base64: png,
      }),
    }),
  );
  assertEquals(response.status, 500, "storage error status");
  assertEquals(publicUrlCalled, false, "unwritten public URL");
});
