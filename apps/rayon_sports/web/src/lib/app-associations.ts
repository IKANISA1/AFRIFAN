export const androidPackageName = "rw.gikundiro.app";
export const appleTeamId = "63STJ5N27W";
export const appleBundleId = "rw.ikanisa.rayonSports";
export const appleApplicationId = `${appleTeamId}.${appleBundleId}`;

// This is the controlled upload-certificate fingerprint recorded for the
// current release artifacts. Google Play normally re-signs production builds,
// so the Play app-signing fingerprint must be added through the public
// build-time setting after the Play app record exists.
export const androidUploadCertificateFingerprint =
  "18:0C:F8:B8:D4:F0:A5:A3:8D:51:D9:C9:E2:FF:51:23:FB:49:CD:CE:6D:93:BD:01:08:E1:D1:29:86:97:D5:10";

const sha256FingerprintPattern = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/;

export function resolveAndroidCertificateFingerprints(
  configured = process.env.NEXT_PUBLIC_ANDROID_APP_LINK_SHA256_FINGERPRINTS,
) {
  const candidates = (configured ?? "")
    .split(/[\s,]+/)
    .map((candidate) => candidate.trim().toUpperCase())
    .filter((candidate) => sha256FingerprintPattern.test(candidate));

  return Array.from(
    new Set([androidUploadCertificateFingerprint, ...candidates]),
  );
}

export function buildAndroidAssetLinks(configured?: string) {
  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: androidPackageName,
        sha256_cert_fingerprints:
          resolveAndroidCertificateFingerprints(configured),
      },
    },
  ];
}

export function buildAppleAppSiteAssociation() {
  return {
    applinks: {
      details: [
        {
          appIDs: [appleApplicationId],
          components: [
            {
              "/": "/privacy*",
              exclude: true,
              comment: "Keep the store privacy URL on the public website.",
            },
            {
              "/": "/terms*",
              exclude: true,
              comment: "Keep the terms URL on the public website.",
            },
            {
              "/": "/support*",
              exclude: true,
              comment: "Keep public support available outside the app.",
            },
            {
              "/": "/account-deletion*",
              exclude: true,
              comment:
                "Keep the public account-deletion request path available when app access is lost.",
            },
            {
              "/": "/.well-known/*",
              exclude: true,
              comment: "Association metadata is a website-only resource.",
            },
            {
              "/": "/api/*",
              exclude: true,
              comment: "API routes never open the mobile app.",
            },
            {
              "/": "/*",
              comment: "Open supported Gikundiro public journeys in the app.",
            },
          ],
        },
      ],
    },
  };
}

export const associationResponseHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Cache-Control":
    "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
  "Content-Type": "application/json; charset=utf-8",
  "Cross-Origin-Resource-Policy": "cross-origin",
  "X-Content-Type-Options": "nosniff",
} as const;

export function createAssociationResponse(
  payload: unknown,
  options: { head?: boolean } = {},
) {
  return new Response(options.head ? null : `${JSON.stringify(payload, null, 2)}\n`, {
    status: 200,
    headers: associationResponseHeaders,
  });
}

export function createAssociationOptionsResponse() {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "public, max-age=86400",
      Vary: "Access-Control-Request-Headers",
    },
  });
}
