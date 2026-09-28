/** Stable, non-sensitive API errors. Never serialize a provider/SQL exception. */
export class OperatorError extends Error {
  constructor(code, status = 400) { super(code); this.name = 'OperatorError'; this.code = code; this.status = status; }
}
export function requireThat(condition, code, status = 400) {
  if (!condition) throw new OperatorError(code, status);
}
export const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export const HEX64 = /^[a-f0-9]{64}$/;
export function exactObject(value, keys, code = 'invalid_request') {
  requireThat(value && typeof value === 'object' && !Array.isArray(value) &&
    Object.keys(value).length === keys.length && keys.every(k => Object.hasOwn(value, k)), code);
}
export function positiveClub(value) {
  requireThat(Number.isSafeInteger(value) && value > 0, 'invalid_club_id');
  return value;
}
