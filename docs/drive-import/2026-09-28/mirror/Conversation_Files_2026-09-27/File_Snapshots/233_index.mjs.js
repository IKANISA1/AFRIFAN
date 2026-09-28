import { IdentityService } from './identity-service.mjs';
import { requireValue } from './errors.mjs';
import { reply,fail,readJson,bearer,nativeIngress } from './http.mjs';
import { dispatchOtp,expireTransientSecrets } from './delivery.mjs';
/** Direct native API. No cookie auth, browser token persistence, admin grant or SQL proxy. */
export default {
 async fetch(request,env){try{
  const match=/^\/v1\/auth\/clubs\/([1-9]\d{0,9})\/(otp\/challenges|otp\/verifications|sessions\/refresh|session|sessions\/revoke|deletion-requests)$/.exec(new URL(request.url).pathname);
  if(!match)return reply({schemaVersion:1,error:'not_found'},404);
  const operation=match[2],method=operation==='session'?'GET':'POST';requireValue(request.method===method,'method_not_allowed',405);
  requireValue(env.AUTH_SERVICE_ENABLED==='true','service_unavailable',503);
  const ip=nativeIngress(request,env),service=new IdentityService(env),id=Number(match[1]);
  const ipKey=await service.vault.hash('ip',ip);
  requireValue(env.AUTH_EDGE_LIMIT&&typeof env.AUTH_EDGE_LIMIT.limit==='function','abuse_control_unavailable',503);
  const limit=await env.AUTH_EDGE_LIMIT.limit({key:`native-auth:${ipKey}`});requireValue(limit?.success===true,'rate_limited',429);
  let result;const key=request.headers.get('idempotency-key');
  if(operation==='session')result=await service.current(id,bearer(request));
  else{const body=await readJson(request);
   if(operation==='otp/challenges')result=await service.challenge(id,body,key,ipKey);
   else if(operation==='otp/verifications')result=await service.verify(id,body,key);
   else if(operation==='sessions/refresh')result=await service.refresh(id,body,key);
   else if(operation==='sessions/revoke')result=await service.revoke(id,bearer(request),body);
   else if(operation==='deletion-requests')result=await service.deletion(id,bearer(request),body,key);
  }
  return reply(result,['otp/challenges','deletion-requests'].includes(operation)?202:200);
 }catch(error){return fail(error);}},
 async scheduled(_event,env,ctx){if(env.AUTH_DELIVERY_ENABLED!=='true')return;
  // Scheduled work is awaited by the platform, not promised as work by the assistant.
  ctx.waitUntil((async()=>{await dispatchOtp(env);await expireTransientSecrets(env);})());}
};
