import {GatewayError,need,LIMITS,UUID,TIER,bounded} from './policy.mjs';
export function response(body,status=200) {
  return new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store, private','pragma':'no-cache','x-content-type-options':'nosniff',
    'referrer-policy':'no-referrer','content-security-policy':"default-src 'none'; frame-ancestors 'none'",
    ...(status===401?{'www-authenticate':'Bearer'}:{})}});
}
export function route(request) {
  const url=new URL(request.url);
  need(!url.search && !url.hash && !url.username && !url.password,'not_found',404);
  const match=/^\/v1\/supporter\/clubs\/([1-9][0-9]{0,15})\/(session|membership\/checkouts(?:\/([0-9a-f-]{36})(\/receipt)?)?)$/.exec(url.pathname);
  need(match,'not_found',404); const clubId=Number(match[1]);need(Number.isSafeInteger(clubId),'not_found',404);
  const operation=match[2]==='session'?'session':!match[3]?'prepare':match[4]?'receipt':'read';
  if(match[3])need(UUID.test(match[3]),'not_found',404);
  need(request.method===(operation==='prepare'?'POST':'GET'),'method_not_allowed',405);
  return {clubId,orderId:match[3]??null,operation,url};
}
export function ingress(request,env,url) {
  need(url.origin===env.NATIVE_ORIGIN && url.protocol==='https:','invalid_origin',403);
  for (const header of ['origin','cookie','sec-fetch-site','sec-fetch-mode','sec-fetch-dest','x-user-id','x-club-id','x-africlub-user-id','x-africlub-club-id','x-actor-id'])
    need(!request.headers.has(header),'native_transport_required',403);
  need(request.headers.get('x-africlub-client')==='native-v1','native_transport_required',403);
  need(request.cf && typeof request.cf==='object' && !Array.isArray(request.cf),'ingress_unverified',403);
  const ip=request.headers.get('cf-connecting-ip');
  need(typeof ip==='string' && ip.length<=45 && /^[0-9a-fA-F:.]+$/.test(ip),'ingress_unverified',403);
  return ip;
}
export function token(request) {
  const value=request.headers.get('authorization');
  need(typeof value==='string' && /^Bearer [0-9a-f-]{36}\.[A-Za-z0-9_-]{43}$/.test(value),'unauthenticated',401);
  const result=value.slice(7),[sessionId,secret]=result.split('.');
  need(UUID.test(sessionId),'unauthenticated',401);
  try { const raw=atob(secret.replaceAll('-','+').replaceAll('_','/'));
    need(raw.length===32 && btoa(raw).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'')===secret,'unauthenticated',401);
  } catch { throw new GatewayError('unauthenticated',401); }
  return result;
}
export async function prepareBody(request,ms=LIMITS.bodyMs) {
  const type=request.headers.get('content-type')?.toLowerCase();
  need(type==='application/json'||type==='application/json; charset=utf-8','unsupported_media_type',415);
  need(!request.headers.has('content-encoding'),'unsupported_media_type',415);
  const length=request.headers.get('content-length');
  need(length===null || (/^[0-9]+$/.test(length)&&Number(length)<=LIMITS.bodyBytes),'payload_too_large',413);
  const reader=request.body?.getReader();need(reader,'invalid_request',400);
  const chunks=[];let total=0;
  try {
    const text=await bounded(async()=>{
      while(true){const {value,done}=await reader.read();if(done)break;total+=value.length;
        need(total<=LIMITS.bodyBytes,'payload_too_large',413);chunks.push(value);}
      need(length===null||Number(length)===total,'invalid_request',400);
      const bytes=new Uint8Array(total);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
      try{return new TextDecoder('utf-8',{fatal:true}).decode(bytes);}catch{throw new GatewayError('invalid_request',400);}
    },ms);
    // Canonical one-field JSON rejects duplicate keys and escaped alternate actors.
    const match=/^\s*\{\s*"tier"\s*:\s*"([a-z0-9][a-z0-9_-]{0,31})"\s*\}\s*$/.exec(text);
    need(match && TIER.test(match[1]),'invalid_request',400);return {tier:match[1]};
  } finally { reader.cancel().catch(()=>{});try{reader.releaseLock();}catch{} }
}
