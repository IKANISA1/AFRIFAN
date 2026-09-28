import {need,UUID} from './policy.mjs';
const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).sort().join('|')===[...keys].sort().join('|');
/** A malformed upstream response can never authorize a native platform call. */
export function handoffProjection(value,actor,operation,expected,now){
 need(exact(value,['schemaVersion','handoff','mayOpenDialer'])&&value.schemaVersion===1&&typeof value.mayOpenDialer==='boolean','handoff_unavailable',503);
 const h=value.handoff;
 if(h===null){need(operation==='handoff_current'&&!value.mayOpenDialer,'handoff_unavailable',503);return value;}
 need(exact(h,['handoffId','orderId','clubId','phase','createdAt','claimedAt','orderExpiresAt','paymentEvidenceAllocated','observedAt']), 'handoff_unavailable',503);
 need(UUID.test(h.handoffId??'')&&UUID.test(h.orderId??'')&&h.clubId===actor.clubId&&['reserved','claimed','allocated','released'].includes(h.phase),'handoff_unavailable',503);
 for(const k of ['createdAt','orderExpiresAt','observedAt'])need(Number.isSafeInteger(h[k])&&h[k]>0,'handoff_unavailable',503);
 need(h.createdAt<=h.observedAt&&h.orderExpiresAt>h.createdAt&&Math.abs(now-h.observedAt)<=300000,'handoff_unavailable',503);
 need(h.claimedAt===null||(Number.isSafeInteger(h.claimedAt)&&h.claimedAt>=h.createdAt&&h.claimedAt<=h.observedAt),'handoff_unavailable',503);
 need(typeof h.paymentEvidenceAllocated==='boolean'&&h.paymentEvidenceAllocated===(h.phase==='allocated'),'handoff_unavailable',503);
 need(!['reserved','released'].includes(h.phase)||h.claimedAt===null,'handoff_unavailable',503);need(h.phase!=='claimed'||h.claimedAt!==null,'handoff_unavailable',503);
 if(operation==='handoff_reserve')need(h.orderId===expected,'handoff_unavailable',503);
 if(operation==='handoff_claim'||operation==='handoff_release')need(h.handoffId===expected,'handoff_unavailable',503);
 if(operation==='handoff_release')need(['released','allocated'].includes(h.phase)&&h.claimedAt===null&&!value.mayOpenDialer,'handoff_unavailable',503);
 if(value.mayOpenDialer)need(operation==='handoff_claim'&&h.phase==='claimed'&&h.orderExpiresAt>now+15000,'handoff_unavailable',503);
 return value;
}
