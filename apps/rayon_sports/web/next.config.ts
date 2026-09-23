import type { NextConfig } from "next";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
const supabaseEndpoint = supabaseUrl ? new URL(supabaseUrl) : null;
const supabaseHost = supabaseEndpoint?.hostname ?? null;
const analyticsUrl = process.env.NEXT_PUBLIC_VITALS_ENDPOINT?.trim();
const analyticsOrigin = analyticsUrl ? new URL(analyticsUrl).origin : null;
const isDevelopment = process.env.NODE_ENV === "development";
const enforceSecureTransport = process.env.AFRICLUB_ALLOW_HTTP_PREVIEW !== "1";
const previewSupabaseOrigin =
  !enforceSecureTransport &&
  supabaseEndpoint?.protocol === "http:" &&
  ["localhost", "127.0.0.1", "[::1]"].includes(supabaseEndpoint.hostname)
    ? supabaseEndpoint.origin
    : null;

const nextConfig: NextConfig = {
  output: "standalone",
  distDir: process.env.NEXT_BUILD_DIR || ".next",
  serverExternalPackages: ["exceljs"],
  typescript: {
    // `npm run typecheck` is the authoritative gate. Skipping Next's duplicate
    // build-time pass avoids flaky `.next/types/*` generation races.
    ignoreBuildErrors: true,
  },
  experimental: {
    cpus: 1,
    workerThreads: false,
    parallelServerCompiles: false,
    parallelServerBuildTraces: false,
    webpackBuildWorker: false,
    webpackMemoryOptimizations: true,
  },
  images: {
    deviceSizes: [360, 390, 414, 640, 672, 720, 750, 828, 1080, 1200, 1920],
    formats: ["image/avif", "image/webp"],
    qualities: [60, 68, 74, 75],
    remotePatterns: [
      ...(supabaseHost
        ? [
            {
              protocol: "https" as const,
              hostname: supabaseHost,
              pathname: "/storage/v1/object/public/**",
            },
          ]
        : []),
      {
        protocol: "https",
        hostname: "*.supabase.co",
        pathname: "/storage/v1/object/public/**",
      },
      {
        protocol: "https",
        hostname: "img.youtube.com",
        pathname: "/vi/**",
      },
    ],
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          ...(enforceSecureTransport
            ? [
                {
                  key: "Strict-Transport-Security",
                  value: "max-age=63072000; includeSubDomains; preload",
                },
              ]
            : []),
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=(), payment=()",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          {
            key: "Cross-Origin-Opener-Policy",
            value: "same-origin-allow-popups",
          },
          {
            key: "X-Permitted-Cross-Domain-Policies",
            value: "none",
          },
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              `script-src 'self' 'unsafe-inline' https://static.cloudflareinsights.com${isDevelopment ? " 'unsafe-eval'" : ""}`,
              "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
              "font-src 'self' https://fonts.gstatic.com",
              "img-src 'self' data: blob: https://*.supabase.co https://img.youtube.com",
              [
                "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
                previewSupabaseOrigin,
                previewSupabaseOrigin?.replace(/^http:/, "ws:"),
                analyticsOrigin,
              ]
                .filter(Boolean)
                .join(" "),
              "frame-ancestors 'none'",
              "base-uri 'self'",
              "form-action 'self'",
              "manifest-src 'self'",
              "worker-src 'self' blob:",
              "media-src 'self' blob: https://*.supabase.co",
              "object-src 'none'",
              ...(enforceSecureTransport ? ["upgrade-insecure-requests"] : []),
            ].join("; "),
          },
        ],
      },
      {
        source: "/api/:path*",
        headers: [
          {
            key: "Cache-Control",
            value: "no-store, max-age=0",
          },
          {
            key: "X-Robots-Tag",
            value: "noindex, nofollow, noarchive",
          },
        ],
      },
      {
        source: "/:path(privacy|terms|support|contact|account-deletion)",
        headers: [
          {
            key: "Cache-Control",
            value:
              "public, max-age=0, s-maxage=300, must-revalidate",
          },
        ],
      },
    ];
  },
};

export default nextConfig;

if (isDevelopment) {
  void import("@opennextjs/cloudflare").then((m) =>
    m.initOpenNextCloudflareForDev(),
  );
}
