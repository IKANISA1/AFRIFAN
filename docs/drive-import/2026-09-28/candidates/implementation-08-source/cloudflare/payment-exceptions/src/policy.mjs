/** Metadata-only case workflow. Never payment confirmation or refund authority. */
export const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export const HEX64 = /^[a-f0-9]{64}$/;
export const NOW_SQL = "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";
export const ACTIONS = ['open', 'triage', 'propose', 'approve', 'reject', 'close', 'reopen'];
export const CATEGORIES = ['late', 'partial', 'duplicate', 'ambiguous', 'missing_reference', 'cancelled_order', 'refund_request'];
export const DISPOSITIONS = ['no_financial_change', 'refer_reconciliation', 'refer_refund_review'];
export const STATES = ['open', 'investigating', 'awaiting_review', 'reviewed', 'closed'];
export const REASONS = ['support_request', 'evidence_received', 'needs_investigation', 'review_complete', 'insufficient_evidence', 'external_referral', 'new_evidence'];
export class CaseError extends Error {
  constructor(code, status = 400) { super(code); this.name = 'CaseError'; this.code = code; this.status = status; }
}
export function demand(ok, code = 'invalid_request', status = 400) { if (!ok) throw new CaseError(code, status); }
export function exact(value, keys) {
  demand(value && typeof value === 'object' && !Array.isArray(value) &&
    Object.keys(value).length === keys.length && keys.every(k => Object.hasOwn(value, k)));
}
export function checkIdentity(value) {
  exact(value, ['accountId', 'audience', 'subject']);
  demand(typeof value.accountId === 'string' && /^[a-f0-9]{32}$/.test(value.accountId) &&
    typeof value.audience === 'string' && HEX64.test(value.audience) &&
    typeof value.subject === 'string' && UUID.test(value.subject), 'authentication_required', 401);
}
export function checkBase(input, keys) {
  exact(input, keys); checkIdentity(input.identity);
  demand(Number.isSafeInteger(input.clubId) && input.clubId > 0, 'invalid_club_id');
}
export function checkCaseId(value) { demand(typeof value === 'string' && UUID.test(value), 'invalid_case_id'); }
export function validateCommand(input) {
  checkBase(input, ['identity', 'clubId', 'caseId', 'operationId', 'expectedRevision', 'action', 'detail']);
  checkCaseId(input.caseId);
  demand(typeof input.operationId === 'string' && UUID.test(input.operationId), 'invalid_operation_id');
  demand(ACTIONS.includes(input.action), 'invalid_action');
  demand(Number.isSafeInteger(input.expectedRevision) && input.expectedRevision >= 0 && input.expectedRevision < 2147483647,
    'invalid_revision');
  demand(input.action === 'open' ? input.expectedRevision === 0 : input.expectedRevision > 0, 'invalid_revision');
  const keys = ['reasonCode', 'evidenceDigest'];
  if (input.action === 'open') keys.push('category', 'orderId', 'evidenceId');
  if (input.action === 'propose') keys.push('disposition');
  exact(input.detail, keys);
  demand(REASONS.includes(input.detail.reasonCode), 'invalid_reason');
  demand(input.detail.evidenceDigest === null ||
    (typeof input.detail.evidenceDigest === 'string' && HEX64.test(input.detail.evidenceDigest)), 'invalid_evidence_digest');
  if (['propose', 'close'].includes(input.action)) demand(input.detail.evidenceDigest !== null, 'evidence_digest_required');
  if (input.action === 'propose') demand(DISPOSITIONS.includes(input.detail.disposition), 'invalid_disposition');
  if (input.action === 'open') {
    demand(CATEGORIES.includes(input.detail.category), 'invalid_category');
    for (const k of ['orderId', 'evidenceId']) demand(input.detail[k] === null ||
      (typeof input.detail[k] === 'string' && UUID.test(input.detail[k])), 'invalid_reference');
    demand(input.detail.orderId !== null || input.detail.evidenceId !== null, 'reference_required');
  }
}
export function canonical(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
}
export async function digest(value) {
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonical(value))))]
    .map(b => b.toString(16).padStart(2, '0')).join('');
}
export function safeError(error) {
  if (error instanceof CaseError) return error;
  // Only explicitly enumerated trigger tokens may cross the trust boundary.
  const message = String(error?.message ?? '');
  for (const [token, status] of Object.entries({
    px_disabled: 503, px_forbidden: 403, px_stale_revision: 409,
    px_invalid_transition: 409, px_self_review: 403, px_case_conflict: 409,
    px_invalid_event: 400, px_immutable: 409,
  })) if (message.includes(token)) return new CaseError(token.slice(3), status);
  return new CaseError('case_service_unavailable', 503);
}
export async function rpc(work) {
  try { return {ok: true, data: await work()}; }
  catch (error) { const e = safeError(error); return {ok: false, error: {code: e.code, status: e.status}}; }
}
