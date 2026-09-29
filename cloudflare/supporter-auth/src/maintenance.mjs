import {drainOtp} from './reliable-delivery.mjs';
import {expireTransientSecrets} from './delivery.mjs';

/** Attempt secret expiry independently of sending. No raw SQL/provider error is retained.
 * A failure still rejects the scheduled promise, so Cron does not report a false success.
 * Neither task is an external replay mechanism; drainOtp uses existing dispatch IDs.
 */
export async function runIdentityMaintenance(env, {drain = drainOtp, expire = expireTransientSecrets} = {}) {
  if (env.AUTH_SERVICE_ENABLED !== 'true') return {schemaVersion: 1, disabled: true};
  const results = await Promise.allSettled([
    Promise.resolve().then(() => expire(env)),
    Promise.resolve().then(() => drain(env)),
  ]);
  if (results.some(result => result.status === 'rejected')) {
    const failure = new Error('identity_maintenance_incomplete');
    failure.code = 'identity_maintenance_incomplete';
    throw failure;
  }
  return {schemaVersion: 1, disabled: false, expiry: results[0].value, delivery: results[1].value};
}
