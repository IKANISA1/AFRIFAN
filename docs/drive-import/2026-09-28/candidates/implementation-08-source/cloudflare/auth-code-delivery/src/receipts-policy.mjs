/** Private, information-only delivery evidence. No authentication/entitlement effect. */
export class ReceiptError extends Error {
  constructor(code = 'receipt_unavailable', status = 503) { super(code); this.code = code; this.status = status; }
}
export const RECEIPT_LIMITS = Object.freeze({
  bodyBytes: 65536, bodyDeadlineMs: 3000, maxEvents: 20, maxEntries: 5,
  maxChanges: 20, maxAgeMs: 8 * 86400000, futureSkewMs: 300000,
  reconcileBatch: 100, keyVersion: '1',
});
export const RECEIPT_PATH = '/webhooks/whatsapp/auth-delivery';
export const statusNames = Object.freeze(['sent', 'delivered', 'read', 'failed', 'deleted']);
export const numericId = v => typeof v === 'string' && /^[1-9][0-9]{4,29}$/.test(v);
export const challengeId = v => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(v);
export const messageId = v => typeof v === 'string' && /^wamid\.[A-Za-z0-9+/_=.-]{1,250}$/.test(v);
export const recipientId = v => typeof v === 'string' && /^[1-9][0-9]{7,14}$/.test(v);
export const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
export function requireReceipt(ok, code = 'invalid_receipt', status = 400) { if (!ok) throw new ReceiptError(code, status); }
export function exactKeys(v, keys) {
  requireReceipt(object(v) && Object.keys(v).length === keys.length && keys.every(k => Object.hasOwn(v, k)));
}
export function receiptRoutes(env) {
  let routes;
  try { routes = JSON.parse(env.RECEIPT_ROUTES_JSON); } catch { throw new ReceiptError('receipt_configuration'); }
  requireReceipt(Array.isArray(routes) && routes.length > 0 && routes.length <= 5, 'receipt_configuration', 503);
  const clubs = new Set(), senderOwners = new Map();
  for (const r of routes) {
    try { exactKeys(r, ['clubId', 'businessAccountId', 'phoneNumberId']); } catch { throw new ReceiptError('receipt_configuration'); }
    requireReceipt(Number.isSafeInteger(r.clubId) && r.clubId > 0 && !clubs.has(r.clubId) && numericId(r.businessAccountId) && numericId(r.phoneNumberId), 'receipt_configuration', 503);
    // Shared senders across clubs are permitted, but a sender may not be assigned two accounts.
    requireReceipt(!senderOwners.has(r.phoneNumberId) || senderOwners.get(r.phoneNumberId) === r.businessAccountId, 'receipt_configuration', 503);
    clubs.add(r.clubId); senderOwners.set(r.phoneNumberId, r.businessAccountId);
  }
  return routes.map(r => Object.freeze({ ...r }));
}
export function receiptKey(env) {
  const key = env.RECEIPT_HMAC_KEY;
  requireReceipt(typeof key === 'string' && /^[0-9a-f]{64}$/.test(key) && !/^(.)\1+$/.test(key) && env.RECEIPT_KEY_VERSION === RECEIPT_LIMITS.keyVersion && key !== env.DISPATCH_HMAC_KEY, 'receipt_configuration', 503);
  return Uint8Array.from(key.match(/../g), h => parseInt(h, 16));
}
export async function hmac(bytes, value) {
  const key = await crypto.subtle.importKey('raw', bytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(JSON.stringify(value))));
}
export const hex = buffer => [...new Uint8Array(buffer)].map(n => n.toString(16).padStart(2, '0')).join('');
export async function sha(value) { return hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(value)))); }
export async function recipientCommitment(env, account, sender, recipient) {
  requireReceipt(numericId(account) && numericId(sender) && recipientId(recipient));
  return hmac(receiptKey(env), ['wa-recipient-v1', account, sender, recipient]);
}
export function receiptDb(env) {
  const db = env.DELIVERY_DB;
  requireReceipt(db && typeof db.prepare === 'function' && typeof db.batch === 'function' && typeof db.withSession === 'function', 'receipt_configuration', 503);
  return db;
}
export function webhookConfiguration(env) {
  requireReceipt(env.RECEIPT_WEBHOOK_ENABLED === 'true', 'receipt_disabled', 503);
  let origin;
  try { const u = new URL(env.RECEIPT_ORIGIN); if (u.protocol !== 'https:' || u.username || u.password || u.pathname !== '/' || u.search || u.hash) throw 0; origin = u.origin; } catch { throw new ReceiptError('receipt_configuration'); }
  const secret = env.WA_WEBHOOK_APP_SECRET, verify = env.WA_WEBHOOK_VERIFY_TOKEN;
  requireReceipt(typeof secret === 'string' && /^[\x21-\x7e]{32,512}$/.test(secret) &&
    typeof verify === 'string' && /^[A-Za-z0-9_-]{32,128}$/.test(verify) && secret !== verify, 'receipt_configuration', 503);
  receiptKey(env); receiptDb(env);
  return { origin, secret, verify, routes: receiptRoutes(env) };
}
