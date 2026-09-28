import { drainOtp } from './reliable-delivery.mjs';
export { drainOtp, otpQueueHealth } from './reliable-delivery.mjs';
const nowSql="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
/** Backward-compatible queue summary. `failed` means no completed local acceptance
 * in this drain; it never proves no provider send. Use drainOtp for precise counts. */
export async function dispatchOtp(env,options={}) {
 const r=await drainOtp(env,options);
 return {disabled:r.disabled,accepted:r.accepted,failed:r.unconfirmed+r.quarantined+r.leaseLost};
}
/** Clear short-lived encrypted secrets in bounded batches; keep audit/identity/history intact. */
export async function expireTransientSecrets(env){if(env.AUTH_SERVICE_ENABLED!=='true')return {disabled:true};
 const db=env.AUTH_DB;if(!db||typeof db.prepare!=='function'||typeof db.batch!=='function')throw new Error('secret_expiry_unavailable');
 try{await db.batch([
  db.prepare(`UPDATE auth_challenges SET verification_cipher=NULL WHERE challenge_id IN
   (SELECT challenge_id FROM auth_challenges WHERE replay_until_ms<${nowSql} AND verification_cipher IS NOT NULL LIMIT 100)`),
  db.prepare(`UPDATE auth_challenges SET delivery_cipher=NULL,verification_cipher=NULL WHERE challenge_id IN
   (SELECT challenge_id FROM auth_challenges WHERE expires_at_ms<${nowSql}-60000 AND (delivery_cipher IS NOT NULL OR verification_cipher IS NOT NULL) LIMIT 100)`),
  db.prepare(`UPDATE auth_refresh_receipts SET response_cipher=NULL WHERE rowid IN
   (SELECT rowid FROM auth_refresh_receipts WHERE replay_until_ms<${nowSql} AND response_cipher IS NOT NULL LIMIT 100)`)
 ,db.prepare(`DELETE FROM auth_rate_windows WHERE rowid IN (SELECT rowid FROM auth_rate_windows WHERE window_start_ms<${nowSql}-172800000 LIMIT 1000)`)
 ]);}catch{throw new Error('secret_expiry_unavailable');}return {disabled:false};}
