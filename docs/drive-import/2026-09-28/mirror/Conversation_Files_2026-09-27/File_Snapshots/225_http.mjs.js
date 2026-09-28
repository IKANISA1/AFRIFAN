import { OperatorError, requireThat } from './errors.mjs';
export const BODY_LIMIT = 4096;
export function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {status, headers: {
    'content-type':'application/json; charset=utf-8', 'cache-control':'no-store',
    'x-content-type-options':'nosniff', 'referrer-policy':'no-referrer',
    'content-security-policy':"default-src 'none'; frame-ancestors 'none'", ...headers,
  }});
}
export function apiError(error, requestId) {
  const known = error instanceof OperatorError;
  return json({schemaVersion:1, error: {code:known ? error.code : 'service_unavailable', requestId}}, known ? error.status : 503);
}
export function originPolicy(request, configuredOrigin, mutation) {
  let origin;
  try { origin = new URL(configuredOrigin); } catch { throw new OperatorError('operator_origin_unconfigured',503); }
  requireThat(origin.protocol === 'https:' && !origin.username && !origin.password &&
    origin.href === `${origin.origin}/`, 'operator_origin_unconfigured',503);
  const url = new URL(request.url);
  requireThat(url.origin === origin.origin, 'origin_not_allowed',403);
  const received = request.headers.get('origin');
  // Access uses cookies. Requiring an exact Origin plus a custom mutation header
  // rejects cross-site forms and avoids relying only on cookie SameSite defaults.
  if (mutation) {
    requireThat(received === origin.origin && request.headers.get('x-africlub-action') === 'publish-review',
      'origin_not_allowed',403);
    const site = request.headers.get('sec-fetch-site');
    requireThat(!site || site === 'same-origin', 'origin_not_allowed',403);
  } else if (received) requireThat(received === origin.origin, 'origin_not_allowed',403);
}
export async function readJson(request) {
  requireThat(/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(request.headers.get('content-type') ?? ''),
    'json_required',415);
  requireThat(!request.headers.get('content-encoding'), 'content_encoding_not_supported',415);
  const declared = request.headers.get('content-length');
  if (declared !== null) requireThat(/^\d+$/.test(declared) && Number(declared) <= BODY_LIMIT, 'request_too_large',413);
  requireThat(request.body, 'invalid_json');
  const reader = request.body.getReader(); const chunks = []; let bytes = 0;
  try {
    for (;;) {
      const {value,done} = await reader.read(); if(done) break;
      bytes += value.byteLength;
      if (bytes > BODY_LIMIT) { await reader.cancel(); throw new OperatorError('request_too_large',413); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const all = new Uint8Array(bytes); let offset = 0;
  for (const chunk of chunks) { all.set(chunk,offset); offset += chunk.byteLength; }
  try { return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(all)); }
  catch { throw new OperatorError('invalid_json'); }
}
