import { afterEach, describe, expect, it, vi } from "vitest";
import {
  androidPackageName,
  androidPlayAppSigningCertificateFingerprint,
  appleApplicationId,
  associationResponseHeaders,
  buildAndroidAssetLinks,
  buildAppleAppSiteAssociation,
  createAssociationResponse,
  resolveAndroidCertificateFingerprints,
} from "./app-associations";

const verifiedPlayAppSigningFingerprint =
  "B8:B4:84:C9:3D:80:83:12:9C:90:1B:D4:9C:BE:35:65:7B:C1:4D:38:F3:D9:19:04:75:45:83:B5:AB:BC:E5:D9";
const configuredFingerprint =
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";
const invalidLocalFingerprint =
  "18:0C:F8:B8:D4:F0:A5:A3:8D:51:D9:C9:E2:FF:51:23:FB:49:CD:CE:6D:93:BD:01:08:E1:D1:29:86:97:D5:10";

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("app association documents", () => {
  it("publishes the exact Play App Signing fingerprint by default", () => {
    expect(androidPlayAppSigningCertificateFingerprint).toBe(
      verifiedPlayAppSigningFingerprint,
    );

    expect(buildAndroidAssetLinks("")).toEqual([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: androidPackageName,
          sha256_cert_fingerprints: [verifiedPlayAppSigningFingerprint],
        },
      },
    ]);
    expect(resolveAndroidCertificateFingerprints("")).not.toContain(
      invalidLocalFingerprint,
    );
  });

  it("adds valid configured fingerprints without replacing the Play default", () => {
    vi.stubEnv(
      "NEXT_PUBLIC_ANDROID_APP_LINK_SHA256_FINGERPRINTS",
      `${configuredFingerprint}, invalid, ${configuredFingerprint.toLowerCase()}`,
    );

    const expectedFingerprints = [
      verifiedPlayAppSigningFingerprint,
      configuredFingerprint,
    ];
    expect(resolveAndroidCertificateFingerprints()).toEqual(
      expectedFingerprints,
    );
    expect(
      buildAndroidAssetLinks()[0]?.target.sha256_cert_fingerprints,
    ).toEqual(expectedFingerprints);
    expect(resolveAndroidCertificateFingerprints("not-a-fingerprint")).toEqual([
      verifiedPlayAppSigningFingerprint,
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
