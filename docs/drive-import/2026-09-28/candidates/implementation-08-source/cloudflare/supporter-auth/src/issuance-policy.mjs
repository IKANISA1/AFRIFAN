import { AuthError } from './errors.mjs';

// The global ceiling cannot be smaller than the sum of club reservations. A club
// cannot spend another club's budget. Values are reviewed configuration, NOT load
// certification. Changing this policy mid-window requires an operational drain.
const own = (o, keys) => o && typeof o === 'object' && !Array.isArray(o) &&
  Object.keys(o).length === keys.length && keys.every(k => Object.hasOwn(o, k));
const integer = (v, min, max) => Number.isSafeInteger(v) && v >= min && v <= max;
const invalid = () => { throw new AuthError('issuance_policy_unconfigured', 503); };
export function issuancePolicy(raw) {
  if (typeof raw !== 'string' || raw.length > 16384) return invalid();
  let p; try { p = JSON.parse(raw); } catch { return invalid(); }
  if (!own(p, ['version', 'globalPerMinute', 'perIpPerMinute', 'phonePer15Minutes', 'clubs']) ||
      p.version !== 1 || !integer(p.globalPerMinute, 1, 10000) ||
      !integer(p.perIpPerMinute, 1, 1000) || !integer(p.phonePer15Minutes, 1, 3) ||
      !p.clubs || typeof p.clubs !== 'object' || Array.isArray(p.clubs)) return invalid();
  const entries = Object.entries(p.clubs);
  if (!entries.length || entries.length > 100) return invalid();
  let total = 0;
  for (const [id, cap] of entries) {
    if (!/^[1-9][0-9]{0,9}$/.test(id) || !integer(Number(id), 1, 9999999999) ||
        !integer(cap, 1, 1000)) return invalid();
    total += cap;
  }
  if (total > p.globalPerMinute) return invalid();
  return Object.freeze({...p, clubs: Object.freeze({...p.clubs})});
}
export function issuanceWindows(env, clubId, ipKey, phoneHash) {
  const policy = issuancePolicy(env.AUTH_ISSUANCE_POLICY_JSON);
  const cap = policy.clubs[String(clubId)];
  if (!cap || !/^[a-f0-9]{64}$/.test(ipKey) || !/^[a-f0-9]{64}$/.test(phoneHash)) return invalid();
  return [
    ['issue:global', 60000, policy.globalPerMinute],
    [`issue:club:${clubId}`, 60000, cap],
    [`issue:ip:${clubId}:${ipKey}`, 60000, Math.min(cap, policy.perIpPerMinute)],
    // Phone budget deliberately spans clubs: prevent a person being spammed by
    // switching tenants. This is distinct from per-club/shared-network fairness.
    [`issue:phone:${phoneHash}`, 900000, policy.phonePer15Minutes],
  ];
}
