import {NOW_SQL} from './policy.mjs';
import {checkoutDatabase,CheckoutError,requireCheckout,uuid,prepareInput,readInput,hash,validOffer,checkoutError} from './checkout-policy.mjs';

/** Private service core. Its caller MUST independently authenticate the human and
 * derive userId/clubId; this database gate is not cross-database session authority. */
export class MembershipCheckoutService {
  constructor(env,principalId){this.env=env;this.db=checkoutDatabase(env);requireCheckout(uuid(principalId),'invalid_configuration');this.principalId=principalId;}
  statement(sql,...args){return this.db.prepare(sql).bind(...args);}
  first(sql,...args){return this.db.withSession('first-primary').prepare(sql).bind(...args).first();}
  async authority(clubId,userId,capability){
    checkoutDatabase(this.env);
    const row=await this.first(`SELECT * FROM pa_checkout_authorizations WHERE principal_id=? AND club_id=? AND user_id=? AND capability=?`,this.principalId,clubId,userId,capability);
    requireCheckout(row,'checkout_permission_denied');return row;
  }
  async previous(v,digest){
    const row=await this.first(`SELECT q.request_sha256,q.request_id,r.reused,d.snapshot_json FROM pa_checkout_requests q
      JOIN pa_checkout_results r ON r.command_id=q.command_id JOIN pa_checkout_order_details d ON d.order_id=r.order_id
      WHERE q.principal_id=? AND q.club_id=? AND q.user_id=? AND q.request_id=?`,this.principalId,v.clubId,v.userId,v.requestId);
    if(!row)return null;
    requireCheckout(row.request_sha256===digest,'idempotency_conflict');
    return {schemaVersion:1,requestId:row.request_id,reused:row.reused===1,checkout:JSON.parse(row.snapshot_json)};
  }
  async prepare(input){
    try{
      const v=prepareInput(input),a=await this.authority(v.clubId,v.userId,'prepare');
      const digest=await hash({clubId:v.clubId,userId:v.userId,tier:v.tier});
      const prior=await this.previous(v,digest);
      if(prior){await this.authority(v.clubId,v.userId,'prepare');return prior;}
      const o=validOffer(await this.first('SELECT * FROM pa_checkout_offers WHERE club_id=? AND tier=?',v.clubId,v.tier));
      const offerHash=await hash({kind:'membership-checkout-offer-v1',...o});
      checkoutDatabase(this.env);
      const columns=['command_id','principal_id','club_id','user_id','request_id','request_sha256','tier',
        'principal_revision','grant_revision','club_revision','subject_revision','control_revision',
        'package_id','package_revision','route_id','route_revision','receiver_id','receiver_revision',
        'checkout_club_revision','offer_sha256','proposed_order_id','proposed_intent_id'];
      const args=[crypto.randomUUID(),this.principalId,v.clubId,v.userId,v.requestId,digest,v.tier,
        a.principal_revision,a.grant_revision,a.club_revision,a.subject_revision,a.control_revision,
        o.package_id,o.package_revision,o.route_id,o.route_revision,o.receiver_id,o.receiver_revision,
        o.checkout_club_revision,offerHash,crypto.randomUUID(),crypto.randomUUID()];
      // One statement's triggers select/reuse or cancel/create, snapshot and audit.
      // D1 batch makes acknowledgement-loss recovery explicit and shares the same
      // database writer with evidence allocation; no remote side effect occurs here.
      await this.db.batch([this.statement(`INSERT INTO pa_checkout_requests(${columns.join(',')},recorded_at_ms)
        VALUES(${columns.map(()=>'?').join(',')},${NOW_SQL})`,...args)]).catch(async error=>{
        await this.authority(v.clubId,v.userId,'prepare');
        if(await this.previous(v,digest))return;throw error;
      });
      await this.authority(v.clubId,v.userId,'prepare');
      const result=await this.previous(v,digest);requireCheckout(result,'checkout_unavailable');return result;
    }catch(error){throw checkoutError(error);}
  }
  async read(input){
    try{
      const v=readInput(input);await this.authority(v.clubId,v.userId,'read');
      const row=await this.first(`SELECT d.snapshot_json,o.state,o.expires_at_ms,${NOW_SQL} now_ms,
        EXISTS(SELECT 1 FROM pa_checkout_reusable z WHERE z.order_id=o.order_id) current_offer
        FROM pa_checkout_order_details d JOIN pa_orders o ON o.order_id=d.order_id
        WHERE o.order_id=? AND o.club_id=? AND o.user_id=?`,v.orderId,v.clubId,v.userId);
      requireCheckout(row,'not_found');await this.authority(v.clubId,v.userId,'read');
      const status=row.state==='fulfilled'?'allocated':row.state==='cancelled'?'cancelled':row.expires_at_ms<=row.now_ms?'expired':row.current_offer?'pending_current':'configuration_changed';
      return {schemaVersion:1,checkout:JSON.parse(row.snapshot_json),status,
        mayPresentPaymentInstruction:status==='pending_current',paymentEvidenceAllocated:status==='allocated',observedAt:row.now_ms};
    }catch(error){throw checkoutError(error);}
  }
}
