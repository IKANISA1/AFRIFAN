import {NOW_SQL,configure,uuid,club,sha,exact,hash} from './policy.mjs';

export class HandoffError extends Error {
  constructor(code='handoff_unavailable') { super(code); this.name='HandoffError'; this.code=code; }
}
const need=(v,c='invalid_request')=>{if(!v)throw new HandoffError(c);};
const normalizeError=e=>{
  if(e instanceof HandoffError)return e;
  const known=['handoff_permission_denied','handoff_unresolved','handoff_order_changed'];
  return new HandoffError(known.find(c=>String(e?.message??'').includes(c))??'handoff_unavailable');
};
export function reviewObject(s) {
  return {clubId:s.clubId,orderId:s.orderId,tier:s.tier,expiresAt:s.expiresAt,
    amount:s.amount,currency:s.currency,country:s.country,provider:s.provider,recipient:s.recipient,ussdCode:s.ussdCode};
}
export async function reviewHash(snapshot) { return hash({purpose:'africlub-handoff-review-v1',...reviewObject(snapshot)}); }

/** Private, staging-only service. Caller derives the human identity; no access token is stored.
 * A replay is evidence ONLY, never a second launch grant. No provider/dialer call exists here. */
export class ServerHandoffService {
  constructor(env,principalId) {
    this.env=env;this.principalId=principalId;need(uuid(principalId),'invalid_configuration');this.db=this.gate();
  }
  gate(){need(this.env.SERVER_HANDOFF_ENABLED==='true','handoff_disabled');
    try{return configure(this.env);}catch{throw new HandoffError('handoff_disabled');}}
  stmt(sql,...args){return this.db.prepare(sql).bind(...args);}
  first(sql,...args){return this.db.withSession('first-primary').prepare(sql).bind(...args).first();}
  async authority(clubId,userId,capability){this.gate();need(club(clubId)&&uuid(userId));
    const a=await this.first('SELECT * FROM pa_handoff_authorizations WHERE principal_id=? AND club_id=? AND user_id=? AND capability=?',this.principalId,clubId,userId,capability);
    need(a,'handoff_permission_denied');return a;}
  async prior(v,digest){
    const row=await this.first('SELECT * FROM pa_handoff_reservations WHERE club_id=? AND user_id=? AND request_id=?',v.clubId,v.userId,v.requestId);
    if(row)need(row.request_sha256===digest,'idempotency_conflict');return row;
  }
  async result(row,firstDelivery){
    const now=await this.first(`SELECT ${NOW_SQL} now_ms,EXISTS(SELECT 1 FROM pa_checkout_reusable WHERE order_id=?) current_order`,row.order_id);
    const validForMs=now.now_ms<row.reserved_at_ms?0:Math.min(5000,Math.max(0,row.invoke_before_ms-now.now_ms));
    return {schemaVersion:1,clubId:row.club_id,orderId:row.order_id,requestId:row.request_id,handoffId:row.handoff_id,
      reviewHash:row.review_sha256,firstDelivery,mayInvokeDialer:firstDelivery&&now.current_order===1&&validForMs>0,
      validForMs:firstDelivery&&now.current_order===1?validForMs:0,reservedAt:row.reserved_at_ms};
  }
  async reserve(input){
    try{
      exact(input,['clubId','userId','sessionId','requestId','orderId','reviewHash']);
      need(club(input.clubId)&&[input.userId,input.sessionId,input.requestId,input.orderId].every(uuid)&&sha(input.reviewHash));
      const v={...input},a=await this.authority(v.clubId,v.userId,'reserve');
      // Deliberately excludes session ID: same user may recover after reauthentication, but never relaunch.
      const digest=await hash({clubId:v.clubId,userId:v.userId,orderId:v.orderId,reviewHash:v.reviewHash});
      const old=await this.prior(v,digest);
      if(old){await this.authority(v.clubId,v.userId,'reserve');return this.result(old,false);}
      const order=await this.first(`SELECT d.snapshot_json,o.expires_at_ms,${NOW_SQL} now_ms
        FROM pa_orders o JOIN pa_checkout_order_details d ON d.order_id=o.order_id
        JOIN pa_checkout_reusable r ON r.order_id=o.order_id WHERE o.order_id=? AND o.club_id=? AND o.user_id=?`,v.orderId,v.clubId,v.userId);
      need(order&&order.expires_at_ms>=order.now_ms+20000,'handoff_order_changed');
      need(await reviewHash(JSON.parse(order.snapshot_json))===v.reviewHash,'handoff_review_changed');
      const handoffId=crypto.randomUUID();
      const columns=['handoff_id','request_id','order_id','club_id','user_id','session_id','principal_id','request_sha256','review_sha256','snapshot_json',
        'principal_revision','grant_revision','club_revision','subject_revision','checkout_revision','control_revision'];
      const args=[handoffId,v.requestId,v.orderId,v.clubId,v.userId,v.sessionId,this.principalId,digest,v.reviewHash,order.snapshot_json,
        a.principal_revision,a.grant_revision,a.club_revision,a.subject_revision,a.checkout_revision,a.control_revision];
      let firstDelivery=false;
      try{
        const result=await this.db.batch([this.stmt(`INSERT INTO pa_handoff_reservations(${columns.join(',')},reserved_at_ms,invoke_before_ms)
          VALUES(${columns.map(()=>'?').join(',')},${NOW_SQL},${NOW_SQL}+5000)`,...args)]);
        // Only an unambiguous acknowledged insert can issue the short-lived launch grant.
        need(Array.isArray(result)&&result.length===1&&result[0].success===true&&result[0].meta?.changes>=1,'handoff_unavailable');
        firstDelivery=true;
      }catch(error){
        await this.authority(v.clubId,v.userId,'reserve');
        const found=await this.prior(v,digest);if(!found)throw error;
        // Lost acknowledgement or competing request: committed evidence, no launch authority.
      }
      await this.authority(v.clubId,v.userId,'reserve');
      const saved=await this.prior(v,digest);need(saved,'handoff_unavailable');
      return this.result(saved,firstDelivery&&saved.handoff_id===handoffId);
    }catch(error){throw normalizeError(error);}
  }
  async active(input){
    try{
      exact(input,['clubId','userId']);need(club(input.clubId)&&uuid(input.userId));
      await this.authority(input.clubId,input.userId,'read');
      const row=await this.first(`SELECT h.*,z.payment_allocated FROM pa_handoff_slots s
        JOIN pa_handoff_reservations h ON h.handoff_id=s.handoff_id JOIN pa_handoff_resolution z ON z.handoff_id=h.handoff_id
        WHERE s.club_id=? AND s.user_id=?`,input.clubId,input.userId);
      await this.authority(input.clubId,input.userId,'read');
      return {schemaVersion:1,clubId:input.clubId,blocked:!!row&&row.payment_allocated!==1,handoff:row?{
        handoffId:row.handoff_id,requestId:row.request_id,orderId:row.order_id,reservedAt:row.reserved_at_ms,
        resolution:row.payment_allocated===1?'payment_allocated':'unresolved'}:null};
    }catch(error){throw normalizeError(error);}
  }
}
