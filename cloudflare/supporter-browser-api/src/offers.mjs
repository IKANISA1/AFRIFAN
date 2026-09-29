import {need,upstreamFields} from './policy.mjs';
/** Strip private catalog/receiver identifiers and reject stale, cross-actor or malformed data. */
export function projectOffers(v,a,now){
 upstreamFields(v,['schemaVersion','clubId','userId','observedAt','offers','preparationOnly']);
 need(v.schemaVersion===1&&v.clubId===a.clubId&&v.userId===a.userId&&v.preparationOnly===true&&
  Number.isSafeInteger(v.observedAt)&&v.observedAt>=now-10000&&v.observedAt<=now+1000&&
  Array.isArray(v.offers)&&v.offers.length<=32,'service_unavailable',503);
 const seen=new Set();
 const offers=v.offers.map(o=>{
  upstreamFields(o,['tier','amount','currency','country']);
  need(typeof o.tier==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.test(o.tier)&&!seen.has(o.tier)&&
   Number.isSafeInteger(o.amount)&&o.amount>0&&o.amount<=2147483647&&
   typeof o.currency==='string'&&/^[A-Z]{3}$/.test(o.currency)&&typeof o.country==='string'&&/^[A-Z]{2}$/.test(o.country),'service_unavailable',503);
  seen.add(o.tier);return {...o};
 });
 return {schemaVersion:1,clubId:a.clubId,observedAt:v.observedAt,offers,preparationOnly:true};
}
