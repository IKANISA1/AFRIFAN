/** Fixed request grammar. Errors never expose SQL, payer data or provider bodies. */
export const NOW_SQL = "CAST(unixepoch('subsec') * 1000 AS INTEGER)";
export const MAX_AMOUNT = 2147483647;
export class AllocationError extends Error {
  constructor(code='allocation_unavailable') { super(code); this.name='AllocationError'; this.code=code; }
}
export function demand(value, code='invalid_request') { if (!value) throw new AllocationError(code); }
export const uuid = value => typeof value==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
export const sha = value => typeof value==='string' && /^[0-9a-f]{64}$/.test(value);
export const club = value => Number.isSafeInteger(value) && value>0;
export const amount = value => Number.isSafeInteger(value) && value>0 && value<=MAX_AMOUNT;
export const timestamp = value => Number.isSafeInteger(value) && value>=0 && value<=253370764799999;
export const reference = value => typeof value==='string' && /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/.test(value);
export function exact(value, fields) {
  demand(value!==null && typeof value==='object' && !Array.isArray(value));
  demand(Object.keys(value).length===fields.length && fields.every(field=>Object.hasOwn(value,field)));
}
export function provider(value) {
  demand(typeof value==='string' && value.length<=64);
  const text=value.trim().toLowerCase();
  const normalized=['mtn','mtn rwanda'].includes(text)?'mtn_rwanda':text;
  demand(/^[a-z][a-z0-9_-]{0,63}$/.test(normalized)); return normalized;
}
function upper(value, size) {
  demand(typeof value==='string'); const normalized=value.trim().toUpperCase();
  demand(new RegExp(`^[A-Z]{${size}}$`).test(normalized)); return normalized;
}
export function normalizeEvidence(input) {
  exact(input,['requestId','raw','parsed','attestationRef']);
  exact(input.raw,['id','userId','clubId','country','provider','sha256','receivedAt','isMock']);
  exact(input.parsed,['id','rawId','userId','clubId','country','providerReference','amount','currency','recipient','direction','parseStatus','isMock','transactionAt']);
  const raw={...input.raw,country:upper(input.raw.country,2),provider:provider(input.raw.provider)};
  const parsed={...input.parsed,country:upper(input.parsed.country,2),currency:upper(input.parsed.currency,3)};
  demand(uuid(input.requestId)&&uuid(raw.id)&&uuid(raw.userId)&&uuid(parsed.id)&&uuid(parsed.rawId)&&uuid(parsed.userId));
  demand(club(raw.clubId)&&club(parsed.clubId)&&sha(raw.sha256)&&timestamp(raw.receivedAt)&&timestamp(parsed.transactionAt));
  demand(raw.id===parsed.rawId&&raw.userId===parsed.userId&&raw.clubId===parsed.clubId&&raw.country===parsed.country,'evidence_binding_mismatch');
  demand(raw.isMock===false&&parsed.isMock===false&&parsed.parseStatus==='parsed'&&parsed.direction==='debit','invalid_evidence');
  demand(amount(parsed.amount)&&typeof parsed.recipient==='string'&&/^[0-9]{3,32}$/.test(parsed.recipient),'invalid_evidence');
  demand(typeof parsed.providerReference==='string'); parsed.providerReference=parsed.providerReference.trim();
  demand(reference(parsed.providerReference)&&reference(input.attestationRef),'invalid_evidence');
  return {requestId:input.requestId,raw,parsed,attestationRef:input.attestationRef};
}
export function normalizeAllocation(input) {
  exact(input,['requestId','clubId','orderId','evidenceId']);
  demand(uuid(input.requestId)&&club(input.clubId)&&uuid(input.orderId)&&uuid(input.evidenceId));
  return {...input};
}
export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value!==null && typeof value==='object') return `{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export async function hash(value) {
  const result=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(canonical(value)));
  return Array.from(new Uint8Array(result),n=>n.toString(16).padStart(2,'0')).join('');
}
export function safeError(error) {
  if (error instanceof AllocationError) return error;
  const message=String(error?.message??'');
  for(const [token,code] of Object.entries({pa_permission_denied:'permission_denied',pa_binding_conflict:'binding_conflict',pa_transaction_used:'transaction_already_used',pa_invalid_evidence:'invalid_evidence',pa_outbox_conflict:'outbox_conflict'}))
    if(message.includes(token)) return new AllocationError(code);
  return new AllocationError('allocation_unavailable');
}
export function configure(env) {
  demand(env.PAYMENT_ALLOCATION_ENABLED==='true','service_disabled');
  demand(env.ALLOCATION_ENVIRONMENT==='isolated-staging','staging_only');
  demand(env.ALLOCATION_DB&&typeof env.ALLOCATION_DB.prepare==='function'&&typeof env.ALLOCATION_DB.batch==='function'&&typeof env.ALLOCATION_DB.withSession==='function','invalid_configuration');
  return env.ALLOCATION_DB;
}
