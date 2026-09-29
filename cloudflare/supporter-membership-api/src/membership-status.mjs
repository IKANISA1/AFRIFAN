import {fields,need,UUID,TIER} from './policy.mjs';
const time=x=>Number.isSafeInteger(x)&&x>=0&&x<=253402300799999;
const valid=x=>need(x,'upstream_contract_invalid',503);
/** Reject inconsistent flags, stale observations and cross-user projections. */
export function membershipStatus(value,actor,now){
 fields(value,['schemaVersion','clubId','userId','observedAt','currentStatus','isActive','membership','historical']);
 valid(value.schemaVersion===1&&value.clubId===actor.clubId&&value.userId===actor.userId&&value.historical===false&&
   time(value.observedAt)&&value.observedAt<=now+1000&&value.observedAt>=now-10000&&
   ['not_member','active','suspended','expired','pending','incomplete'].includes(value.currentStatus)&&value.isActive===(value.currentStatus==='active'));
 const m=value.membership;
 if(m===null){valid(value.currentStatus==='not_member');return {...value};}
 fields(m,['membershipId','tier','recordedStatus','paymentStatus','renewedAt','expiresAt']);
 valid(UUID.test(m.membershipId)&&typeof m.tier==='string'&&TIER.test(m.tier)&&['active','suspended','expired'].includes(m.recordedStatus)&&
  ['pending','verified'].includes(m.paymentStatus)&&(m.renewedAt===null||time(m.renewedAt))&&(m.expiresAt===null||time(m.expiresAt)));
 const state=m.recordedStatus==='suspended'?'suspended':m.recordedStatus==='expired'||(m.expiresAt!==null&&m.expiresAt<=value.observedAt)?'expired':
  m.paymentStatus!=='verified'?'pending':m.expiresAt===null||m.renewedAt===null||m.renewedAt>value.observedAt||m.expiresAt<=m.renewedAt?'incomplete':'active';
 // A second projection at response-time may only downgrade active to expired.
 valid(value.currentStatus===state||(state==='active'&&value.currentStatus==='expired'&&m.expiresAt<=now));
 return {...value,currentStatus:state==='active'&&m.expiresAt<=now?'expired':state,isActive:state==='active'&&m.expiresAt>now,membership:{...m}};
}
