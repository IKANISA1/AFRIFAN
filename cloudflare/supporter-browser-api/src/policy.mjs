import {browserConfig} from '../../supporter-auth/src/browser-session-service.mjs';
import {AuthError,UUID,exactKeys} from '../../supporter-auth/src/errors.mjs';
export {UUID,exactKeys};
export class BrowserError extends Error {
 constructor(code,status=400){super(code);this.code=code;this.status=status;}
}
export function need(value,code='invalid_request',status=400){if(!value)throw new BrowserError(code,status);}
export const CODES=new Set(['invalid_request','bootstrap_required','bootstrap_consumed','already_authenticated',
 'unauthenticated','reauthentication_required','session_changed','csrf_rejected','idempotency_conflict',
 'invalid_code','challenge_consumed','challenge_unavailable','account_unavailable','rate_limited',
 'service_unavailable','browser_disabled','browser_not_configured','identity_unavailable','not_found','permission_denied']);
export function config(env){
 need(env.BROWSER_API_ENABLED==='true','browser_disabled',503);
 const c=browserConfig({...env,AUTH_BROWSER_ENABLED:'true'});
 need(typeof env.BROWSER_RATE_KEY==='string'&&/^[0-9a-f]{64}$/.test(env.BROWSER_RATE_KEY),'browser_not_configured',503);
 for(const method of ['start','bootstrap','challenge','verify','current','rotate','logout'])
  need(typeof env.BROWSER_IDENTITY?.[method]==='function','browser_not_configured',503);
 need(typeof env.EDGE_LIMIT?.limit==='function'&&typeof env.SUBJECT_LIMIT?.limit==='function','browser_not_configured',503);
 return c;
}
export async function bounded(fn,ms=8000){
 let timer;
 try{return await Promise.race([Promise.resolve().then(fn),new Promise((_,reject)=>{
  timer=setTimeout(()=>reject(new BrowserError('service_unavailable',503)),ms);
 })]);}finally{clearTimeout(timer);}
}
export function unwrap(result){
 if(result?.ok===false){
  need(CODES.has(result.error)&&[400,401,403,404,409,429,503].includes(result.status),'identity_unavailable',503);
  throw new BrowserError(result.error,result.status);
 }
 need(result?.ok===true&&Object.keys(result).length===2&&Object.hasOwn(result,'value'),'identity_unavailable',503);
 return result.value;
}
export function publicError(e){
 return (e instanceof BrowserError||e instanceof AuthError)&&CODES.has(e.code)?e:new BrowserError('service_unavailable',503);
}
export function upstreamFields(value,keys){
 try{exactKeys(value,keys);}catch{throw new BrowserError('identity_unavailable',503);}
}
export function session(v,clubId,now){
 upstreamFields(v,['schemaVersion','clubId','userId','sessionId','authenticatedAt','expiresAt','absoluteExpiresAt','role','phoneVerified','csrfToken']);
 need(v.schemaVersion===1&&v.clubId===clubId&&typeof v.userId==='string'&&UUID.test(v.userId)&&
  typeof v.sessionId==='string'&&UUID.test(v.sessionId)&&v.role==='supporter'&&v.phoneVerified===true&&
  Number.isSafeInteger(v.authenticatedAt)&&v.authenticatedAt>=0&&v.authenticatedAt<=now&&
  Number.isSafeInteger(v.expiresAt)&&v.expiresAt>now&&Number.isSafeInteger(v.absoluteExpiresAt)&&
  v.absoluteExpiresAt>=v.expiresAt&&v.absoluteExpiresAt<=253402300799999&&
  typeof v.csrfToken==='string'&&/^[0-9a-f]{64}$/.test(v.csrfToken),'identity_unavailable',503);
 return {...v};
}
export async function rateKey(secret,label,value){
 const bytes=Uint8Array.from(secret.match(/../g),x=>parseInt(x,16));
 const k=await crypto.subtle.importKey('raw',bytes,{name:'HMAC',hash:'SHA-256'},false,['sign']);
 return Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',k,new TextEncoder().encode(`${label}\0${value}`))),x=>x.toString(16).padStart(2,'0')).join('');
}
