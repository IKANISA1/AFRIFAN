/** One unpredictable request nonce. Inbound nonce/CSP headers are never authoritative. */
export function createCspNonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes));
}

export function validCspNonce(value: string | null): value is string {
  return value !== null && /^[A-Za-z0-9+/]{22}==$/.test(value);
}

export function contentSecurityPolicy(options: {
  nonce?: string; development: boolean; allowHttpPreview: boolean; supabaseUrl?: string;
}): string {
  const nonce = options.nonce;
  if (nonce !== undefined && !validCspNonce(nonce)) throw Error("invalid_csp_nonce");
  let previewOrigin: string | undefined;
  try {
    const url = new URL(options.supabaseUrl ?? "");
    if (options.allowHttpPreview && url.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)) previewOrigin = url.origin;
  } catch { /* Missing configuration grants no additional source. */ }
  return [
    "default-src 'self'",
    ["script-src 'self'", nonce ? `'nonce-${nonce}' 'strict-dynamic'` : "",
      options.development ? "'unsafe-eval'" : ""].filter(Boolean).join(" "),
    nonce ? `style-src 'self' 'nonce-${nonce}'` : "style-src 'self'",
    // The application uses scalar inline style attributes for layout and progress.
    // Style elements require the request nonce; script attributes remain forbidden.
    "style-src-attr 'unsafe-inline'", "script-src-attr 'none'", "font-src 'self'",
    "img-src 'self' data: blob: https://*.supabase.co https://img.youtube.com",
    ["connect-src 'self' https://*.supabase.co wss://*.supabase.co", previewOrigin,
      previewOrigin?.replace(/^http:/, "ws:")].filter(Boolean).join(" "),
    "frame-ancestors 'none'", "base-uri 'self'", "form-action 'self'", "manifest-src 'self'",
    "worker-src 'self' blob:", "media-src 'self' blob: https://*.supabase.co", "object-src 'none'",
    ...(options.allowHttpPreview ? [] : ["upgrade-insecure-requests"]),
  ].join("; ");
}

export function isHtmlCspPath(path: string): boolean {
  return !path.startsWith("/api/") && path !== "/api" && !path.startsWith("/_next/") &&
    !/\.(?:css|js|png|jpe?g|gif|svg|webp|avif|ico|woff2?|ttf|map|json|txt|xml|webmanifest)$/i.test(path);
}
