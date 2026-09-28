// Public errors never contain a provider body, telephone number, code or credential.
export class DeliveryError extends Error {
  constructor(code='delivery_unavailable') {super(code);this.name='DeliveryError';this.code=code;}
}
export const LIMITS=Object.freeze({deadlineMs:6000,minimumRemainingMs:15000,maxCodeMs:600000,responseBytes:16384,reviewMs:7*86400000});
export const uuid=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(v);
export const id=v=>typeof v==='string'&&/^[1-9][0-9]{4,29}$/.test(v);
export const phone=v=>typeof v==='string'&&/^\+[1-9][0-9]{7,14}$/.test(v);
export function demand(value,code='invalid_delivery_request') {if(!value)throw new DeliveryError(code);}
export function exact(value,keys) {
  demand(value&&typeof value==='object'&&!Array.isArray(value));
  demand(Object.keys(value).length===keys.length&&keys.every(k=>Object.hasOwn(value,k)));
}
export function inputRequest(value,now) {
  exact(value,['challengeId','clubId','phone','code','expiresAt','channel']);
  demand(uuid(value.challengeId)&&Number.isSafeInteger(value.clubId)&&value.clubId>0&&phone(value.phone));
  demand(typeof value.code==='string'&&/^[0-9]{6}$/.test(value.code)&&value.channel==='whatsapp');
  demand(Number.isSafeInteger(value.expiresAt)&&value.expiresAt>now&&value.expiresAt<=now+LIMITS.maxCodeMs,'invalid_expiry');
  return Object.freeze({...value});
}
export function configuration(env,now) {
  demand(env.DELIVERY_ENABLED==='true','delivery_disabled');
  demand(env.DELIVERY_DB&&typeof env.DELIVERY_DB.prepare==='function','invalid_delivery_config');
  demand(typeof env.WA_ACCESS_TOKEN==='string'&&/^[\x21-\x7e]{32,4096}$/.test(env.WA_ACCESS_TOKEN),'invalid_delivery_config');
  demand(typeof env.DISPATCH_HMAC_KEY==='string'&&/^[0-9a-f]{64}$/.test(env.DISPATCH_HMAC_KEY)&&!/^(.)\1+$/.test(env.DISPATCH_HMAC_KEY),'invalid_delivery_config');
  demand(/^v[1-9][0-9]?\.0$/.test(env.WA_GRAPH_VERSION??''),'invalid_delivery_config');
  let routes;try{routes=JSON.parse(env.DELIVERY_ROUTES_JSON);}catch{throw new DeliveryError('invalid_delivery_config');}
  demand(Array.isArray(routes)&&routes.length>0&&routes.length<=5,'invalid_delivery_config');
  const clubs=new Set();
  for(const r of routes){
    exact(r,['clubId','phoneNumberId','templateId','templateName','language','reviewRef','reviewExpiresAt']);
    demand(Number.isSafeInteger(r.clubId)&&r.clubId>0&&!clubs.has(r.clubId),'invalid_delivery_config');clubs.add(r.clubId);
    demand(id(r.phoneNumberId)&&id(r.templateId)&&/^[a-z][a-z0-9_]{0,511}$/.test(r.templateName??''),'invalid_delivery_config');
    // Product policy is English-only. Only provider-approved matching editions are sent.
    demand(['en','en_US','en_GB'].includes(r.language),'invalid_delivery_config');
    demand(typeof r.reviewRef==='string'&&/^[A-Za-z0-9][A-Za-z0-9._:/-]{2,127}$/.test(r.reviewRef),'invalid_delivery_config');
    demand(Number.isSafeInteger(r.reviewExpiresAt)&&r.reviewExpiresAt>now&&r.reviewExpiresAt<=now+LIMITS.reviewMs,'invalid_delivery_config');
  }
  return Object.freeze({version:env.WA_GRAPH_VERSION,routes:routes.map(r=>Object.freeze({...r}))});
}
