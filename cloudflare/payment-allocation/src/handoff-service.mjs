import {MembershipCheckoutService} from './checkout-service.mjs';
import {NOW_SQL} from './policy.mjs';
import {CheckoutError,requireCheckout,uuid,club,exact,hash} from './checkout-policy.mjs';
const revisions=['principal_revision','grant_revision','club_revision','subject_revision','control_revision'];
const currentOrder=`EXISTS(SELECT 1 FROM pa_checkout_reusable z JOIN pa_orders o ON o.order_id=z.order_id
 WHERE z.order_id=? AND z.club_id=? AND z.user_id=? AND o.expires_at_ms>${NOW_SQL}+15000)`;
const unresolved=`EXISTS(SELECT 1 FROM pa_handoff_heads h JOIN pa_handoff_reservations r ON r.handoff_id=h.handoff_id
 JOIN pa_orders o ON o.order_id=r.order_id WHERE h.club_id=? AND h.user_id=? AND o.state<>'fulfilled' AND
 NOT EXISTS(SELECT 1 FROM pa_handoff_releases z WHERE z.handoff_id=r.handoff_id) AND
 (EXISTS(SELECT 1 FROM pa_handoff_claims c WHERE c.handoff_id=r.handoff_id) OR (o.state='pending' AND o.expires_at_ms>${NOW_SQL})))`;
function input(value,fields){
 try{exact(value,['clubId','userId',...fields]);}catch{throw new CheckoutError('invalid_request');}
 requireCheckout(club(value.clubId)&&uuid(value.userId));for(const name of fields)requireCheckout(uuid(value[name]));return {...value};
}
/** Private SAME-DB journal, not payment or a proof the carrier opened. Claim grants
 * a single first-response opportunity. Replays NEVER regrant permission to dial. */
export class PaymentHandoffService extends MembershipCheckoutService {
 gate(){requireCheckout(this.env.HANDOFF_JOURNAL_ENABLED==='true','handoff_disabled');}
 async auth(v,cap){this.gate();const a=await this.authority(v.clubId,v.userId,cap);const s=await this.first('SELECT revision FROM pa_handoff_settings WHERE singleton=1 AND enabled=1');requireCheckout(s,'handoff_disabled');return {...a,handoff_revision:s.revision};}
 assertion(expression,...args){const assertionId=crypto.randomUUID();return {assertionId,statement:this.statement(`INSERT INTO pa_handoff_guards(guard_id,ok) VALUES(?,CASE WHEN (${expression}) THEN 1 ELSE 0 END)`,assertionId,...args)};}
 authGuard(v,a,cap){return this.assertion(`EXISTS(SELECT 1 FROM pa_checkout_authorizations z,pa_handoff_settings h WHERE
 z.principal_id=? AND z.club_id=? AND z.user_id=? AND z.capability=? AND ${revisions.map(x=>`z.${x}=?`).join(' AND ')}
 AND h.singleton=1 AND h.enabled=1 AND h.revision=?)`,this.principalId,v.clubId,v.userId,cap,...revisions.map(x=>a[x]),a.handoff_revision);}
 async commit(steps){const guards=steps.filter(s=>s.assertionId);await this.db.batch([...steps.map(s=>s.statement??s),...guards.map(s=>this.statement('DELETE FROM pa_handoff_guards WHERE guard_id=?',s.assertionId))]);}
 async row(v,by='head'){
  return this.first(`SELECT r.*,c.claimed_at_ms,z.released_at_ms,o.state order_state,o.expires_at_ms,${NOW_SQL} observed_at_ms FROM pa_handoff_reservations r
   JOIN pa_orders o ON o.order_id=r.order_id LEFT JOIN pa_handoff_claims c ON c.handoff_id=r.handoff_id
   LEFT JOIN pa_handoff_releases z ON z.handoff_id=r.handoff_id
   ${by==='head'?'JOIN pa_handoff_heads h ON h.handoff_id=r.handoff_id':''}
   WHERE r.club_id=? AND r.user_id=? ${by==='head'?'':by==='request'?'AND r.request_id=?':'AND r.handoff_id=?'}`,
   v.clubId,v.userId,...(by==='head'?[]:[by==='request'?v.requestId:v.handoffId]));
 }
 view(row){return {schemaVersion:1,handoff:row?{handoffId:row.handoff_id,orderId:row.order_id,clubId:row.club_id,
  phase:row.order_state==='fulfilled'?'allocated':row.claimed_at_ms!==null?'claimed':row.released_at_ms!==null?'released':'reserved',
  createdAt:row.created_at_ms,claimedAt:row.claimed_at_ms??null,orderExpiresAt:row.expires_at_ms,
  paymentEvidenceAllocated:row.order_state==='fulfilled',observedAt:row.observed_at_ms}:null,mayOpenDialer:false};}
 async currentHandoff(value){const v=input(value,[]);await this.auth(v,'read');const r=await this.row(v);await this.auth(v,'read');return this.view(r);}
 async reserveHandoff(value){
  const v=input(value,['orderId','requestId']),a=await this.auth(v,'prepare');
  const prior=await this.row(v,'request');if(prior){requireCheckout(prior.order_id===v.orderId,'idempotency_conflict');await this.auth(v,'prepare');return this.view(prior);}
  const original=await this.first('SELECT snapshot_json FROM pa_checkout_order_details d JOIN pa_orders o ON o.order_id=d.order_id WHERE d.order_id=? AND o.club_id=? AND o.user_id=?',v.orderId,v.clubId,v.userId);
  requireCheckout(original,'not_found');const digest=await hash({snapshot:original.snapshot_json});
  if(await this.first(`SELECT 1 ok WHERE ${unresolved}`,v.clubId,v.userId)) {
    const raced=await this.row(v,'request');
    if(raced){requireCheckout(raced.order_id===v.orderId,'idempotency_conflict');await this.auth(v,'prepare');return this.view(raced);}
    throw new CheckoutError('unresolved_payment_handoff');
  }
  const id=crypto.randomUUID();
  try{await this.commit([
   this.authGuard(v,a,'prepare'),this.assertion(currentOrder,v.orderId,v.clubId,v.userId),this.assertion(`NOT (${unresolved})`,v.clubId,v.userId),
   this.statement(`INSERT INTO pa_handoff_reservations VALUES(?,?,?,?,?,?,?,${NOW_SQL})`,id,this.principalId,v.clubId,v.userId,v.requestId,v.orderId,digest),
   this.statement('INSERT INTO pa_handoff_heads VALUES(?,?,?) ON CONFLICT(user_id,club_id) DO UPDATE SET handoff_id=excluded.handoff_id',v.userId,v.clubId,id),
   this.statement(`INSERT INTO pa_handoff_audit VALUES(?,?,?,'reserved',${NOW_SQL})`,crypto.randomUUID(),id,this.principalId),this.authGuard(v,a,'prepare')
  ]);}catch(error){
   await this.auth(v,'prepare');const raced=await this.row(v,'request');if(raced){requireCheckout(raced.order_id===v.orderId,'idempotency_conflict');return this.view(raced);}
   throw new CheckoutError('handoff_outcome_unknown');
  }
  await this.auth(v,'prepare');return this.view(await this.row({...v,handoffId:id},'id'));
 }
 async claimHandoff(value){
  const v=input(value,['handoffId','requestId']),a=await this.auth(v,'prepare'),r=await this.row(v,'id');requireCheckout(r,'not_found');
  const priorKey=await this.first('SELECT handoff_id FROM pa_handoff_claims WHERE user_id=? AND club_id=? AND request_id=?',v.userId,v.clubId,v.requestId);
  requireCheckout(!priorKey||priorKey.handoff_id===v.handoffId,'idempotency_conflict');
  if(r.claimed_at_ms!==null){await this.auth(v,'prepare');return this.view(r);}
  requireCheckout(r.released_at_ms===null,'handoff_released');
  requireCheckout(r.order_state==='pending'&&r.expires_at_ms>r.observed_at_ms+15000,'checkout_not_payable');
  try{await this.commit([
   this.authGuard(v,a,'prepare'),this.assertion('EXISTS(SELECT 1 FROM pa_handoff_heads WHERE user_id=? AND club_id=? AND handoff_id=?)',v.userId,v.clubId,v.handoffId),
   this.assertion(currentOrder,r.order_id,v.clubId,v.userId),
   this.statement(`INSERT INTO pa_handoff_claims VALUES(?,?,?,?,?,${NOW_SQL})`,v.handoffId,this.principalId,v.userId,v.clubId,v.requestId),
   this.statement(`INSERT INTO pa_handoff_audit VALUES(?,?,?,'claimed',${NOW_SQL})`,crypto.randomUUID(),v.handoffId,this.principalId),this.authGuard(v,a,'prepare')
  ]);}catch(error){
   // Even same-request recovery CANNOT establish that a previous response never
   // reached a device. Return status only; do not repeat the first-call grant.
   await this.auth(v,'prepare');const observed=await this.row(v,'id');if(observed&&observed.claimed_at_ms!==null)return this.view(observed);
   throw new CheckoutError('handoff_outcome_unknown');
  }
  await this.auth(v,'prepare');const observed=await this.row(v,'id');
  requireCheckout(observed&&observed.claimed_at_ms!==null,'handoff_outcome_unknown');
  return {...this.view(observed),mayOpenDialer:observed.order_state==='pending'&&observed.expires_at_ms>observed.observed_at_ms+15000};
 }
 /** Explicit authenticated user action. The immutable release row is its audit
  * record. The old head and order remain; no money or historical claim is altered.
  */
 async releaseHandoff(value) {
  const v=input(value,['handoffId','requestId']),a=await this.auth(v,'prepare');
  requireCheckout(this.env.HANDOFF_RELEASE_ENABLED==='true','handoff_release_disabled');
  const setting=await this.first('SELECT revision FROM pa_handoff_release_settings WHERE singleton=1 AND enabled=1');
  requireCheckout(setting,'handoff_release_disabled');
  const r=await this.row(v,'id');requireCheckout(r,'not_found');
  const prior=await this.first('SELECT * FROM pa_handoff_releases WHERE user_id=? AND club_id=? AND request_id=?',v.userId,v.clubId,v.requestId);
  requireCheckout(!prior||prior.handoff_id===v.handoffId,'idempotency_conflict');
  const existing=await this.first('SELECT request_id FROM pa_handoff_releases WHERE handoff_id=?',v.handoffId);
  if(existing){requireCheckout(existing.request_id===v.requestId,'idempotency_conflict');await this.auth(v,'prepare');return this.view(r);}
  requireCheckout(r.claimed_at_ms===null&&r.order_state!=='fulfilled','handoff_not_releasable');
  try {await this.commit([
   this.authGuard(v,a,'prepare'),
   this.assertion('EXISTS(SELECT 1 FROM pa_handoff_release_settings WHERE singleton=1 AND enabled=1 AND revision=?)',setting.revision),
   this.assertion(`EXISTS(SELECT 1 FROM pa_handoff_heads h JOIN pa_handoff_reservations r ON r.handoff_id=h.handoff_id
    JOIN pa_orders o ON o.order_id=r.order_id WHERE h.handoff_id=? AND h.user_id=? AND h.club_id=?
    AND o.state<>'fulfilled' AND NOT EXISTS(SELECT 1 FROM pa_handoff_claims c WHERE c.handoff_id=h.handoff_id))`,v.handoffId,v.userId,v.clubId),
   this.statement(`INSERT INTO pa_handoff_releases VALUES(?,?,?,?,?,${NOW_SQL},'never_claimed')`,v.handoffId,this.principalId,v.userId,v.clubId,v.requestId),
   this.assertion('changes()=1'),this.authGuard(v,a,'prepare')
  ]);}catch{
   await this.auth(v,'prepare');
   const saved=await this.first('SELECT request_id FROM pa_handoff_releases WHERE handoff_id=?',v.handoffId);
   if(saved&&saved.request_id===v.requestId)return this.view(await this.row(v,'id'));
   throw new CheckoutError('handoff_outcome_unknown');
  }
  await this.auth(v,'prepare');return this.view(await this.row(v,'id'));
 }
}
