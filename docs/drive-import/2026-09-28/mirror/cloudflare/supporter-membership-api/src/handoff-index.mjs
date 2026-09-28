import {createGateway} from './index.mjs';
import {config,need,fields,UUID,bounded,rateKey,GatewayError,LIMITS} from './policy.mjs';
import {ingress,token,response} from './http.mjs';
import {identity} from './projection.mjs';

function handoffRoute(request) {
  const url=new URL(request.url);
  need(!url.search&&!url.hash&&!url.username&&!url.password,'not_found',404);
  const match=/^\/v1\/supporter\/clubs\/([1-9][0-9]{0,15})\/membership\/(handoffs|checkouts\/([0-9a-f-]{36})\/handoff)$/.exec(url.pathname);
  need(match,'not_found',404);const clubId=Number(match[1]);need(Number.isSafeInteger(clubId),'not_found',404);
  if(match[3])need(UUID.test(match[3]),'not_found',404);
  need(request.method===(match[3]?'POST':'GET'),'method_not_allowed',405);
  return {url,clubId,orderId:match[3]??null};
}
async function hashBody(request,ms) {
  const type=request.headers.get('content-type')?.toLowerCase();
  need(type==='application/json'||type==='application/json; charset=utf-8','unsupported_media_type',415);
  need(!request.headers.has('content-encoding'),'unsupported_media_type',415);
  const length=request.headers.get('content-length');
  need(length===null||(/^\d+$/.test(length)&&Number(length)<=256),'payload_too_large',413);
  const reader=request.body?.getReader();need(reader,'invalid_request',400);
  let total=0;const chunks=[];
  try{
    const text=await bounded(async()=>{
      while(true){const {value,done}=await reader.read();if(done)break;total+=value.length;need(total<=256,'payload_too_large',413);chunks.push(value);}
      need(length===null||Number(length)===total,'invalid_request',400);
      const all=new Uint8Array(total);let n=0;for(const c of chunks){all.set(c,n);n+=c.length;}
      try{return new TextDecoder('utf-8',{fatal:true}).decode(all);}catch{throw new GatewayError('invalid_request',400);}
    },ms);
    const match=/^\s*\{\s*"reviewHash"\s*:\s*"([0-9a-f]{64})"\s*\}\s*$/.exec(text);
    need(match,'invalid_request',400);return match[1];
  }finally{reader.cancel().catch(()=>{});try{reader.releaseLock();}catch{}}
}
function same(a,b){return a.userId===b.userId&&a.clubId===b.clubId&&a.sessionId===b.sessionId&&a.authenticatedAt===b.authenticatedAt;}
function activeResult(v,clubId){
  fields(v,['schemaVersion','clubId','blocked','handoff']);
  need(v.schemaVersion===1&&v.clubId===clubId&&typeof v.blocked==='boolean','upstream_contract_invalid',503);
  if(v.handoff===null){need(!v.blocked,'upstream_contract_invalid',503);return v;}
  const h=v.handoff;fields(h,['handoffId','requestId','orderId','reservedAt','resolution']);
  need([h.handoffId,h.requestId,h.orderId].every(x=>typeof x==='string'&&UUID.test(x))&&Number.isSafeInteger(h.reservedAt)&&h.reservedAt>=0&&
    ['unresolved','payment_allocated'].includes(h.resolution)&&v.blocked===(h.resolution==='unresolved'),'upstream_contract_invalid',503);
  return v;
}
function reserveResult(v,r,requestId,reviewHash){
  fields(v,['schemaVersion','clubId','orderId','requestId','handoffId','reviewHash','firstDelivery','mayInvokeDialer','validForMs','reservedAt']);
  need(v.schemaVersion===1&&v.clubId===r.clubId&&v.orderId===r.orderId&&v.requestId===requestId&&v.reviewHash===reviewHash&&
    typeof v.handoffId==='string'&&UUID.test(v.handoffId)&&typeof v.firstDelivery==='boolean'&&typeof v.mayInvokeDialer==='boolean'&&
    Number.isSafeInteger(v.validForMs)&&v.validForMs>=0&&v.validForMs<=5000&&Number.isSafeInteger(v.reservedAt)&&v.reservedAt>=0&&
    (v.mayInvokeDialer?(v.firstDelivery&&v.validForMs>0):v.validForMs===0),'upstream_contract_invalid',503);
  return v;
}
/** Opt-in composition reuses all original membership routes, identity, ingress and rate boundaries. */
export function createHandoffGateway({clock=Date.now,rpcMs=LIMITS.rpcMs,bodyMs=LIMITS.bodyMs,monotonicNow=()=>performance.now()}={}){
  const original=createGateway({clock,rpcMs,bodyMs});
  return {async fetch(request,env){
    if(!new URL(request.url).pathname.includes('/handoff'))return original.fetch(request,env);
    let invoked=false,requestId=null;
    try{
      const r=handoffRoute(request),clubs=config(env);
      need(env.SERVER_HANDOFF_API_ENABLED==='true','service_disabled',503);
      need(env.HANDOFF_RESERVER&&typeof env.HANDOFF_RESERVER.reserve==='function'&&env.HANDOFF_RECOVERY&&typeof env.HANDOFF_RECOVERY.active==='function','invalid_configuration',503);
      need(clubs.some(c=>c.clubId===r.clubId),'not_found',404);
      const ip=ingress(request,env,r.url),accessToken=token(request),day=Math.floor(clock()/86400000);
      if(!r.orderId)need(!request.body&&!request.headers.has('idempotency-key'),'invalid_request',400);
      const ipKey=await rateKey(env.GATEWAY_RATE_KEY,'membership-ip',`${day}:${ip}`);
      need((await bounded(()=>env.EDGE_LIMIT.limit({key:ipKey}),rpcMs))?.success===true,'rate_limited',429);
      const authenticate=async()=>identity(await bounded(()=>env.IDENTITY.current({clubId:r.clubId,accessToken}),rpcMs),r.clubId,accessToken,clock());
      const actor=await authenticate();need(request.headers.get('x-africlub-session')===actor.sessionId,'session_changed',409);
      const key=await rateKey(env.GATEWAY_RATE_KEY,'membership-subject',`${day}:${r.clubId}:${actor.userId}`);
      need((await bounded(()=>env.SUBJECT_LIMIT.limit({key}),rpcMs))?.success===true,'rate_limited',429);
      let output;let grantStarted=0;
      if(r.orderId){
        requestId=request.headers.get('idempotency-key');need(typeof requestId==='string'&&UUID.test(requestId),'invalid_request',400);
        const reviewHash=await hashBody(request,bodyMs);
        need(same(actor,await authenticate()),'unauthenticated',401);config(env);
        need(env.SERVER_HANDOFF_API_ENABLED==='true','service_disabled',503);
        grantStarted=monotonicNow();invoked=true;
        const raw=await bounded(()=>env.HANDOFF_RESERVER.reserve({clubId:actor.clubId,userId:actor.userId,sessionId:actor.sessionId,requestId,orderId:r.orderId,reviewHash}),rpcMs);
        output=reserveResult(raw,r,requestId,reviewHash);
      }else output=activeResult(await bounded(()=>env.HANDOFF_RECOVERY.active({clubId:actor.clubId,userId:actor.userId}),rpcMs),r.clubId);
      need(same(actor,await authenticate()),'unauthenticated',401);config(env);need(env.SERVER_HANDOFF_API_ENABLED==='true','service_disabled',503);
      if(invoked){
        // Conservative: subtract the ENTIRE private-call and post-auth duration from the remaining grant.
        const elapsed=Math.ceil(monotonicNow()-grantStarted);need(Number.isFinite(elapsed)&&elapsed>=0,'upstream_contract_invalid',503);
        const left=Math.max(0,output.validForMs-elapsed);
        output={...output,mayInvokeDialer:output.mayInvokeDialer&&left>0,validForMs:output.mayInvokeDialer?left:0};
      }
      return response(output);
    }catch(error){
      if(invoked)return response({schemaVersion:1,error:'handoff_outcome_unknown',outcome:'unknown',requestId},503);
      if(error instanceof GatewayError)return response({schemaVersion:1,error:error.code},error.status);
      const code=['handoff_permission_denied','permission_denied'].some(c=>error?.code===c||error?.message===c)?'permission_denied':'service_unavailable';
      return response({schemaVersion:1,error:code},code==='permission_denied'?403:503);
    }
  }};
}
export default createHandoffGateway();
