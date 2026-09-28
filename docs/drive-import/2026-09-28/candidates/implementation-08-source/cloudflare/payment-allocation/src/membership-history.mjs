import {NOW_SQL,uuid,club,exact} from './policy.mjs';
import {requireCheckout,checkoutError} from './checkout-policy.mjs';
import {cursorFor,parseHistoryCursor,projectHistory,projectHistoryReceipt} from '../../shared/membership-history.mjs';

/** Same financial database; indexed keyset reads, not a materialized copy or wallet.
 * Current authentication belongs to the gateway; service/subject grants are checked
 * before and after each read. Pages are live observations, not a multi-request snapshot.
 */
export async function readMembershipHistory(service,input){
 try{
  exact(input,['clubId','userId','cursor','limit']);requireCheckout(club(input.clubId)&&uuid(input.userId)&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=20,'invalid_input');
  let before;try{before=parseHistoryCursor(input.cursor,input);}catch{requireCheckout(false,'invalid_input');}
  await service.authority(input.clubId,input.userId,'read');
  const sql=`SELECT order_id,allocation_id,amount,currency,recorded_at_ms
   FROM pa_ledger INDEXED BY pa_membership_history_owner
   WHERE club_id=? AND user_id=? AND ledger_scope='subscription'
   ${before?'AND (recorded_at_ms,allocation_id)<(?,?)':''}
   ORDER BY recorded_at_ms DESC,allocation_id DESC LIMIT ?`;
  const args=[input.clubId,input.userId,...(before?[before.recordedAt,before.allocationId]:[]),input.limit+1];
  const result=await service.db.withSession('first-primary').prepare(sql).bind(...args).all();
  requireCheckout(Array.isArray(result.results)&&result.results.length<=input.limit+1,'checkout_unavailable');
  const time=await service.first(`SELECT ${NOW_SQL} AS now_ms`);
  const items=result.results.slice(0,input.limit).map(r=>({orderId:r.order_id,allocationId:r.allocation_id,recordedAt:r.recorded_at_ms,amount:r.amount,currency:r.currency}));
  const page={schemaVersion:1,clubId:input.clubId,userId:input.userId,observedAt:time.now_ms,scope:'membership_allocations',historical:true,snapshot:false,items,
   nextCursor:result.results.length>input.limit?cursorFor(input,items.at(-1)):null};
  const projected=projectHistory(page,input,time.now_ms,input.cursor,input.limit);
  await service.authority(input.clubId,input.userId,'read');return projected;
 }catch(e){throw checkoutError(e);}
}
/** Owned receipt lookup does not require a device's local order ID registry or a
 * newer checkout snapshot. Historical imported membership orders can be read too.
 * Never repairs a mismatch by inventing, modifying, or re-allocating evidence.
 */
export async function readHistoricalMembershipReceipt(service,input){
 try{
  exact(input,['clubId','userId','orderId']);requireCheckout(club(input.clubId)&&uuid(input.userId)&&uuid(input.orderId),'invalid_input');
  await service.authority(input.clubId,input.userId,'read');
  const r=await service.first(`SELECT o.source_intent_id,o.tier,l.allocation_id,l.amount,l.currency,l.recorded_at_ms,a.evidence_id,r.receipt_json
   FROM pa_ledger l JOIN pa_orders o ON o.order_id=l.order_id JOIN pa_allocations a ON a.allocation_id=l.allocation_id
   JOIN pa_receipts r ON r.allocation_id=l.allocation_id
   WHERE l.order_id=? AND l.club_id=? AND l.user_id=? AND o.club_id=l.club_id AND o.user_id=l.user_id
   AND o.kind='membership' AND l.ledger_scope='subscription' AND l.business_target_fulfilled=1 AND o.state='fulfilled'`,input.orderId,input.clubId,input.userId);
  await service.authority(input.clubId,input.userId,'read');requireCheckout(r,'not_found');
  const value=JSON.parse(r.receipt_json);
  exact(value,['schemaVersion','allocationId','clubId','orderId','sourceIntentId','evidenceId','userId','kind','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membership']);
  requireCheckout(value.schemaVersion===1&&value.allocationId===r.allocation_id&&value.clubId===input.clubId&&value.orderId===input.orderId&&value.sourceIntentId===r.source_intent_id&&value.evidenceId===r.evidence_id&&value.userId===input.userId&&value.kind==='membership'&&value.amount===r.amount&&value.currency===r.currency&&value.recordedAt===r.recorded_at_ms&&value.membership?.tier===r.tier&&value.allocationPersisted===true&&value.businessTargetFulfilled===true,'checkout_unavailable');
  const time=await service.first(`SELECT ${NOW_SQL} AS now_ms`);
  const envelope={schemaVersion:1,clubId:input.clubId,userId:input.userId,observedAt:time.now_ms,receipt:{schemaVersion:1,clubId:input.clubId,orderId:input.orderId,allocationId:r.allocation_id,amount:r.amount,currency:r.currency,recordedAt:r.recorded_at_ms,allocationPersisted:true,businessTargetFulfilled:true,membershipAtAllocation:value.membership,historical:true}};
  const projected=projectHistoryReceipt(envelope,input,input.orderId,time.now_ms);
  await service.authority(input.clubId,input.userId,'read');return projected;
 }catch(e){throw checkoutError(e);}
}
