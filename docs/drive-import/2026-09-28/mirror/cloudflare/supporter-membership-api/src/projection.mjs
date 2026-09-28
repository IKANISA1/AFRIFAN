import {fields,need,UUID,TIER} from './policy.mjs';
const timestamp=v=>Number.isSafeInteger(v)&&v>=0&&v<=253402300799999;
const amount=v=>Number.isSafeInteger(v)&&v>0&&v<=2147483647;
const valid=(v)=>need(v,'upstream_contract_invalid',503);
export function identity(result,clubId,accessToken,now){
  if(result?.ok===false){
    fields(result,['ok','error','status']);
    need(![401,403].includes(result.status),'unauthenticated',401);
    need(false,'identity_unavailable',503);
  }
  fields(result,['ok','value']);valid(result.ok===true);const v=result.value;
  fields(v,['schemaVersion','userId','clubId','sessionId','phoneVerified','role','authenticatedAt']);
  valid(v.schemaVersion===1&&UUID.test(v.userId)&&v.clubId===clubId&&v.sessionId===accessToken.split('.')[0]&&
    v.phoneVerified===true&&v.role==='supporter'&&timestamp(v.authenticatedAt)&&v.authenticatedAt<=now);
  return {...v};
}
export function snapshot(c,id){
  fields(c,['schemaVersion','orderId','intentId','userId','clubId','packageId','tier','amount','currency','country','provider','recipient','ussdCode','createdAt','expiresAt','paymentVerified','membershipActivated']);
  valid(c.schemaVersion===1&&UUID.test(c.orderId)&&UUID.test(c.intentId)&&UUID.test(c.packageId)&&c.userId===id.userId&&c.clubId===id.clubId);
  valid(typeof c.tier==='string'&&TIER.test(c.tier)&&amount(c.amount)&&typeof c.currency==='string'&&/^[A-Z]{3}$/.test(c.currency)&&
    typeof c.country==='string'&&/^[A-Z]{2}$/.test(c.country)&&typeof c.provider==='string'&&/^[a-z][a-z0-9_-]{0,63}$/.test(c.provider));
  valid(typeof c.recipient==='string'&&/^[0-9]{3,32}$/.test(c.recipient)&&typeof c.ussdCode==='string'&&c.ussdCode.length<=128&&/^\*[0-9*]+#$/.test(c.ussdCode));
  valid(timestamp(c.createdAt)&&timestamp(c.expiresAt)&&c.expiresAt-c.createdAt===86400000&&c.paymentVerified===false&&c.membershipActivated===false);
  return c;
}
export function prepared(result,id,requestId,tier){
  fields(result,['schemaVersion','requestId','reused','checkout']);valid(result.schemaVersion===1&&result.requestId===requestId&&typeof result.reused==='boolean');
  const c=snapshot(result.checkout,id);valid(c.tier===tier);
  // No USSD, recipient or price is exposed by an original-result replay. Always
  // read current status before rendering a payment instruction.
  return {schemaVersion:1,requestId,clubId:id.clubId,orderId:c.orderId,tier:c.tier,reused:result.reused,paymentVerified:false,membershipActivated:false};
}
export function current(result,id,orderId,now){
  fields(result,['schemaVersion','checkout','status','mayPresentPaymentInstruction','paymentEvidenceAllocated','observedAt']);
  valid(result.schemaVersion===1);const c=snapshot(result.checkout,id);valid(c.orderId===orderId);
  valid(['pending_current','expired','cancelled','allocated','configuration_changed'].includes(result.status));
  valid(result.mayPresentPaymentInstruction===(result.status==='pending_current')&&result.paymentEvidenceAllocated===(result.status==='allocated')&&timestamp(result.observedAt));
  // A source response must be fresh enough for immediate display; this is still
  // a point-in-time observation, not a reservation or commit-time auth guarantee.
  valid(result.observedAt<=now+1000&&result.observedAt>=now-10000);
  if(result.status==='pending_current')valid(result.observedAt<c.expiresAt);
  return {schemaVersion:1,clubId:c.clubId,orderId:c.orderId,tier:c.tier,status:result.status,
    paymentEvidenceAllocated:result.paymentEvidenceAllocated,observedAt:result.observedAt,expiresAt:c.expiresAt,
    paymentInstruction:result.status==='pending_current'?{amount:c.amount,currency:c.currency,country:c.country,provider:c.provider,recipient:c.recipient,ussdCode:c.ussdCode}:null};
}
export function receipt(result,id,c){
  fields(result,['schemaVersion','allocationId','clubId','orderId','sourceIntentId','evidenceId','userId','kind','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membership']);
  valid(result.schemaVersion===1&&UUID.test(result.allocationId)&&UUID.test(result.evidenceId)&&result.clubId===id.clubId&&result.userId===id.userId&&
    result.orderId===c.orderId&&result.sourceIntentId===c.intentId&&result.kind==='membership'&&result.amount===c.amount&&result.currency===c.currency&&
    result.allocationPersisted===true&&result.businessTargetFulfilled===true&&timestamp(result.recordedAt));
  const m=result.membership;fields(m,['id','tier','status','paymentStatus','expiresAt']);
  valid(UUID.test(m.id)&&m.tier===c.tier&&['active','suspended','expired'].includes(m.status)&&m.paymentStatus==='verified'&&timestamp(m.expiresAt)&&m.expiresAt>result.recordedAt);
  return {schemaVersion:1,clubId:id.clubId,orderId:c.orderId,allocationId:result.allocationId,amount:c.amount,currency:c.currency,
    recordedAt:result.recordedAt,allocationPersisted:true,businessTargetFulfilled:true,membershipAtAllocation:{...m},historical:true};
}
