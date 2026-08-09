import { describe, expect, it } from "vitest";
import {
  androidPackageName,
  androidUploadCertificateFingerprint,
  appleApplicationId,
  associationResponseHeaders,
  buildAndroidAssetLinks,
  buildAppleAppSiteAssociation,
  createAssociationResponse,
  resolveAndroidCertificateFingerprints,
} from "./app-associations";

const playFingerprint =
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

describe("app association documents", () => {
  it("publishes the Android package with controlled and configured fingerprints", () => {
    const document = buildAndroidAssetLinks(
      `${playFingerprint}, invalid, ${playFingerprint.toLowerCase()}`,
    );

    expect(document).toEqual([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: androidPackageName,
          sha256_cert_fingerprints: [
            androidUploadCertificateFingerprint,
            playFingerprint,
          ],
        },
      },
    ]);
    expect(resolveAndroidCertificateFingerprints("not-a-fingerprint")).toEqual([
      androidUploadCertificateFingerprint,
    ]);
  });

  it("publishes the iOS application and keeps policy routes on the web", () => {
    const document = buildAppleAppSiteAssociation();
    expect(document.applinks.details[0]?.appIDs).toEqual([appleApplicationId]);
    expect(document.applinks.details[0]?.components).toContainEqual(
      expect.objectContaining({ "/": "/account-deletion*", exclude: true }),
    );
    expect(document.applinks.details[0]?.components.at(-1)).toEqual(
      expect.objectContaining({ "/": "/*" }),
    );
  });

  it("uses verifier-safe JSON, CORS, caching, and nosniff headers", async () => {
    const response = createAssociationResponse({ ok: true });
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe(
      associationResponseHeaders["Content-Type"],
    );
    expect(response.headers.get("access-control-allow-origin")).toBe("*");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    await expect(response.json()).resolves.toEqual({ ok: true });
  });
});
