import { AuthError } from './errors.mjs';

const CLUBS = Object.freeze([6,24,26,44,1001]);
const DEFAULT = Object.freeze({schemaVersion:1, globalPerMinute:50, perClubPerMinute:10,
  perIpPerMinute:30, perPhonePer15Minutes:3, clubs:CLUBS});
const fail = () => { throw new AuthError('otp_rate_policy_unconfigured',503); };
/** A static deployment policy, not caller input. The global ceiling reserves enough
 * capacity for every approved club's full quota. Existing rate keys never reset
 * when policy settings change. Values are pilot limits, not capacity certification. */
export function otpRatePolicy(env = {}) {
  const raw = env.AUTH_OTP_RATE_POLICY_JSON;
  let p = DEFAULT;
  if (raw !== undefined) {
    if (typeof raw !== 'string' || raw.length > 2048) fail();
    try { p = JSON.parse(raw); } catch { fail(); }
  }
  const keys = Object.keys(DEFAULT);
  if (!p || Array.isArray(p) || typeof p !== 'object' || Object.keys(p).length !== keys.length ||
    keys.some(k=>!Object.hasOwn(p,k)) || p.schemaVersion !== 1) fail();
  for (const [k,max] of [['globalPerMinute',500],['perClubPerMinute',100],['perIpPerMinute',100],['perPhonePer15Minutes',3]]) {
    if (!Number.isSafeInteger(p[k]) || p[k] < 1 || p[k] > max) fail();
  }
  if (!Array.isArray(p.clubs) || !p.clubs.length || new Set(p.clubs).size !== p.clubs.length ||
    p.clubs.some(c=>!CLUBS.includes(c)) || p.globalPerMinute < p.perClubPerMinute*p.clubs.length) fail();
  return Object.freeze({...p, clubs:Object.freeze([...p.clubs])});
}
export function issuanceWindows(policy, clubId, ipHash, phoneHash) {
  if (!policy.clubs.includes(clubId)) throw new AuthError('club_not_available',503);
  if (![ipHash,phoneHash].every(s=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s))) fail();
  return [
    ['issue:global',60_000,policy.globalPerMinute],
    [`issue:club:${clubId}`,60_000,policy.perClubPerMinute],
    [`issue:ip:${ipHash}`,60_000,policy.perIpPerMinute],
    [`issue:phone:${phoneHash}`,900_000,policy.perPhonePer15Minutes],
  ];
}
