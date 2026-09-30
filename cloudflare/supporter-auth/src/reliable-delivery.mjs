import {assertRegisteredKeyPolicy} from './key-state.mjs';
import {IdentityService} from './identity-service.mjs';
import {sendPrivateWhatsAppOtp} from './private-delivery-sender.mjs';
import {deliveryPolicy,queuePolicy,deliveryDemand,OtpDispatchError,boundedDelivery} from './delivery-policy.mjs';
export const NOW="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
const joins=`auth_challenges q JOIN auth_clubs c ON c.club_id=q.club_id
 JOIN auth_settings x ON x.singleton=1 JOIN auth_delivery_control d ON d.singleton=1`;
const ready=`c.enabled=1 AND c.revision=q.club_revision AND x.import_ready=1
 AND length(x.import_evidence)>0 AND x.key_version='1' AND d.enabled=1`;
// Account revocation is checked as well as tenant revocation. New-phone challenges
// require the existing reviewed signup switch; no delivery creates an identity.
const subject=`((q.subject_at_request IS NULL AND c.allow_signup=1 AND NOT EXISTS(
 SELECT 1 FROM auth_accounts a WHERE a.phone_hash=q.phone_hash AND a.status<>'active')) OR
 EXISTS(SELECT 1 FROM auth_accounts a WHERE a.user_id=q.subject_at_request AND a.phone_hash=q.phone_hash
 AND a.auth_epoch=q.subject_epoch AND a.status='active'))`;
const due=`q.state='open' AND q.expires_at_ms>${NOW}+30000 AND q.delivery_cipher IS NOT NULL
 AND q.delivery_attempts<3 AND q.next_attempt_ms<=${NOW} AND q.delivery_state IN('queued','retry')
 AND (q.delivery_attempts=0 OR EXISTS(SELECT 1 FROM auth_delivery_attempts old WHERE old.challenge_id=q.challenge_id AND old.attempt=q.delivery_attempts))`;
const slots=xs=>xs.map(()=>'?').join(',');
const summary=()=>({schemaVersion:1,disabled:false,leased:0,accepted:0,unconfirmed:0,quarantined:0,leaseLost:0,skipped:0});
function statement(s,sql,...args){return s.stmt(sql,...args);}
async function outcome(s,lease){return s.stmt('SELECT outcome FROM auth_delivery_outcomes WHERE lease_id=?',lease).first();}
async function transact(s,steps){await s.batch(steps);}
async function quarantineLegacy(s,p,result){
 const rows=await s.stmt(`SELECT q.challenge_id FROM auth_challenges q WHERE q.club_id IN(${slots(p.clubIds)})
 AND q.delivery_state IN('queued','retry','leased') AND q.delivery_attempts>0
 AND NOT EXISTS(SELECT 1 FROM auth_delivery_attempts a WHERE a.challenge_id=q.challenge_id)
 AND NOT EXISTS(SELECT 1 FROM auth_delivery_quarantine z WHERE z.challenge_id=q.challenge_id)
 ORDER BY q.challenge_id LIMIT 100`,...p.clubIds).all();
 for(const q of rows.results){
  try {await transact(s,[
   statement(s,`INSERT INTO auth_delivery_quarantine SELECT challenge_id,'legacy_unconfirmed',${NOW}
    FROM auth_challenges q WHERE challenge_id=? AND delivery_attempts>0 AND delivery_state IN('queued','retry','leased')
    AND NOT EXISTS(SELECT 1 FROM auth_delivery_attempts a WHERE a.challenge_id=q.challenge_id)`,q.challenge_id),
   s.assertion('changes()=1'),
   statement(s,`UPDATE auth_challenges SET delivery_state='failed',delivery_cipher=NULL,lease_id=NULL,lease_until_ms=NULL
    WHERE challenge_id=?`,q.challenge_id)
  ]);result.quarantined++;}catch{
   const saved=await s.stmt('SELECT 1 ok FROM auth_delivery_quarantine WHERE challenge_id=?',q.challenge_id).first();
   deliveryDemand(saved,'delivery_quarantine_unavailable');
  }
 }
}
async function recoverExpired(s,p,result){
 const rows=await s.stmt(`SELECT a.lease_id,a.challenge_id,q.delivery_attempts FROM auth_delivery_attempts a
 JOIN auth_challenges q ON q.challenge_id=a.challenge_id WHERE a.club_id IN(${slots(p.clubIds)})
 AND q.delivery_state='leased' AND q.lease_id=a.lease_id AND q.lease_until_ms<=${NOW}
 AND NOT EXISTS(SELECT 1 FROM auth_delivery_outcomes o WHERE o.lease_id=a.lease_id)
 ORDER BY a.lease_until_ms,a.lease_id LIMIT 100`,...p.clubIds).all();
 for(const r of rows.results){
  try {await transact(s,[
   statement(s,`UPDATE auth_challenges SET delivery_state=CASE WHEN delivery_attempts>=3 THEN 'failed' ELSE 'retry' END,
    delivery_cipher=CASE WHEN delivery_attempts>=3 THEN NULL ELSE delivery_cipher END,lease_id=NULL,lease_until_ms=NULL,
    next_attempt_ms=${NOW}+? WHERE challenge_id=? AND lease_id=? AND delivery_state='leased' AND lease_until_ms<=${NOW}`,
    p.retryDelayMs,r.challenge_id,r.lease_id),s.assertion('changes()=1'),
   statement(s,`INSERT INTO auth_delivery_outcomes VALUES(?,'lease_expired',${NOW})`,r.lease_id)
  ]);}catch{result.leaseLost++;}
 }
}
async function endUnconfirmed(s,p,c,lease,invalidated=false){
 const terminal=invalidated||c.delivery_attempts>=3;
 try{await transact(s,[
  statement(s,`UPDATE auth_challenges SET delivery_state=?,next_attempt_ms=${NOW}+?,
   delivery_cipher=CASE WHEN ? THEN NULL ELSE delivery_cipher END,lease_id=NULL,lease_until_ms=NULL
   WHERE challenge_id=? AND lease_id=? AND delivery_state='leased'`,terminal?'failed':'retry',p.retryDelayMs,terminal?1:0,c.challenge_id,lease),
  s.assertion('changes()=1'),statement(s,`INSERT INTO auth_delivery_outcomes VALUES(?,?,${NOW})`,lease,invalidated?'invalidated':'unconfirmed')
 ]);return 'unconfirmed';}catch{
  const saved=await outcome(s,lease).catch(()=>null);
  return saved?.outcome==='accepted'?'accepted':saved&&['unconfirmed','invalidated'].includes(saved.outcome)?'unconfirmed':'leaseLost';
 }
}
/** Production caller supplies only env. Injected clock/sender are test ports, never request fields.
 * Retries use the SAME durable private dispatch ID. A timeout does not cancel remote work.
 * All returned counts concern this drain; they are not authentication or handset receipts. */
async function drain(env,{clock=Date.now,sender=sendPrivateWhatsAppOtp,rpcTimeoutMs,monotonic=()=>performance.now()}={}){
 const result=summary();
 if(env.AUTH_DELIVERY_ENABLED!=='true'||env.AUTH_SERVICE_ENABLED!=='true')return {...result,disabled:true};
 const p=deliveryPolicy(env),policyBytes=env.AUTH_DELIVERY_POLICY_JSON;
 const callMs=rpcTimeoutMs??p.rpcTimeoutMs;
 deliveryDemand(Number.isInteger(callMs)&&callMs>0&&callMs<=p.rpcTimeoutMs,'invalid_delivery_timeout');
 deliveryDemand(typeof env.AUTH_DB?.withSession==='function','primary_database_required');
 const s=new IdentityService({...env,AUTH_DB:env.AUTH_DB.withSession('first-primary')},{clock}),
  keyReady=ready.replace("x.key_version='1'",`x.key_version='${s.vault.currentVersion}'`);
 await assertRegisteredKeyPolicy(s.db,s.vault);
 const control=await s.stmt('SELECT revision FROM auth_delivery_control WHERE singleton=1 AND enabled=1').first();
 deliveryDemand(control,'delivery_control_disabled');
 const started=monotonic(),counts=new Map();
 await quarantineLegacy(s,p,result);await recoverExpired(s,p,result);
 for(let i=0;i<p.batchLimit;i++){
  if(monotonic()-started>=p.runBudgetMs)break;
  if(env.AUTH_DELIVERY_ENABLED!=='true'||env.AUTH_SERVICE_ENABLED!=='true')break;
  const allowed=p.clubIds.filter(id=>(counts.get(id)??0)<p.perClubLimit);if(!allowed.length)break;
  const c=await s.stmt(`SELECT q.*,c.auth_template,d.revision delivery_revision FROM ${joins}
   LEFT JOIN auth_delivery_turns t ON t.club_id=q.club_id
   WHERE q.club_id IN(${slots(allowed)}) AND ${keyReady} AND ${subject} AND ${due}
   AND NOT EXISTS(SELECT 1 FROM auth_delivery_quarantine z WHERE z.challenge_id=q.challenge_id)
   ORDER BY COALESCE(t.last_sequence,0),q.next_attempt_ms,q.challenge_id LIMIT 1`,...allowed).first();
  if(!c)break;
  const lease=crypto.randomUUID();counts.set(c.club_id,(counts.get(c.club_id)??0)+1);
  try {await transact(s,[
   s.assertion(`EXISTS(SELECT 1 FROM ${joins} WHERE q.challenge_id=? AND ${keyReady} AND ${subject}
    AND d.revision=? AND ${due})`,c.challenge_id,control.revision),
   statement(s,`UPDATE auth_challenges SET delivery_state='leased',lease_id=?,lease_until_ms=${NOW}+?,delivery_attempts=delivery_attempts+1
    WHERE challenge_id=? AND delivery_state IN('queued','retry') AND delivery_attempts=? AND next_attempt_ms<=${NOW}`,lease,p.leaseMs,c.challenge_id,c.delivery_attempts),
   s.assertion('changes()=1'),
   statement(s,`INSERT INTO auth_delivery_attempts SELECT lease_id,challenge_id,club_id,delivery_attempts,${NOW},lease_until_ms
    FROM auth_challenges WHERE challenge_id=? AND lease_id=?`,c.challenge_id,lease),s.assertion('changes()=1'),
   statement(s,'UPDATE auth_delivery_control SET sequence=sequence+1 WHERE singleton=1 AND enabled=1 AND revision=?',control.revision),s.assertion('changes()=1'),
   statement(s,`INSERT INTO auth_delivery_turns SELECT ?,sequence FROM auth_delivery_control WHERE singleton=1
    ON CONFLICT(club_id) DO UPDATE SET last_sequence=excluded.last_sequence`,c.club_id)
  ]);}catch{result.skipped++;continue;}
  result.leased++;c.delivery_attempts++;
  let accepted;
  try{
   const payload=await s.vault.open(c.delivery_cipher,`challenge:${c.challenge_id}`);
   const live=await env.AUTH_DB.withSession('first-primary').prepare(`SELECT 1 ok FROM ${joins} WHERE q.challenge_id=? AND q.lease_id=? AND q.delivery_state='leased'
    AND q.state='open' AND q.expires_at_ms>${NOW}+30000 AND q.lease_until_ms>${NOW}+?
    AND ${keyReady} AND ${subject} AND d.revision=?`).bind(c.challenge_id,lease,callMs+1000,control.revision).first();
   deliveryDemand(live&&env.AUTH_DELIVERY_ENABLED==='true'&&env.AUTH_SERVICE_ENABLED==='true'&&
    env.AUTH_DELIVERY_POLICY_JSON===policyBytes&&env.AUTH_DELIVERY_MODE==='private-deduplicated','delivery_invalidated');
   const remaining=p.runBudgetMs-(monotonic()-started);deliveryDemand(remaining>0,'delivery_budget_expired');
   accepted=await boundedDelivery(()=>sender(env,{...payload,template:c.auth_template,challengeId:c.challenge_id,
    clubId:c.club_id,expiresAt:c.expires_at_ms}),Math.min(callMs,remaining));
   deliveryDemand(accepted?.accepted===true&&typeof accepted.messageId==='string'&&accepted.messageId.length<=256&&
    /^wamid\.[A-Za-z0-9+/_=:.-]+$/.test(accepted.messageId),'private_delivery_unconfirmed');
  }catch(error){result[await endUnconfirmed(s,p,c,lease,error?.code==='delivery_invalidated')]++;continue;}
  try{await transact(s,[
   s.assertion(`EXISTS(SELECT 1 FROM ${joins} WHERE q.challenge_id=? AND q.lease_id=? AND ${keyReady}
    AND ${subject} AND d.revision=? AND q.state='open' AND q.expires_at_ms>${NOW} AND q.lease_until_ms>${NOW})`,c.challenge_id,lease,control.revision),
   statement(s,`UPDATE auth_challenges SET delivery_state='accepted',provider_message_id=?,delivery_cipher=NULL,lease_id=NULL,lease_until_ms=NULL
    WHERE challenge_id=? AND lease_id=? AND delivery_state='leased'`,accepted.messageId,c.challenge_id,lease),s.assertion('changes()=1'),
   statement(s,`INSERT INTO auth_delivery_outcomes VALUES(?,'accepted',${NOW})`,lease)
  ]);result.accepted++;}catch{
   const saved=await outcome(s,lease).catch(()=>null);
   if(saved?.outcome==='accepted')result.accepted++;
   else result[await endUnconfirmed(s,p,c,lease)]++;
  }
 }
 return result;
}
/** Bounded, aggregate, primary-database observation for a PRIVATE operations consumer.
 * Counts saturate at 1,000; no challenge IDs, phones, codes, users or tokens returned. */
async function queueHealth(env){
 deliveryDemand(env.AUTH_DELIVERY_HEALTH_ENABLED==='true'&&env.AUTH_DB,'delivery_health_disabled');
 const p=queuePolicy(env),db=env.AUTH_DB;
 deliveryDemand(typeof db.withSession==='function','primary_database_required');
 const primary=db.withSession('first-primary');
 const control=await primary.prepare(`SELECT enabled,revision,${NOW} observed_at_ms FROM auth_delivery_control WHERE singleton=1`).first();
 deliveryDemand(control,'delivery_control_unavailable');const clubs=[];
 for(const id of p.clubIds){const counts={};for(const state of ['queued','leased','retry','failed','accepted']){
   const r=await primary.prepare(`SELECT COUNT(*) n FROM(SELECT 1 FROM auth_challenges WHERE club_id=? AND delivery_state=? LIMIT 1001)`).bind(id,state).first();
   counts[state]={count:Math.min(r.n,1000),capped:r.n>1000};
  }
  const oldest=await primary.prepare(`SELECT MIN(next_attempt_ms) ms FROM(SELECT next_attempt_ms FROM auth_challenges
   WHERE club_id=? AND state='open' AND delivery_cipher IS NOT NULL AND delivery_attempts<3
   AND delivery_state IN('queued','retry') AND expires_at_ms>${NOW} ORDER BY next_attempt_ms,challenge_id LIMIT 1)`).bind(id).first();
  clubs.push({clubId:id,states:counts,oldestPendingAt:oldest?.ms??null});
 }
 return {schemaVersion:1,observedAt:control.observed_at_ms,controlEnabled:control.enabled===1,revision:control.revision,clubs,
  paymentAuthority:false,authenticationAuthority:false};
}

// Never let SQL/provider diagnostics escape into scheduled-operation errors.
export async function drainOtp(env,options={}) {
 try {return await drain(env,options);}catch(error){
  if(error instanceof OtpDispatchError)throw error;
  throw new OtpDispatchError('delivery_storage_unavailable');
 }
}
export async function otpQueueHealth(env) {
 try {return await queueHealth(env);}catch(error){
  if(error instanceof OtpDispatchError)throw error;
  throw new OtpDispatchError('delivery_health_unavailable');
 }
}
