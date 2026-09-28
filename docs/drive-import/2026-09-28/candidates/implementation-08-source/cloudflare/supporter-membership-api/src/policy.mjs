/** Membership gateway only: no allocation, ingestion, user-ID override or provider authority. */
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const TIER = /^[a-z0-9][a-z0-9_-]{0,31}$/;
export const LIMITS = Object.freeze({bodyBytes:2048, bodyMs:1500, rpcMs:5000, responseBytes:16384});
export class GatewayError extends Error {
  constructor(code='service_unavailable', status=503) { super(code); this.code=code; this.status=status; }
}
export function need(value, code='invalid_request', status=400) {
  if (!value) throw new GatewayError(code,status);
}
export function fields(value,keys,code='upstream_contract_invalid') {
  need(value && typeof value==='object' && !Array.isArray(value) &&
    Object.keys(value).length===keys.length && keys.every(k=>Object.hasOwn(value,k)),code,503);
}
export function origin(value) {
  try {
    const u=new URL(value);
    return typeof value==='string' && value===u.origin && u.protocol==='https:' &&
      !u.username && !u.password && u.hostname.includes('.') && !u.hostname.endsWith('.');
  } catch { return false; }
}
export function config(env) {
  need(env.MEMBERSHIP_API_ENABLED==='true','service_disabled',503);
  need(env.MEMBERSHIP_ENVIRONMENT==='isolated-staging','staging_only',503);
  need(origin(env.NATIVE_ORIGIN),'invalid_configuration',503);
  need(typeof env.GATEWAY_RATE_KEY==='string' && /^[0-9a-f]{64}$/.test(env.GATEWAY_RATE_KEY) &&
    !/^(.)\1+$/.test(env.GATEWAY_RATE_KEY),'invalid_configuration',503);
  let routes; try { routes=JSON.parse(env.CLUB_ROUTES_JSON); } catch { throw new GatewayError('invalid_configuration'); }
  need(Array.isArray(routes) && routes.length>0 && routes.length<=5,'invalid_configuration',503);
  const ids=new Set(),slugs=new Set();
  for (const c of routes) {
    fields(c,['clubId','clubSlug'],'invalid_configuration');
    need(Number.isSafeInteger(c.clubId) && c.clubId>0 && typeof c.clubSlug==='string' &&
      /^[a-z][a-z0-9_-]{1,63}$/.test(c.clubSlug) && !ids.has(c.clubId) && !slugs.has(c.clubSlug),'invalid_configuration',503);
    ids.add(c.clubId); slugs.add(c.clubSlug);
  }
  for (const [binding,method] of Object.entries({IDENTITY:'current',CHECKOUT:'prepare',CHECKOUT_READER:'read',PAYMENT_RECEIPTS:'readReceipt',EDGE_LIMIT:'limit',SUBJECT_LIMIT:'limit'}))
    need(env[binding] && typeof env[binding][method]==='function','invalid_configuration',503);
  // No broad database or financial mutation binding belongs on this gateway.
  for (const key of ['AUTH_DB','ALLOCATION_DB','PAYMENT_ALLOCATOR','PAYMENT_INGESTOR','OTP_DELIVERY'])
    need(!env[key],'invalid_configuration',503);
  return routes;
}
export async function bounded(work,ms=LIMITS.rpcMs) {
  let timer;
  try { return await Promise.race([Promise.resolve().then(work),new Promise((_,reject)=>{
    timer=setTimeout(()=>reject(new GatewayError('upstream_timeout')),ms);
  })]); } finally { clearTimeout(timer); }
}
export async function rateKey(key,label,value) {
  const k=await crypto.subtle.importKey('raw',Uint8Array.from(key.match(/../g),v=>parseInt(v,16)),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  return Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',k,new TextEncoder().encode(`${label}\0${value}`))),v=>v.toString(16).padStart(2,'0')).join('');
}
export function errorCode(error) {
  // Workers RPC may not retain application-defined Error properties. Only exact
  // enumerated codes/messages are interpreted; never return an arbitrary message.
  const allowed=['not_found','checkout_permission_denied','permission_denied','checkout_rate_limited'];
  return allowed.find(c=>error?.code===c || error?.message===c)??'service_unavailable';
}
