/** Stable public errors: never expose SQL, provider responses, phone numbers or tokens. */
export class AuthError extends Error {
  constructor(code, status=400) { super(code); this.name='AuthError'; this.code=code; this.status=status; }
}
export function requireValue(ok, code='invalid_request', status=400) {
  if(!ok) throw new AuthError(code,status);
}
export const publicError = error => error instanceof AuthError ? error : new AuthError('service_unavailable',503);
export function exactKeys(value, required, optional=[]) {
  requireValue(value && typeof value==='object' && !Array.isArray(value));
  requireValue(required.every(k=>Object.hasOwn(value,k)) && Object.keys(value).every(k=>[...required,...optional].includes(k)));
}
export const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const SECRET=/^[A-Za-z0-9_-]{43}$/;
export function clubId(value){ requireValue(Number.isSafeInteger(value)&&value>0);return value; }
export function requestKey(value){requireValue(typeof value==='string'&&/^[A-Za-z0-9_-]{16,128}$/.test(value));return value;}
export function phoneNumber(value){requireValue(typeof value==='string'&&/^\+[1-9]\d{7,14}$/.test(value));return value;}
