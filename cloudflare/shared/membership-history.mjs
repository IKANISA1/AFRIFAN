/** Shared read-only wire contract. Cursors are selectors, never authorization.
 * They contain private identifiers and must not be logged, persisted, or put in links.
 */
export const HISTORY_PAGE_SIZE=20;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const isUuid=v=>typeof v==='string'&&UUID.exec(v)?.[0]===v;
const stamp=v=>Number.isSafeInteger(v)&&v>=0&&v<=253370764799999;
const exact=(v,keys)=>v!==null&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
function check(v){if(!v)throw new Error('invalid_history_contract');}
export function cursorFor(actor,item){return `mh1:${actor.clubId}:${actor.userId}:${item.recordedAt}:${item.allocationId}`;}
export function parseHistoryCursor(value,actor){
 if(value===null)return null;
 check(typeof value==='string'&&value.length<=160);
 const p=value.split(':');check(p.length===5&&p[0]==='mh1'&&p[1]===String(actor.clubId)&&p[2]===actor.userId&&isUuid(p[2])&&/^(0|[1-9][0-9]{0,14})$/.test(p[3])&&stamp(Number(p[3]))&&isUuid(p[4]));
 return {recordedAt:Number(p[3]),allocationId:p[4]};
}
export function historyBefore(a,b){return a.recordedAt<b.recordedAt||(a.recordedAt===b.recordedAt&&a.allocationId<b.allocationId);}
export function projectHistory(result,actor,now,cursor=null,limit=HISTORY_PAGE_SIZE){
 check(Number.isInteger(limit)&&limit>=1&&limit<=HISTORY_PAGE_SIZE);
 const before=parseHistoryCursor(cursor,actor);
 check(exact(result,['schemaVersion','clubId','userId','observedAt','scope','historical','snapshot','items','nextCursor']));
 check(result.schemaVersion===1&&result.clubId===actor.clubId&&result.userId===actor.userId&&isUuid(result.userId)&&result.scope==='membership_allocations'&&result.historical===true&&result.snapshot===false&&stamp(result.observedAt)&&result.observedAt<=now+1000&&result.observedAt>=now-10000&&Array.isArray(result.items)&&result.items.length<=limit);
 const orders=new Set(),ids=new Set();let previous=before;
 const items=result.items.map(item=>{
  check(exact(item,['orderId','allocationId','recordedAt','amount','currency']));
  check(isUuid(item.orderId)&&isUuid(item.allocationId)&&stamp(item.recordedAt)&&item.recordedAt<=result.observedAt&&Number.isInteger(item.amount)&&item.amount>0&&item.amount<=2147483647&&typeof item.currency==='string'&&item.currency.length===3&&/^[A-Z]{3}$/.test(item.currency)&&!orders.has(item.orderId)&&!ids.has(item.allocationId)&&(!previous||historyBefore(item,previous)));
  orders.add(item.orderId);ids.add(item.allocationId);previous=item;return {...item};
 });
 check(result.nextCursor===null||(items.length===limit&&result.nextCursor===cursorFor(actor,items.at(-1))));
 return {...result,items};
}
export function projectHistoryReceipt(result,actor,orderId,now){
 check(exact(result,['schemaVersion','clubId','userId','observedAt','receipt']));
 check(result.schemaVersion===1&&result.clubId===actor.clubId&&result.userId===actor.userId&&stamp(result.observedAt)&&result.observedAt<=now+1000&&result.observedAt>=now-10000);
 const r=result.receipt;
 check(exact(r,['schemaVersion','clubId','orderId','allocationId','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membershipAtAllocation','historical']));
 check(r.schemaVersion===1&&r.clubId===actor.clubId&&r.orderId===orderId&&isUuid(r.orderId)&&isUuid(r.allocationId)&&Number.isInteger(r.amount)&&r.amount>0&&r.amount<=2147483647&&typeof r.currency==='string'&&r.currency.length===3&&/^[A-Z]{3}$/.test(r.currency)&&stamp(r.recordedAt)&&r.recordedAt<=result.observedAt&&r.allocationPersisted===true&&r.businessTargetFulfilled===true&&r.historical===true);
 const m=r.membershipAtAllocation;
 check(exact(m,['id','tier','status','paymentStatus','expiresAt'])&&isUuid(m.id)&&typeof m.tier==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.exec(m.tier)?.[0]===m.tier&&['active','suspended','expired'].includes(m.status)&&m.paymentStatus==='verified'&&stamp(m.expiresAt)&&m.expiresAt>r.recordedAt);
 return {...result,receipt:{...r,membershipAtAllocation:{...m}}};
}
