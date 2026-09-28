import { IdentityService } from './identity-service.mjs';
import { sendWhatsAppOtp } from './whatsapp.mjs';
import { sendPrivateWhatsAppOtp, requirePrivateDelivery } from './private-delivery-sender.mjs';
const nowSql="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
/** Leased, bounded outbox drain. Provider acceptance is not a handset delivery receipt. */
export async function dispatchOtp(env,{clock=Date.now,sender}={}){
 if(env.AUTH_DELIVERY_ENABLED!=='true'||env.AUTH_SERVICE_ENABLED!=='true')return {disabled:true,accepted:0,failed:0};
 const mode=env.AUTH_DELIVERY_MODE??'legacy';
 if(!['legacy','private-deduplicated'].includes(mode))throw new Error('invalid_delivery_mode');
 if(mode==='private-deduplicated')requirePrivateDelivery(env);
 const selectedSender=sender??(mode==='private-deduplicated'?sendPrivateWhatsAppOtp:sendWhatsAppOtp);
 const service=new IdentityService(env,{clock}),db=service.db;
 await service.stmt(`UPDATE auth_challenges SET delivery_state='failed',delivery_cipher=NULL,lease_id=NULL,lease_until_ms=NULL WHERE challenge_id IN
  (SELECT challenge_id FROM auth_challenges WHERE delivery_state='leased' AND delivery_attempts>=3 AND lease_until_ms<=${nowSql} LIMIT 100)`).run();
 const candidates=await db.prepare(`SELECT challenge_id FROM auth_challenges WHERE state='open' AND expires_at_ms>${nowSql}
  AND delivery_cipher IS NOT NULL AND delivery_attempts<3 AND next_attempt_ms<=${nowSql}
  AND (delivery_state IN ('queued','retry') OR (delivery_state='leased' AND lease_until_ms<=${nowSql}))
  ORDER BY next_attempt_ms,challenge_id LIMIT 10`).all();
 let accepted=0,failed=0;
 for(const candidate of candidates.results){const lease=crypto.randomUUID();
  const changed=await service.stmt(`UPDATE auth_challenges SET delivery_state='leased',lease_id=?,lease_until_ms=?,delivery_attempts=delivery_attempts+1
   WHERE challenge_id=? AND state='open' AND expires_at_ms>${nowSql} AND delivery_cipher IS NOT NULL AND delivery_attempts<3 AND next_attempt_ms<=${nowSql}
   AND (delivery_state IN ('queued','retry') OR (delivery_state='leased' AND lease_until_ms<=${nowSql}))
   AND EXISTS(SELECT 1 FROM auth_clubs c,auth_settings x WHERE c.club_id=auth_challenges.club_id AND c.revision=auth_challenges.club_revision AND c.enabled=1 AND x.singleton=1 AND x.import_ready=1 AND length(x.import_evidence)>0 AND x.key_version='1')`,
   lease,clock()+30_000,candidate.challenge_id).run();if(changed.meta.changes!==1)continue;
  const c=await service.stmt(`SELECT q.*,c.auth_template FROM auth_challenges q JOIN auth_clubs c ON c.club_id=q.club_id
   WHERE q.challenge_id=? AND q.lease_id=? AND q.state='open' AND q.expires_at_ms>${nowSql} AND c.enabled=1 AND c.revision=q.club_revision`,candidate.challenge_id,lease).first();if(!c)continue;
  try{const payload=await service.vault.open(c.delivery_cipher,`challenge:${c.challenge_id}`);
   const result=await selectedSender(env,{...payload,template:c.auth_template,challengeId:c.challenge_id,clubId:c.club_id,expiresAt:c.expires_at_ms});
   if(result?.accepted!==true||typeof result.messageId!=='string'||result.messageId.length>256||!/^wamid\.[A-Za-z0-9+/_=:.-]+$/.test(result.messageId))throw new Error('unconfirmed_provider_acceptance');
   await service.stmt(`UPDATE auth_challenges SET delivery_state='accepted',provider_message_id=?,delivery_cipher=NULL,lease_id=NULL,lease_until_ms=NULL
    WHERE challenge_id=? AND lease_id=?`,result.messageId,c.challenge_id,lease).run();accepted++;
  }catch{
   await service.stmt(`UPDATE auth_challenges SET delivery_state=CASE WHEN delivery_attempts>=3 THEN 'failed' ELSE 'retry' END,
    next_attempt_ms=?,delivery_cipher=CASE WHEN delivery_attempts>=3 THEN NULL ELSE delivery_cipher END,lease_id=NULL,lease_until_ms=NULL WHERE challenge_id=? AND lease_id=?`,clock()+30_000,c.challenge_id,lease).run();failed++;
  }
 }
 return {disabled:false,accepted,failed};
}
/** Clear short-lived encrypted secrets in bounded batches; keep audit/identity/history intact. */
export async function expireTransientSecrets(env){if(env.AUTH_SERVICE_ENABLED!=='true')return {disabled:true};
 const service=new IdentityService(env);await service.db.batch([
  service.db.prepare(`UPDATE auth_challenges SET verification_cipher=NULL WHERE challenge_id IN
   (SELECT challenge_id FROM auth_challenges WHERE replay_until_ms<${nowSql} AND verification_cipher IS NOT NULL LIMIT 100)`),
  service.db.prepare(`UPDATE auth_challenges SET delivery_cipher=NULL,verification_cipher=NULL WHERE challenge_id IN
   (SELECT challenge_id FROM auth_challenges WHERE expires_at_ms<${nowSql}-60000 AND (delivery_cipher IS NOT NULL OR verification_cipher IS NOT NULL) LIMIT 100)`),
  service.db.prepare(`UPDATE auth_refresh_receipts SET response_cipher=NULL WHERE rowid IN
   (SELECT rowid FROM auth_refresh_receipts WHERE replay_until_ms<${nowSql} AND response_cipher IS NOT NULL LIMIT 100)`)
 ,service.db.prepare(`DELETE FROM auth_rate_windows WHERE rowid IN (SELECT rowid FROM auth_rate_windows WHERE window_start_ms<${nowSql}-172800000 LIMIT 1000)`)
 ]);return {disabled:false};}
